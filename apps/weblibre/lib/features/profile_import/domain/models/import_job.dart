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

/// A single imported visit, kept only so it can be removed again.
///
/// Places identifies a visit by (url, timestamp), which is exactly what this
/// pair is. It is deliberately smaller than [ImportHistoryEntry]: an undo does
/// not need the title or visit count.
@immutable
class ImportHistoryRef {
  final String url;
  final int visitedAtMillis;

  const ImportHistoryRef({required this.url, required this.visitedAtMillis});

  /// Key used for deduplication and for the compact on-disk form.
  String get key => historyRefKey(url, visitedAtMillis);

  Map<String, dynamic> toJson() => {'u': url, 't': visitedAtMillis};

  factory ImportHistoryRef.fromJson(Map<String, dynamic> json) {
    return ImportHistoryRef(
      url: json['u'] as String? ?? '',
      visitedAtMillis: (json['t'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Stable identity of one Places visit.
String historyRefKey(String url, int visitedAtMillis) =>
    '$url\u0000$visitedAtMillis';

/// What a completed import wrote, so it can be undone exactly.
///
/// Only the *last* import is remembered. That is the useful granularity for
/// undo — the user notices a bad import immediately — and it keeps the stored
/// payload bounded without a growing journal.
@immutable
class ImportJob {
  /// Monotonic-ish identifier, also used as the file's identity.
  final String id;

  /// Human-readable source, e.g. "Chrome / Brave / Edge".
  final String sourceLabel;

  final DateTime importedAt;

  /// Title of the top-level folder the bookmarks were placed in, if any.
  ///
  /// Undo finds the folder by this exact title under the unfiled root and
  /// deletes it, so nothing outside the import is touched.
  final String? bookmarkFolderTitle;

  /// The visits written, in import order.
  final List<ImportHistoryRef> history;

  /// Whether existing bookmarks/history were erased before importing.
  ///
  /// Undo never tries to restore erased data; it removes only what this job
  /// added, and the UI warns before a replacing import.
  final bool replacedBookmarks;
  final bool replacedHistory;

  const ImportJob({
    required this.id,
    required this.sourceLabel,
    required this.importedAt,
    this.bookmarkFolderTitle,
    this.history = const [],
    this.replacedBookmarks = false,
    this.replacedHistory = false,
  });

  bool get isEmpty =>
      (bookmarkFolderTitle == null || bookmarkFolderTitle!.isEmpty) &&
      history.isEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': sourceLabel,
    'at': importedAt.millisecondsSinceEpoch,
    'folder': bookmarkFolderTitle,
    'history': [
      for (final ref in history) [ref.url, ref.visitedAtMillis],
    ],
    'replacedBookmarks': replacedBookmarks,
    'replacedHistory': replacedHistory,
  };

  factory ImportJob.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'];
    final history = <ImportHistoryRef>[];
    if (rawHistory is List) {
      for (final row in rawHistory) {
        if (row is List && row.length >= 2) {
          history.add(
            ImportHistoryRef(
              url: row[0]?.toString() ?? '',
              visitedAtMillis: (row[1] as num?)?.toInt() ?? 0,
            ),
          );
        }
      }
    }
    return ImportJob(
      id: json['id']?.toString() ?? '',
      sourceLabel: json['source']?.toString() ?? 'Unknown',
      importedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['at'] as num?)?.toInt() ?? 0,
      ),
      bookmarkFolderTitle: json['folder']?.toString(),
      history: history,
      replacedBookmarks: json['replacedBookmarks'] == true,
      replacedHistory: json['replacedHistory'] == true,
    );
  }
}
