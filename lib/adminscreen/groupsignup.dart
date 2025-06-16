import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For debugPrint

class GroupRegisterPage extends StatefulWidget {
  const GroupRegisterPage({super.key});

  @override
  State<GroupRegisterPage> createState() => _GroupRegisterPageState();
}

class _GroupRegisterPageState extends State<GroupRegisterPage> {
  final _nameController = TextEditingController();
  final _shortGroupNameController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _numberController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _registerGroup() async {
    if (_nameController.text.isEmpty ||
        _shortGroupNameController.text.isEmpty ||
        _groupNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _numberController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      debugPrint('Validation Error: One or more fields are empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final requestBody = jsonEncode({
        'name': _nameController.text,
        'short_group_name': _shortGroupNameController.text,
        'group_name': _groupNameController.text,
        'email': _emailController.text,
        'number': _numberController.text,
        'password': _passwordController.text,
        'role_id': '2',
        'status': '0',
      });
      debugPrint('Request Body: $requestBody');

      final response = await http.post(
        Uri.parse('https://tagai.caxis.ca/public/api/group-master'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Success: Group registered successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group registered successfully!')),
        );
        Navigator.pop(context);
      } else {
        debugPrint('Registration Failed: Status ${response.statusCode}, Body: ${response.body}');
        try {
          final errorJson = jsonDecode(response.body);
          final errorMessage = errorJson['message'] ?? 'Unknown error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: $errorMessage')),
          );
        } catch (e) {
          debugPrint('Error parsing response body: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: ${response.body}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Network or Unexpected Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
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
                    'Register Group',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your Group Account.',
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
                        'Name',
                        'Enter group name',
                        _nameController,
                        Icons.business_outlined,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Short Group Name field
                      _buildInputField(
                        'Short Group Name',
                        'Enter short name',
                        _shortGroupNameController,
                        Icons.short_text_outlined,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Group Name field
                      _buildInputField(
                        'Group Name',
                        'Enter full group name',
                        _groupNameController,
                        Icons.corporate_fare_outlined,
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
                          onPressed: _isLoading ? null : _registerGroup,
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
                                  'Register Group',
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

  Widget _buildInputField(String label, String hint, TextEditingController controller, IconData icon) {
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
    _shortGroupNameController.dispose();
    _groupNameController.dispose();
    _emailController.dispose();
    _numberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}