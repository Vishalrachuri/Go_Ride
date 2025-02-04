// lib/screens/ride_tracking_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/ride.dart';
import '../services/location_service.dart';
import '../widgets/custom_button.dart';

class RideTrackingScreen extends StatefulWidget {
  final Ride ride;
  final bool isDriver;

  const RideTrackingScreen({
    Key? key,
    required this.ride,
    required this.isDriver,
  }) : super(key: key);

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  final LocationService _locationService = LocationService();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _locationSubscription;
  Position? _lastPosition;
  bool _isLoading = true;
  bool _isLocationTracking = false;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    setState(() => _isLoading = true);

    try {
      final hasPermission = await _locationService.checkLocationPermission();
      if (!hasPermission) {
        _showError('Location permission is required for tracking');
        return;
      }

      // Add pickup and destination markers
      _markers.addAll({
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(
            widget.ride.pickupLatitude,
            widget.ride.pickupLongitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: widget.ride.pickupLocation),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(
            widget.ride.destinationLatitude,
            widget.ride.destinationLongitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: widget.ride.destination),
        ),
      });

      // Get route between pickup and destination
      final routePoints = await _locationService.getRouteCoordinates(
        LatLng(widget.ride.pickupLatitude, widget.ride.pickupLongitude),
        LatLng(widget.ride.destinationLatitude, widget.ride.destinationLongitude),
      );

      if (routePoints.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: routePoints,
            color: Colors.blue,
            width: 5,
          ),
        );
      }

      // Start location tracking if driver
      if (widget.isDriver) {
        await _locationService.startTracking(widget.ride.id);
        _subscribeToLocationUpdates();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      _showError('Error initializing tracking: $e');
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToLocationUpdates() {
    _locationSubscription = _locationService.locationStream?.listen((position) {
      setState(() {
        _lastPosition = position;
        _updateDriverMarker(position);
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        }
      });
    });
  }

  void _updateDriverMarker(Position position) {
    _markers.removeWhere(
          (marker) => marker.markerId == const MarkerId('driver'),
    );
    _markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(position.latitude, position.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Current Location'),
        rotation: position.heading,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    if (widget.isDriver) {
      _locationService.stopTracking();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Ride'),
        actions: [
          if (widget.isDriver)
            IconButton(
              icon: Icon(_isLocationTracking ? Icons.gps_off : Icons.gps_fixed),
              onPressed: () {
                setState(() => _isLocationTracking = !_isLocationTracking);
                if (_isLocationTracking) {
                  _locationService.startTracking(widget.ride.id);
                  _subscribeToLocationUpdates();
                } else {
                  _locationService.stopTracking();
                  _locationSubscription?.cancel();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.ride.pickupLatitude,
                widget.ride.pickupLongitude,
              ),
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
          ),
          if (widget.isDriver && widget.ride.status == 'active')
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: CustomButton(
                text: 'Complete Ride',
                onPressed: () {
                  // TODO: Implement ride completion
                },
                backgroundColor: Colors.green,
              ),
            ),
        ],
      ),
    );
  }
}