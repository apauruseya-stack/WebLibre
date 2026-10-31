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
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:weblibre/features/geckoview/features/browser/domain/providers/blocked_trackers.dart';

/// A compact shield badge showing how many trackers were blocked on [tabId].
///
/// Returns an empty box when nothing has been blocked yet, so it can be dropped
/// into toolbars, app bars or tab cards without reserving space. Tapping it
/// opens the site info sheet's Privacy X-Ray section when [onTap] is provided.
class PrivacyXRayBadge extends HookConsumerWidget {
  final String tabId;
  final VoidCallback? onTap;

  const PrivacyXRayBadge({required this.tabId, this.onTap, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final trackersAsync = ref.watch(pageTrackersProvider(tabId));
    final count = trackersAsync.value?.blockedCount ?? 0;

    if (count == 0 || trackersAsync.hasError) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: '$count blocked',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MdiIcons.shieldCheck,
                size: 14,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}