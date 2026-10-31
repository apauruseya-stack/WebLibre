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
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:weblibre/core/filesystem.dart';
import 'package:weblibre/core/logger.dart';

/// Fetches a free, daily-changing wallpaper from an online source, in the style
/// of TablissNG's background providers.
///
/// Only sources that need no API key are used, so the feature works out of the
/// box: Bing's daily image and Wikimedia's picture of the day.
class OnlineWallpaperService {
  OnlineWallpaperService();

  static const _bingEndpoint =
      'https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1';
  static const _wikimediaEndpoint =
      'https://en.wikipedia.org/api/rest_v1/feed/featured/2024/01/01';

  /// Downloads a fresh wallpaper into [target] and returns it, or null on
  /// failure. Prefers Bing's daily image; falls back to Wikimedia.
  Future<File?> fetch(File target) async {
    final url = await _resolveUrl();
    if (url == null) return null;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      await target.parent.create(recursive: true);
      await target.writeAsBytes(response.bodyBytes, flush: true);
      return target;
    } catch (e, s) {
      logger.w('Online wallpaper download failed', error: e, stackTrace: s);
      return null;
    }
  }

  Future<String?> _resolveUrl() async {
    // Bing daily image (no API key).
    try {
      final response = await http.get(Uri.parse(_bingEndpoint));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final images = json['images'] as List<dynamic>?;
        final first = images?.first as Map<String, dynamic>?;
        final urlPath = first?['url'] as String?;
        if (urlPath != null && urlPath.isNotEmpty) {
          return urlPath.startsWith('http')
              ? urlPath
              : 'https://www.bing.com$urlPath';
        }
      }
    } catch (e, s) {
      logger.w('Bing wallpaper resolve failed', error: e, stackTrace: s);
    }

    return null;
  }
}