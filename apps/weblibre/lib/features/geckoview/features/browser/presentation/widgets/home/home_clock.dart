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
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:weblibre/features/wallpaper/domain/providers.dart';

/// A large, centred clock for the home surface, in the style of TablissNG.
///
/// Replaces the brand mark in the home header so the page reads as a clock
/// face rather than a logo. Updates once a second so the seconds hand (when
/// shown) stays live; the minute is always current.
///
/// Tapping the clock flips the bundled Cat Browser logo wallpaper between its
/// black and white variants (persisted in the profile dir).
class HomeClock extends HookConsumerWidget {
  const HomeClock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = useState(DateTime.now());

    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        now.value = DateTime.now();
      });
      return timer.cancel;
    }, const []);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final time = now.value;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return GestureDetector(
      onTap: () async {
        // Flip the bundled logo wallpaper between black and white.
        final currentWallpaper = ref.read(resolvedHomeWallpaperProvider);
        final current = (currentWallpaper?.assetPath ?? '').contains('white')
            ? 'white'
            : 'black';
        final next = current == 'white' ? 'black' : 'white';
        await setHomeWallpaperLogoChoice(next);
        ref.invalidate(resolvedHomeWallpaperProvider);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        Text(
          '$hour:$minute',
          style: theme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w300,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: colorScheme.onSurface,
            letterSpacing: -2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatDate(time),
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
    );
  }

  String _formatDate(DateTime time) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[time.weekday - 1]}, ${months[time.month - 1]} ${time.day}';
  }
}