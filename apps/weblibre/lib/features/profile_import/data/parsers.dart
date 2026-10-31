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

import 'package:flutter_mozilla_components/flutter_mozilla_components.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:weblibre/features/geckoview/features/bookmarks/domain/entities/import_bookmark_node.dart';
import 'package:weblibre/features/profile_import/domain/models/import_bundle.dart';

String _stamp(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Detects and parses Chrome's `Bookmarks` JSON file.
class ChromeBookmarksParser {
  const ChromeBookmarksParser();

  static ImportBundle? tryParse(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['roots'] is! Map<String, dynamic>) return null;
      if (decoded['version'] is! int) return null;
      final roots = decoded['roots'] as Map<String, dynamic>;
      final converted = <ImportBookmarkNode>[];
      for (final key in const ['bookmark_bar', 'other', 'synced']) {
        final node = roots[key];
        if (node is Map<String, dynamic>) {
          final c = _convert(node);
          if (c != null) converted.add(c);
        }
      }
      final stamp = DateTime.now();
      final folder = ImportBookmarkFolder(
        title: 'Imported from Chrome (${_stamp(stamp)})',
        children: converted,
      );
      var count = 0;
      void tally(ImportBookmarkNode n) {
        if (n is ImportBookmarkItem) count++;
        if (n is ImportBookmarkFolder) n.children.forEach(tally);
      }
      tally(folder);

      final tree = ImportBookmarkTree(
        sections: {BookmarkRoot.unfiled.id: [folder]},
        stats: ImportBookmarkStats(bookmarkCount: count, folderCount: converted.length),
      );
      return ImportBundle(
        source: ImportSource.chromeBookmarks,
        sourceLabel: 'Chrome / Brave / Edge',
        bookmarks: tree,
      );
    } catch (_) {
      return null;
    }
  }

  static ImportBookmarkNode? _convert(Map<String, dynamic> node) {
    final type = node['type'] as String?;
    final name = (node['name'] as String?) ?? '';
    if (type == 'url') {
      final url = node['url'] as String?;
      if (url == null) return null;
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      return ImportBookmarkItem(url: uri, title: name.isEmpty ? url : name);
    }
    if (type == 'folder') {
      final children = node['children'];
      final converted = <ImportBookmarkNode>[];
      if (children is List) {
        for (final child in children) {
          if (child is Map<String, dynamic>) {
            final c = _convert(child);
            if (c != null) converted.add(c);
          }
        }
      }
      return ImportBookmarkFolder(
        title: name.isEmpty ? 'Folder' : name,
        children: converted,
      );
    }
    return null;
  }
}

/// Parses a Firefox `places.sqlite` file (read-only).
class FirefoxPlacesParser {
  const FirefoxPlacesParser();

  static ImportBundle? tryParsePath(String path) {
    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
      final bookmarks = _parseBookmarks(db);
      final history = _parseHistory(db);
      if (bookmarks == null) return null;
      return ImportBundle(
        source: ImportSource.firefoxPlaces,
        sourceLabel: 'Firefox / Fennec / IronFox',
        bookmarks: bookmarks,
        history: history,
      );
    } catch (_) {
      return null;
    } finally {
      db?.close();
    }
  }

  static ImportBookmarkTree? _parseBookmarks(Database db) {
    final rootRow = db.select(
      "SELECT id FROM moz_bookmarks WHERE guid = 'root________' LIMIT 1",
    );
    if (rootRow.isEmpty) return null;
    final rootId = rootRow.first['id'] as int;

    final rows = db.select(
      'SELECT id, parent, title, type, fk FROM moz_bookmarks',
    );

    final childrenByParent = <int, List<Map<String, Object?>>>{}; 
    for (final r in rows) {
      final parent = r['parent'] as int?;
      if (parent == null) continue;
      childrenByParent
          .putIfAbsent(parent, () => [])
          .add(Map<String, Object?>.from(r));
    }

    ImportBookmarkNode? build(Map<String, Object?> row) {
      final type = row['type'] as int?;
      final id = row['id'] as int?;
      if (id == null) return null;
      final title = (row['title'] as String?) ?? '';
      if (type == 1) {
        final fk = row['fk'] as int?;
        String? url;
        if (fk != null) {
          final placeRows = db.select(
            'SELECT url FROM moz_places WHERE id = ?',
            [fk],
          );
          if (placeRows.isNotEmpty) {
            url = placeRows.first['url'] as String?;
          }
        }
        if (url == null) return null;
        final uri = Uri.tryParse(url);
        if (uri == null) return null;
        return ImportBookmarkItem(
          url: uri,
          title: title.isEmpty ? url : title,
        );
      }
      if (type == 2) {
        final kids = childrenByParent[id] ?? const [];
        final converted = <ImportBookmarkNode>[];
        for (final k in kids) {
          final c = build(k);
          if (c != null) converted.add(c);
        }
        return ImportBookmarkFolder(
          title: title.isEmpty ? 'Folder' : title,
          children: converted,
        );
      }
      return null;
    }

    final topChildren = childrenByParent[rootId] ?? const [];
    final converted = <ImportBookmarkNode>[];
    for (final c in topChildren) {
      final node = build(c);
      if (node != null) converted.add(node);
    }
    if (converted.isEmpty) return null;

    final stamp = DateTime.now();
    final folder = ImportBookmarkFolder(
      title: 'Imported from Firefox (${_stamp(stamp)})',
      children: converted,
    );
    var count = 0;
    void tally(ImportBookmarkNode n) {
      if (n is ImportBookmarkItem) count++;
      if (n is ImportBookmarkFolder) n.children.forEach(tally);
    }
    tally(folder);

    return ImportBookmarkTree(
      sections: {BookmarkRoot.unfiled.id: [folder]},
      stats: ImportBookmarkStats(bookmarkCount: count, folderCount: converted.length),
    );
  }

  static List<ImportHistoryEntry> _parseHistory(Database db) {
    final rows = db.select(
      'SELECT p.url, p.title, h.visit_date, p.visit_count '
      'FROM moz_places p JOIN moz_historyvisits h ON h.place_id = p.id',
    );
    final entries = <ImportHistoryEntry>[];
    for (final r in rows) {
      final url = r['url'] as String?;
      if (url == null) continue;
      final visitedMicros = r['visit_date'];
      DateTime visitedAt;
      if (visitedMicros is int) {
        visitedAt = DateTime.fromMicrosecondsSinceEpoch(
          visitedMicros,
          isUtc: true,
        );
      } else {
        visitedAt = DateTime.now().toUtc();
      }
      entries.add(
        ImportHistoryEntry(
          url: Uri.tryParse(url) ?? Uri(),
          title: r['title'] as String?,
          visitedAt: visitedAt,
          visitCount: (r['visit_count'] as int?) ?? 1,
        ),
      );
    }
    return entries;
  }
}

