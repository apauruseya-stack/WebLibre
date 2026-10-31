/*
 * Copyright (c) 2024-2026 Fabian Freund.
 *
 * This file is part of WebLibre
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
import 'package:flutter_mozilla_components/flutter_mozilla_components.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:weblibre/core/logger.dart';
import 'package:weblibre/features/geckoview/domain/providers.dart';
import 'package:weblibre/features/user/data/models/general_settings.dart';
import 'package:weblibre/features/user/domain/repositories/general_settings.dart';

part 'cookie_banner.g.dart';

/// Pushes the cookie banner mode to the built-in extension whenever the
/// setting changes.
///
/// Activated at app scope in `main.dart`, so a change made on the settings
/// screen reaches native even when no browser view is mounted. The extension
/// itself does the detection and the clicking; this only sets its limits.
@Riverpod(keepAlive: true)
class CookieBannerReplicationService extends _$CookieBannerReplicationService {
  final _service = GeckoCookieBannerService();

  @override
  void build() {
    ref.listen(
      generalSettingsWithDefaultsProvider,
      (previous, next) => _push(next),
      fireImmediately: true,
    );
  }

  Future<void> _push(GeneralSettings settings) async {
    try {
      await _service.setConfig(
        CookieBannerConfig(
          mode: switch (settings.cookieBannerHandling) {
            CookieBannerHandling.off => 'off',
            CookieBannerHandling.detect => 'detect',
            CookieBannerHandling.reject => 'reject',
            CookieBannerHandling.rejectOrHide => 'rejectOrHide',
          },
          siteModes: settings.cookieBannerSiteModes,
        ),
      );
    } catch (error, stackTrace) {
      // The engine may not be up yet on a cold start; the next settings change
      // or the next launch pushes it again.
      logger.w(
        'Failed to push cookie banner configuration',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// The latest cookie banner decision per site, newest event wins.
///
/// This is a display cache only. Losing it on a restart costs a status row, not
/// the decisions themselves: those live in the page and in the site's cookies.
@Riverpod(keepAlive: true)
class CookieBannerStatus extends _$CookieBannerStatus {
  @override
  Map<String, CookieBannerEventData> build() {
    final subscription = ref
        .watch(eventServiceProvider)
        .cookieBannerEvents
        .listen((event) {
          if (event.siteKey.isEmpty) {
            return;
          }
          state = {...state, event.siteKey: event};
        });

    ref.onDispose(subscription.cancel);

    return const {};
  }
}

/// The most recent decision for [host], if one was reported this session.
///
/// A parent-domain entry also matches its subdomains, so a decision recorded
/// for `example.com` still explains `www.example.com`.
@riverpod
CookieBannerEventData? cookieBannerStatusFor(Ref ref, String? host) {
  if (host == null || host.isEmpty) {
    return null;
  }

  final statuses = ref.watch(cookieBannerStatusProvider);
  final direct = statuses[host];
  if (direct != null) {
    return direct;
  }

  CookieBannerEventData? match;
  var matchLength = 0;
  for (final entry in statuses.entries) {
    if (host.endsWith('.${entry.key}') && entry.key.length > matchLength) {
      match = entry.value;
      matchLength = entry.key.length;
    }
  }

  return match;
}
