import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../models/place_details.dart';
import '../models/ride.dart';
import '../widgets/map_view.dart';
import '../widgets/ride_creation_form.dart';
import 'auth_screen.dart';
import 'scheduled_rides_screen.dart';
import 'chat_screen.dart';
import 'account_screen.dart';
import '../services/ride_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Controllers
  GoogleMapController? _mapController;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variables
  int _selectedIndex = 0;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isCreatingRide = false;
  bool _isLocationInitialized = false;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isFollowingUser = true;
  String? _accessToken;
  Map<String, dynamic>? _userData;
  bool _isDriverMode = false;
  PlaceDetails? _pickupLocation;
  PlaceDetails? _destinationLocation;

  // Location streaming
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationPermission();
    }
  }

  Future<void> _initialize() async {
    try {
      await _checkAuth();
      await _checkLocationPermission();
    } catch (e) {
      _showError('Error initializing app: $e');
    }
  }

  Future<void> _checkLocationPermission() async {
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

      await _getCurrentLocation();
      _startLocationStream();
    } catch (e) {
      _showError('Error accessing location services: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoading = true);

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      setState(() {
        _currentPosition = position;
        _isLocationInitialized = true;
      });

      await _updateCameraPosition(
        LatLng(position.latitude, position.longitude),
      );
    } catch (e) {
      _showError('Could not get current location. Please check your settings.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startLocationStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen(
          (Position position) {
        setState(() => _currentPosition = position);
        if (_isFollowingUser && _mapController != null) {
          _updateCameraPosition(
            LatLng(position.latitude, position.longitude),
            zoom: 15,
          );
        }
      },
      onError: (error) {
        _showError('Error updating location: $error');
      },
    );
  }

  Future<void> _checkAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      final userDataString = prefs.getString('user_data');

      if (_accessToken == null || userDataString == null) {
        _redirectToLogin();
        return;
      }

      setState(() {
        _userData = json.decode(userDataString);
        _isDriverMode = _userData?['user_type'] == 'driver';
      });
    } catch (e) {
      _showError('Authentication error');
      _redirectToLogin();
    }
  }

  Future<void> _updateCameraPosition(
      LatLng target, {
        double? zoom,
        double bearing = 0,
        double tilt = 0,
      }) async {
    if (_mapController == null) return;

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: zoom ?? 15,
          bearing: bearing,
          tilt: tilt,
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentPosition != null) {
      _updateCameraPosition(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      );
    }
  }

  void _updateMarkers() {
    Set<Marker> markers = {};

    if (_pickupLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(_pickupLocation!.lat, _pickupLocation!.lng),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    if (_destinationLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(_destinationLocation!.lat, _destinationLocation!.lng),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    setState(() => _markers = markers);
    _fitBounds();
  }

  Future<void> _fitBounds() async {
    if (_mapController == null || _markers.length < 2) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (Marker marker in _markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.1, minLng - 0.1),
          northeast: LatLng(maxLat + 0.1, maxLng + 0.1),
        ),
        50,
      ),
    );
  }


  void _redirectToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
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
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Home Tab with Map and Ride Form
          Stack(
            children: [
              // Map View
              MapView(
                currentPosition: _currentPosition,
                markers: _markers,
                polylines: _polylines,
                isFollowingUser: _isFollowingUser,
                onMapCreated: _onMapCreated,
                onToggleFollow: () => setState(() => _isFollowingUser = !_isFollowingUser),
                onCurrentLocation: _getCurrentLocation,
              ),

              // Ride Creation Form
              DraggableScrollableSheet(
                initialChildSize: 0.4,
                minChildSize: 0.2,
                maxChildSize: 0.9,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: RideCreationForm(
                        currentPosition: _currentPosition,
                        onPickupSelected: (details) {
                          setState(() {
                            _pickupLocation = details;
                            _updateMarkers();
                          });
                        },
                        onDestinationSelected: (details) {
                          setState(() {
                            _destinationLocation = details;
                            _updateMarkers();
                          });
                        },
                        onCreateRide: (date, time, seats) async {
                          setState(() => _isCreatingRide = true);

                          try {
                            if (_pickupLocation == null || _destinationLocation == null) {
                              throw Exception('Please select pickup and destination locations');
                            }

                            final scheduledDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );

                            final rideService = RideService();
                            final request = CreateRideRequest(
                                pickupLocation: _pickupLocation!.name,
                                pickupLatitude: _pickupLocation!.lat,
                                pickupLongitude: _pickupLocation!.lng,
                                destination: _destinationLocation!.name,
                                destinationLatitude: _destinationLocation!.lat,
                                destinationLongitude: _destinationLocation!.lng,
                                scheduledTime: scheduledDateTime,
                                seatsAvailable: seats
                            );

                            await rideService.createRide(request);

                            if (!mounted) return;

                            _showMessage(_isDriverMode ? 'Ride offered successfully' : 'Ride requested successfully');

                            setState(() {
                              _pickupLocation = null;
                              _destinationLocation = null;
                              _markers = {};
                            });

                          } catch (e) {
                            if (!mounted) return;
                            _showError(e.toString());
                          } finally {
                            if (mounted) {
                              setState(() => _isCreatingRide = false);
                            }
                          }
                        },
                        isLoading: _isCreatingRide,
                        isDriverMode: _isDriverMode,
                        onToggleMode: () {
                          setState(() {
                            _isDriverMode = !_isDriverMode;
                            _pickupLocation = null;
                            _destinationLocation = null;
                            _markers = {};
                          });
                        },
                      ),
                    ),
                  );
                },
              ),

              // Loading Indicator
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),

          // Other Tabs
          const ScheduledRidesScreen(),
          const ChatScreen(),
          const AccountScreen(),
        ],
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Rides',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 65,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 8,
        shadowColor: Colors.black26,
      ),
    );
  }
}