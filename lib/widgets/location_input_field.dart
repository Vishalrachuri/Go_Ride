import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/place_details.dart';

class LocationInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;  // Added hint parameter
  final String apiKey;
  final Position? currentPosition;
  final Function(PlaceDetails) onLocationSelected;

  const LocationInputField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,  // Made hint optional
    required this.apiKey,
    this.currentPosition,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  State<LocationInputField> createState() => _LocationInputFieldState();
}

class _LocationInputFieldState extends State<LocationInputField> {
  List<Map<String, dynamic>> _predictions = [];
  bool _isLoading = false;
  bool _error = false;
  Timer? _debounce;

  void _searchPlaces(String query) {
    if (query.length < 3) return;

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _isLoading = true;
        _error = false;
      });

      try {
        String baseUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
        String url = '$baseUrl?input=$query&key=${widget.apiKey}';

        if (widget.currentPosition != null) {
          url += '&location=${widget.currentPosition!.latitude},${widget.currentPosition!.longitude}';
          url += '&radius=50000';
        }

        final response = await http.get(Uri.parse(url));
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          setState(() {
            _predictions = List<Map<String, dynamic>>.from(data['predictions']);
            _isLoading = false;
          });
        } else {
          setState(() {
            _predictions = [];
            _error = true;
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _error = true;
          _isLoading = false;
        });
        debugPrint('Error searching places: $e');
      }
    });
  }

  Future<void> _getPlaceDetails(String placeId) async {
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
              '?place_id=$placeId'
              '&fields=geometry,formatted_address,name'
              '&key=${widget.apiKey}'
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final result = data['result'];
        final details = PlaceDetails(
          placeId: placeId,
          name: result['formatted_address'] ?? result['name'],
          lat: result['geometry']['location']['lat'],
          lng: result['geometry']['location']['lng'],
        );

        widget.controller.text = details.name;
        widget.onLocationSelected(details);
      } else {
        _showError("Could not fetch location details.");
      }
    } catch (e) {
      _showError("Error fetching location details.");
      debugPrint('Error getting place details: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
              '?latlng=${position.latitude},${position.longitude}'
              '&key=${widget.apiKey}'
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final place = data['results'][0];
        final details = PlaceDetails(
          placeId: place['place_id'],
          name: place['formatted_address'],
          lat: position.latitude,
          lng: position.longitude,
        );

        widget.controller.text = details.name;
        widget.onLocationSelected(details);
      } else {
        _showError("Unable to fetch location.");
      }
    } catch (e) {
      _showError("Error retrieving current location.");
      debugPrint('Error getting current location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    setState(() {
      _error = true;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,  // Using the hint parameter
            prefixIcon: const Icon(Icons.location_on),
            suffixIcon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _useCurrentLocation,
            ),
          ),
          onChanged: _searchPlaces,
        ),
        if (_error)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "No results found. Try a different search.",
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        if (_predictions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(prediction['description']),
                  onTap: () {
                    _getPlaceDetails(prediction['place_id']);
                    setState(() => _predictions = []);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}