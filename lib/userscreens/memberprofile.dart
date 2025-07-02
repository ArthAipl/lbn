import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? name;
  String? email;
  String? number;
  String? userId;
  String? groupId;
  bool isLoading = true;
  String? errorMessage;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _numberController;

  Map<String, dynamic>? memberData;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _numberController = TextEditingController();
    fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString('user_id');
      print('Retrieved user_id from SharedPreferences: $storedUserId');

      if (storedUserId == null) {
        setState(() {
          errorMessage = 'User ID not found in SharedPreferences';
          isLoading = false;
        });
        print('Error: User ID not found in SharedPreferences');
        return;
      }

      print('Making API call to https://tagai.caxis.ca/public/api/member');
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/member'),
        headers: {'Content-Type': 'application/json'},
      );

      print('API response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        print('API response data: $responseData');

        final List<dynamic> members = responseData['members'] ?? [];
        final member = members.firstWhere(
          (m) => m['M_ID'].toString() == storedUserId,
          orElse: () => null,
        );

        if (member != null) {
          print('Found matching member: $member');
          setState(() {
            userId = storedUserId;
            name = member['Name'] ?? prefs.getString('user_name') ?? 'N/A';
            email = member['email'] ?? prefs.getString('user_email') ?? 'N/A';
            number = member['number'] ?? prefs.getString('user_phone') ?? 'N/A';
            groupId = member['G_ID']?.toString() ?? prefs.getString('group_id');
            _nameController.text = name!;
            _emailController.text = email!;
            _numberController.text = number!;
            memberData = member;
            isLoading = false;
          });

          if (groupId != null) {
            await prefs.setString('group_id', groupId!);
          }
        } else {
          print('No matching member found in API, using SharedPreferences data');
          setState(() {
            userId = storedUserId;
            name = prefs.getString('user_name') ?? 'N/A';
            email = prefs.getString('user_email') ?? 'N/A';
            number = prefs.getString('user_phone') ?? 'N/A';
            groupId = prefs.getString('group_id');
            _nameController.text = name!;
            _emailController.text = email!;
            _numberController.text = number!;
            errorMessage = 'User not found in API, showing stored data';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          userId = storedUserId;
          errorMessage = 'Failed to fetch data from API: ${response.statusCode}';
          name = prefs.getString('user_name') ?? 'N/A';
          email = prefs.getString('user_email') ?? 'N/A';
          number = prefs.getString('user_phone') ?? 'N/A';
          groupId = prefs.getString('group_id');
          _nameController.text = name!;
          _emailController.text = email!;
          _numberController.text = number!;
          isLoading = false;
        });
        print('Error: Failed to fetch data from API, status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
      print('Exception caught: $e');
    }
  }

  Future<void> saveUserData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final updatedData = {
        'M_ID': userId,
        'Name': _nameController.text,
        'email': _emailController.text,
        'number': _numberController.text,
      };

      print('Sending updated data to API: $updatedData');
      final response = await http.put(
        Uri.parse('https://tagai.caxis.ca/public/api/member/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updatedData),
      );

      print('Save API response status code: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        await prefs.setString('user_name', _nameController.text);
        await prefs.setString('user_email', _emailController.text);
        await prefs.setString('user_phone', _numberController.text);

        setState(() {
          name = _nameController.text;
          email = _emailController.text;
          number = _numberController.text;
          isLoading = false;
          errorMessage = 'Profile updated successfully';
        });
        print('Profile updated successfully');
      } else {
        setState(() {
          errorMessage = 'Failed to update profile: ${response.statusCode}';
          isLoading = false;
        });
        print('Error: Failed to update profile, status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error saving data: $e';
        isLoading = false;
      });
      print('Exception caught while saving: $e');
    }
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.black, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black54),
          prefixIcon: Icon(icon, color: Colors.black54),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSaveButton({required VoidCallback onPressed, required String text}) {
    return Container(
      width: double.infinity,
      height: 55,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (errorMessage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: errorMessage!.contains('successfully') 
            ? Colors.green[50] 
            : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: errorMessage!.contains('successfully') 
              ? Colors.green 
              : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            errorMessage!.contains('successfully') 
                ? Icons.check_circle 
                : Icons.error,
            color: errorMessage!.contains('successfully') 
                ? Colors.green 
                : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage!,
              style: TextStyle(
                color: errorMessage!.contains('successfully') 
                    ? Colors.green[800] 
                    : Colors.red[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
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
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildSectionHeader(
                        icon: Icons.person,
                        title: 'Personal Information',
                        subtitle: 'Manage your personal details',
                      ),
                      const SizedBox(height: 32),
                      _buildErrorMessage(),
                      _buildCustomTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                      ),
                      _buildCustomTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      _buildCustomTextField(
                        controller: _numberController,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a phone number';
                          }
                          return null;
                        },
                      ),
                      _buildSaveButton(
                        onPressed: saveUserData,
                        text: 'Save Profile',
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}