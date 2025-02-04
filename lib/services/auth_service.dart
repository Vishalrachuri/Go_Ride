// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AuthService {
  // Signup method
  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String confirmPassword,
    required String name,
    required String phoneNumber,
    required String dateOfBirth,
    required String userType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'confirm_password': confirmPassword,
          'name': name,
          'phone_number': phoneNumber,
          'date_of_birth': dateOfBirth,
          'user_type': userType,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Save token and user data
        await _saveUserData(data);
        return data;
      } else {
        throw Exception(data['detail'] ?? 'Signup failed');
      }
    } catch (e) {
      throw Exception('Error during signup: $e');
    }
  }

  // Login method
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveUserData(data);
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Login failed');
      }
    } catch (e) {
      print('Login error: $e');
      throw Exception('Error during login: $e');
    }
  }

  // Google Sign In method
  static Future<Map<String, dynamic>> googleSignIn({
    required String email,
    required String name,
    required String googleId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/google-signin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'name': name,
          'google_id': googleId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveUserData(data);
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Google sign in failed');
      }
    } catch (e) {
      throw Exception('Error during Google sign in: $e');
    }
  }

  // Save user data to SharedPreferences
  static Future<void> _saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    if (data['access_token'] != null) {
      await prefs.setString('access_token', data['access_token']);
    }

    if (data['user'] != null) {
      await prefs.setString('user_data', jsonEncode(data['user']));
    }
  }

  // Logout method
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}