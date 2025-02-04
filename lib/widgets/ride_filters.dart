import 'package:flutter/material.dart';

class RideFilters extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final bool isDriver;

  const RideFilters({
    Key? key,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.isDriver,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selectedFilter == 'all',
            onSelected: (_) => onFilterChanged('all'),
            showCheckmark: false,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Upcoming'),
            selected: selectedFilter == 'upcoming',
            onSelected: (_) => onFilterChanged('upcoming'),
            showCheckmark: false,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Active'),
            selected: selectedFilter == 'active',
            onSelected: (_) => onFilterChanged('active'),
            showCheckmark: false,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Completed'),
            selected: selectedFilter == 'completed',
            onSelected: (_) => onFilterChanged('completed'),
            showCheckmark: false,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Cancelled'),
            selected: selectedFilter == 'cancelled',
            onSelected: (_) => onFilterChanged('cancelled'),
            showCheckmark: false,
          ),
          if (isDriver) ...[
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Available Requests'),
              selected: selectedFilter == 'requests',
              onSelected: (_) => onFilterChanged('requests'),
              showCheckmark: false,
            ),
          ],
        ],
      ),
    );
  }
}