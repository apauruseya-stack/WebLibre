/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

import 'package:flutter_mozilla_components/src/pigeons/gecko.g.dart';

/// Pushes the cookie banner handling mode to the native side.
///
/// The built-in extension owns detection and clicking. This service only tells
/// it how far it may go.
class GeckoCookieBannerService {
  final GeckoCookieBannerApi _api;

  GeckoCookieBannerService({GeckoCookieBannerApi? api})
    : _api = api ?? GeckoCookieBannerApi();

  Future<void> setConfig(CookieBannerConfig config) => _api.setConfig(config);

  Future<void> setRules(String rulesJson) => _api.setRules(rulesJson);
}
