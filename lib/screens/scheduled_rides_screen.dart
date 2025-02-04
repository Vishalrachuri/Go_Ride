import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ride.dart';
import '../widgets/ride_card.dart';
import '../widgets/ride_filters.dart';
import '../utils/constants.dart';
import 'auth_screen.dart';
import 'ride_details_screen.dart';

class ScheduledRidesScreen extends StatefulWidget {
  const ScheduledRidesScreen({Key? key}) : super(key: key);

  @override
  State<ScheduledRidesScreen> createState() => _ScheduledRidesScreenState();
}

class _ScheduledRidesScreenState extends State<ScheduledRidesScreen> {
  bool _isLoading = false;
  List<Ride> _rides = [];
  String? _accessToken;
  Map<String, dynamic>? _userData;
  String _selectedFilter = 'all';
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

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
      final bool isDriver = _userData?['user_type'] == 'driver';

      final response = await http.get(
        Uri.parse('$baseUrl/rides${isDriver && _selectedFilter == 'requests' ? '/requests' : ''}'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _rides = (data['rides'] as List)
              .map((ride) => Ride.fromJson(ride))
              .toList();
        });
      } else if (response.statusCode == 401) {
        _redirectToLogin();
      } else {
        throw Exception('Failed to load rides');
      }
    } catch (e) {
      _showError('Error loading rides: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRideStatus(int rideId, String newStatus) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/rides/$rideId/status'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        _showMessage('Ride status updated successfully');
        _loadRides();
      } else {
        _showError('Failed to update ride status');
      }
    } catch (e) {
      _showError('Error updating ride status: $e');
    }
  }

  List<Ride> _getFilteredRides() {
    if (_selectedFilter == 'all') return _rides;

    final now = DateTime.now();
    return _rides.where((ride) {
      switch (_selectedFilter) {
        case 'upcoming':
          return ride.scheduledTime.isAfter(now) &&
              ride.status == 'scheduled';
        case 'active':
          return ride.status == 'active';
        case 'completed':
          return ride.status == 'completed';
        case 'cancelled':
          return ride.status == 'cancelled';
        case 'requests':
          return ride.status == 'scheduled' &&
              ride.driverId == null;
        default:
          return true;
      }
    }).toList();
  }

  void _showRideDetails(Ride ride) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RideDetailsScreen(ride: ride),
      ),
    );
  }

  void _redirectToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    _showMessage(message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final filteredRides = _getFilteredRides();
    final bool isDriver = _userData?['user_type'] == 'driver';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Rides'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshKey.currentState?.show(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          RideFilters(
            selectedFilter: _selectedFilter,
            onFilterChanged: (filter) {
              setState(() => _selectedFilter = filter);
            },
            isDriver: isDriver,
          ),

          // Rides List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              key: _refreshKey,
              onRefresh: _loadRides,
              child: filteredRides.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No rides found',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    if (_selectedFilter != 'all') ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedFilter = 'all');
                        },
                        child: const Text('Show all rides'),
                      ),
                    ],
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: filteredRides.length,
                itemBuilder: (context, index) {
                  final ride = filteredRides[index];
                  return RideCard(
                    ride: ride,
                    onTap: () => _showRideDetails(ride),
                    showActions: isDriver &&
                        ride.status == 'scheduled',
                    onAccept: isDriver
                        ? () => _updateRideStatus(
                      ride.id,
                      'active',
                    )
                        : null,
                    onReject: isDriver
                        ? () => _updateRideStatus(
                      ride.id,
                      'cancelled',
                    )
                        : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}