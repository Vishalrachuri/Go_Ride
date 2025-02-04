class Ride {
  final int id;
  final int? driverId;
  final int? riderId;
  final String pickupLocation;
  final double pickupLatitude;
  final double pickupLongitude;
  final String destination;
  final double destinationLatitude;
  final double destinationLongitude;
  final DateTime scheduledTime;
  final int seatsAvailable;
  final String status;
  final String? notes;
  final String? routePolyline;
  final int? estimatedDuration;
  final DateTime? actualStartTime;
  final DateTime? actualEndTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? driver;
  final Map<String, dynamic>? rider;

  Ride({
    required this.id,
    this.driverId,
    this.riderId,
    required this.pickupLocation,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destination,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.scheduledTime,
    required this.seatsAvailable,
    required this.status,
    this.notes,
    this.routePolyline,
    this.estimatedDuration,
    this.actualStartTime,
    this.actualEndTime,
    required this.createdAt,
    required this.updatedAt,
    this.driver,
    this.rider,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'],
      driverId: json['driver_id'],
      riderId: json['rider_id'],
      pickupLocation: json['pickup_location'],
      pickupLatitude: json['pickup_latitude'].toDouble(),
      pickupLongitude: json['pickup_longitude'].toDouble(),
      destination: json['destination'],
      destinationLatitude: json['destination_latitude'].toDouble(),
      destinationLongitude: json['destination_longitude'].toDouble(),
      scheduledTime: DateTime.parse(json['scheduled_time']),
      seatsAvailable: json['seats_available'],
      status: json['status'],
      notes: json['notes'],
      routePolyline: json['route_polyline'],
      estimatedDuration: json['estimated_duration'],
      actualStartTime: json['actual_start_time'] != null
          ? DateTime.parse(json['actual_start_time'])
          : null,
      actualEndTime: json['actual_end_time'] != null
          ? DateTime.parse(json['actual_end_time'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      driver: json['driver'],
      rider: json['rider'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'rider_id': riderId,
      'pickup_location': pickupLocation,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'destination': destination,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'scheduled_time': scheduledTime.toIso8601String(),
      'seats_available': seatsAvailable,
      'status': status,
      'notes': notes,
      'route_polyline': routePolyline,
      'estimated_duration': estimatedDuration,
      'actual_start_time': actualStartTime?.toIso8601String(),
      'actual_end_time': actualEndTime?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'driver': driver,
      'rider': rider,
    };
  }
}