// lib/services/ride_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place_details.dart';
import '../utils/constants.dart';

class CreateRideRequest {
  final String pickupLocation;
  final double pickupLatitude;
  final double pickupLongitude;
  final String destination;
  final double destinationLatitude;
  final double destinationLongitude;
  final DateTime scheduledTime;
  final int seatsAvailable;
  final String? notes;
  final String? routePolyline;
  final int? estimatedDuration;

  CreateRideRequest({
    required this.pickupLocation,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destination,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.scheduledTime,
    required this.seatsAvailable,
    this.notes,
    this.routePolyline,
    this.estimatedDuration,
  });

  Map<String, dynamic> toJson() {
    return {
      'pickup_location': pickupLocation,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'destination': destination,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'scheduled_time': scheduledTime.toIso8601String(),
      'seats_available': seatsAvailable,
      'notes': notes,
      'route_polyline': routePolyline,
      'estimated_duration': estimatedDuration,
    };
  }
}

class RideService {
  Future<Map<String, dynamic>> createRide(CreateRideRequest request) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/rides'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['detail'] ?? 'Failed to create ride');
      }
    } catch (e) {
      throw Exception('Error creating ride: $e');
    }
  }
}