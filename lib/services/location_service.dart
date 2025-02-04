// lib/services/location_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/constants.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamController<Position>? _locationController;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _updateTimer;
  String? _accessToken;
  int? _currentRideId;
  bool _isTracking = false;

  void initialize(String accessToken) {
    _accessToken = accessToken;
  }

  Future<bool> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> startTracking(int rideId) async {
    if (_isTracking) return;

    final hasPermission = await checkLocationPermission();
    if (!hasPermission) {
      throw Exception('Location permission not granted');
    }

    _currentRideId = rideId;
    _locationController = StreamController<Position>.broadcast();
    _isTracking = true;

    // Start location updates
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen(_handleLocationUpdate);

    // Start periodic updates to server
    _updateTimer = Timer.periodic(
      const Duration(seconds: 15),
          (_) => _updateLocationOnServer(),
    );
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _updateTimer?.cancel();
    _updateTimer = null;
    await _locationController?.close();
    _locationController = null;
    _currentRideId = null;
  }

  Stream<Position>? get locationStream => _locationController?.stream;

  void _handleLocationUpdate(Position position) {
    if (_locationController?.isClosed ?? true) return;
    _locationController?.add(position);
  }

  Future<void> _updateLocationOnServer() async {
    if (!_isTracking || _currentRideId == null || _accessToken == null) return;

    try {
      final position = await Geolocator.getCurrentPosition();

      final response = await http.post(
        Uri.parse('$baseUrl/rides/$_currentRideId/location'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'bearing': position.heading,
          'speed': position.speed,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update location on server');
      }
    } catch (e) {
      print('Error updating location: $e');
      // Continue tracking even if server update fails
    }
  }

  Future<List<LatLng>> getRouteCoordinates(LatLng start, LatLng end) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://maps.googleapis.com/maps/api/directions/json'
                '?origin=${start.latitude},${start.longitude}'
                '&destination=${end.latitude},${end.longitude}'
                '&key=$GOOGLE_MAPS_API_KEY'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'].isEmpty) return [];

        final points = data['routes'][0]['overview_polyline']['points'];
        return _decodePolyline(points);
      }
      return [];
    } catch (e) {
      print('Error getting route: $e');
      return [];
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;

      do {
        result |= (encoded.codeUnitAt(index) - 63) << shift;
        shift += 5;
        index++;
      } while (index < len && result & 1 != 0);

      if (result & 1 != 0) {
        result = ~(result >> 1);
      } else {
        result >>= 1;
      }

      lat += result;

      shift = 0;
      result = 0;

      do {
        result |= (encoded.codeUnitAt(index) - 63) << shift;
        shift += 5;
        index++;
      } while (index < len && result & 1 != 0);

      if (result & 1 != 0) {
        result = ~(result >> 1);
      } else {
        result >>= 1;
      }

      lng += result;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}