/*
 * Copyright (c) 2024-2026 Fabian Freund.
 *
 * This file is part of Cat Browser
 * (see https://weblibre.eu).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_mozilla_components/flutter_mozilla_components.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:weblibre/core/providers/app_localizations.dart';
import 'package:weblibre/core/providers/router.dart';
import 'package:weblibre/domain/services/app_initialization.dart';
import 'package:weblibre/features/geckoview/domain/providers.dart';
import 'package:weblibre/features/sync/domain/entities/sync_repository_state.dart';
import 'package:weblibre/features/sync/domain/repositories/sync.dart';
import 'package:weblibre/features/user/data/models/general_settings.dart';
import 'package:weblibre/features/user/domain/repositories/general_settings.dart';
import 'package:weblibre/l10n/generated/app_localizations.dart';
import 'package:weblibre/presentation/utils/app_initialization_l10n.dart';
import 'package:weblibre/presentation/widgets/failure_widget.dart';
import 'package:weblibre/presentation/widgets/multi_finger_tap_guard.dart';
import 'package:weblibre/presentation/widgets/navigation_bar_style.dart';
import 'package:weblibre/utils/ui_helper.dart' as ui_helper;

class MainApp extends HookConsumerWidget {
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode? themeMode;
  final double uiScaleFactor;
  final bool disableAnimations;
  final Locale? locale;

  // Accessibility
  final TextScaleMode textScaleMode;
  final double textScaleFactor;
  final double maxSystemScale;
  final bool boldText;
  final ReduceMotionMode reduceMotionMode;

  const MainApp({
    required this.theme,
    required this.darkTheme,
    required this.themeMode,
    required this.uiScaleFactor,
    required this.disableAnimations,
    required this.locale,
    this.textScaleMode = TextScaleMode.system,
    this.textScaleFactor = 1.0,
    this.maxSystemScale = 1.5,
    this.boldText = false,
    this.reduceMotionMode = ReduceMotionMode.system,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initializationResult = ref.watch(appInitializationServiceProvider);
    final router = ref.watch(routerProvider);

    // The provider reads the system locale list only when it builds, and has
    // no binding of its own to hear that the list changed.
    useEffect(() {
      final observer = _LocaleChangeObserver(
        () => ref.invalidate(appLocalizationsProvider),
      );
      WidgetsBinding.instance.addObserver(observer);
      return () => WidgetsBinding.instance.removeObserver(observer);
    }, const []);

    return initializationResult.fold(
      (initializationState) {
        if (!initializationState.initialized) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            darkTheme: darkTheme,
            themeMode: themeMode,
            themeAnimationStyle: disableAnimations
                ? AnimationStyle.noAnimation
                : null,
            locale: locale,
            localeListResolutionCallback: resolveAppLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) {
              return _StatusBarInsetsOverride(
                child: _AppMediaQueryOverrides(
                  uiScaleFactor: uiScaleFactor,
                  disableAnimations: disableAnimations,
                  textScaleMode: textScaleMode,
                  textScaleFactor: textScaleFactor,
                  maxSystemScale: maxSystemScale,
                  boldText: boldText,
                  reduceMotionMode: reduceMotionMode,
                  child: NavigationBarStyle(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        if (initializationState.stage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              initializationState.stage!.label(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          themeAnimationStyle: disableAnimations
              ? AnimationStyle.noAnimation
              : null,
          locale: locale,
          localeListResolutionCallback: resolveAppLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router.value,
          builder: (context, child) {
            return _StatusBarInsetsOverride(
              child: _AppMediaQueryOverrides(
                uiScaleFactor: uiScaleFactor,
                disableAnimations: disableAnimations,
                textScaleMode: textScaleMode,
                textScaleFactor: textScaleFactor,
                maxSystemScale: maxSystemScale,
                boldText: boldText,
                reduceMotionMode: reduceMotionMode,
                child: NavigationBarStyle(
                  child: MultiFingerTapGuard(
                    child: _SyncEventListener(
                      child: _DownloadStoppedListener(
                        child: _StrictContainerBlockListener(
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      onFailure: (errorMessage) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          themeAnimationStyle: disableAnimations
              ? AnimationStyle.noAnimation
              : null,
          locale: locale,
          localeListResolutionCallback: resolveAppLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            return _StatusBarInsetsOverride(
              child: _AppMediaQueryOverrides(
                uiScaleFactor: uiScaleFactor,
                disableAnimations: disableAnimations,
                textScaleMode: textScaleMode,
                textScaleFactor: textScaleFactor,
                maxSystemScale: maxSystemScale,
                boldText: boldText,
                reduceMotionMode: reduceMotionMode,
                child: NavigationBarStyle(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);

              return Scaffold(
                appBar: AppBar(
                  title: Text(l10n.mainApp_initializationErrorTitle),
                ),
                body: Center(
                  child: FailureWidget(
                    title: l10n.mainApp_initializationErrorMessage,
                    exception: errorMessage.toString(),
                    onRetry: () async {
                      await ref
                          .read(appInitializationServiceProvider.notifier)
                          .reinitialize();
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DownloadStoppedListener extends HookConsumerWidget {
  final Widget child;

  const _DownloadStoppedListener({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadStoppedEvents = ref.watch(
      eventServiceProvider.select((service) => service.downloadStoppedEvents),
    );

    useOnStreamChange(
      downloadStoppedEvents,
      onData: (download) {
        final l10n = AppLocalizations.of(context);
        switch (download.status) {
          case DownloadStatus.completed:
            ui_helper.showInfoMessage(
              context,
              l10n.mainApp_downloadCompleted,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: l10n.common_open,
                onPressed: () async {
                  final opened = await GeckoDownloadsService()
                      .openDownloadedFile(
                        fileName: download.fileName ?? '',
                        directoryPath: download.directoryPath ?? '',
                        contentType: download.contentType,
                      );

                  if (!opened && context.mounted) {
                    ui_helper.showErrorMessage(
                      context,
                      AppLocalizations.of(context).mainApp_downloadOpenFailed,
                    );
                  }
                },
              ),
            );
          case DownloadStatus.failed:
            ui_helper.showErrorMessage(
              context,
              l10n.mainApp_downloadFailed(download.fileName ?? download.url),
              persist: true,
            );
          case DownloadStatus.initiated:
          case DownloadStatus.downloading:
          case DownloadStatus.paused:
          case DownloadStatus.cancelled:
          case null:
            break;
        }
      },
    );

    return child;
  }
}

/// Surfaces a snackbar when the container-proxy extension cancels a navigation
/// because the active tab's container is in strict mode (only assigned sites
/// may load). Strict blocks carry no destination container — the load was
/// already cancelled natively — so this listener only notifies the user.
class _StrictContainerBlockListener extends HookConsumerWidget {
  final Widget child;

  const _StrictContainerBlockListener({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siteAssignmentEvents = ref.watch(
      eventServiceProvider.select((service) => service.siteAssignementEvent),
    );

    useOnStreamChange(
      siteAssignmentEvents,
      onData: (event) {
        if (!event.strict) {
          return;
        }

        final host = Uri.tryParse(event.url)?.host;
        final l10n = AppLocalizations.of(context);
        ui_helper.showInfoMessage(
          context,
          host != null && host.isNotEmpty
              ? l10n.mainApp_containerBlockedWithHost(host)
              : l10n.mainApp_containerBlockedNoHost,
        );
      },
    );

    return child;
  }
}

MediaQueryData applyAppMediaQueryOverrides({
  required MediaQueryData mediaQuery,
  required double uiScaleFactor,
  required bool disableAnimations,
}) {
  final textScaler = uiScaleFactor == 1.0
      ? mediaQuery.textScaler
      : _AppTextScaler(
          baseTextScaler: mediaQuery.textScaler,
          uiScaleFactor: uiScaleFactor,
        );

  if (disableAnimations) {
    return mediaQuery.copyWith(textScaler: textScaler, disableAnimations: true);
  }

  if (uiScaleFactor == 1.0) {
    return mediaQuery;
  }

  return mediaQuery.copyWith(textScaler: textScaler);
}

/// Bridges [WidgetsBindingObserver.didChangeLocales] to a plain callback.
class _LocaleChangeObserver extends WidgetsBindingObserver {
  final VoidCallback onChanged;

  _LocaleChangeObserver(this.onChanged);

  @override
  void didChangeLocales(List<Locale>? locales) => onChanged();
}

/// Removes the top system-bar inset from [MediaQuery] while the status bar is
/// hidden, so fullscreen content really reaches the top edge of the screen
/// instead of leaving an empty strip where the status bar used to be.
class _StatusBarInsetsOverride extends ConsumerWidget {
  final Widget child;

  const _StatusBarInsetsOverride({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideStatusBar = ref.watch(
      generalSettingsWithDefaultsProvider.select((s) => s.hideStatusBar),
    );

    if (!hideStatusBar) {
      return child;
    }

    final mediaQuery = MediaQuery.of(context);

    return MediaQuery(
      data: mediaQuery.copyWith(
        padding: mediaQuery.padding.copyWith(top: 0),
        viewPadding: mediaQuery.viewPadding.copyWith(top: 0),
      ),
      child: child,
    );
  }
}

class _AppMediaQueryOverrides extends StatelessWidget {
  final double uiScaleFactor;
  final bool disableAnimations;
  final TextScaleMode textScaleMode;
  final double textScaleFactor;
  final double maxSystemScale;
  final bool boldText;
  final ReduceMotionMode reduceMotionMode;
  final Widget child;

  const _AppMediaQueryOverrides({
    required this.uiScaleFactor,
    required this.disableAnimations,
    this.textScaleMode = TextScaleMode.system,
    this.textScaleFactor = 1.0,
    this.maxSystemScale = 1.5,
    this.boldText = false,
    this.reduceMotionMode = ReduceMotionMode.system,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final systemScale = MediaQuery.textScalerOf(context).textScaleFactor;
    double effectiveScale = uiScaleFactor;

    switch (textScaleMode) {
      case TextScaleMode.system:
        effectiveScale = uiScaleFactor;
      case TextScaleMode.app:
        effectiveScale = textScaleFactor;
      case TextScaleMode.capped:
        final capped = systemScale.clamp(1.0, maxSystemScale);
        effectiveScale = uiScaleFactor * capped;
    }

    final motionDisabled = disableAnimations ||
        reduceMotionMode == ReduceMotionMode.on ||
        (reduceMotionMode == ReduceMotionMode.system &&
            MediaQuery.of(context).accessibleNavigation);

    if (effectiveScale == 1.0 && !motionDisabled && !boldText) {
      return child;
    }

    final mediaQuery = MediaQuery.of(context);
    final overridden = mediaQuery.copyWith(
      textScaler: (effectiveScale == 1.0 && textScaleMode == TextScaleMode.system)
          ? mediaQuery.textScaler
          : _AppTextScaler(
              baseTextScaler: mediaQuery.textScaler,
              uiScaleFactor: effectiveScale,
            ),
      boldText: boldText || mediaQuery.boldText,
      disableAnimations: motionDisabled,
    );

    return MediaQuery(data: overridden, child: child);
  }
}

class _AppTextScaler extends TextScaler {
  final TextScaler baseTextScaler;
  final double uiScaleFactor;

  const _AppTextScaler({
    required this.baseTextScaler,
    required this.uiScaleFactor,
  }) : assert(uiScaleFactor > 0);

  @override
  double scale(double fontSize) =>
      baseTextScaler.scale(fontSize) * uiScaleFactor;

  @override
  double get textScaleFactor => scale(1.0);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is _AppTextScaler &&
        baseTextScaler == other.baseTextScaler &&
        uiScaleFactor == other.uiScaleFactor;
  }

  @override
  int get hashCode => Object.hash(baseTextScaler, uiScaleFactor);
}

class _SyncEventListener extends ConsumerWidget {
  final Widget child;

  const _SyncEventListener({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(syncEventProvider, (previous, next) {
      if (next.isLoading || !next.hasValue) return;

      final event = next.value;
      if (event == null) return;

      final (syncEvent, syncError) = event;

      switch (syncEvent) {
        // case SyncEvent.completed:
        //   ui_helper.showInfoMessage(
        //     context,
        //     'Synchronization complete',
        //     duration: const Duration(seconds: 2),
        //   );
        case SyncEvent.error:
          ui_helper.showErrorMessage(
            context,
            syncError ?? AppLocalizations.of(context).mainApp_syncFailed,
          );
        case SyncEvent.started:
        case SyncEvent.completed:
        case null:
          break;
      }
    });

    return child;
  }
}
