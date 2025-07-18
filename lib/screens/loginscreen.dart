import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lbn/adminscreen/admindashboard.dart';
import 'package:lbn/userscreens/userdashboard.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  bool _validateInputs() {
    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter phone number';
      });
      return false;
    }
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter password';
      });
      return false;
    }
    if (_phoneController.text.length < 10) {
      setState(() {
        _errorMessage = 'Please enter a valid phone number';
      });
      return false;
    }
    return true;
  }

  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Remove user-related keys to ensure clean state
      await prefs.remove('M_ID');
      await prefs.remove('Name');
      await prefs.remove('email');
      await prefs.remove('number');
      await prefs.remove('Grop_code');
      await prefs.remove('G_ID');
      await prefs.remove('role_id');
      await prefs.remove('group_name'); // Optional, for admins
      await prefs.remove('short_group_name'); // Optional, for admins

      // Determine role_id to handle admin (2) or member (3)
      final roleId = userData['role_id']?.toString();
      if (roleId == null) {
        throw Exception('Missing role_id in user data');
      }

      // Handle field variations for admin and member
      final mId = userData['M_ID']?.toString(); // Only for members
      final name = userData['Name']?.toString() ?? userData['name']?.toString();
      final email = userData['email']?.toString();
      final number = userData['number']?.toString();
      final groupCode = userData['Grop_code']?.toString();
      final gId = userData['G_ID']?.toString();

      // Validate required fields (M_ID only required for members)
      if (name == null || email == null || number == null || groupCode == null || gId == null) {
        throw Exception('Missing required user data fields');
      }
      if (roleId == '3' && mId == null) {
        throw Exception('Missing M_ID for member');
      }

      // Save user data
      if (roleId == '3') {
        await prefs.setString('M_ID', mId!); // Save M_ID only for members
      }
      await prefs.setString('Name', name);
      await prefs.setString('email', email);
      await prefs.setString('number', number);
      await prefs.setString('Grop_code', groupCode);
      await prefs.setString('G_ID', gId);
      await prefs.setString('role_id', roleId);

      // Save additional admin fields if role_id is 2 (optional, remove if not needed)
      if (roleId == '2') {
        await prefs.setString('group_name', userData['group_name']?.toString() ?? '');
        await prefs.setString('short_group_name', userData['short_group_name']?.toString() ?? '');
      }

      debugPrint('User data saved successfully: role_id=$roleId, Name=$name, G_ID=$gId${roleId == '3' ? ', M_ID=$mId' : ''}');
    } catch (e) {
      debugPrint('Error saving user data: $e');
      setState(() {
        _errorMessage = 'Failed to save user data. Please try again.';
      });
      rethrow; // Prevent navigation if saving fails
    }
  }

  Future<void> _login() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://tagai.caxis.ca/public/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'identifier': _phoneController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // Check if responseData['data'] exists
        if (responseData['data'] == null) {
          setState(() {
            _errorMessage = 'Invalid response: No user data received';
          });
          debugPrint('Error: No user data in response');
          return;
        }

        final userData = responseData['data'];
        // Check the nested 'status' field in the user data
        if (userData['status'] == "0") {
          setState(() {
            _errorMessage = 'Login denied: Account is inactive or disabled.';
          });
          debugPrint('Login denied: Status is 0');
          return;
        } else if (userData['status'] == "1") {
          final userRole = int.tryParse(userData['role_id']?.toString() ?? '');
          if (userRole == null) {
            setState(() {
              _errorMessage = 'Invalid user role in response';
            });
            debugPrint('Error: Invalid or missing role_id');
            return;
          }

          // Save user data before navigating
          await _saveUserData(userData);

          // Navigate based on role_id
          if (userRole == 2) {
            debugPrint('Navigating to Admin Dashboard');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AdminDashboard()),
            );
          } else if (userRole == 3) {
            debugPrint('Navigating to User Dashboard');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => UserDashboard()),
            );
          } else {
            setState(() {
              _errorMessage = 'Unknown user role: $userRole';
            });
            debugPrint('Error: Unknown user role: $userRole');
          }
        } else {
          setState(() {
            _errorMessage = 'Invalid status in response';
          });
          debugPrint('Error: Invalid status value: ${userData['status']}');
        }
      } else {
        String errorMsg = responseData['message'] ?? 'Server error';
        if (responseData['errors'] != null) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          errorMsg = errors.values.join(', ');
        }
        setState(() {
          _errorMessage = errorMsg;
        });
        debugPrint('Server error: ${response.statusCode} - $errorMsg');
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Connection error. Please check your internet.';
      });
      debugPrint('Connection error: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Connect, network, grow, invest, repeat wisely.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Phone Number',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                hintText: 'Enter your phone number',
                                prefixIcon: const Icon(Icons.phone_android),
                                counterText: '',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _passwordController, // Fixed typo: _passwordContainer -> _passwordController
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  child: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            width: double.infinity,
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {},
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}