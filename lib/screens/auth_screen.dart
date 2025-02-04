import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../utils/constants.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool _isLoading = false;
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
      debugPrint('Error during auth: $e');
      _showMessage("Something went wrong. Please try again.", isError: true);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        await _saveUserData(responseData);

        if (!mounted) return;

        _showMessage('Login successful!');

        // Navigate after brief delay
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        final error = json.decode(response.body)['detail'] ?? 'Login failed';
        _showMessage(error, isError: true);
      }
    } catch (e) {
      debugPrint('Login error: $e');
      _showMessage('Login failed. Please check your connection.', isError: true);
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
        if (!mounted) return;

        _showMessage("Signup successful!");
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
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
        if (!mounted) return;

        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        _showMessage("Failed to authenticate with server", isError: true);
      }
    } catch (e) {
      debugPrint('Google sign in error: $e');
      _showMessage("Google sign in failed", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveUserData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (data['access_token'] != null) {
        await prefs.setString('access_token', data['access_token']);
      }

      if (data['user'] != null) {
        await prefs.setString('user_data', json.encode(data['user']));
      }
    } catch (e) {
      debugPrint('Error saving user data: $e');
      throw Exception('Failed to save user data: $e');
    }
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

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (!RegExp(r'^\+?[\d-]{10,}$').hasMatch(value)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo and Title
                  Image.asset(
                    'assets/images/go_ride_logo.png',
                    height: 100,
                    width: 100,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image: $error');
                      return const Icon(
                        Icons.car_rental,
                        size: 100,
                        color: Colors.deepPurple,
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  Text(
                    isLogin ? 'Welcome Back!' : 'Create Account',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Form Fields
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    prefixIcon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    prefixIcon: Icons.lock,
                    obscureText: true,
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 16),

                  if (!isLogin) ...[
                    CustomTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      prefixIcon: Icons.lock_outline,
                      obscureText: true,
                      validator: _validateConfirmPassword,
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      prefixIcon: Icons.person,
                      validator: (value) =>
                      value?.isEmpty ?? true ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      prefixIcon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 16),

                    // Date Picker
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate:
                          DateTime.now().subtract(const Duration(days: 6570)),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _selectedDate == null
                              ? 'Select Date'
                              : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // User Type Selection
                    DropdownButtonFormField<String>(
                      value: _selectedUserType,
                      decoration: const InputDecoration(
                        labelText: 'Account Type',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'rider', child: Text('Rider')),
                        DropdownMenuItem(value: 'driver', child: Text('Driver')),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedUserType = value!);
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Submit Button
                  CustomButton(
                    text: isLogin ? 'Login' : 'Sign Up',
                    onPressed: _handleSubmit,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),

                  // Toggle Auth Mode
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

                  ElevatedButton.icon(
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      height: 24,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata),
                    ),
                    label: const Text('Sign in with Google'),
                    onPressed: _handleGoogleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}