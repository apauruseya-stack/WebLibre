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
import 'package:flutter_test/flutter_test.dart';
import 'package:weblibre/features/profile_import/domain/import_planner.dart';
import 'package:weblibre/features/profile_import/domain/models/import_bundle.dart';
import 'package:weblibre/features/profile_import/domain/models/import_job.dart';

ImportHistoryEntry _entry(String url, int millis) => ImportHistoryEntry(
  url: Uri.parse(url),
  title: url,
  visitedAt: DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
);

void main() {
  group('planHistoryImport', () {
    test('keeps distinct visits and sorts them by time', () {
      final plan = planHistoryImport(
        incoming: [
          _entry('https://b.example', 2000),
          _entry('https://a.example', 1000),
        ],
      );

      expect(plan.entries.map((e) => e.url.toString()), [
        'https://a.example',
        'https://b.example',
      ]);
      expect(plan.alreadyPresent, 0);
      expect(plan.duplicateInFile, 0);
    });

    test('drops a repeated (url, timestamp) inside the file once', () {
      final plan = planHistoryImport(
        incoming: [
          _entry('https://a.example', 1000),
          _entry('https://a.example', 1000),
          _entry('https://a.example', 2000),
        ],
      );

      expect(plan.entries.length, 2);
      expect(plan.duplicateInFile, 1);
    });

    test('skips visits already present in Places', () {
      final existing = {
        historyRefKey('https://a.example', 1000),
      };
      final plan = planHistoryImport(
        incoming: [
          _entry('https://a.example', 1000),
          _entry('https://a.example', 2000),
        ],
        existingKeys: existing,
      );

      expect(plan.entries.length, 1);
      expect(plan.alreadyPresent, 1);
    });

    test('same url at a different timestamp is not a duplicate', () {
      final plan = planHistoryImport(
        incoming: [
          _entry('https://a.example', 1000),
          _entry('https://a.example', 1001),
        ],
      );

      expect(plan.entries.length, 2);
    });

    test('an empty file plans nothing', () {
      final plan = planHistoryImport(incoming: const []);
      expect(plan.entries, isEmpty);
      expect(plan.total, 0);
    });
  });

  group('ImportJob', () {
    test('round-trips through JSON with history intact', () {
      final job = ImportJob(
        id: 'job-1',
        sourceLabel: 'Chrome / Brave / Edge',
        importedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        bookmarkFolderTitle: 'Imported from Chrome (2026-10-31)',
        history: const [
          ImportHistoryRef(url: 'https://a.example', visitedAtMillis: 1000),
          ImportHistoryRef(url: 'https://b.example', visitedAtMillis: 2000),
        ],
        replacedBookmarks: true,
        replacedHistory: false,
      );

      final restored = ImportJob.fromJson(job.toJson());

      expect(restored.id, job.id);
      expect(restored.sourceLabel, job.sourceLabel);
      expect(restored.importedAt, job.importedAt);
      expect(restored.bookmarkFolderTitle, job.bookmarkFolderTitle);
      expect(restored.replacedBookmarks, isTrue);
      expect(restored.replacedHistory, isFalse);
      expect(restored.history.length, 2);
      expect(restored.history.first.url, 'https://a.example');
      expect(restored.history.last.visitedAtMillis, 2000);
    });

    test('a job with no bookmarks and no history is empty', () {
      final job = ImportJob(
        id: 'job-2',
        sourceLabel: 'Unknown',
        importedAt: DateTime.now(),
      );
      expect(job.isEmpty, isTrue);
    });

    test('a job with only a bookmark folder is not empty', () {
      final job = ImportJob(
        id: 'job-3',
        sourceLabel: 'Chrome',
        importedAt: DateTime.now(),
        bookmarkFolderTitle: 'Imported from Chrome (2026-10-31)',
      );
      expect(job.isEmpty, isFalse);
    });
  });
}
