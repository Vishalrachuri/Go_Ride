import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:car_pooling_app/utils/constants.dart';  // To this
import 'auth_screen.dart';

class ScheduledRidesScreen extends StatefulWidget {
  const ScheduledRidesScreen({Key? key}) : super(key: key);

  @override
  State<ScheduledRidesScreen> createState() => _ScheduledRidesScreenState();
}

class _ScheduledRidesScreenState extends State<ScheduledRidesScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _rides = [];
  String? _accessToken;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      final userDataString = prefs.getString('user_data');

      if (_accessToken == null || userDataString == null) {
        _redirectToLogin();
        return;
      }

      _userData = json.decode(userDataString);

      final response = await http.get(
        Uri.parse('$baseUrl/rides'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _rides = List<Map<String, dynamic>>.from(data['rides']);
        });
      } else {
        _showError('Failed to load rides');
      }
    } catch (e) {
      _showError('Error loading rides: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _updateRideStatus(int rideId, String newStatus) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/rides/$rideId'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        _showMessage('Ride status updated successfully');
        _loadRides(); // Reload rides to show updated status
      } else {
        _showError('Failed to update ride status');
      }
    } catch (e) {
      _showError('Error updating ride status: $e');
    }
  }

  void _showRideDetails(Map<String, dynamic> ride) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.75,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ride Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildDetailRow('From:', ride['pickup_location']),
              _buildDetailRow('To:', ride['destination']),
              _buildDetailRow(
                'Date & Time:',
                DateFormat('MMM dd, yyyy hh:mm a')
                    .format(DateTime.parse(ride['scheduled_time'])),
              ),
              _buildDetailRow(
                'Status:',
                ride['status'].toUpperCase(),
                color: _getStatusColor(ride['status']),
              ),
              if (ride['seats_available'] != null)
                _buildDetailRow(
                  'Available Seats:',
                  ride['seats_available'].toString(),
                ),
              const SizedBox(height: 24),
              if (ride['status'] == 'scheduled') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      _updateRideStatus(ride['id'], 'cancelled');
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel Ride'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: color != null ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _redirectToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );
  }

  void _showError(String message) {
    _showMessage(message, isError: true);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_rides.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scheduled Rides'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.directions_car_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'No rides scheduled',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your scheduled rides will appear here',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Rides'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRides,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRides,
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: _rides.length,
          itemBuilder: (context, index) {
            final ride = _rides[index];
            final status = ride['status'].toLowerCase();
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: Icon(
                  _userData?['user_type'] == 'driver'
                      ? Icons.drive_eta
                      : Icons.person_outline,
                  color: _getStatusColor(status),
                ),
                title: Text(ride['destination']),
                subtitle: Text(
                  DateFormat('MMM dd, yyyy hh:mm a')
                      .format(DateTime.parse(ride['scheduled_time'])),
                ),
                trailing: Chip(
                  label: Text(
                    status.toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: _getStatusColor(status),
                ),
                onTap: () => _showRideDetails(ride),
              ),
            );
          },
        ),
      ),
    );
  }
}