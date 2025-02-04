import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place_details.dart';
import 'location_input_field.dart';
import 'custom_button.dart';
import '../utils/constants.dart';

class RideCreationForm extends StatefulWidget {
  final Position? currentPosition;
  final Function(PlaceDetails) onPickupSelected;
  final Function(PlaceDetails) onDestinationSelected;
  final Function(DateTime, TimeOfDay, int) onCreateRide;
  final bool isLoading;
  final bool isDriverMode;
  final VoidCallback onToggleMode;

  const RideCreationForm({
    Key? key,
    this.currentPosition,
    required this.onPickupSelected,
    required this.onDestinationSelected,
    required this.onCreateRide,
    required this.isLoading,
    required this.isDriverMode,
    required this.onToggleMode,
  }) : super(key: key);

  @override
  State<RideCreationForm> createState() => _RideCreationFormState();
}

class _RideCreationFormState extends State<RideCreationForm> {
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _seatsAvailable = 1;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      // Validate that the selected time is not in the past
      final now = DateTime.now();
      final selectedDateTime = DateTime(
        _selectedDate?.year ?? now.year,
        _selectedDate?.month ?? now.month,
        _selectedDate?.day ?? now.day,
        picked.hour,
        picked.minute,
      );

      if (selectedDateTime.isBefore(now)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a future time'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() => _selectedTime = picked);
    }
  }

  void _handleCreateRide() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select date and time'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validate that pickup and destination are different
      if (_pickupController.text == _destinationController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup and destination cannot be the same'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create date time combination and validate it's in the future
      final now = DateTime.now();
      final selectedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      if (selectedDateTime.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a future date and time'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      widget.onCreateRide(_selectedDate!, _selectedTime!, _seatsAvailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isDriverMode
                                ? Theme.of(context).primaryColor
                                : Colors.grey[200],
                            foregroundColor: widget.isDriverMode
                                ? Colors.white
                                : Colors.black54,
                            elevation: widget.isDriverMode ? 2 : 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: () {
                            if (!widget.isDriverMode) widget.onToggleMode();
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.drive_eta,
                                size: 20,
                                color: widget.isDriverMode
                                    ? Colors.white
                                    : Colors.black54,
                              ),
                              const SizedBox(width: 8),
                              const Text('Driver'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !widget.isDriverMode
                                ? Theme.of(context).primaryColor
                                : Colors.grey[200],
                            foregroundColor: !widget.isDriverMode
                                ? Colors.white
                                : Colors.black54,
                            elevation: !widget.isDriverMode ? 2 : 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: () {
                            if (widget.isDriverMode) widget.onToggleMode();
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person,
                                size: 20,
                                color: !widget.isDriverMode
                                    ? Colors.white
                                    : Colors.black54,
                              ),
                              const SizedBox(width: 8),
                              const Text('Rider'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Location Fields
              LocationInputField(
                controller: _pickupController,
                label: 'Pickup Location',
                hint: 'Enter pickup location',
                apiKey: GOOGLE_MAPS_API_KEY,
                currentPosition: widget.currentPosition,
                onLocationSelected: widget.onPickupSelected,
              ),
              const SizedBox(height: 16),

              LocationInputField(
                controller: _destinationController,
                label: 'Destination',
                hint: 'Enter destination',
                apiKey: GOOGLE_MAPS_API_KEY,
                currentPosition: widget.currentPosition,
                onLocationSelected: widget.onDestinationSelected,
              ),
              const SizedBox(height: 24),

              // Date & Time Selection
              Text(
                'Schedule',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _selectedDate == null
                            ? 'Select Date'
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        _selectedTime == null
                            ? 'Select Time'
                            : _selectedTime!.format(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              // Seats Selection (Driver mode only)
              if (widget.isDriverMode) ...[
                const SizedBox(height: 24),
                Text(
                  'Available Seats',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          if (_seatsAvailable > 1) {
                            setState(() => _seatsAvailable--);
                          }
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                        ),
                      ),
                      Text(
                        '$_seatsAvailable',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          if (_seatsAvailable < 6) {
                            setState(() => _seatsAvailable++);
                          }
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              CustomButton(
                text: widget.isDriverMode ? 'Offer Ride' : 'Request Ride',
                onPressed: _handleCreateRide,
                isLoading: widget.isLoading,
                backgroundColor: Colors.green,
                icon: widget.isDriverMode ? Icons.drive_eta : Icons.directions_walk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}