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
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_mozilla_components/flutter_mozilla_components.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:weblibre/core/logger.dart';
import 'package:weblibre/features/geckoview/features/bookmarks/domain/entities/import_bookmark_node.dart';
import 'package:weblibre/features/geckoview/features/bookmarks/utils/bookmark_importer.dart';
import 'package:weblibre/features/profile_import/data/import_job_store.dart';
import 'package:weblibre/features/profile_import/data/profile_import_service.dart';
import 'package:weblibre/features/profile_import/domain/import_planner.dart';
import 'package:weblibre/features/profile_import/domain/models/import_bundle.dart';
import 'package:weblibre/features/profile_import/domain/models/import_job.dart';

/// How many visits travel in one platform-channel message.
///
/// Large enough that a 50k import is ~50 round trips, small enough that a
/// cancelled batch is cheap to roll back and the UI can breathe between them.
const _historyBatchSize = 1000;

class ProfileImportScreen extends HookConsumerWidget {
  const ProfileImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = useState<ImportBundle?>(null);
    final lastJob = useState<ImportJob?>(null);
    final parsing = useState(false);
    final importing = useState(false);
    final undoing = useState(false);
    final cancelRequested = useRef(false);
    final progress = useState<double?>(null);
    final phase = useState<String?>(null);
    final status = useState<String?>(null);
    final replaceBookmarks = useState(false);
    final replaceHistory = useState(false);

    useEffect(() {
      unawaited(() async {
        final job = await const ImportJobStore().load();
        if (job != null) lastJob.value = job;
      }());
      return null;
    }, const []);

    Future<void> pick() async {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result.isEmpty) return;
      final path = result.first.path;
      if (path == null) return;
      parsing.value = true;
      status.value = null;
      try {
        final parsed = await const ProfileImportService().parseFile(path);
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
      if (b == null) return;

      final historyService = GeckoHistoryService();
      final bookmarkService = GeckoBookmarksService();
      final importedRefs = <ImportHistoryRef>[];
      String? folderTitle;
      var cancelled = false;

      cancelRequested.value = false;
      importing.value = true;
      status.value = null;
      phase.value = 'Preparing';

      try {
        final bookmarks = b.bookmarks;
        if (bookmarks != null && !bookmarks.isEmpty) {
          phase.value = 'Importing bookmarks';
          folderTitle = _topLevelFolderTitle(bookmarks);
          await BookmarkTreeImporter(bookmarkService).import(
            bookmarks,
            replace: replaceBookmarks.value,
          );
        }

        if (b.history.isNotEmpty) {
          if (replaceHistory.value) {
            phase.value = 'Clearing existing history';
            await historyService.deleteEverything();
          }

          phase.value = 'Checking for duplicates';
          final plan = await _planHistory(b, historyService);
          final entries = plan.entries;
          final total = entries.length;

          phase.value = 'Importing history';
          progress.value = 0;

          for (var i = 0; i < total; i += _historyBatchSize) {
            if (cancelRequested.value) {
              cancelled = true;
              break;
            }
            final end = (i + _historyBatchSize).clamp(0, total);
            final slice = entries.sublist(i, end);
            final visits = [
              for (final entry in slice)
                VisitImport(
                  url: entry.url.toString(),
                  title: entry.title,
                  visitedAtMillis: entry.visitedAt.millisecondsSinceEpoch,
                  visitCount: entry.visitCount,
                ),
            ];
            await historyService.importVisits(visits);
            importedRefs.addAll(
              slice.map(
                (entry) => ImportHistoryRef(
                  url: entry.url.toString(),
                  visitedAtMillis: entry.visitedAt.millisecondsSinceEpoch,
                ),
              ),
            );
            progress.value = end / total;
          }

          if (cancelled) {
            phase.value = 'Rolling back';
            await _deleteHistory(historyService, importedRefs);
            if (folderTitle != null) {
              await _deleteBookmarkFolder(bookmarkService, folderTitle);
            }
            status.value =
                'Import cancelled. Nothing was kept, including bookmarks.';
            return;
          }

          if (plan.alreadyPresent > 0 || plan.duplicateInFile > 0) {
            status.value =
                'Imported ${importedRefs.length} history entries. '
                'Skipped ${plan.alreadyPresent} already present and '
                '${plan.duplicateInFile} duplicate entries.';
          } else {
            status.value = 'Imported ${importedRefs.length} history entries.';
          }
        } else if (!(b.bookmarks?.isEmpty ?? true)) {
          status.value = 'Bookmarks imported.';
        }

        final job = ImportJob(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sourceLabel: b.sourceLabel,
          importedAt: DateTime.now(),
          bookmarkFolderTitle: folderTitle,
          history: importedRefs,
          replacedBookmarks: replaceBookmarks.value,
          replacedHistory: replaceHistory.value,
        );
        await const ImportJobStore().save(job);
        lastJob.value = job.isEmpty ? null : job;
      } catch (e, s) {
        logger.e('Import apply failed', error: e, stackTrace: s);
        // Best effort: leave nothing half-written behind.
        await _deleteHistory(historyService, importedRefs);
        if (folderTitle != null) {
          await _deleteBookmarkFolder(bookmarkService, folderTitle);
        }
        status.value = 'Import failed: $e';
      } finally {
        importing.value = false;
        progress.value = null;
        phase.value = null;
      }
    }

