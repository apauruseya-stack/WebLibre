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
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:weblibre/core/logger.dart';
import 'package:weblibre/features/profile_import/domain/models/import_job.dart';

/// Persists the most recent import so undo survives a restart.
///
/// The payload is one JSON file under the app support directory. A 50k-visit
/// import is a few megabytes, which is cheap enough for a single write and
/// avoids a database for something read at most twice.
class ImportJobStore {
  const ImportJobStore();

  static const _dirName = 'profile_import';
  static const _fileName = 'last_job.json';

  Future<File> _file() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, _dirName));
    await dir.create(recursive: true);
    return File(p.join(dir.path, _fileName));
  }

  Future<void> save(ImportJob job) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(job.toJson()), flush: true);
    } catch (e, s) {
      // Losing undo is annoying, not fatal; never fail an import over it.
      logger.w('Failed to persist import job', error: e, stackTrace: s);
    }
  }

  Future<ImportJob?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final job = ImportJob.fromJson(decoded);
      return job.isEmpty ? null : job;
    } catch (e, s) {
      logger.w('Failed to read import job', error: e, stackTrace: s);
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (e, s) {
      logger.w('Failed to clear import job', error: e, stackTrace: s);
    }
  }

  @visibleForTesting
  static String get debugFileName => _fileName;
}
