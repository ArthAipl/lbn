import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class MemberRegisterPage extends StatefulWidget {
  const MemberRegisterPage({super.key});

  @override
  State<MemberRegisterPage> createState() => _MemberRegisterPageState();
}

class _MemberRegisterPageState extends State<MemberRegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _numberController = TextEditingController();
  final _groupCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Function to validate group code using the group-master API
  Future<bool> _validateGroupCode(String groupCode) async {
    try {
      final response = await http
          .get(
            Uri.parse('https://tagai.caxis.ca/public/api/group-master'),
            headers: {
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw const SocketException('Group code validation timed out');
            },
          );

      print('Group Master Status Code: ${response.statusCode}');
      print('Group Master Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // Parse the response: {"groups": [{...}, ...]}
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> groups = responseData['groups'] ?? [];
        
        // Check for groups with non-null Grop_code and status "1" (approved)
        final validCodes = groups
            .where((group) => group['Grop_code'] != null && group['status'] == '1')
            .map((group) => group['Grop_code'].toString())
            .toList();

        print('Valid Group Codes: $validCodes');
        return validCodes.contains(groupCode);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to validate group code: ${response.body}')),
        );
        return false;
      }
    } catch (e) {
      print('Group Code Validation Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error validating group code: $e')),
      );
      return false;
    }
  }

  Future<void> _registerMember() async {
    // Validate inputs
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _numberController.text.isEmpty ||
        _groupCodeController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    // Basic email and phone number validation
    if (!_emailController.text.contains('@') || !_emailController.text.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }
    if (_numberController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    // Validate group code
    final isValidGroupCode = await _validateGroupCode(_groupCodeController.text);
    if (!isValidGroupCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or unapproved group code')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse('https://tagai.caxis.ca/public/api/member'),
            headers: {
              'Content-Type': 'application/json',
              // Add 'Authorization' header if required by the API
              // 'Authorization': 'Bearer your_token_here',
            },
            body: jsonEncode({
              'Name': _nameController.text,
              'email': _emailController.text,
              'number': _numberController.text,
              'Grop_code': _groupCodeController.text,
              'password': _passwordController.text,
              'role_id': '3',
              'status': '1',
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw const SocketException('Request timed out');
            },
          );

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member registered successfully!')),
        );
        await Future.delayed(const Duration(seconds: 2)); // Show SnackBar
        Navigator.pop(context);
      } else {
        // Parse the error message for better user feedback
        String errorMessage = 'Registration failed';
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson['error'] != null) {
            errorMessage = errorJson['error'];
          } else if (errorJson['message'] != null) {
            errorMessage = errorJson['message'];
          }
        } catch (_) {
          errorMessage = 'Registration failed: ${response.body}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } on SocketException catch (e) {
      print('Network Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please check your connection.')),
      );
    } catch (e) {
      print('Error Type: ${e.runtimeType}');
      print('Error Details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
        print('Loading state set to false');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header section with dark background
            Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
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
                  const SizedBox(height: 35),
                  // Title and subtitle
                  const Text(
                    'Register as Member',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join a group and start networking with others.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            // White form section
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Name field
                      _buildInputField(
                        'Full Name',
                        'Enter your full name',
                        _nameController,
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 20),
                      // Email field
                      _buildInputField(
                        'Email Address',
                        'Enter email address',
                        _emailController,
                        Icons.email_outlined,
                      ),
                      const SizedBox(height: 20),
                      // Number field
                      _buildInputField(
                        'Phone Number',
                        'Enter phone number',
                        _numberController,
                        Icons.phone_outlined,
                      ),
                      const SizedBox(height: 20),
                      // Group Code field
                      _buildInputField(
                        'Group Code',
                        'Enter group code',
                        _groupCodeController,
                        Icons.group_outlined,
                      ),
                      const SizedBox(height: 20),
                      // Password field
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
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: '••••••••••••',
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
                      const SizedBox(height: 32),
                      // Register button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _registerMember,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Register as Member',
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
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
      String label, String hint, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
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
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _numberController.dispose();
    _groupCodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}