    Future<void> undo() async {
      final job = lastJob.value;
      if (job == null) return;
      undoing.value = true;
      status.value = null;
      try {
        final historyService = GeckoHistoryService();
        await _deleteHistory(historyService, job.history);

        if (job.bookmarkFolderTitle != null) {
          await _deleteBookmarkFolder(
            GeckoBookmarksService(),
            job.bookmarkFolderTitle!,
          );
        }

        await const ImportJobStore().clear();
        lastJob.value = null;
        status.value =
            'Import undone. Removed ${job.history.length} history entries'
            '${job.bookmarkFolderTitle == null ? '' : ' and the imported bookmark folder'}.';
      } catch (e, s) {
        logger.e('Import undo failed', error: e, stackTrace: s);
        status.value = 'Undo failed: $e';
      } finally {
        undoing.value = false;
      }
    }

    final b = bundle.value;
    final busy = importing.value || undoing.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Import & migrate')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (lastJob.value != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text('Last import: ${lastJob.value!.sourceLabel}'),
                subtitle: Text(
                  '${lastJob.value!.history.length} history entries'
                  '${lastJob.value!.bookmarkFolderTitle == null ? '' : ', bookmarks'}'
                  ' · ${_formatDate(lastJob.value!.importedAt)}',
                ),
                trailing: TextButton(
                  onPressed: busy ? null : undo,
                  child: const Text('Undo'),
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: busy || parsing.value ? null : pick,
            icon: const Icon(Icons.file_open),
            label: const Text('Pick a profile file'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Supported: Chrome / Brave / Edge bookmarks JSON and History SQLite, '
            'Firefox places.sqlite and extensions.json, Chrome Preferences.',
            style: TextStyle(fontSize: 12),
          ),
          if (parsing.value) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (b != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Source: ${b.sourceLabel}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Bookmarks: ${b.bookmarkCount}'),
                    Text('History: ${b.history.length}'),
                    if (b.tabs.isNotEmpty)
                      Text('Tabs: ${b.tabs.length} (coming in a later release)'),
                    if (b.addons.isNotEmpty)
                      Text(
                        'Extensions: ${b.addons.length} (coming in a later release)',
                      ),
                    if (b.issues.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final issue in b.issues)
                        Text(
                          'Issue: ${issue.reason}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            if (!(b.bookmarks?.isEmpty ?? true))
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Replace existing bookmarks'),
                subtitle: const Text(
                  'Deletes every bookmark before importing. This cannot be undone.',
                ),
                value: replaceBookmarks.value,
                onChanged: busy
                    ? null
                    : (value) => replaceBookmarks.value = value,
              ),
            if (b.history.isNotEmpty)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Replace existing history'),
                subtitle: const Text(
                  'Deletes every history entry before importing. This cannot be undone.',
                ),
                value: replaceHistory.value,
                onChanged: busy ? null : (value) => replaceHistory.value = value,
              ),
            const SizedBox(height: 8),
            if (importing.value) ...[
              LinearProgressIndicator(value: progress.value),
              const SizedBox(height: 4),
              Text(
                phase.value ?? 'Importing',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => cancelRequested.value = true,
                icon: const Icon(Icons.stop),
                label: const Text('Cancel import'),
              ),
            ] else
              FilledButton.icon(
                onPressed: b.isEmpty || busy ? null : apply,
                icon: const Icon(Icons.download),
                label: const Text('Import'),
              ),
          ],
          if (status.value != null) ...[
            const SizedBox(height: 16),
            Text(status.value!),
          ],
        ],
      ),
    );
  }

  Future<HistoryImportPlan> _planHistory(
    ImportBundle bundle,
    GeckoHistoryService service,
  ) async {
    final entries = bundle.history;
    if (entries.isEmpty) {
      return const HistoryImportPlan(entries: []);
    }
    final min = entries
        .map((e) => e.visitedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final max = entries
        .map((e) => e.visitedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    // A fresh install answers with an empty list; a populated one returns only
    // the visits inside this import's own time range, which is what a dedupe
    // check needs.
    final existing = await service.getDetailedVisits(
      min.subtract(const Duration(seconds: 1)),
      max.add(const Duration(seconds: 1)),
      VisitType.values.toSet(),
    );
    final existingKeys = {
      for (final visit in existing) historyRefKey(visit.url, visit.visitTime),
    };
    return planHistoryImport(
      incoming: entries,
      existingKeys: existingKeys,
    );
  }

  Future<void> _deleteHistory(
    GeckoHistoryService service,
    List<ImportHistoryRef> refs,
  ) async {
    for (var i = 0; i < refs.length; i += _historyBatchSize) {
      final end = (i + _historyBatchSize).clamp(0, refs.length);
      await service.deleteVisits([
        for (final ref in refs.sublist(i, end))
          VisitImport(
            url: ref.url,
            title: null,
            visitedAtMillis: ref.visitedAtMillis,
            visitCount: 1,
          ),
      ]);
    }
  }

  Future<void> _deleteBookmarkFolder(
    GeckoBookmarksService service,
    String title,
  ) async {
    for (final root in const [BookmarkRoot.unfiled, BookmarkRoot.root]) {
      final tree = await service.getTree(root.id, recursive: true);
      final folder = _findFolder(tree, title);
      if (folder != null) {
        await service.deleteNode(folder.guid);
        return;
      }
    }
  }

  BookmarkNode? _findFolder(BookmarkNode? node, String title) {
    if (node == null) return null;
    if (node.type == BookmarkNodeType.folder && node.title == title) {
      return node;
    }
    for (final child in node.children ?? const <BookmarkNode>[]) {
      final found = _findFolder(child, title);
      if (found != null) return found;
    }
    return null;
  }

  String? _topLevelFolderTitle(ImportBookmarkTree tree) {
    for (final nodes in tree.sections.values) {
      for (final node in nodes) {
        if (node is ImportBookmarkFolder) return node.title;
      }
    }
    return null;
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
