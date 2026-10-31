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
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:weblibre/features/settings/presentation/controllers/save_settings.dart';
import 'package:weblibre/features/user/data/models/general_settings.dart';
import 'package:weblibre/features/user/domain/repositories/general_settings.dart';

class CookieBannerRuleEditorScreen extends ConsumerWidget {
  const CookieBannerRuleEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(generalSettingsWithDefaultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cookie banner rules')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Disabled rules',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (settings.cookieBannerDisabledRules.isEmpty)
            const Text('None disabled.')
          else
            Wrap(
              spacing: 8,
              children: [
                for (final id in settings.cookieBannerDisabledRules)
                  Chip(
                    label: Text(id),
                    onDeleted: () async {
                      final next = List<String>.from(settings.cookieBannerDisabledRules)
                        ..remove(id);
                      await ref
                          .read(saveGeneralSettingsControllerProvider.notifier)
                          .save((s) => s.copyWith.cookieBannerDisabledRules(next));
                    },
                  ),
              ],
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final controller = TextEditingController();
              final result = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Disable a rule'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'rule id, e.g. cookiebot'),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Disable')),
                  ],
                ),
              );
              if (result != null && result.isNotEmpty) {
                final next = List<String>.from(settings.cookieBannerDisabledRules);
                if (!next.contains(result)) next.add(result);
                await ref
                    .read(saveGeneralSettingsControllerProvider.notifier)
                    .save((s) => s.copyWith.cookieBannerDisabledRules(next));
              }
            },
            icon: const Icon(Icons.block),
            label: const Text('Disable a rule by id'),
          ),
          const Divider(),
          Text(
            'Custom selectors per site',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final entry in settings.cookieBannerCustomSelectors.entries)
            ListTile(
              title: Text(entry.key),
              subtitle: Text(entry.value.join(', ')),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final next = Map<String, List<String>>.from(settings.cookieBannerCustomSelectors)
                    ..remove(entry.key);
                  await ref
                      .read(saveGeneralSettingsControllerProvider.notifier)
                      .save((s) => s.copyWith.cookieBannerCustomSelectors(next));
                },
              ),
            ),
          TextButton.icon(
            onPressed: () async {
              final hostController = TextEditingController();
              final selectorController = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Add custom selector'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: hostController,
                        decoration: const InputDecoration(hintText: 'host, e.g. example.com'),
                      ),
                      TextField(
                        controller: selectorController,
                        decoration: const InputDecoration(hintText: 'CSS selector to click'),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
                  ],
                ),
              );
              if (ok == true) {
                final host = hostController.text.trim();
                final selector = selectorController.text.trim();
                if (host.isEmpty || selector.isEmpty) return;
                final next = Map<String, List<String>>.from(settings.cookieBannerCustomSelectors);
                next[host] = [...(next[host] ?? const []), selector];
                await ref
                    .read(saveGeneralSettingsControllerProvider.notifier)
                    .save((s) => s.copyWith.cookieBannerCustomSelectors(next));
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add custom selector for a site'),
          ),
          const Divider(),
          TextButton.icon(
            onPressed: () async {
              final payload = jsonEncode({
                'disabledRules': settings.cookieBannerDisabledRules,
                'customSelectors': settings.cookieBannerCustomSelectors,
              });
              await Clipboard.setData(ClipboardData(text: payload));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard.')),
                );
              }
            },
            icon: const Icon(Icons.upload),
            label: const Text('Export overrides'),
          ),
          TextButton.icon(
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              final text = data?.text;
              if (text == null || text.isEmpty) return;
              try {
                final decoded = jsonDecode(text);
                if (decoded is Map<String, dynamic>) {
                  final disabled = (decoded['disabledRules'] as List?)?.cast<String>() ?? [];
                  final custom = <String, List<String>>{};
                  final raw = decoded['customSelectors'];
                  if (raw is Map) {
                    for (final e in raw.entries) {
                      if (e.value is List) {
                        custom[e.key.toString()] =
                            (e.value as List).map((x) => x.toString()).toList();
                      }
                    }
                  }
                  await ref
                      .read(saveGeneralSettingsControllerProvider.notifier)
                      .save((s) => s.copyWith(
                            cookieBannerDisabledRules: disabled,
                            cookieBannerCustomSelectors: custom,
                          ));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Overrides imported.')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Import failed: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Import overrides'),
          ),
        ],
      ),
    );
  }
}
