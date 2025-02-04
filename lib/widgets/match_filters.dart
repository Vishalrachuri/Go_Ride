import 'package:flutter/material.dart';

class MatchFilters extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final double? minMatchPercentage;
  final double? maxDistance;
  final Function(double) onMatchPercentageChanged;
  final Function(double) onMaxDistanceChanged;

  const MatchFilters({
    Key? key,
    required this.selectedFilter,
    required this.onFilterChanged,
    this.minMatchPercentage = 0,
    this.maxDistance = 50,
    required this.onMatchPercentageChanged,
    required this.onMaxDistanceChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Sort options
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Best Match'),
                    selected: selectedFilter == 'match',
                    onSelected: (_) => onFilterChanged('match'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Nearest'),
                    selected: selectedFilter == 'distance',
                    onSelected: (_) => onFilterChanged('distance'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Soonest'),
                    selected: selectedFilter == 'time',
                    onSelected: (_) => onFilterChanged('time'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Match percentage slider
            Row(
              children: [
                const Icon(Icons.percent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Minimum Match Percentage',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Slider(
                        value: minMatchPercentage ?? 0,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${(minMatchPercentage ?? 0).round()}%',
                        onChanged: onMatchPercentageChanged,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Distance slider
            Row(
              children: [
                const Icon(Icons.route, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maximum Distance',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Slider(
                        value: maxDistance ?? 50,
                        min: 1,
                        max: 100,
                        divisions: 20,
                        label: '${(maxDistance ?? 50).round()} km',
                        onChanged: onMaxDistanceChanged,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}