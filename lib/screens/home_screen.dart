
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../utils/constants.dart';
import '../models/place_details.dart';
import '../widgets/location_input_field.dart';
import 'auth_screen.dart';
import 'scheduled_rides_screen.dart';
import 'chat_screen.dart';
import 'account_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  // Logger instance
  final _logger = Logger();
  final String _apiKey = 'AIzaSyBh5QRHCUySeig7queszJvrcuEoF2C6VKs';

  // State variables
  int _selectedIndex = 0;
  GoogleMapController? mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isLoadingRides = false;
  bool _isLocationInitialized = false;
  Set<Marker> _markers = {};
  bool isCarMode = true;
  String? _accessToken;
  Map<String, dynamic>? _userData;
  List<dynamic> _rides = [];
  PlaceDetails? _pickupPlaceDetails;
  PlaceDetails? _destinationPlaceDetails;
  bool _isFollowingUser = true;

  // Location streaming
  StreamSubscription<Position>? _positionStream;

  // Controllers
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _seatsAvailable = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    mapController?.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled. Please enable location services.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are required for this app.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permissions are permanently denied. Please enable them in settings.');
        return;
      }

      await _initializeApp();
      _startLocationStream();
    } catch (e) {
      _logger.e('Error requesting location permission: $e');
      _showError('Error accessing location services');
    }
  }

  Future<void> _initializeApp() async {
    try {
      await _checkAuth();
      await Future.wait([
        _getCurrentLocation(),
        _loadRides(),
      ]);
    } catch (e) {
      _logger.e('Error initializing app: $e');
      _showError('Error initializing app');
    }
  }

  void _startLocationStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
      timeLimit: Duration(seconds: 5),
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen(
          (Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });

          // Update camera position if following user
          if (mapController != null && _isFollowingUser) {
            mapController!.animateCamera(
              CameraUpdate.newLatLng(
                LatLng(position.latitude, position.longitude),
              ),
            );
          }
        }
      },
      onError: (error) {
        _logger.e('Location stream error: $error');
        _showError('Error updating location');
      },
    );
  }


  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoading = true);

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _isLocationInitialized = true;
      });

      if (mapController != null) {
        await mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15,
            ),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error getting location: $e');
      _showError('Could not get current location. Please check your location settings.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      final userDataString = prefs.getString('user_data');

      if (_accessToken == null || userDataString == null) {
        if (mounted) {
          _showError('Please login again');
          _redirectToLogin();
        }
        return;
      }

      try {
        final userData = json.decode(userDataString);
        if (mounted) {
          setState(() {
            _userData = userData;
            isCarMode = userData['user_type'] == 'driver';
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          _showError('Error loading user data');
          _redirectToLogin();
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Authentication error');
        _redirectToLogin();
      }
    }
  }

  void _updateMapMarkers() {
    if (!mounted) return;

    Set<Marker> newMarkers = {};

    // Only add pickup location marker
    if (_pickupPlaceDetails != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(_pickupPlaceDetails!.lat, _pickupPlaceDetails!.lng),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    // Only add destination marker
    if (_destinationPlaceDetails != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(_destinationPlaceDetails!.lat, _destinationPlaceDetails!.lng),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    setState(() => _markers = newMarkers);
    _updateCameraPosition();
  }

  Future<void> _updateCameraPosition() async {
    if (mapController == null || _markers.isEmpty) return;

    List<LatLng> points = _markers.map((m) => m.position).toList();

    double minLat = points.map((p) => p.latitude).reduce(min);
    double maxLat = points.map((p) => p.latitude).reduce(max);
    double minLng = points.map((p) => p.longitude).reduce(min);
    double maxLng = points.map((p) => p.longitude).reduce(max);

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );

    await mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  Widget _buildHomeTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (GoogleMapController controller) async {
            setState(() => mapController = controller);
            if (_currentPosition != null) {
              await controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    zoom: 15,
                  ),
                ),
              );
            }
          },
          initialCameraPosition: CameraPosition(
            target: _currentPosition != null
                ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                : const LatLng(0, 0),
            zoom: _currentPosition != null ? 15 : 2,
          ),
          myLocationButtonEnabled: false, // Disable default button
          myLocationEnabled: true,
          markers: _markers,
          zoomControlsEnabled: true,
          mapType: MapType.normal,
          compassEnabled: true,
          onCameraMove: (_) {
            setState(() => _isFollowingUser = false);
          },
        ),
        // Location control buttons
    /*
        Positioned(
          right: 16,
          bottom: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'toggleFollow',
                onPressed: () {
                  setState(() => _isFollowingUser = !_isFollowingUser);
                  if (_isFollowingUser && _currentPosition != null) {
                    mapController?.animateCamera(
                      CameraUpdate.newLatLng(
                        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      ),
                    );
                  }
                },
                child: Icon(_isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'refreshLocation',
                onPressed: _getCurrentLocation,
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
        */
        DraggableScrollableSheet(
          initialChildSize: 0.3,
          minChildSize: 0.2,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: _buildLocationCard(),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _loadRides() async {
    if (_isLoadingRides) return;

    try {
      setState(() => _isLoadingRides = true);

      if (_accessToken == null) {
        _redirectToLogin();
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/rides'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() => _rides = data['rides'] ?? []);
        }
      } else if (response.statusCode == 401) {
        _redirectToLogin();
      } else {
        throw Exception('Failed to load rides');
      }
    } catch (e) {
      _logger.e('Error loading rides: $e');
      _showError('Failed to load rides');
    } finally {
      if (mounted) {
        setState(() => _isLoadingRides = false);
      }
    }
  }

  void _redirectToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearForm() {
    setState(() {
      _pickupController.clear();
      _destinationController.clear();
      _selectedDate = null;
      _selectedTime = null;
      _seatsAvailable = 1;
      _pickupPlaceDetails = null;
      _destinationPlaceDetails = null;
      _updateMapMarkers();
    });
  }

  Widget _buildLocationCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User Type Toggle
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCarMode ? Colors.deepPurple : Colors
                          .grey,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => setState(() => isCarMode = true),
                    child: const Text('Driver'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !isCarMode ? Colors.deepPurple : Colors
                          .grey,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => setState(() => isCarMode = false),
                    child: const Text('Rider'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Location Input Fields
            LocationInputField(
              controller: _pickupController,
              label: 'Pickup Location',
              apiKey: _apiKey,
              currentPosition: _currentPosition,
              onLocationSelected: (details) {
                setState(() {
                  _pickupPlaceDetails = details;
                  _updateMapMarkers();
                });
              },
            ),
            const SizedBox(height: 12),
            LocationInputField(
              controller: _destinationController,
              label: 'Destination',
              apiKey: _apiKey,
              currentPosition: _currentPosition,
              onLocationSelected: (details) {
                setState(() {
                  _destinationPlaceDetails = details;
                  _updateMapMarkers();
                });
              },
            ),
            const SizedBox(height: 16),

            // Date & Time Selection
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null && mounted) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedDate == null
                          ? 'Select Date'
                          : '${_selectedDate!.day}/${_selectedDate!
                          .month}/${_selectedDate!.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null && mounted) {
                        setState(() => _selectedTime = picked);
                      }
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _selectedTime == null ? 'Select Time' : _selectedTime!
                          .format(context),
                    ),
                  ),
                ),
              ],
            ),

            // Seats Selection (Driver mode only)
            if (isCarMode) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Available Seats: ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      if (_seatsAvailable > 1) {
                        setState(() => _seatsAvailable--);
                      }
                    },
                  ),
                  Text(
                    '$_seatsAvailable',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_seatsAvailable < 6) {
                        setState(() => _seatsAvailable++);
                      }
                    },
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            // Create Ride Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : _createRide,
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text(
                  isCarMode ? 'Offer Ride' : 'Request Ride',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createRide() async {
    if (_pickupPlaceDetails == null ||
        _destinationPlaceDetails == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      _showError('Please fill in all fields');
      return;
    }

    try {
      setState(() => _isLoading = true);

      final DateTime scheduledDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final response = await http.post(
        Uri.parse('$baseUrl/rides'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'pickup_location': _pickupPlaceDetails!.name,
          'pickup_latitude': _pickupPlaceDetails!.lat,
          'pickup_longitude': _pickupPlaceDetails!.lng,
          'destination': _destinationPlaceDetails!.name,
          'destination_latitude': _destinationPlaceDetails!.lat,
          'destination_longitude': _destinationPlaceDetails!.lng,
          'scheduled_time': scheduledDateTime.toIso8601String(),
          'seats_available': _seatsAvailable,
        }),
      );

      if (response.statusCode == 200) {
        _showMessage(
          isCarMode
              ? 'Ride offered successfully'
              : 'Ride requested successfully',
        );
        _clearForm();
        await _loadRides();
      } else if (response.statusCode == 401) {
        _redirectToLogin();
      } else {
        throw Exception('Failed to create ride');
      }
    } catch (e) {
      _logger.e('Error creating ride: $e');
      _showError('Failed to create ride');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          const ScheduledRidesScreen(),
          const ChatScreen(),
          const AccountScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Scheduled'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Account'),
        ],
      ),
    );
  }
}