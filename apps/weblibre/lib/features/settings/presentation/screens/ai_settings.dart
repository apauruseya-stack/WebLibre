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
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:weblibre/features/settings/presentation/controllers/save_settings.dart';
import 'package:weblibre/features/user/data/models/general_settings.dart';
import 'package:weblibre/features/user/domain/repositories/general_settings.dart';

class AiSettingsScreen extends HookConsumerWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(generalSettingsWithDefaultsProvider);

    Future<void> save(GeneralSettings Function(GeneralSettings) update) async {
      await ref
          .read(saveGeneralSettingsControllerProvider.notifier)
          .save((current) => update(current));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI (on-device)')),
      body: ListView(
        children: [
          SwitchListTile.adaptive(
            title: const Text('Enable local AI features'),
            subtitle: const Text('Master switch. All AI runs on this device.'),
            value: settings.enableLocalAiFeatures,
            onChanged: (v) => save((s) => s.copyWith.enableLocalAiFeatures(v)),
          ),
          const Divider(),
          SwitchListTile.adaptive(
            title: const Text('Page summarization'),
            subtitle: const Text('Summarize pages with citations.'),
            value: settings.aiSummarize,
            onChanged: settings.enableLocalAiFeatures
                ? (v) => save((s) => s.copyWith.aiSummarize(v))
                : null,
          ),
          SwitchListTile.adaptive(
            title: const Text('Tab comparison'),
            subtitle: const Text('Compare 2-5 open tabs.'),
            value: settings.aiTabCompare,
            onChanged: settings.enableLocalAiFeatures
                ? (v) => save((s) => s.copyWith.aiTabCompare(v))
                : null,
          ),
          SwitchListTile.adaptive(
            title: const Text('Semantic search'),
            subtitle: const Text('Search history/bookmarks/feeds by meaning.'),
            value: settings.aiSemanticSearch,
            onChanged: settings.enableLocalAiFeatures
                ? (v) => save((s) => s.copyWith.aiSemanticSearch(v))
                : null,
          ),
          SwitchListTile.adaptive(
            title: const Text('Feed triage'),
            subtitle: const Text('Rank feeds by interest (chronological stays default).'),
            value: settings.aiFeedTriage,
            onChanged: settings.enableLocalAiFeatures
                ? (v) => save((s) => s.copyWith.aiFeedTriage(v))
                : null,
          ),
          const Divider(),
          ListTile(
            title: const Text('Models'),
            subtitle: const Text('Download, verify and delete models. Nothing downloads without consent.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Models are not bundled in the APK. Download them from Settings -> AI -> Models. '
              'Inference works offline after download. Page content never leaves this device.',
            ),
          ),
        ],
      ),
    );
  }
}
