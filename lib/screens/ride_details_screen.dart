import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/ride.dart';
import 'chat_detail_screen.dart';

class RideDetailsScreen extends StatefulWidget {
  final Ride ride;

  const RideDetailsScreen({
    Key? key,
    required this.ride,
  }) : super(key: key);

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _setupMapMarkers();
  }

  void _setupMapMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(
          widget.ride.pickupLatitude,
          widget.ride.pickupLongitude,
        ),
        infoWindow: InfoWindow(title: 'Pickup: ${widget.ride.pickupLocation}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(
          widget.ride.destinationLatitude,
          widget.ride.destinationLongitude,
        ),
        infoWindow: InfoWindow(title: 'Destination: ${widget.ride.destination}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    if (widget.ride.routePolyline != null) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _decodePolyline(widget.ride.routePolyline!),
          color: Colors.blue,
          width: 5,
        ),
      };
    }
  }

  void _fitMapBounds() {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(widget.ride.pickupLatitude, widget.ride.destinationLatitude),
        math.min(widget.ride.pickupLongitude, widget.ride.destinationLongitude),
      ),
      northeast: LatLng(
        math.max(widget.ride.pickupLatitude, widget.ride.destinationLatitude),
        math.max(widget.ride.pickupLongitude, widget.ride.destinationLongitude),
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
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

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(widget.ride.status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Details'),
        actions: [
          if (widget.ride.status == 'scheduled' || widget.ride.status == 'active')
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(
                      userId: widget.ride.driverId ?? widget.ride.riderId ?? 0,
                      rideId: widget.ride.id,
                      userName: widget.ride.driver?['name'] ??
                          widget.ride.rider?['name'] ??
                          'Unknown User',
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Map View
          SizedBox(
            height: 250,
            child: GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                _fitMapBounds();
              },
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  widget.ride.pickupLatitude,
                  widget.ride.pickupLongitude,
                ),
                zoom: 12,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
            ),
          ),

          // Ride Details
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status and Time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(
                            statusColor.red,
                            statusColor.green,
                            statusColor.blue,
                            0.1,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          widget.ride.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Route Details
                  _buildLocationRow(
                    icon: Icons.circle,
                    iconColor: Colors.green,
                    title: 'Pickup Location',
                    address: widget.ride.pickupLocation,
                  ),
                  const SizedBox(height: 24),
                  _buildLocationRow(
                    icon: Icons.location_on,
                    iconColor: Colors.red,
                    title: 'Destination',
                    address: widget.ride.destination,
                  ),

                  const SizedBox(height: 24),

                  // Additional details if available
                  if (widget.ride.notes?.isNotEmpty ?? false) ...[
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.ride.notes!),
                    const SizedBox(height: 16),
                  ],

                  if (widget.ride.estimatedDuration != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Estimated duration: ${widget.ride.estimatedDuration} minutes',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}