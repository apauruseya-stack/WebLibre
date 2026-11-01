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
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weblibre/features/geckoview/features/preferences/data/models/preference_setting.dart';
import 'package:weblibre/features/geckoview/features/tabs/utils/setting_groups_serializer.dart';

void main() {
  late Map<String, PreferenceSettingGroup> groups;

  setUpAll(() {
    final content =
        jsonDecode(File('assets/preferences/settings.json').readAsStringSync())
            as Map<String, dynamic>;
    groups = deserializePreferenceSettingGroups(
      PreferencePartition.user,
      content,
    );
  });

  PreferenceSetting? settingNamed(String name) {
    for (final group in groups.values) {
      final setting = group.settings[name];
      if (setting != null) {
        return setting;
      }
    }
    return null;
  }

  group('bundled settings.json', () {
    test('deserializes into preference groups', () {
      expect(groups, isNotEmpty);
      expect(
        groups.values.expand((group) => group.settings.entries),
        isNotEmpty,
      );
    });

    test('keeps Cloudflare challenges out of tracking protection', () {
      // Strict ETP includes the tracking-content list, which matches
      // cloudflare.com via parent-domain lookup. Without this exception the
      // Turnstile/challenge script from challenges.cloudflare.com is blocked
      // and protected sites loop on the challenge page forever.
      final setting = settingNamed('urlclassifier.trackingSkipURLs');

      expect(setting, isNotNull);
      expect(setting!.value, contains('*://challenges.cloudflare.com/*'));
      expect(setting.enforceOnStartup, isTrue);
      expect(setting.locked, isTrue);
    });
  });
}
