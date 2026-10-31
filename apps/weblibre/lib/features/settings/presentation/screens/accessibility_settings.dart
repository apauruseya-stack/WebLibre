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
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:weblibre/features/settings/presentation/controllers/save_settings.dart';
import 'package:weblibre/features/user/data/models/general_settings.dart';
import 'package:weblibre/features/user/domain/repositories/general_settings.dart';

class AccessibilitySettingsScreen extends HookConsumerWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(generalSettingsWithDefaultsProvider);

    Future<void> save(GeneralSettings Function(GeneralSettings) update) async {
      await ref
          .read(saveGeneralSettingsControllerProvider.notifier)
          .save((current) => update(current));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: ListView(
        children: [
          ListTile(title: const Text('Text scale mode')),
          SegmentedButton<TextScaleMode>(
            segments: const [
              ButtonSegment(value: TextScaleMode.system, label: Text('System')),
              ButtonSegment(value: TextScaleMode.app, label: Text('App')),
              ButtonSegment(value: TextScaleMode.capped, label: Text('Capped')),
            ],
            selected: {settings.textScaleMode},
            onSelectionChanged: (v) => save((s) => s.copyWith.textScaleMode(v.first)),
          ),
          ListTile(
            title: const Text('App text scale'),
            subtitle: Text(settings.textScaleFactor.toStringAsFixed(2)),
          ),
          Slider(
            value: settings.textScaleFactor,
            min: 0.5,
            max: 2.0,
            divisions: 30,
            label: settings.textScaleFactor.toStringAsFixed(2),
            onChanged: (v) => save((s) => s.copyWith.textScaleFactor(v)),
          ),
          SwitchListTile.adaptive(
            title: const Text('Bold text'),
            value: settings.boldText,
            onChanged: (v) => save((s) => s.copyWith.boldText(v)),
          ),
          ListTile(title: const Text('High contrast')),
          SegmentedButton<HighContrastMode>(
            segments: const [
              ButtonSegment(value: HighContrastMode.system, label: Text('System')),
              ButtonSegment(value: HighContrastMode.on, label: Text('On')),
              ButtonSegment(value: HighContrastMode.off, label: Text('Off')),
            ],
            selected: {settings.highContrastMode},
            onSelectionChanged: (v) =>
                save((s) => s.copyWith.highContrastMode(v.first)),
          ),
          SwitchListTile.adaptive(
            title: const Text('Large touch targets'),
            value: settings.largeTouchTargets,
            onChanged: (v) => save((s) => s.copyWith.largeTouchTargets(v)),
          ),
          SwitchListTile.adaptive(
            title: const Text('Show focus ring'),
            value: settings.showFocusRing,
            onChanged: (v) => save((s) => s.copyWith.showFocusRing(v)),
          ),
          ListTile(title: const Text('Reduce motion')),
          SegmentedButton<ReduceMotionMode>(
            segments: const [
              ButtonSegment(value: ReduceMotionMode.system, label: Text('System')),
              ButtonSegment(value: ReduceMotionMode.on, label: Text('On')),
              ButtonSegment(value: ReduceMotionMode.off, label: Text('Off')),
            ],
            selected: {settings.reduceMotionMode},
            onSelectionChanged: (v) =>
                save((s) => s.copyWith.reduceMotionMode(v.first)),
          ),
        ],
      ),
    );
  }
}
