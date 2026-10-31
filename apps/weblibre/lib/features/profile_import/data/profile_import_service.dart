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
import 'dart:io';

import 'package:weblibre/features/profile_import/data/parsers.dart';
import 'package:weblibre/features/profile_import/domain/models/import_bundle.dart';

/// Detects the format of a picked file and parses it into an [ImportBundle].
///
/// Detection is by file name and content shape, never by trusting the
/// extension alone.
class ProfileImportService {
  const ProfileImportService();

  Future<ImportBundle?> parseFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final lower = path.toLowerCase();
    final name = path.split(Platform.pathSeparator).last.toLowerCase();

    // SQLite files (Chrome History, Firefox places.sqlite).
    if (name.endsWith('.sqlite') ||
        name.endsWith('.db') ||
        name == 'history' ||
        name == 'places.sqlite') {
      if (name.contains('places')) {
        return FirefoxPlacesParser.tryParsePath(path);
      }
      // Try Chrome history first.
      final history = ChromeHistoryParser.tryParsePath(path);
      if (history != null) {
        return ImportBundle(
          source: ImportSource.chromeHistory,
          sourceLabel: 'Chrome / Brave / Edge',
          history: history,
        );
      }
      return FirefoxPlacesParser.tryParsePath(path);
    }

    // JSON / text files.
    String text;
    try {
      text = await file.readAsString();
    } catch (_) {
      return null;
    }

    if (name == 'bookmarks' || lower.endsWith('bookmarks.json')) {
      final chrome = ChromeBookmarksParser.tryParse(text);
      if (chrome != null) return chrome;
    }
    if (name == 'preferences' || name == 'secure preferences') {
      final addons = ChromePreferencesParser.tryParse(text);
      if (addons != null) {
        return ImportBundle(
          source: ImportSource.chromePreferences,
          sourceLabel: 'Chrome / Brave / Edge',
          addons: addons,
        );
      }
    }
    if (name == 'extensions.json') {
      final addons = FirefoxExtensionsParser.tryParse(text);
      if (addons != null) {
        return ImportBundle(
          source: ImportSource.firefoxExtensions,
          sourceLabel: 'Firefox / Fennec / IronFox',
          addons: addons,
        );
      }
    }
    // Generic JSON shape detection.
    final chromeBm = ChromeBookmarksParser.tryParse(text);
    if (chromeBm != null) return chromeBm;
    final chromePrefs = ChromePreferencesParser.tryParse(text);
    if (chromePrefs != null) {
      return ImportBundle(
        source: ImportSource.chromePreferences,
        sourceLabel: 'Chrome / Brave / Edge',
        addons: chromePrefs,
      );
    }
    final ffExt = FirefoxExtensionsParser.tryParse(text);
    if (ffExt != null) {
      return ImportBundle(
        source: ImportSource.firefoxExtensions,
        sourceLabel: 'Firefox / Fennec / IronFox',
        addons: ffExt,
      );
    }

    // HTML bookmarks (Netscape) - delegate to existing util by returning a
    // bundle flagged as html; the screen will route to the existing importer.
    if (text.trimLeft().startsWith('<')) {
      return const ImportBundle(
        source: ImportSource.htmlBookmarks,
        sourceLabel: 'HTML bookmarks',
      );
    }

    return null;
  }
}
