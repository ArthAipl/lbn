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
  late TextEditingController groupNameController;
  late TextEditingController shortGroupNameController;
  late TextEditingController nameController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    numberController = TextEditingController();
    groupCodeController = TextEditingController();
    groupNameController = TextEditingController();
    shortGroupNameController = TextEditingController();
    nameController = TextEditingController();
    fetchProfile();
  }

  @override
  void dispose() {
    emailController.dispose();
    numberController.dispose();
    groupCodeController.dispose();
    groupNameController.dispose();
    shortGroupNameController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gId = prefs.getString('G_ID') ?? '1'; // Default to '1' for testing

      if (gId.isEmpty) {
        setState(() {
          error = 'Invalid G_ID: G_ID is empty';
          isLoading = false;
        });
        if (kDebugMode) {
          print('Error: $error');
        }
        await clearPreferences();
        return;
      }

      if (kDebugMode) {
        print('Fetching profile for G_ID: $gId');
      }

      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/group-master'),
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

        if (kDebugMode) {
          print('Group List: ${jsonEncode(groupList)}');
          print('Searching for G_ID: $gId');
        }

        final group = groupList.firstWhere(
          (item) => item['G_ID']?.toString() == gId,
          orElse: () => null,
        );

        if (group != null) {
          setState(() {
            profile = Map<String, dynamic>.from(group);
            emailController.text = group['email']?.toString() ?? '';
            numberController.text = group['number']?.toString() ?? '';
            groupCodeController.text = group['Grop_code']?.toString() ?? '';
            groupNameController.text = group['group_name']?.toString() ?? '';
            shortGroupNameController.text = group['short_group_name']?.toString() ?? '';
            nameController.text = group['name']?.toString() ?? '';
            isLoading = false;
          });
          if (kDebugMode) {
            print('Profile loaded: $profile');
            print('Fetched G_ID: ${profile?['G_ID']}');
          }
        } else {
          setState(() {
            error = 'No group found with G_ID: $gId';
            isLoading = false;
          });
          if (kDebugMode) {
            print('Error: $error');
          }
          await clearPreferences();
          _showSnackBar('Invalid group ID. Please log in again.', isError: true);
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
    // Validate input fields
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

    if (groupNameController.text.isEmpty) {
      _showSnackBar('Please enter a valid group name', isError: true);
      if (kDebugMode) {
        print('Validation Error: Invalid group name');
      }
      return;
    }

    if (shortGroupNameController.text.isEmpty) {
      _showSnackBar('Please enter a valid short group name', isError: true);
      if (kDebugMode) {
        print('Validation Error: Invalid short group name');
      }
      return;
    }

    if (nameController.text.isEmpty) {
      _showSnackBar('Please enter a valid name', isError: true);
      if (kDebugMode) {
        print('Validation Error: Invalid name');
      }
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final gId = prefs.getString('G_ID') ?? '';

      if (gId.isEmpty) {
        _showSnackBar('Invalid group ID. Please log in again.', isError: true);
        setState(() {
          isSaving = false;
        });
        return;
      }

      // Prepare the update payload
      final updateData = {
        'G_ID': gId,
        'email': emailController.text,
        'number': numberController.text,
        'group_name': groupNameController.text,
        'short_group_name': shortGroupNameController.text,
        'name': nameController.text,
      };

      if (kDebugMode) {
        print('Update Request Payload: ${jsonEncode(updateData)}');
      }

      // Try PUT request with G_ID in the URL
      final response = await http.put(
        Uri.parse('https://tagai.caxis.ca/public/api/group-master/$gId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(updateData),
      );

      if (kDebugMode) {
        print('Update Response: ${response.statusCode} - ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse response to ensure it’s valid
        try {
          final responseData = jsonDecode(response.body);
          if (kDebugMode) {
            print('Parsed Update Response: $responseData');
          }

          // Update local profile data
          setState(() {
            profile?['email'] = emailController.text;
            profile?['number'] = numberController.text;
            profile?['group_name'] = groupNameController.text;
            profile?['short_group_name'] = shortGroupNameController.text;
            profile?['Grop_code'] = groupCodeController.text;
            profile?['name'] = nameController.text;
          });

          // Update SharedPreferences
          await prefs.setString('email', emailController.text);
          await prefs.setString('number', numberController.text);
          await prefs.setString('group_name', groupNameController.text);
          await prefs.setString('short_group_name', shortGroupNameController.text);
          await prefs.setString('Grop_code', groupCodeController.text);
          await prefs.setString('name', nameController.text);

          _showSnackBar('Profile updated successfully', isError: false);
        } catch (e) {
          _showSnackBar('Error parsing update response: $e', isError: true);
          if (kDebugMode) {
            print('Parse Error: $e');
          }
        }
      } else {
        // Handle specific status codes
        String errorMessage = 'Failed to update profile: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
          if (errorData['error'] != null) {
            errorMessage += ' - ${errorData['error']}';
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing error response: $e');
          }
        }

        if (response.statusCode == 500) {
          errorMessage = 'Server error: $errorMessage. Please verify G_ID ($gId) exists in the database.';
        } else if (response.statusCode == 404) {
          errorMessage = 'Update endpoint not found. Tried: https://tagai.caxis.ca/public/api/group-master/$gId';
        } else if (response.statusCode == 422) {
          errorMessage = 'Validation error on server. Please check input data.';
        } else if (response.statusCode == 405) {
          errorMessage = 'Method not allowed. Try PATCH instead of PUT or check the endpoint.';
        }

        _showSnackBar(errorMessage, isError: true);
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

  Future<void> clearPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('M_ID');
      await prefs.remove('Name');
      await prefs.remove('email');
      await prefs.remove('number');
      await prefs.remove('Grop_code');
      await prefs.remove('G_ID');
      await prefs.remove('role_id');
      await prefs.remove('group_name');
      await prefs.remove('short_group_name');
      await prefs.remove('name');
      if (kDebugMode) {
        print('Shared preferences cleared');
      }
      setState(() {
        profile = null;
        emailController.clear();
        numberController.clear();
        groupCodeController.clear();
        groupNameController.clear();
        shortGroupNameController.clear();
        nameController.clear();
        isLoading = true;
        error = null;
      });
      await fetchProfile();
      _showSnackBar('Preferences cleared successfully', isError: false);
    } catch (e) {
      _showSnackBar('Error clearing preferences: $e', isError: true);
      if (kDebugMode) {
        print('Error clearing preferences: $e');
      }
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
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.black,
            size: 22,
          ),
          filled: true,
          fillColor: Colors.white,
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
                          color: Colors.black,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.black,
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
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchProfile,
                      color: Colors.black,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile Header
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6C63FF), Color(0xFF5A52E8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
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
                                  Text(
                                    profile!['name']?.toString() ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    profile!['group_name']?.toString() ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
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

                            _buildTextField(
                              controller: nameController,
                              label: 'Name',
                              icon: Icons.person_outlined,
                              enabled: true,
                            ),

                            _buildTextField(
                              controller: shortGroupNameController,
                              label: 'Short Group Name',
                              icon: Icons.group_outlined,
                              enabled: true,
                            ),

                            _buildTextField(
                              controller: groupNameController,
                              label: 'Group Name',
                              icon: Icons.group_outlined,
                              enabled: true,
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
                                        'Save',
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
                    ),
    );
  }
}