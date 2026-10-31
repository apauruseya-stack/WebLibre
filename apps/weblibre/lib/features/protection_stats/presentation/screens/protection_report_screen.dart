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
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:weblibre/features/geckoview/features/browser/domain/providers/blocked_trackers.dart';
import 'package:weblibre/features/cookie_banners/domain/services/cookie_banner.dart';

class ProtectionReportScreen extends ConsumerWidget {
  const ProtectionReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(trackerStatisticsProvider);
    final bannerStatuses = ref.watch(cookieBannerStatusProvider);

    final bannersHandled = bannerStatuses.values
        .where((e) => e.action == 'rejected' || e.action == 'hidden')
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Protection report')),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load stats: $e')),
        data: (summary) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trackers blocked',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${summary.total}',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      if (summary.since != null)
                        Text('Since ${summary.since!.toLocal().toString().split(' ').first}'),
                      Text('Last 7 days: ${summary.lastSevenDaysTotal}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'By category (last 7 days)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final entry in summary.lastSevenDays.entries)
                        ListTile(
                          leading: Icon(entry.key.icon),
                          title: Text(entry.key.name),
                          trailing: Text('${entry.value}'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cookie banners handled',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$bannersHandled',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const Text('Computed on this device. Nothing is sent anywhere.'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
