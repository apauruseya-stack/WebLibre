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
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_mozilla_components/flutter_mozilla_components.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:weblibre/core/logger.dart';
import 'package:weblibre/features/geckoview/features/bookmarks/utils/bookmark_importer.dart';
import 'package:weblibre/features/profile_import/data/profile_import_service.dart';
import 'package:weblibre/features/profile_import/domain/models/import_bundle.dart';
import 'package:weblibre/l10n/generated/app_localizations.dart';

class ProfileImportScreen extends HookConsumerWidget {
  const ProfileImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = useState<ImportBundle?>(null);
    final parsing = useState(false);
    final importing = useState(false);
    final status = useState<String?>(null);

    Future<void> pick() async {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (result.isEmpty) return;
      final path = result.first.path;
      if (path == null) return;
      parsing.value = true;
      status.value = null;
      try {
        final parsed = await ProfileImportService().parseFile(path);
        bundle.value = parsed;
        if (parsed == null) {
          status.value = 'Could not detect a supported format.';
        }
      } catch (e, s) {
        logger.e('Import parse failed', error: e, stackTrace: s);
        status.value = 'Parse failed: $e';
      } finally {
        parsing.value = false;
      }
    }

    Future<void> apply() async {
      final b = bundle.value;
      if (b == null || b.bookmarks == null) return;
      importing.value = true;
      status.value = null;
      try {
        final service = GeckoBookmarksService();
        final importer = BookmarkTreeImporter(service);
        final count = await importer.import(
          b.bookmarks!,
          replace: false,
        );
        status.value = 'Imported $count bookmarks.';
      } catch (e, s) {
        logger.e('Import apply failed', error: e, stackTrace: s);
        status.value = 'Import failed: $e';
      } finally {
        importing.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('Import & migrate')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: parsing.value || importing.value ? null : pick,
              icon: const Icon(Icons.file_open),
              label: Text('Pick a profile file'),
            ),
            const SizedBox(height: 16),
            if (parsing.value) const CircularProgressIndicator(),
            if (bundle.value != null) ...[
              Text('Source: ${bundle.value!.sourceLabel}'),
              Text('Bookmarks: ${bundle.value!.bookmarkCount}'),
              if (bundle.value!.history.isNotEmpty)
                Text('History: ${bundle.value!.history.length} (not imported in this release)'),
              if (bundle.value!.tabs.isNotEmpty)
                Text('Tabs: ${bundle.value!.tabs.length} (not imported in this release)'),
              if (bundle.value!.addons.isNotEmpty)
                Text('Extensions: ${bundle.value!.addons.length} (not imported in this release)'),
              if (bundle.value!.issues.isNotEmpty)
                ...bundle.value!.issues.map((i) => Text('Issue: ${i.reason}')),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: importing.value || bundle.value!.bookmarks == null ? null : apply,
                child: importing.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Import bookmarks'),
              ),
            ],
            if (status.value != null) ...[
              const SizedBox(height: 16),
              Text(status.value!),
            ],
          ],
        ),
      ),
    );
  }
}
