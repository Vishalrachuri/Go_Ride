// lib/widgets/location_input_field.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/place_details.dart';

class LocationInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String apiKey;
  final Position? currentPosition;
  final Function(PlaceDetails) onLocationSelected;

  const LocationInputField({
    Key? key,
    required this.controller,
    required this.label,
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

  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) return;

    setState(() => _isLoading = true);

    try {
      String baseUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
      String url = '$baseUrl?input=$query&key=${widget.apiKey}';

      if (widget.currentPosition != null) {
        url += '&location=${widget.currentPosition!.latitude},${widget.currentPosition!.longitude}';
        url += '&radius=50000'; // 50km radius
      }

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        setState(() {
          _predictions = List<Map<String, dynamic>>.from(data['predictions']);
        });
      }
    } catch (e) {
      print('Error searching places: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getPlaceDetails(String placeId) async {
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
      }
    } catch (e) {
      print('Error getting place details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.location_on),
            suffixIcon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : null,
          ),
          onChanged: _searchPlaces,
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
}