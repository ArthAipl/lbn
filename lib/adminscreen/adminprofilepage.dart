import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For debugPrint

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _shortGroupNameController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _numberController = TextEditingController();
  final _panNumController = TextEditingController();
  final _groupCodeController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = true; // Start in edit mode
  String _mId = ''; // Store M_ID internally

  @override
  void initState() {
    super.initState();
    debugPrint('ProfilePage: Initializing at ${DateTime.now().toIso8601String()}');
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    debugPrint('ProfilePage: Attempting to load user data');
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      debugPrint('ProfilePage: SharedPreferences keys: ${prefs.getKeys()}');
      final userId = prefs.getString('G_ID') ?? '';
      debugPrint('ProfilePage: Retrieved user ID from SharedPreferences: "$userId"');

      if (userId.isEmpty) {
        debugPrint('ProfilePage: Error - user ID (G_ID) is empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User ID not found. Please log in first.')),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pop(context);
        });
        return;
      }

      // Fetch M_ID from SharedPreferences
      _mId = prefs.getString('M_ID') ?? '';
      debugPrint('ProfilePage: Retrieved M_ID from SharedPreferences: "$_mId"');

      debugPrint('ProfilePage: Fetching profile data from API for G_ID: $userId');
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/group-master/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('ProfilePage: API response: $responseData');

        setState(() {
          _nameController.text = responseData['name']?.toString() ?? '';
          _shortGroupNameController.text = responseData['short_group_name']?.toString() ?? '';
          _groupNameController.text = responseData['group_name']?.toString() ?? '';
          _emailController.text = responseData['email']?.toString() ?? '';
          _numberController.text = responseData['number']?.toString() ?? '';
          _panNumController.text = responseData['pan_num']?.toString() ?? '';
          _groupCodeController.text = responseData['Grop_code']?.toString() ?? '';
          _mId = responseData['M_ID']?.toString() ?? _mId; // Update M_ID if provided
        });

        await prefs.setString('name', _nameController.text);
        await prefs.setString('short_group_name', _shortGroupNameController.text);
        await prefs.setString('group_name', _groupNameController.text);
        await prefs.setString('email', _emailController.text);
        await prefs.setString('number', _numberController.text);
        await prefs.setString('pan_num', _panNumController.text);
        await prefs.setString('Grop_code', _groupCodeController.text);
        await prefs.setString('M_ID', _mId);

        debugPrint('ProfilePage: Loaded data from API and saved to SharedPreferences - '
            'Name: ${_nameController.text}, '
            'Short Group Name: ${_shortGroupNameController.text}, '
            'Group Name: ${_groupNameController.text}, '
            'Email: ${_emailController.text}, '
            'Number: ${_numberController.text}, '
            'PAN Number: ${_panNumController.text}, '
            'Group Code: ${_groupCodeController.text}, '
            'M_ID: $_mId');

        if (_nameController.text.isEmpty &&
            _shortGroupNameController.text.isEmpty &&
            _groupNameController.text.isEmpty &&
            _emailController.text.isEmpty &&
            _numberController.text.isEmpty &&
            _panNumController.text.isEmpty &&
            _groupCodeController.text.isEmpty &&
            _mId.isEmpty) {
          debugPrint('ProfilePage: Warning - All API fields are empty');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No profile data found. Please update your profile.')),
          );
        }
      } else {
        final errorJson = jsonDecode(response.body);
        final errorMessage = errorJson['message'] ?? 'Unknown error';
        debugPrint('ProfilePage: Failed to fetch profile with status ${response.statusCode}: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $errorMessage')),
        );
      }
    } catch (e) {
      debugPrint('ProfilePage: Error fetching profile data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('ProfilePage: Finished loading user data at ${DateTime.now().toIso8601String()}');
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.isEmpty ||
        _shortGroupNameController.text.isEmpty ||
        _groupNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _numberController.text.isEmpty ||
        _panNumController.text.isEmpty ||
        _groupCodeController.text.isEmpty ||
        _mId.isEmpty) {
      debugPrint('ProfilePage: Update failed - Empty fields: '
          'Name: ${_nameController.text}, '
          'Short Group Name: ${_shortGroupNameController.text}, '
          'Group Name: ${_groupNameController.text}, '
          'Email: ${_emailController.text}, '
          'Number: ${_numberController.text}, '
          'PAN Number: ${_panNumController.text}, '
          'Group Code: ${_groupCodeController.text}, '
          'M_ID: $_mId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    // Alternative: Skip M_ID validation if not required by API
    // if (_nameController.text.isEmpty ||
    //     _shortGroupNameController.text.isEmpty ||
    //     _groupNameController.text.isEmpty ||
    //     _emailController.text.isEmpty ||
    //     _numberController.text.isEmpty ||
    //     _panNumController.text.isEmpty ||
    //     _groupCodeController.text.isEmpty) {
    //   debugPrint('ProfilePage: Update failed - Empty fields: ...');
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Please fill all fields')),
    //   );
    //   return;
    // }

    debugPrint('ProfilePage: Attempting to update profile with data - '
        'Name: ${_nameController.text}, '
        'Short Group Name: ${_shortGroupNameController.text}, '
        'Group Name: ${_groupNameController.text}, '
        'Email: ${_emailController.text}, '
        'Number: ${_numberController.text}, '
        'PAN Number: ${_panNumController.text}, '
        'Group Code: ${_groupCodeController.text}, '
        'M_ID: $_mId');

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('G_ID') ?? '';
      debugPrint('ProfilePage: Retrieved user ID from SharedPreferences: "$userId"');

      if (userId.isEmpty) {
        debugPrint('ProfilePage: Error - user ID (G_ID) is empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User ID not found. Please log in first.')),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pop(context);
        });
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final requestBody = jsonEncode({
        'id': userId,
        'name': _nameController.text,
        'short_group_name': _shortGroupNameController.text,
        'group_name': _groupNameController.text,
        'email': _emailController.text,
        'number': _numberController.text,
        'pan_num': _panNumController.text,
        'Grop_code': _groupCodeController.text,
        'M_ID': _mId,
      });

      debugPrint('ProfilePage: Sending API request to update profile with body: $requestBody');
      final response = await http.put(
        Uri.parse('https://tagai.caxis.ca/public/api/group-master'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await prefs.setString('name', _nameController.text);
        await prefs.setString('short_group_name', _shortGroupNameController.text);
        await prefs.setString('group_name', _groupNameController.text);
        await prefs.setString('email', _emailController.text);
        await prefs.setString('number', _numberController.text);
        await prefs.setString('pan_num', _panNumController.text);
        await prefs.setString('Grop_code', _groupCodeController.text);
        await prefs.setString('M_ID', _mId);
        await prefs.setString('G_ID', userId);

        debugPrint('ProfilePage: Profile updated successfully and saved to SharedPreferences');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        setState(() {
          _isEditing = false; // Exit edit mode after successful update
        });
      } else {
        final errorJson = jsonDecode(response.body);
        final errorMessage = errorJson['message'] ?? 'Unknown error';
        debugPrint('ProfilePage: Profile update failed with status ${response.statusCode}: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $errorMessage')),
        );
      }
    } catch (e) {
      debugPrint('ProfilePage: Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('ProfilePage: Finished profile update attempt at ${DateTime.now().toIso8601String()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('ProfilePage: Building UI, isEditing: $_isEditing, isLoading: $_isLoading');
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                debugPrint('ProfilePage: Back button tapped');
                                Navigator.pop(context);
                              },
                              child: const Icon(
                                Icons.arrow_back_ios,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        Center(
                          child: Text(
                            'Edit Profile',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'Update your information',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.4,
                            ),
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
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            _buildInputField(
                              'Name',
                              'Enter your name',
                              _nameController,
                              Icons.person_outlined,
                              enabled: _isEditing,
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              'Short Group Name',
                              'Enter short name',
                              _shortGroupNameController,
                              Icons.short_text_outlined,
                              enabled: _isEditing,
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              'Group Name',
                              'Enter full group name',
                              _groupNameController,
                              Icons.corporate_fare_outlined,
                              enabled: _isEditing,
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              'Email Address',
                              'Enter email address',
                              _emailController,
                              Icons.email_outlined,
                              enabled: _isEditing,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              'Phone Number',
                              'Enter phone number',
                              _numberController,
                              Icons.phone_outlined,
                              enabled: _isEditing,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              'PAN Number',
                              'Enter PAN number',
                              _panNumController,
                              Icons.credit_card,
                              enabled: _isEditing,
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              'Group Code',
                              'Group code',
                              _groupCodeController,
                              Icons.code,
                              enabled: false, // Non-editable
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      debugPrint('ProfilePage: Cancel button tapped');
                                      setState(() {
                                        _isEditing = false;
                                      });
                                      _loadUserData();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      side: const BorderSide(color: Colors.black),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _updateProfile,
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
                                            'Update Profile',
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
    String label,
    String hint,
    TextEditingController controller,
    IconData icon, {
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
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
          enabled: enabled,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: enabled ? null : Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            filled: !enabled,
            fillColor: enabled ? null : Colors.grey[50],
          ),
          style: TextStyle(
            color: enabled ? Colors.black : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    debugPrint('ProfilePage: Disposing controllers at ${DateTime.now().toIso8601String()}');
    _nameController.dispose();
    _shortGroupNameController.dispose();
    _groupNameController.dispose();
    _emailController.dispose();
    _numberController.dispose();
    _panNumController.dispose();
    _groupCodeController.dispose();
    super.dispose();
  }
}