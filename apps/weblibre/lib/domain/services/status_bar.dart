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
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:weblibre/features/user/data/models/general_settings.dart';
import 'package:weblibre/features/user/domain/repositories/general_settings.dart';

part 'status_bar.g.dart';

/// Applies the configured system-UI mode.
///
/// Hiding uses [SystemUiMode.immersiveSticky] rather than
/// `SystemUiMode.manual` with only the bottom overlay: on Android 11+ with
/// edge-to-edge enabled, the manual mode is frequently re-shown by the
/// platform after a resume or a transient dialog. Immersive-sticky reliably
/// removes the status bar and lets the content draw to the very top edge.
Future<void> _applyStatusBarMode(bool hide) async {
  try {
    if (hide) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  } catch (_) {
    // Best-effort: ignore failures on platforms that don't support it.
  }
}

/// Re-applies the status bar mode when the app comes back to the foreground or
/// the window metrics change (rotation, multi-window, cutout changes).
///
/// Android restores the system bars after some transient dialogs, permission
/// prompts and the notification shade; without this the status bar would
/// silently reappear until the setting is toggled again.
class _StatusBarLifecycleObserver extends WidgetsBindingObserver {
  _StatusBarLifecycleObserver(this._readHidden);

  /// Reads the current setting instead of capturing it, so a toggle made after
  /// the observer was created is honoured on the next resume.
  final bool Function() _readHidden;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_applyStatusBarMode(_readHidden()));
    }
  }

  @override
  void didChangeMetrics() {
    unawaited(_applyStatusBarMode(_readHidden()));
  }
}

/// Always-mounted side-effect provider that hides (or shows) the status bar
/// according to the [GeneralSettings.hideStatusBar] setting.
@Riverpod(keepAlive: true)
void statusBarApplier(Ref ref) {
  bool readHidden() =>
      ref.read(generalSettingsWithDefaultsProvider).hideStatusBar;

  ref.listen(
    generalSettingsWithDefaultsProvider.select((s) => s.hideStatusBar),
    (_, hide) => unawaited(_applyStatusBarMode(hide)),
    fireImmediately: true,
  );

  final observer = _StatusBarLifecycleObserver(readHidden);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
}
