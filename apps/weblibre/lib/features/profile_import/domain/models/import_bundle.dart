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
import 'package:weblibre/features/geckoview/features/bookmarks/domain/entities/import_bookmark_node.dart';

/// Where a profile import came from.
enum ImportSource {
  chromeBookmarks,
  chromeHistory,
  firefoxPlaces,
  firefoxSessionStore,
  firefoxExtensions,
  chromePreferences,
  htmlBookmarks,
  firefoxJsonBookmarks,
  unknown,
}

/// A history entry imported from another browser.
@immutable
class ImportHistoryEntry {
  final Uri url;
  final String? title;
  final DateTime visitedAt;
  final int visitCount;

  const ImportHistoryEntry({
    required this.url,
    this.title,
    required this.visitedAt,
    this.visitCount = 1,
  });
}

/// An open tab imported from a foreign session store.
@immutable
class ImportTab {
  final Uri url;
  final String? title;

  const ImportTab({required this.url, this.title});
}

/// An extension found in a foreign profile.
@immutable
class ImportAddon {
  final String id;
  final String name;
  final String? version;

  const ImportAddon({required this.id, required this.name, this.version});
}

/// Something that could not be imported, with a reason.
@immutable
class ImportIssue {
  final String reason;
  final String? detail;

  const ImportIssue({required this.reason, this.detail});
}

/// The canonical result of parsing a foreign profile file.
@immutable
class ImportBundle {
  final ImportSource source;
  final String sourceLabel;
  final ImportBookmarkTree? bookmarks;
  final List<ImportHistoryEntry> history;
  final List<ImportTab> tabs;
  final List<ImportAddon> addons;
  final List<ImportIssue> issues;

  const ImportBundle({
    required this.source,
    required this.sourceLabel,
    this.bookmarks,
    this.history = const [],
    this.tabs = const [],
    this.addons = const [],
    this.issues = const [],
  });

  bool get isEmpty =>
      (bookmarks == null || bookmarks!.isEmpty) &&
      history.isEmpty &&
      tabs.isEmpty &&
      addons.isEmpty;

  int get bookmarkCount => bookmarks?.stats.bookmarkCount ?? 0;
}
