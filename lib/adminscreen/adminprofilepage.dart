import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({Key? key}) : super(key: key);

  @override
  _AdminProfilePageState createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  Map<String, dynamic>? profile;
  bool isLoading = true;
  String? error;
  late TextEditingController emailController;
  late TextEditingController numberController;
  late TextEditingController groupCodeController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    numberController = TextEditingController();
    groupCodeController = TextEditingController();
    fetchProfile();
  }

  @override
  void dispose() {
    emailController.dispose();
    numberController.dispose();
    groupCodeController.dispose();
    super.dispose();
  }

  Future<void> fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gId = prefs.getString('G_ID') ?? '461430';
      
      if (gId.isEmpty) {
        setState(() {
          error = 'Invalid G_ID: G_ID is empty';
          isLoading = false;
        });
        if (kDebugMode) {
          print('Error: $error');
        }
        return;
      }

      if (kDebugMode) {
        print('Fetching profile for G_ID: $gId');
      }

      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/group-master')
      );

      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = jsonDecode(response.body);
          if (kDebugMode) {
            print('API Response: ${jsonEncode(data)}');
          }
        } catch (e) {
          setState(() {
            error = 'Error parsing API response: $e';
            isLoading = false;
          });
          if (kDebugMode) {
            print('Error: $error');
            print('Raw Response: ${response.body}');
          }
          return;
        }

        List<dynamic> groupList;
        if (data is List) {
          groupList = data;
        } else if (data is Map<String, dynamic> && data.containsKey('groups')) {
          groupList = data['groups'];
        } else {
          setState(() {
            error = 'Unexpected API response format';
            isLoading = false;
          });
          if (kDebugMode) {
            print('Error: $error');
          }
          return;
        }

        final group = groupList.firstWhere(
          (item) => item['Grop_code']?.toString() == gId,
          orElse: () => null,
        );

        if (group != null) {
          setState(() {
            profile = Map<String, dynamic>.from(group);
            emailController.text = group['email']?.toString() ?? '';
            numberController.text = group['number']?.toString() ?? '';
            groupCodeController.text = group['Grop_code']?.toString() ?? '';
            isLoading = false;
          });
          if (kDebugMode) {
            print('Profile loaded: $profile');
          }
        } else {
          setState(() {
            error = 'No group found with G_ID: $gId';
            isLoading = false;
          });
          if (kDebugMode) {
            print('Error: $error');
          }
        }
      } else {
        setState(() {
          error = 'Failed to load profile (Status: ${response.statusCode})';
          isLoading = false;
        });
        if (kDebugMode) {
          print('Error: $error');
          print('Raw Response: ${response.body}');
        }
      }
    } catch (e) {
      setState(() {
        error = 'Error fetching profile: $e';
        isLoading = false;
      });
      if (kDebugMode) {
        print('Error: $error');
      }
    }
  }

  Future<void> updateProfile() async {
    if (emailController.text.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text)) {
      _showSnackBar('Please enter a valid email', isError: true);
      if (kDebugMode) {
        print('Validation Error: Invalid email');
      }
      return;
    }

    if (numberController.text.isEmpty || numberController.text.length < 10) {
      _showSnackBar('Please enter a valid phone number', isError: true);
      if (kDebugMode) {
        print('Validation Error: Invalid phone number');
      }
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://tagai.caxis.ca/public/api/group-master/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'Grop_code': profile?['Grop_code']?.toString(),
          'email': emailController.text,
          'number': numberController.text,
        }),
      );

      if (kDebugMode) {
        print('Update Request: ${{
          'Grop_code': profile?['Grop_code']?.toString(),
          'email': emailController.text,
          'number': numberController.text,
        }}');
        print('Update Response: ${response.statusCode} - ${response.body}');
      }

      if (response.statusCode == 200) {
        setState(() {
          profile?['email'] = emailController.text;
          profile?['number'] = numberController.text;
        });
        _showSnackBar('Profile updated successfully', isError: false);
      } else {
        _showSnackBar('Failed to update profile', isError: true);
        if (kDebugMode) {
          print('Update Error: Status ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      _showSnackBar('Error updating profile: $e', isError: true);
      if (kDebugMode) {
        print('Update Error: $e');
      }
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: 16,
          color: enabled ? Colors.black : Colors.grey[600],
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.black,
            size: 22,
          ),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: fetchProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : profile == null
                  ? Center(
                      child: Text(
                        'No profile data available',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  profile!['name']?.toString() ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile!['group_name']?.toString() ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Group Information
                          const Text(
                            'Group Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildInfoCard(
                            'SHORT GROUP NAME',
                            profile!['short_group_name']?.toString() ?? 'N/A',
                          ),

                          const SizedBox(height: 24),

                          // Contact Information
                          const Text(
                            'Contact Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: emailController,
                            label: 'Email Address',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),

                          _buildTextField(
                            controller: numberController,
                            label: 'Phone Number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),

                          _buildTextField(
                            controller: groupCodeController,
                            label: 'Group Code',
                            icon: Icons.code_outlined,
                            enabled: false,
                          ),

                          const SizedBox(height: 32),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : updateProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
    );
  }
}