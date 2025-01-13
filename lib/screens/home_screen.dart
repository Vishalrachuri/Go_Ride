import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../utils/constants.dart';
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

  // State variables
  int _selectedIndex = 0;
  GoogleMapController? mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isLoadingRides = false;
  Set<Marker> _markers = {};
  bool isCarMode = true;
  String? _accessToken;
  Map<String, dynamic>? _userData;
  List<dynamic> _rides = [];

  // Controllers
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _seatsAvailable = 1;

  // ScrollController for DraggableScrollableSheet
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    mapController?.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Initialization Methods
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

  Future<void> _checkAuth() async {
    try {
      print('Loading user data...');
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      final userDataString = prefs.getString('user_data');

      print('Token found: ${_accessToken != null}');
      print('User data found: ${userDataString != null}');

      if (_accessToken == null || userDataString == null) {
        print('Missing auth data');
        if (mounted) {
          _showError('Please login again');
          _redirectToLogin();
        }
        return;
      }

      try {
        final userData = json.decode(userDataString);
        print('User data parsed: $userData');

        if (mounted) {
          setState(() {
            _userData = userData;
            isCarMode = userData['user_type'] == 'driver';
            _isLoading = false;
          });
          print('State updated with user data');
        }
      } catch (e) {
        print('Error parsing user data: $e');
        if (mounted) {
          _showError('Error loading user data');
          _redirectToLogin();
        }
      }
    } catch (e) {
      print('Auth check error: $e');
      if (mounted) {
        _showError('Authentication error');
        _redirectToLogin();
      }
    }
  }


  // Location Methods
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _markers = {
            Marker(
              markerId: const MarkerId('currentLocation'),
              position: LatLng(position.latitude, position.longitude),
              infoWindow: const InfoWindow(title: 'Your Location'),
            ),
          };
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
      }
    } catch (e) {
      _logger.e('Error getting location: $e');
      _showError('Could not get current location');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
// Ride Methods
  Future<void> _loadRides() async {
    if (_isLoadingRides) return;

    try {
      setState(() => _isLoadingRides = true);

      if (_accessToken == null) {
        print('No access token found');
        _redirectToLogin();
        return;
      }

      print('Making request to: $baseUrl/rides');
      print('Using token: $_accessToken');

      final response = await http.get(
        Uri.parse('$baseUrl/rides'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _rides = data['rides'] ?? [];
            print('Loaded ${_rides.length} rides');
          });
        }
      } else if (response.statusCode == 404) {
        // No rides found - that's okay
        if (mounted) {
          setState(() {
            _rides = [];
            print('No rides found');
          });
        }
      } else if (response.statusCode == 401) {
        print('Unauthorized - redirecting to login');
        _redirectToLogin();
      } else {
        print('Error response: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load rides: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in _loadRides: $e');
      _logger.e('Error loading rides: $e');
      // Only show error if it's not a "no rides found" situation
      if (!e.toString().contains('404')) {
        _showError('Failed to load rides: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRides = false);
      }
    }
  }

  Future<void> _createRide() async {
    if (_pickupController.text.isEmpty ||
        _destinationController.text.isEmpty ||
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
          'pickup_location': _pickupController.text,
          'pickup_latitude': _currentPosition?.latitude ?? 0,
          'pickup_longitude': _currentPosition?.longitude ?? 0,
          'destination': _destinationController.text,
          'destination_latitude': 0,
          'destination_longitude': 0,
          'scheduled_time': scheduledDateTime.toIso8601String(),
          'seats_available': _seatsAvailable,
        }),
      );

      if (response.statusCode == 200) {
        _showMessage(
          isCarMode ? 'Ride offered successfully' : 'Ride requested successfully',
        );
        _clearForm();
        _loadRides();
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

  // UI Helper Methods
  void _clearForm() {
    setState(() {
      _pickupController.clear();
      _destinationController.clear();
      _selectedDate = null;
      _selectedTime = null;
      _seatsAvailable = 1;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  void _redirectToLogin() {
    if (!mounted) return;
    print('Redirecting to login screen');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
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
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  // UI Building Methods
  Widget _buildLocationCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                      backgroundColor: isCarMode ? Colors.deepPurple : Colors.grey,
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
                      backgroundColor: !isCarMode ? Colors.deepPurple : Colors.grey,
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

            // Location Fields
            TextField(
              controller: _pickupController,
              decoration: InputDecoration(
                labelText: 'Pickup Location',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                labelText: 'Destination',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date & Time Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedDate == null
                          ? 'Select Date'
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectTime(context),
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _selectedTime == null
                          ? 'Select Time'
                          : _selectedTime!.format(context),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Seats Row (only for drivers)
            if (isCarMode) ...[
              Row(
                children: [
                  const Text(
                    'Available Seats: ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => setState(() {
                      if (_seatsAvailable > 1) _seatsAvailable--;
                    }),
                  ),
                  Text(
                    '$_seatsAvailable',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() {
                      if (_seatsAvailable < 6) _seatsAvailable++;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Submit Button
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
  Widget _buildHomeTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (GoogleMapController controller) async {
            try {
              setState(() {
                mapController = controller;
              });
              if (_currentPosition != null) {
                await controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 15,
                    ),
                  ),
                );
              }
            } catch (e) {
              _logger.e('Error initializing map: $e');
              _showError('Error loading map');
            }
          },
          initialCameraPosition: CameraPosition(
            target: _currentPosition != null
                ? LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            )
                : const LatLng(37.42796133580664, -122.085749655962),
            zoom: 15,
          ),
          myLocationButtonEnabled: true,
          myLocationEnabled: true,
          zoomControlsEnabled: true,
          zoomGesturesEnabled: true,
          markers: _markers,
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.3,
          minChildSize: 0.2,
          maxChildSize: 0.9,
          snap: true,
          snapSizes: const [0.3, 0.9],
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
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
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Scheduled',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}