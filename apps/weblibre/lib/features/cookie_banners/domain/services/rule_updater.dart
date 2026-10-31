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

import 'package:crypto/crypto.dart';
import 'package:flutter_mozilla_components/flutter_mozilla_components.dart';
import 'package:http/http.dart' as http;
import 'package:weblibre/core/logger.dart';

/// Fetches an updated rule pack, verifies its SHA-256 against a pinned value,
/// and pushes it to the built-in extension. Nothing is applied unless the
/// hash matches.
class CookieBannerRuleUpdater {
  /// Pinned SHA-256 of the current official rule pack. Empty disables updates.
  static const String pinnedHash = '';

  final GeckoCookieBannerService _service;

  CookieBannerRuleUpdater({GeckoCookieBannerService? service})
    : _service = service ?? GeckoCookieBannerService();

  Future<bool> checkAndUpdate(String url) async {
    if (url.isEmpty || pinnedHash.isEmpty) {
      return false;
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return false;
      final body = response.body;
      final digest = sha256.convert(utf8.encode(body)).toString();
      if (digest != pinnedHash) {
        logger.w('Rule pack hash mismatch: $digest != $pinnedHash');
        return false;
      }
      await _service.setRules(body);
      return true;
    } catch (e, s) {
      logger.w('Rule update failed', error: e, stackTrace: s);
      return false;
    }
  }
}
