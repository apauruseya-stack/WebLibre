/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package eu.weblibre.flutter_mozilla_components.feature

import eu.weblibre.flutter_mozilla_components.ext.EventSequence
import eu.weblibre.flutter_mozilla_components.pigeons.CookieBannerConfig
import eu.weblibre.flutter_mozilla_components.pigeons.CookieBannerEventData
import eu.weblibre.flutter_mozilla_components.pigeons.GeckoStateEvents
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import mozilla.components.concept.engine.webextension.MessageHandler
import mozilla.components.concept.engine.webextension.Port
import mozilla.components.concept.engine.webextension.WebExtensionRuntime
import mozilla.components.support.base.log.logger.Logger
import mozilla.components.support.webextensions.BuiltInWebExtensionController
import org.json.JSONObject

/**
 * Hosts the built-in cookie banner extension and bridges it to Dart.
 *
 * The extension does the detection and clicking; this class only forwards the
 * user's mode and the per-site overrides to it, and turns its reports into
 * events. It never decides on its own that a banner may be accepted.
 */
object CookieBannerFeature {
    private val logger = Logger("CookieBanner")

    private const val EXTENSION_ID = "cookie-banner@weblibre.eu"
    private const val EXTENSION_URL =
        "resource://android/assets/extensions/cookie_banner/"
    private const val NATIVE_PORT_NAME = "cookieBanner"

    @Volatile
    private var config: CookieBannerConfig? = null

    @Volatile
    private var stateEvents: GeckoStateEvents? = null

    private val extensionController = BuiltInWebExtensionController(
        EXTENSION_ID,
        EXTENSION_URL,
        NATIVE_PORT_NAME,
    )

    fun install(runtime: WebExtensionRuntime, events: GeckoStateEvents) {
        stateEvents = events
        extensionController.registerBackgroundMessageHandler(
            BackgroundMessageHandler(),
        )
        extensionController.install(
            runtime,
            onSuccess = {
                logger.debug("Installed cookie banner extension: ${it.id}")
                pushConfig()
            },
            onError = { throwable ->
                logger.error("Failed to install cookie banner extension", throwable)
            },
        )
    }

    fun setConfig(newConfig: CookieBannerConfig) {
        config = newConfig
        pushConfig()
    }

    fun setRules(rulesJson: String) {
        val message = JSONObject().apply {
            put("type", "rules")
            put("rules", rulesJson)
        }
        runBlocking {
            withContext(Dispatchers.Default) {
                try {
                    extensionController.sendBackgroundMessage(message)
                } catch (error: Throwable) {
                    logger.debug("Cookie banner rules not delivered yet", error)
                }
            }
        }
    }

    /**
     * Sends the current mode to the background page. Called again when the
     * background connects, which is the first moment a message can land.
     */
    private fun pushConfig() {
        val current = config ?: return

        val message = JSONObject().apply {
            put("type", "config")
            put("mode", current.mode)
            put("siteModes", JSONObject(current.siteModes as Map<*, *>))
        }

        runBlocking {
            withContext(Dispatchers.Default) {
                try {
                    extensionController.sendBackgroundMessage(message)
                } catch (error: Throwable) {
                    // The background page may not be up yet; onPortConnected
                    // pushes the same configuration once it is.
                    logger.debug("Cookie banner config not delivered yet", error)
                }
            }
        }
    }

    private class BackgroundMessageHandler : MessageHandler {
        override fun onPortConnected(port: Port) {
            logger.debug("Cookie banner native port connected")
            pushConfig()
        }

        override fun onPortMessage(message: Any, port: Port) {
            val json = message as? JSONObject ?: return
            if (json.optString("type") != "event") {
                return
            }

            val event = json.optJSONObject("event") ?: return
            val action = event.optString("action")
            if (action.isEmpty()) {
                return
            }

            val data = CookieBannerEventData(
                url = event.optString("url"),
                siteKey = event.optString("siteKey"),
                action = action,
                ruleId = event.optString("ruleId").ifEmpty { null },
                confidence = if (event.has("confidence")) {
                    event.optDouble("confidence")
                } else {
                    null
                },
                occurredAtMs = event.optLong(
                    "occurredAtMs",
                    System.currentTimeMillis(),
                ),
            )

            stateEvents?.onCookieBannerEvent(EventSequence.next(), data) {}
        }
    }
}
