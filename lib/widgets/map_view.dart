import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'map_controls.dart';

class MapView extends StatefulWidget {
  final Position? currentPosition;
  final Set<Marker> markers;
  final Set<Polyline>? polylines;
  final bool isFollowingUser;
  final Function(GoogleMapController) onMapCreated;
  final VoidCallback onToggleFollow;
  final Future<void> Function() onCurrentLocation;

  const MapView({
    Key? key,
    this.currentPosition,
    required this.markers,
    this.polylines,
    required this.isFollowingUser,
    required this.onMapCreated,
    required this.onToggleFollow,
    required this.onCurrentLocation,
  }) : super(key: key);

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: widget.onMapCreated,
          initialCameraPosition: CameraPosition(
            target: widget.currentPosition != null
                ? LatLng(
              widget.currentPosition!.latitude,
              widget.currentPosition!.longitude,
            )
                : const LatLng(0, 0),
            zoom: widget.currentPosition != null ? 15 : 2,
          ),
          myLocationButtonEnabled: false,
          myLocationEnabled: true,
          markers: widget.markers,
          polylines: widget.polylines ?? {},
          zoomControlsEnabled: false,
          mapType: MapType.normal,
          compassEnabled: true,
          onCameraMove: (_) {
            if (widget.isFollowingUser) {
              widget.onToggleFollow();
            }
          },
        ),
        Positioned(
          right: 16,
          bottom: 90,
          child: MapControls(
            onCurrentLocation: () async {
              setState(() => _isLoading = true);
              await widget.onCurrentLocation();
              setState(() => _isLoading = false);
            },
            onToggleFollow: widget.onToggleFollow,
            isFollowingUser: widget.isFollowingUser,
            isLoading: _isLoading,
          ),
        ),
      ],
    );
  }
}