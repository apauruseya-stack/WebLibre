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
    // Try every free source TablissNG uses, in order, until one yields an image.
    for (final resolver in <Future<String?> Function()>[
      _resolveBing,
      _resolveWikimedia,
      _resolveNasa,
    ]) {
      try {
        final url = await resolver();
        if (url != null && url.isNotEmpty) return url;
      } catch (e, s) {
        logger.w('Wallpaper source failed', error: e, stackTrace: s);
      }
    }
    return null;
  }

  Future<String?> _resolveBing() async {
    final response = await http.get(Uri.parse(_bingEndpoint));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final images = json['images'] as List<dynamic>?;
    final first = images?.first as Map<String, dynamic>?;
    final urlPath = first?['url'] as String?;
    if (urlPath == null || urlPath.isEmpty) return null;
    return urlPath.startsWith('http') ? urlPath : 'https://www.bing.com$urlPath';
  }

  Future<String?> _resolveWikimedia() async {
    // Wikimedia's picture of the day (free, no API key).
    final now = DateTime.now().toUtc();
    final endpoint =
        'https://en.wikipedia.org/api/rest_v1/feed/featured/'
        '${now.year}/${now.month.toString().padLeft(2, '0')}/'
        '${now.day.toString().padLeft(2, '0')}';
    final response = await http.get(Uri.parse(endpoint));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final image = json['image'] as Map<String, dynamic>?;
    final source = image?['source'] as String?;
    return (source != null && source.isNotEmpty) ? source : null;
  }

  Future<String?> _resolveNasa() async {
    // NASA Astronomy Picture of the Day (free DEMO_KEY, rate-limited).
    final response = await http.get(
      Uri.parse('https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY'),
    );
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final url = (json['hdurl'] ?? json['url']) as String?;
    return (url != null && url.isNotEmpty) ? url : null;
  }
}