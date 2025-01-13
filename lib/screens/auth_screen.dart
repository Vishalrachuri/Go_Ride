import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';  // Make sure path is correct
import 'home_screen.dart';  // Adjust the path as needed

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool _isLoading = false;
  bool _showForgotPassword = false;
  String _selectedUserType = 'rider';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (isLogin) {
        await _handleLogin();
      } else {
        await _handleSignup();
      }
    } catch (e) {
      print('Error during auth: $e');
      _showMessage("Something went wrong. Please try again.", isError: true);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _handleLogin() async {
    try {
      setState(() => _isLoading = true);

      print('Login attempt - Email: ${_emailController.text.trim()}');

      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Save user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear(); // Clear old data first

        // Save token
        final token = responseData['access_token'];
        await prefs.setString('access_token', token);
        print('Saved token: $token');

        // Save user data
        final userData = json.encode(responseData['user']);
        await prefs.setString('user_data', userData);
        print('Saved user data: $userData');

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate after brief delay
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        // Navigate to home screen
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
        );
      } else {
        if (!mounted) return;
        final error = json.decode(response.body)['detail'] ?? 'Login failed';
        _showMessage('Login failed: $error', isError: true);
      }
    } catch (e) {
      print('Login error: $e');
      if (mounted) {
        _showMessage('Login failed: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveUserData(Map<String, dynamic> data) async {
    try {
      print('Starting to save user data...');
      final prefs = await SharedPreferences.getInstance();

      // Save access token
      if (data['access_token'] != null) {
        await prefs.setString('access_token', data['access_token']);
        print('Access token saved successfully');
      } else {
        print('Warning: No access token in response data');
      }

      // Save user data
      if (data['user'] != null) {
        final userDataString = json.encode(data['user']);
        await prefs.setString('user_data', userDataString);
        print('User data saved successfully: $userDataString');
      } else {
        print('Warning: No user data in response data');
      }

      // Verify saved data
      final savedToken = prefs.getString('access_token');
      final savedUserData = prefs.getString('user_data');
      print('Verification - Saved token: ${savedToken != null}');
      print('Verification - Saved user data: ${savedUserData != null}');

    } catch (e) {
      print('Error saving user data: $e');
      throw Exception('Failed to save user data: $e');
    }
  }

  Future<void> _handleSignup() async {
    if (_selectedDate == null) {
      _showMessage("Please select your date of birth", isError: true);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'confirm_password': _confirmPasswordController.text,
          'name': _nameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'date_of_birth':
          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
          'user_type': _selectedUserType,
        }),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        await _saveUserData(responseData);
        if (mounted) {
          _showMessage("Signup successful!");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (ctx) => const HomeScreen()),
          );
        }
      } else {
        _showMessage(responseData['detail'] ?? "Signup failed", isError: true);
      }
    } catch (e) {
      _showMessage("Signup failed. Please try again.", isError: true);
    }
  }
  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _isLoading = true);

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final response = await http.post(
        Uri.parse('$baseUrl/google-signin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': userCredential.user?.email,
          'name': userCredential.user?.displayName,
          'google_id': userCredential.user?.uid,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        await _saveUserData(responseData);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (ctx) => const HomeScreen()),
          );
        }
      } else {
        _showMessage("Failed to authenticate with server", isError: true);
      }
    } catch (e) {
      print('Google sign in error: $e');
      _showMessage("Google sign in failed", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Future<void> _saveUserData(Map<String, dynamic> userData) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString('user_data', json.encode(userData['user']));
  //   await prefs.setString('access_token', userData['access_token']);
  // }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Login' : 'Sign Up'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              if (!isLogin) ...[
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().subtract(const Duration(days: 6570)),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 12),
                        Text(
                          _selectedDate == null
                              ? 'Select Date of Birth'
                              : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                          style: TextStyle(
                            color: _selectedDate == null ? Colors.grey : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedUserType,
                  decoration: const InputDecoration(
                    labelText: 'User Type',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'rider', child: Text('Rider')),
                    DropdownMenuItem(value: 'driver', child: Text('Driver')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedUserType = value!;
                    });
                  },
                ),
              ],
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(isLogin ? 'Login' : 'Sign Up'),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                    _formKey.currentState?.reset();
                  });
                },
                child: Text(
                  isLogin
                      ? "Don't have an account? Sign up"
                      : "Already have an account? Login",
                ),
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _handleGoogleSignIn,
                icon: Image.asset(
                  'assets/images/google_logo.png',
                  height: 24,
                ),
                label: const Text('Sign in with Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}