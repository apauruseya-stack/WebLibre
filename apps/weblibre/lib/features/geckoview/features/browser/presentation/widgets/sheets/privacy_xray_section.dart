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
import 'package:flutter/services.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:weblibre/features/geckoview/features/browser/domain/providers/blocked_trackers.dart';
import 'package:weblibre/features/geckoview/features/browser/presentation/utils/blocked_trackers_l10n.dart';
import 'package:weblibre/l10n/generated/app_localizations.dart';

/// A compact "Privacy X-Ray" summary for the page in [tabId].
///
/// Surfaces, at a glance, how many trackers were blocked on this page and
/// under which categories, so the protection that is otherwise hidden in the
/// detailed tracking-protection section becomes visible the moment the sheet
/// opens.
class PrivacyXRaySection extends HookConsumerWidget {
  final String tabId;

  final ValueChanged<bool>? onExpandedChanged;

  const PrivacyXRaySection({
    required this.tabId,
    this.onExpandedChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trackersAsync = ref.watch(pageTrackersProvider(tabId));
    final trackers = trackersAsync.value;

    if (trackersAsync.hasError) {
      return const SizedBox.shrink();
    }

    if (trackers == null) {
      return Skeletonizer(
        child: ListTile(
          leading: const Icon(MdiIcons.shieldSearch),
          title: Text(BoneMock.title),
          subtitle: Text(BoneMock.subtitle),
        ),
      );
    }

    final count = trackers.blockedCount;
    final topCategories = trackers.blocked.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Icon(
          MdiIcons.shieldSearch,
          color: count > 0
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
        title: const Text('Privacy X-Ray'),
        subtitle: Text(
          count == 0
              ? l10n.browser_noTrackersBlocked
              : l10n.browser_trackersBlockedCount(count),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        onExpansionChanged: (expanded) {
          unawaited(HapticFeedback.selectionClick());
          onExpandedChanged?.call(expanded);
        },
        children: [
          if (count == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nothing blocked on this page yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in topCategories)
                    Chip(
                      avatar: Icon(entry.key.icon, size: 16),
                      label: Text(
                        '${entry.key.label(context)} (${entry.value.length})',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}