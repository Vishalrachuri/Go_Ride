import 'package:flutter/material.dart';

class MapControls extends StatelessWidget {
  final VoidCallback onCurrentLocation;
  final VoidCallback onToggleFollow;
  final bool isFollowingUser;
  final bool isLoading;

  const MapControls({
    Key? key,
    required this.onCurrentLocation,
    required this.onToggleFollow,
    required this.isFollowingUser,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed,
                color: isFollowingUser ? Theme.of(context).primaryColor : Colors.grey,
              ),
              onPressed: onToggleFollow,
              tooltip: isFollowingUser ? 'Stop following' : 'Follow location',
            ),
            const Divider(height: 1),
            IconButton(
              icon: isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.my_location),
              onPressed: isLoading ? null : onCurrentLocation,
              tooltip: 'Current location',
            ),
          ],
        ),
      ),
    );
  }
}