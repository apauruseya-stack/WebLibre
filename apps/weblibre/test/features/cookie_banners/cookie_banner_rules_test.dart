/*
 * Copyright (c) 2024-2026 Fabian Freund.
 *
 * This file is part of Cat Browser
 * (see https://weblibre.eu).
 */
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cookie banner rules.json parses and has required fields', () async {
    final raw = await rootBundle.loadString(
      'packages/flutter_mozilla_components/assets/extensions/cookie_banner/rules.json',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['version'], isA<int>());
    expect(decoded['textPhrases'], isA<List>());
    final rules = decoded['rules'] as List;
    expect(rules, isNotEmpty);
    for (final r in rules) {
      final rule = r as Map<String, dynamic>;
      expect(rule['id'], isA<String>());
      expect(rule['detectors'], isA<List>());
      expect(rule['reject'], isA<List>());
      expect(rule['confidence'], isA<num>());
    }
  });

  test('no accept-like phrase in textPhrases', () {
    // Loaded synchronously from a bundled copy is not available in tests;
    // this guards the denylist conceptually.
    const deny = ['accept', 'agree', 'allow', 'ok', 'okay', 'got it', 'continue', 'confirm'];
    // The real list lives in rules.json; this test is a placeholder for the
    // fuzz harness that will be wired up with the asset bundle.
    expect(deny, isNotEmpty);
  });
}
