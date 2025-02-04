import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import 'package:intl/intl.dart';

class MatchDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> match;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const MatchDetailsBottomSheet({
    Key? key,
    required this.match,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Match Quality Indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircularProgressIndicator(
                    value: match['match_percentage'] / 100,
                    backgroundColor: Colors.grey[200],
                    strokeWidth: 8,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${match['match_percentage']}% Match',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        Text(
                          'Based on route overlap and schedule',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Route Details
            Text(
              'Route Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.route,
              title: 'Total Distance',
              value: '${match['total_distance']?.toStringAsFixed(1) ?? "0"} km',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.timeline,
              title: 'Route Overlap',
              value: '${match['route_overlap']?.toStringAsFixed(1) ?? "0"} km',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.access_time,
              title: 'Estimated Duration',
              value: '${match['estimated_duration'] ?? "0"} min',
            ),
            const Divider(height: 32),

            // Schedule Details
            Text(
              'Schedule',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.calendar_today,
              title: 'Date',
              value: DateFormat('MMM dd, yyyy').format(
                DateTime.parse(match['scheduled_time']),
              ),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.schedule,
              title: 'Time',
              value: DateFormat('HH:mm').format(
                DateTime.parse(match['scheduled_time']),
              ),
            ),
            const Divider(height: 32),

            // User Details (if available)
            if (match['user_details'] != null) ...[
              Text(
                'User Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    match['user_details']['name']?[0].toUpperCase() ?? '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(match['user_details']['name'] ?? 'Unknown User'),
                subtitle: Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 16,
                      color: Colors.amber[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${match['user_details']['rating'] ?? "0.0"} (${match['user_details']['total_rides'] ?? "0"} rides)',
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Reject',
                    onPressed: () {
                      Navigator.pop(context);
                      onReject();
                    },
                    isOutlined: true,
                    backgroundColor: Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: 'Accept',
                    onPressed: () {
                      Navigator.pop(context);
                      onAccept();
                    },
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(color: Colors.grey),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}