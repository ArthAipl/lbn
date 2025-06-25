import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Enhanced AppBar widget with gradient
PreferredSizeWidget buildAppBar(String title, BuildContext context) {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.black, Color(0xFF2C2C2C)],
        ),
      ),
    ),
    leading: IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
      ),
      onPressed: () => Navigator.pop(context),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
    centerTitle: true,
  );
}

// Editable Info Card widget
Widget buildEditableInfoCard({
  required String title,
  required TextEditingController controller,
  required IconData icon,
  required String? Function(String?) validator,
  bool readOnly = false,
  bool enabled = true,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.grey.shade50],
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? [Colors.black, const Color(0xFF2C2C2C)]
                  : [Colors.grey.shade400, Colors.grey.shade500],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: controller,
                readOnly: readOnly,
                enabled: enabled,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.black87 : Colors.grey.shade500,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 15,
                  ),
                  hintText: 'Enter $title',
                ),
                validator: validator,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// User Profile Screen with Inline Editing
class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  _UserProfileState createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _userId = '';
  String _authToken = '';
  String _roleId = '';
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _groupCodeController;
  String? _errorMessage;
  bool _isLoading = false;
  bool _hasChanges = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _groupCodeController = TextEditingController();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadUserData();
    _animationController.forward();

    // Listen for changes
    _nameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _groupCodeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      print('SharedPreferences keys: $keys');
      print(
          'SharedPreferences values: ${keys.map((key) => '$key: ${prefs.get(key)}').join(', ')}');

      // Handle user_id which might be stored as int or string
      var userIdRaw = prefs.get('user_id');
      if (userIdRaw != null) {
        _userId = userIdRaw.toString();
      }

      // Handle role_id which might be stored as int or string
      var roleIdRaw = prefs.get('user_role') ?? prefs.get('role_id');
      if (roleIdRaw != null) {
        _roleId = roleIdRaw.toString();
      } else {
        _roleId = '3'; // Default to role 3 if not found
      }

      // Load user_name, default to empty string if null
      String name = prefs.getString('user_name') ?? '';
      print('Loaded user_name from SharedPreferences: "$name"');

      setState(() {
        _authToken = prefs.getString('auth_token') ?? prefs.getString('token') ?? '';
        _nameController.text = name;
        _emailController.text = prefs.getString('user_email') ?? '';
        _phoneController.text = prefs.getString('user_phone') ?? '';
        _groupCodeController.text = prefs.getString('group_code') ?? '';
        _errorMessage = _userId.isEmpty
            ? 'No profile data found. Please log in.'
            : name.isEmpty
                ? 'Please enter your name below and save.'
                : null;
        _hasChanges = false;
      });

      if (_userId.isEmpty) {
        print('Error: user_id is missing in SharedPreferences');
      } else {
        print('user_id loaded: $_userId');
        print('role_id loaded: $_roleId');
        print('auth_token loaded: ${_authToken.isNotEmpty ? "Yes" : "No"}');
        print('name loaded: $name');
        print('Profile data loaded successfully');
      }
    } catch (e) {
      print('Error loading SharedPreferences: $e');
      setState(() {
        _errorMessage = 'Failed to load profile: $e';
      });
    }
  }

  void _redirectToLogin() {
    print('Redirecting to login screen');
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Save to SharedPreferences first
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _userId);
      String name = _nameController.text.trim();
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', _emailController.text.trim());
      await prefs.setString('user_phone', _phoneController.text.trim());
      await prefs.setString('group_code', _groupCodeController.text.trim());
      print('Saved user_name to SharedPreferences: "$name"');

      // Prepare headers with authentication if available
      Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      };

      if (_authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_authToken';
      }

      print('Request headers: $headers');
      print('User ID: $_userId, Role ID: $_roleId');

      // Try different API approaches - focusing on UPDATE operations
      List<Map<String, dynamic>> apiAttempts = [
        {
          'method': 'PUT',
          'url': 'https://tagai.caxis.ca/public/api/users/$_userId',
          'body': {
            'name': name,
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'group_code': _groupCodeController.text.trim(),
          },
        },
        {
          'method': 'PATCH',
          'url': 'https://tagai.caxis.ca/public/api/users/$_userId',
          'body': {
            'name': name,
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'group_code': _groupCodeController.text.trim(),
          },
        },
        {
          'method': 'POST',
          'url': 'https://tagai.caxis.ca/public/api/users/update',
          'body': {
            'user_id': _userId,
            'name': name,
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'group_code': _groupCodeController.text.trim(),
          },
        },
        {
          'method': 'PUT',
          'url': 'https://tagai.caxis.ca/public/api/profile',
          'body': {
            'user_id': _userId,
            'name': name,
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'group_code': _groupCodeController.text.trim(),
          },
        },
        {
          'method': 'POST',
          'url': 'https://tagai.caxis.ca/public/api/profile/update',
          'body': {
            'user_id': _userId,
            'name': name,
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'group_code': _groupCodeController.text.trim(),
          },
        },
        {
          'method': 'PUT',
          'url': 'https://tagai.caxis.ca/public/api/member/$_userId',
          'body': {
            'user_id': _userId,
            'role_id': 3,
            'name': name,
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'group_code': _groupCodeController.text.trim(),
            'action': 'update',
          },
        },
        {
          'method': 'POST',
          'url': 'https://tagai.caxis.ca/public/api/member/update',
          'body': {
            'user_id': _userId,
            'role_id': 3,
            'name': name,
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'group_code': _groupCodeController.text.trim(),
            'is_update': true,
          },
        },
        {
          'method': 'POST',
          'url': 'https://tagai.caxis.ca/public/api/update-member',
          'body': {
            'id': _userId,
            'user_id': _userId,
            'role_id': 3,
            'name': name,
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'group_code': _groupCodeController.text.trim(),
          },
        },
        {
          'method': 'POST',
          'url': 'https://tagai.caxis.ca/public/api/member',
          'body': {
            'user_id': _userId,
            'role_id': 3,
            'name': name,
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'group_code': _groupCodeController.text.trim(),
            'method': 'PUT',
            '_method': 'PUT',
            'update': 1,
          },
        },
      ];

      http.Response? successResponse;
      String successEndpoint = '';
      String successMethod = '';

      for (var attempt in apiAttempts) {
        try {
          print('\n=== Trying ${attempt['method']} ${attempt['url']} ===');
          print('Body: ${jsonEncode(attempt['body'])}');

          http.Response response;

          switch (attempt['method']) {
            case 'PUT':
              response = await http.put(
                Uri.parse(attempt['url']),
                headers: headers,
                body: jsonEncode(attempt['body']),
              );
              break;
            case 'PATCH':
              response = await http.patch(
                Uri.parse(attempt['url']),
                headers: headers,
                body: jsonEncode(attempt['body']),
              );
              break;
            default:
              response = await http.post(
                Uri.parse(attempt['url']),
                headers: headers,
                body: jsonEncode(attempt['body']),
              );
          }

          print('Response Status: ${response.statusCode}');
          print('Response Body: ${response.body}');

          if (response.statusCode == 200 || response.statusCode == 201) {
            try {
              final responseData = jsonDecode(response.body);
              if (responseData is Map) {
                bool isSuccess = responseData['success'] == true ||
                    responseData['status'] == true ||
                    responseData['status'] == 'success' ||
                    responseData.containsKey('data') ||
                    responseData.containsKey('user') ||
                    responseData.containsKey('member');

                if (isSuccess || responseData['status'] != false) {
                  successResponse = response;
                  successEndpoint = attempt['url'];
                  successMethod = attempt['method'];
                  print('✅ SUCCESS with ${attempt['method']} ${attempt['url']}');
                  break;
                }
              }
            } catch (e) {
              successResponse = response;
              successEndpoint = attempt['url'];
              successMethod = attempt['method'];
              print('✅ SUCCESS (non-JSON response) with ${attempt['method']} ${attempt['url']}');
              break;
            }
          } else if (response.statusCode == 404) {
            print('❌ Endpoint not found: ${attempt['url']}');
          } else if (response.statusCode == 403) {
            print('❌ Access forbidden (403): ${response.body}');
          } else if (response.statusCode == 422) {
            try {
              final errorData = jsonDecode(response.body);
              print('❌ Validation Error: ${errorData}');
            } catch (e) {
              print('❌ Validation Error (unparseable): ${response.body}');
            }
          } else {
            print('❌ Failed with status ${response.statusCode}: ${response.body}');
          }
        } catch (e) {
          print('❌ Network error for ${attempt['method']} ${attempt['url']}: $e');
          continue;
        }
      }

      if (successResponse != null) {
        setState(() {
          _hasChanges = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Profile updated successfully!\nUsed: $successMethod $successEndpoint'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );

        print('🎉 Profile updated successfully using: $successMethod $successEndpoint');
      } else {
        setState(() {
          _errorMessage =
              'Unable to update profile on server.\n\nThis might be because:\n• The API requires special permissions\n• Your account role doesn\'t allow updates\n• The server endpoints have changed\n\nYour changes are saved locally.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Saved locally - Server update failed'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );

        print('❌ All API attempts failed. The server requires specific permissions or endpoints have changed.');
      }
    } catch (e) {
      print('💥 Critical error in _saveUserData: $e');
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: buildAppBar('Profile', context),
      body: _errorMessage != null && _userId.isEmpty
          ? Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.red.shade400,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Profile Not Found',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.black, Color(0xFF2C2C2C)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: _redirectToLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Go to Login',
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
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black, Color(0xFF2C2C2C)],
                          ),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0.1)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(47),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _nameController.text.isEmpty ? 'No Name' : _nameController.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _emailController.text.isEmpty ? 'No Email' : _emailController.text,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage != null && _userId.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.orange.shade600, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const Text(
                              'Edit Your Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 20),
                            buildEditableInfoCard(
                              title: 'Full Name',
                              controller: _nameController,
                              icon: Icons.person_outline,
                              validator: (value) =>
                                  value!.trim().isEmpty ? 'Please enter your name' : null,
                            ),
                            buildEditableInfoCard(
                              title: 'Email Address',
                              controller: _emailController,
                              icon: Icons.email_outlined,
                              validator: (value) {
                                if (value!.trim().isEmpty) return 'Please enter your email';
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(value.trim())) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            buildEditableInfoCard(
                              title: 'Phone Number',
                              controller: _phoneController,
                              icon: Icons.phone_outlined,
                              validator: (value) =>
                                  value!.trim().isEmpty ? 'Please enter your phone number' : null,
                            ),
                            const SizedBox(height: 24),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: _hasChanges ? 50 : 0,
                              child: _hasChanges
                                  ? Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Colors.black, Color(0xFF2C2C2C)],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black87,
                                            blurRadius: 15,
                                            offset: Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: _isLoading ? null : _saveUserData,
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: const [
                                                  Icon(
                                                    Icons.save_outlined,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Save Changes',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}