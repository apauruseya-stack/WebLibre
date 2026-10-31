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
import 'package:flutter/foundation.dart';
import 'package:weblibre/features/profile_import/domain/models/import_bundle.dart';
import 'package:weblibre/features/profile_import/domain/models/import_job.dart';

/// Result of filtering a parsed history against itself and against Places.
@immutable
class HistoryImportPlan {
  /// Entries that still need to be written, in ascending visit order.
  final List<ImportHistoryEntry> entries;

  /// Entries dropped because the same (url, timestamp) was already in Places.
  final int alreadyPresent;

  /// Entries dropped because an earlier entry in the same file had the same
  /// (url, timestamp).
  final int duplicateInFile;

  const HistoryImportPlan({
    required this.entries,
    this.alreadyPresent = 0,
    this.duplicateInFile = 0,
  });

  int get total => entries.length + alreadyPresent + duplicateInFile;
}

/// Filters [incoming] so every (url, timestamp) is imported at most once.
///
/// [existingKeys] is the set of [historyRefKey] values already in Places for
/// the time range the import covers. Sorting by visit time makes a cancel or an
/// undo deterministic and lets Places index in insertion order.
HistoryImportPlan planHistoryImport({
  required List<ImportHistoryEntry> incoming,
  Set<String> existingKeys = const {},
}) {
  final seen = <String>{};
  final kept = <ImportHistoryEntry>[];
  var alreadyPresent = 0;
  var duplicateInFile = 0;

  for (final entry in incoming) {
    final key = historyRefKey(
      entry.url.toString(),
      entry.visitedAt.millisecondsSinceEpoch,
    );
    if (existingKeys.contains(key)) {
      alreadyPresent++;
      continue;
    }
    if (!seen.add(key)) {
      duplicateInFile++;
      continue;
    }
    kept.add(entry);
  }

  kept.sort((a, b) => a.visitedAt.compareTo(b.visitedAt));

  return HistoryImportPlan(
    entries: kept,
    alreadyPresent: alreadyPresent,
    duplicateInFile: duplicateInFile,
  );
}
