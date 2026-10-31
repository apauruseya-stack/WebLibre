/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package eu.weblibre.flutter_mozilla_components.api

import eu.weblibre.flutter_mozilla_components.feature.CookieBannerFeature
import eu.weblibre.flutter_mozilla_components.pigeons.CookieBannerConfig
import eu.weblibre.flutter_mozilla_components.pigeons.GeckoCookieBannerApi

class GeckoCookieBannerApiImpl : GeckoCookieBannerApi {
    override suspend fun setConfig(config: CookieBannerConfig) {
        CookieBannerFeature.setConfig(config)
    }

    override suspend fun setRules(rulesJson: String) {
        CookieBannerFeature.setRules(rulesJson)
    }
}
