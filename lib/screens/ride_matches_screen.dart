import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_button.dart';
import '../widgets/match_filters.dart';
import '../widgets/match_details_sheet.dart';

class RideMatchesScreen extends StatefulWidget {
  final int rideId;

  const RideMatchesScreen({Key? key, required this.rideId}) : super(key: key);

  @override
  State<RideMatchesScreen> createState() => _RideMatchesScreenState();
}

class _RideMatchesScreenState extends State<RideMatchesScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _filteredMatches = [];
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String? _accessToken;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Filter state
  String _selectedFilter = 'match';
  double _minMatchPercentage = 0;
  double _maxDistance = 50;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');

      if (_accessToken == null) {
        _showError('Please login again');
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/rides/${widget.rideId}/matches'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          _matches = List<Map<String, dynamic>>.from(data['matches']);
          _filterAndSortMatches();
          _updateMapMarkers();
        });
      } else {
        throw Exception('Failed to load matches');
      }
    } catch (e) {
      _showError('Error loading matches: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterAndSortMatches() {
    setState(() {
      // Apply filters
      _filteredMatches = _matches.where((match) {
        final matchPercentage = match['match_percentage'] ?? 0;
        final distance = match['distance_to_pickup'] ?? 0;

        return matchPercentage >= _minMatchPercentage &&
            distance <= _maxDistance;
      }).toList();

      // Apply sorting
      _filteredMatches.sort((a, b) {
        switch (_selectedFilter) {
          case 'match':
            return (b['match_percentage'] ?? 0)
                .compareTo(a['match_percentage'] ?? 0);
          case 'distance':
            return (a['distance_to_pickup'] ?? 0)
                .compareTo(b['distance_to_pickup'] ?? 0);
          case 'time':
            return DateTime.parse(a['scheduled_time'])
                .compareTo(DateTime.parse(b['scheduled_time']));
          default:
            return 0;
        }
      });
    });
  }

  void _updateMapMarkers() {
    if (_filteredMatches.isEmpty) return;

    Set<Marker> markers = {};
    Set<Polyline> polylines = {};
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

    for (var i = 0; i < _filteredMatches.length; i++) {
      final match = _filteredMatches[i];
      final pickupLatLng = LatLng(
        match['pickup_lat'].toDouble(),
        match['pickup_lng'].toDouble(),
      );
      final destinationLatLng = LatLng(
        match['destination_lat'].toDouble(),
        match['destination_lng'].toDouble(),
      );

      // Add markers
      markers.add(
        Marker(
          markerId: MarkerId('pickup_$i'),
          position: pickupLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Pickup ${i + 1}',
            snippet: match['pickup_location'],
          ),
        ),
      );

      markers.add(
        Marker(
          markerId: MarkerId('destination_$i'),
          position: destinationLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destination ${i + 1}',
            snippet: match['destination'],
          ),
        ),
      );

      // Add route polyline if available
      if (match['route_polyline'] != null) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('route_$i'),
            points: _decodePolyline(match['route_polyline']),
            color: Colors.blue.withOpacity(0.6),
            width: 4,
          ),
        );
      }

      // Update bounds
      minLat = pickupLatLng.latitude < minLat ? pickupLatLng.latitude : minLat;
      maxLat = pickupLatLng.latitude > maxLat ? pickupLatLng.latitude : maxLat;
      minLng = pickupLatLng.longitude < minLng ? pickupLatLng.longitude : minLng;
      maxLng = pickupLatLng.longitude > maxLng ? pickupLatLng.longitude : maxLng;
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });

    _fitMapBounds(minLat, maxLat, minLng, maxLng);
  }

  void _fitMapBounds(double minLat, double maxLat, double minLng, double maxLng) {
    if (_mapController == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.1, minLng - 0.1),
          northeast: LatLng(maxLat + 0.1, maxLng + 0.1),
        ),
        50,
      ),
    );
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

  Future<void> _acceptMatch(int matchedRideId) async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/${widget.rideId}/accept-match'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'matched_ride_id': matchedRideId}),
      );

      if (response.statusCode == 200) {
        _showMessage('Match accepted successfully');
        await _loadMatches();
      } else {
        throw Exception('Failed to accept match');
      }
    } catch (e) {
      _showError('Error accepting match: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rejectMatch(int matchedRideId) async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/${widget.rideId}/reject-match'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'matched_ride_id': matchedRideId}),
      );

      if (response.statusCode == 200) {
        _showMessage('Match rejected successfully');
        await _loadMatches();
      } else {
        throw Exception('Failed to reject match');
      }
    } catch (e) {
      _showError('Error rejecting match: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMatchDetails(Map<String, dynamic> match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MatchDetailsBottomSheet(
        match: match,
        onAccept: () => _acceptMatch(match['ride_id']),
        onReject: () => _rejectMatch(match['ride_id']),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
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
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('Matched Rides (${_filteredMatches.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMatches,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Filters
          MatchFilters(
            selectedFilter: _selectedFilter,
            onFilterChanged: (filter) {
              setState(() {
                _selectedFilter = filter;
                _filterAndSortMatches();
              });
            },
            minMatchPercentage: _minMatchPercentage,
            maxDistance: _maxDistance,
            onMatchPercentageChanged: (value) {
              setState(() {
                _minMatchPercentage = value;
                _filterAndSortMatches();
              });
            },
            onMaxDistanceChanged: (value) {
              setState(() {
                _maxDistance = value;
                _filterAndSortMatches();
              });
            },
          ),

          // Map view
          SizedBox(
            height: 300,
            child: GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: const CameraPosition(
                target: LatLng(0, 0),
                zoom: 2,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapType: MapType.normal,
            ),
          ),

          // Matches list
          Expanded(
            child: _filteredMatches.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.no_transfer,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No matches found',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  if (_matches.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your filters',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Refresh',
                    onPressed: _loadMatches,
                    icon: Icons.refresh,
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredMatches.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final match = _filteredMatches[index];
                return _buildMatchCard(match);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    return GestureDetector(
      onTap: () => _showMatchDetails(match),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.route, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Match ${match['match_percentage']}%',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${match['distance_to_pickup'].toStringAsFixed(1)} km away',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildLocationInfo(
                icon: Icons.location_on,
                iconColor: Colors.green,
                label: 'Pickup',
                location: match['pickup_location'],
              ),
              const SizedBox(height: 8),
              _buildLocationInfo(
                icon: Icons.location_on,
                iconColor: Colors.red,
                label: 'Destination',
                location: match['destination'],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scheduled for: ${DateTime.parse(match['scheduled_time']).toLocal().toString().substring(0, 16)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomButton(
                    text: 'View Details',
                    onPressed: () => _showMatchDetails(match),
                    icon: Icons.info_outline,
                    isOutlined: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInfo({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String location,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                location,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}