/// Parses Chrome's `History` SQLite file (read-only).
class ChromeHistoryParser {
  const ChromeHistoryParser();

  static List<ImportHistoryEntry>? tryParsePath(String path) {
    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
      final rows = db.select(
        'SELECT u.url, u.title, v.visit_time FROM urls u '
        'JOIN visits v ON v.url = u.id',
      );
      final entries = <ImportHistoryEntry>[];
      for (final r in rows) {
        final url = r['url'] as String?;
        if (url == null) continue;
        final t = r['visit_time'];
        DateTime visitedAt;
        if (t is int) {
          visitedAt = DateTime.utc(1601).add(Duration(microseconds: t));
        } else {
          visitedAt = DateTime.now().toUtc();
        }
        entries.add(
          ImportHistoryEntry(
            url: Uri.tryParse(url) ?? Uri(),
            title: r['title'] as String?,
            visitedAt: visitedAt,
          ),
        );
      }
      return entries;
    } catch (_) {
      return null;
    } finally {
      db?.close();
    }
  }
}

/// Parses Chrome's `Preferences` JSON for an extension list.
class ChromePreferencesParser {
  const ChromePreferencesParser();

  static List<ImportAddon>? tryParse(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return null;
      final extensions = decoded['extensions'];
      if (extensions is! Map<String, dynamic>) return null;
      final settings = extensions['settings'];
      if (settings is! Map<String, dynamic>) return null;
      final result = <ImportAddon>[];
      for (final entry in settings.entries) {
        final v = entry.value;
        if (v is! Map<String, dynamic>) continue;
        final manifest = v['manifest'];
        final manifestMap = manifest is Map<String, dynamic> ? manifest : null;
        final name = manifestMap?['name'] as String? ?? entry.key;
        result.add(
          ImportAddon(
            id: entry.key,
            name: name,
            version: manifestMap?['version'] as String?,
          ),
        );
      }
      return result;
    } catch (_) {
      return null;
    }
  }
}

/// Parses Firefox's `extensions.json`.
class FirefoxExtensionsParser {
  const FirefoxExtensionsParser();

  static List<ImportAddon>? tryParse(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return null;
      final addons = decoded['addons'];
      if (addons is! List) return null;
      final result = <ImportAddon>[];
      for (final a in addons) {
        if (a is! Map<String, dynamic>) continue;
        final id = a['id'] as String? ?? a['internalName'] as String? ?? '';
        final defaultLocale = a['defaultLocale'];
        final localeMap = defaultLocale is Map<String, dynamic> ? defaultLocale : null;
        final name = localeMap?['name'] as String? ?? a['name'] as String? ?? id;
        result.add(ImportAddon(id: id, name: name, version: a['version'] as String?));
      }
      return result;
    } catch (_) {
      return null;
    }
  }
}
