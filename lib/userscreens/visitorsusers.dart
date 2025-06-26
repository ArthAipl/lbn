import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

class VisitorManagementScreen extends StatefulWidget {
  const VisitorManagementScreen({Key? key}) : super(key: key);

  @override
  State<VisitorManagementScreen> createState() => _VisitorManagementScreenState();
}

class _VisitorManagementScreenState extends State<VisitorManagementScreen> {
  List<Map<String, dynamic>> visitors = [];
  List<Map<String, dynamic>> meetings = [];
  bool isLoading = true;
  String? userId;
  String? groupId;
  String? userName;
  String? userEmail;
  String? userPhone;
  int? userRole;
  String? groupCode;
  Set<String> validGroupIds = {}; // Store valid G_IDs from existing visitors

  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController aboutController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String? selectedMeetingId;

  @override
  void initState() {
    super.initState();
    debugPrint('=== VisitorManagementScreen: initState called ===');
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      debugPrint('=== Loading user data from SharedPreferences ===');
      final prefs = await SharedPreferences.getInstance();
      
      // Get all user data from SharedPreferences
      final loadedUserId = prefs.getString('user_id');
      final loadedGroupCode = prefs.getString('group_code');
      final loadedUserName = prefs.getString('user_name');
      final loadedUserEmail = prefs.getString('user_email');
      final loadedUserPhone = prefs.getString('user_phone');
      final loadedUserRole = prefs.getInt('user_role');
      
      // Try to get G_ID from various possible keys
      String? loadedGroupId;
      loadedGroupId = prefs.getString('G_ID') ?? 
                     prefs.getString('g_id') ?? 
                     prefs.getString('group_id');
      
      debugPrint('=== SharedPreferences Data Retrieved ===');
      debugPrint('  - user_id: "$loadedUserId" (Type: ${loadedUserId.runtimeType})');
      debugPrint('  - group_code: "$loadedGroupCode" (Type: ${loadedGroupCode.runtimeType})');
      debugPrint('  - G_ID: "$loadedGroupId" (Type: ${loadedGroupId.runtimeType})');
      debugPrint('  - user_name: "$loadedUserName" (Type: ${loadedUserName.runtimeType})');
      debugPrint('  - user_email: "$loadedUserEmail" (Type: ${loadedUserEmail.runtimeType})');
      debugPrint('  - user_phone: "$loadedUserPhone" (Type: ${loadedUserPhone.runtimeType})');
      debugPrint('  - user_role: $loadedUserRole (Type: ${loadedUserRole.runtimeType})');
      
      // Check all available keys in SharedPreferences for debugging
      debugPrint('=== All SharedPreferences Keys ===');
      final allKeys = prefs.getKeys();
      for (String key in allKeys) {
        final value = prefs.get(key);
        debugPrint('  - $key: "$value" (Type: ${value.runtimeType})');
      }
      
      setState(() {
        userId = loadedUserId;
        groupId = loadedGroupId;
        groupCode = loadedGroupCode;
        userName = loadedUserName;
        userEmail = loadedUserEmail;
        userPhone = loadedUserPhone;
        userRole = loadedUserRole;
      });
      
      debugPrint('=== User Data Set in State ===');
      debugPrint('  - userId: "$userId"');
      debugPrint('  - groupId: "$groupId"');
      debugPrint('  - groupCode: "$groupCode"');
      debugPrint('  - userName: "$userName"');
      debugPrint('  - userEmail: "$userEmail"');
      debugPrint('  - userPhone: "$userPhone"');
      debugPrint('  - userRole: $userRole');
      
      if (userId != null && userId!.isNotEmpty) {
        debugPrint('SUCCESS: User ID found, proceeding to fetch data...');
        await _fetchData();
      } else {
        debugPrint('ERROR: Missing critical user data!');
        _showErrorSnackBar('User authentication failed. Please login again.');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('=== ERROR in _loadUserData ===');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      _showErrorSnackBar('Failed to load user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchData() async {
    try {
      debugPrint('=== Starting to fetch data ===');
      debugPrint('Using User ID: "$userId" and Group ID: "$groupId"');
      
      await Future.wait([
        _fetchVisitors(),
        _fetchMeetings(),
      ]);
      
      setState(() {
        isLoading = false;
      });
      
      debugPrint('=== Data fetching completed ===');
      debugPrint('Total visitors loaded: ${visitors.length}');
      debugPrint('Total meetings loaded: ${meetings.length}');
      debugPrint('Valid Group IDs found: $validGroupIds');
      
    } catch (e, stackTrace) {
      debugPrint('=== ERROR in _fetchData ===');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      
      setState(() {
        isLoading = false;
      });
      
      _showErrorSnackBar('Failed to load data: $e');
    }
  }

  Future<void> _fetchVisitors() async {
    try {
      debugPrint('=== Fetching Visitors ===');
      debugPrint('API URL: https://tagai.caxis.ca/public/api/visitor-invites');
      debugPrint('Filtering by User ID: "$userId" and Group ID: "$groupId"');
      
      final client = http.Client();
      
      final response = await client.get(
        Uri.parse('https://tagai.caxis.ca/public/api/visitor-invites'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Flutter App',
        },
      );

      debugPrint('Visitors API Response:');
      debugPrint('  - Status Code: ${response.statusCode}');
      debugPrint('  - Headers: ${response.headers}');
      debugPrint('  - Body Length: ${response.body.length}');
      
      if (response.statusCode == 200) {
        try {
          final List<dynamic> data = json.decode(response.body);
          debugPrint('  - Total visitors in API: ${data.length}');
          
          // Collect all unique G_IDs from the API response
          Set<String> allGroupIds = {};
          Set<String> allUserIds = {};
          
          for (var visitor in data) {
            if (visitor['G_ID'] != null) {
              allGroupIds.add(visitor['G_ID'].toString());
            }
            if (visitor['M_ID'] != null) {
              allUserIds.add(visitor['M_ID'].toString());
            }
          }
          
          debugPrint('=== ALL G_IDs IN DATABASE ===');
          debugPrint('Unique G_IDs found: $allGroupIds');
          debugPrint('Unique M_IDs found: $allUserIds');
          debugPrint('Your G_ID "$groupId" exists in database: ${allGroupIds.contains(groupId)}');
          debugPrint('Your M_ID "$userId" exists in database: ${allUserIds.contains(userId)}');
          
          // Store valid group IDs for later use
          validGroupIds = allGroupIds;
          
          // Print first few visitors for debugging
          if (data.isNotEmpty) {
            debugPrint('Sample visitor data:');
            for (int i = 0; i < (data.length > 5 ? 5 : data.length); i++) {
              debugPrint('  Visitor ${i + 1}: ${data[i]}');
            }
          }
          
          // Filter visitors by current user ID
          final filteredVisitors = data
              .where((visitor) {
                final visitorMId = visitor['M_ID']?.toString();
                final visitorGId = visitor['G_ID']?.toString();
                
                debugPrint('Comparing visitor - M_ID: "$visitorMId", G_ID: "$visitorGId"');
                debugPrint('  with user - ID: "$userId", Group: "$groupId"');
                
                // Primary filter: Check if visitor belongs to current user (by M_ID)
                final matchesUserId = visitorMId == userId;
                
                // Secondary filter: Check if visitor belongs to same group (by G_ID)
                final matchesGroupId = groupId != null && visitorGId == groupId;
                
                debugPrint('  - Matches User ID: $matchesUserId');
                debugPrint('  - Matches Group ID: $matchesGroupId');
                
                return matchesUserId || matchesGroupId;
              })
              .cast<Map<String, dynamic>>()
              .toList();
              
          debugPrint('  - Filtered visitors for user: ${filteredVisitors.length}');
          
          // Show all visitors that match the criteria
          if (filteredVisitors.isNotEmpty) {
            debugPrint('=== VISITORS ADDED BY CURRENT USER/GROUP ===');
            for (int i = 0; i < filteredVisitors.length; i++) {
              final visitor = filteredVisitors[i];
              debugPrint('Visitor ${i + 1}:');
              debugPrint('  - ID: ${visitor['vis_inv_id']}');
              debugPrint('  - Name: ${visitor['Visitor_Name']}');
              debugPrint('  - Email: ${visitor['Visitor_Email']}');
              debugPrint('  - Phone: ${visitor['Visitor_Phone']}');
              debugPrint('  - About: ${visitor['About_Visitor']}');
              debugPrint('  - M_ID: ${visitor['M_ID']}');
              debugPrint('  - G_ID: ${visitor['G_ID']}');
              debugPrint('  - M_C_Id: ${visitor['M_C_Id']}');
              debugPrint('  - Created: ${visitor['created_at']}');
              debugPrint('  - Updated: ${visitor['updated_at']}');
              debugPrint('  ---');
            }
          }
          
          setState(() {
            visitors = filteredVisitors;
          });
          
          if (filteredVisitors.isEmpty) {
            debugPrint('WARNING: No visitors found for user ID: "$userId" or Group ID: "$groupId"');
          }
          
        } catch (parseError) {
          debugPrint('ERROR: Failed to parse JSON response');
          debugPrint('Parse Error: $parseError');
          debugPrint('Response body: ${response.body}');
          throw Exception('Failed to parse visitors data');
        }
        
      } else if (response.statusCode == 302) {
        debugPrint('ERROR: Received redirect (302)');
        debugPrint('Redirect location: ${response.headers['location']}');
        throw Exception('API requires authentication or URL is incorrect');
      } else {
        debugPrint('ERROR: Failed to fetch visitors');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
        throw Exception('Failed to load visitors: ${response.statusCode}');
      }
      
      client.close();
      
    } catch (e, stackTrace) {
      debugPrint('=== ERROR in _fetchVisitors ===');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error Message: $e');
      debugPrint('StackTrace: $stackTrace');
      _showErrorSnackBar('Failed to load visitors: $e');
    }
  }

  Future<void> _fetchMeetings() async {
    try {
      debugPrint('=== Fetching Meetings ===');
      debugPrint('API URL: https://tagai.caxis.ca/public/api/meeting-cals');
      
      final client = http.Client();
      
      final response = await client.get(
        Uri.parse('https://tagai.caxis.ca/public/api/meeting-cals'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Flutter App',
        },
      );

      debugPrint('Meetings API Response:');
      debugPrint('  - Status Code: ${response.statusCode}');
      debugPrint('  - Headers: ${response.headers}');
      debugPrint('  - Body Length: ${response.body.length}');

      if (response.statusCode == 200) {
        try {
          final List<dynamic> data = json.decode(response.body);
          debugPrint('  - Total meetings in API: ${data.length}');
          
          final today = DateTime.now();
          debugPrint('  - Today\'s date for filtering: ${today.toIso8601String()}');
          
          // Print first few meetings for debugging
          if (data.isNotEmpty) {
            debugPrint('Sample meeting data:');
            for (int i = 0; i < (data.length > 3 ? 3 : data.length); i++) {
              debugPrint('  Meeting ${i + 1}: ${data[i]}');
            }
          }
          
          final filteredMeetings = data
              .where((meeting) {
                final meetingDateStr = meeting['Meeting_Date']?.toString();
                debugPrint('Processing meeting date: $meetingDateStr');
                
                if (meetingDateStr == null || meetingDateStr.isEmpty) {
                  debugPrint('  - Skipping meeting with null/empty date');
                  return false;
                }
                
                final meetingDate = DateTime.tryParse(meetingDateStr);
                if (meetingDate == null) {
                  debugPrint('  - Failed to parse date: $meetingDateStr');
                  return false;
                }
                
                final isUpcoming = meetingDate.isAfter(today.subtract(const Duration(days: 1)));
                debugPrint('  - Meeting date: ${meetingDate.toIso8601String()}, Is upcoming: $isUpcoming');
                
                return isUpcoming;
              })
              .cast<Map<String, dynamic>>()
              .toList();
              
          debugPrint('  - Filtered upcoming meetings: ${filteredMeetings.length}');
          
          setState(() {
            meetings = filteredMeetings;
          });
          
        } catch (parseError) {
          debugPrint('ERROR: Failed to parse meetings JSON');
          debugPrint('Parse Error: $parseError');
          throw Exception('Failed to parse meetings data');
        }
        
      } else if (response.statusCode == 302) {
        debugPrint('ERROR: Meetings API received redirect (302)');
        debugPrint('Redirect location: ${response.headers['location']}');
        throw Exception('Meetings API requires authentication');
      } else {
        debugPrint('ERROR: Failed to fetch meetings');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
        throw Exception('Failed to load meetings: ${response.statusCode}');
      }
      
      client.close();
      
    } catch (e, stackTrace) {
      debugPrint('=== ERROR in _fetchMeetings ===');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error Message: $e');
      debugPrint('StackTrace: $stackTrace');
      _showErrorSnackBar('Failed to load meetings: $e');
    }
  }

  Future<void> _addVisitor() async {
    try {
      debugPrint('=== Adding New Visitor ===');
      
      if (!_validateForm()) {
        debugPrint('Form validation failed');
        return;
      }
      
      // Ensure we have valid user data
      if (userId == null || userId!.isEmpty) {
        debugPrint('ERROR: User ID is null or empty');
        _showErrorSnackBar('User ID not found. Please login again.');
        return;
      }
      
      // Determine which G_ID to use
      String? gIdToSend;
      
      debugPrint('=== DETERMINING G_ID TO USE ===');
      debugPrint('Available options:');
      debugPrint('  - groupId from SharedPreferences: "$groupId"');
      debugPrint('  - userId as fallback: "$userId"');
      debugPrint('  - Valid G_IDs from database: $validGroupIds');
      
      // Strategy 1: Try the groupId from SharedPreferences if it exists in valid G_IDs
      if (groupId != null && groupId!.isNotEmpty && validGroupIds.contains(groupId)) {
        gIdToSend = groupId;
        debugPrint('Using groupId from SharedPreferences: "$gIdToSend"');
      }
      // Strategy 2: Try userId if it exists in valid G_IDs
      else if (userId != null && validGroupIds.contains(userId)) {
        gIdToSend = userId;
        debugPrint('Using userId as G_ID: "$gIdToSend"');
      }
      // Strategy 3: Try the first valid G_ID that might be related to this user
      else if (validGroupIds.isNotEmpty) {
        // Look for any G_ID that might be related to the user
        for (String validGId in validGroupIds) {
          // You might want to add logic here to determine which G_ID belongs to the user
          // For now, let's try the first one as a test
          gIdToSend = validGId;
          debugPrint('Using first available valid G_ID as test: "$gIdToSend"');
          break;
        }
      }
      // Strategy 4: Use userId as last resort
      else {
        gIdToSend = userId;
        debugPrint('Using userId as last resort G_ID: "$gIdToSend"');
      }
      
      if (gIdToSend == null || gIdToSend.isEmpty) {
        debugPrint('ERROR: Could not determine valid G_ID');
        _showErrorSnackBar('Cannot determine valid Group ID. Please contact support.');
        return;
      }
      
      // Prepare request data
      final requestData = {
        'Visitor_Name': nameController.text.trim(),
        'About_Visitor': aboutController.text.trim(),
        'Visitor_Email': emailController.text.trim(),
        'Visitor_Phone': phoneController.text.trim(),
        'M_C_Id': selectedMeetingId,
        'G_ID': gIdToSend,
        'M_ID': userId,
      };
      
      debugPrint('=== Request Data for Adding Visitor ===');
      debugPrint('  - Visitor_Name: "${requestData['Visitor_Name']}"');
      debugPrint('  - About_Visitor: "${requestData['About_Visitor']}"');
      debugPrint('  - Visitor_Email: "${requestData['Visitor_Email']}"');
      debugPrint('  - Visitor_Phone: "${requestData['Visitor_Phone']}"');
      debugPrint('  - M_C_Id: "${requestData['M_C_Id']}"');
      debugPrint('  - G_ID: "${requestData['G_ID']}" (Strategy used: ${gIdToSend == groupId ? 'SharedPreferences groupId' : gIdToSend == userId ? 'userId as G_ID' : 'valid G_ID from database'})');
      debugPrint('  - M_ID: "${requestData['M_ID']}"');
      
      final client = http.Client();
      
      debugPrint('=== Sending POST request to add visitor ===');
      debugPrint('URL: https://tagai.caxis.ca/public/api/visitor-invites');
      debugPrint('Request Body: ${json.encode(requestData)}');
      
      final response = await client.post(
        Uri.parse('https://tagai.caxis.ca/public/api/visitor-invites'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Flutter App',
        },
        body: json.encode(requestData),
      );

      debugPrint('=== Add Visitor API Response ===');
      debugPrint('  - Status Code: ${response.statusCode}');
      debugPrint('  - Headers: ${response.headers}');
      debugPrint('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('SUCCESS: Visitor added successfully');
        
        _clearForm();
        Navigator.of(context).pop();
        
        debugPrint('Refreshing visitors list...');
        await _fetchVisitors();
        
        _showSuccessSnackBar('Visitor added successfully');
        
      } else if (response.statusCode == 302) {
        debugPrint('ERROR: Add visitor API received redirect (302)');
        debugPrint('This indicates authentication is required');
        debugPrint('Redirect location: ${response.headers['location']}');
        _showErrorSnackBar('Authentication required. Please login again.');
        
      } else if (response.statusCode == 422) {
        debugPrint('ERROR: Validation error (422)');
        debugPrint('This means the server rejected the data');
        
        try {
          final errorData = json.decode(response.body);
          debugPrint('Parsed Error Data: $errorData');
          
          String errorMessage = 'Validation failed: ';
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
          
          // Check for specific field errors
          if (errorData['errors'] != null) {
            final errors = errorData['errors'] as Map<String, dynamic>;
            debugPrint('Field-specific errors:');
            errors.forEach((field, messages) {
              debugPrint('  - $field: $messages');
            });
            
            // Show specific G_ID error if present
            if (errors['G_ID'] != null) {
              debugPrint('=== G_ID VALIDATION ERROR DETAILS ===');
              debugPrint('  - Sent G_ID: "${requestData['G_ID']}"');
              debugPrint('  - G_ID Type: ${requestData['G_ID'].runtimeType}');
              debugPrint('  - G_ID Length: ${requestData['G_ID'].toString().length}');
              debugPrint('  - G_ID Value (raw): ${requestData['G_ID']}');
              debugPrint('  - Error Messages: ${errors['G_ID']}');
              debugPrint('  - Available user data:');
              debugPrint('    * userId: "$userId"');
              debugPrint('    * groupId: "$groupId"');
              debugPrint('    * groupCode: "$groupCode"');
              debugPrint('  - Valid G_IDs from database: $validGroupIds');
              debugPrint('  - G_ID exists in valid list: ${validGroupIds.contains(requestData['G_ID'])}');
              debugPrint('=== END G_ID ERROR DETAILS ===');
              
              // Suggest trying a different G_ID
              if (validGroupIds.isNotEmpty) {
                debugPrint('SUGGESTION: Try using one of these valid G_IDs: $validGroupIds');
                errorMessage = 'Invalid Group ID. Valid options: ${validGroupIds.join(', ')}';
              } else {
                errorMessage = 'Invalid Group ID. No valid Group IDs found in database.';
              }
            }
          }
          
          _showErrorSnackBar(errorMessage);
        } catch (parseError) {
          debugPrint('Failed to parse error response: $parseError');
          _showErrorSnackBar('Validation failed. Please check your input.');
        }
        
      } else {
        debugPrint('ERROR: Failed to add visitor');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Error Response: ${response.body}');
        
        try {
          final errorData = json.decode(response.body);
          debugPrint('Parsed Error Data: $errorData');
          _showErrorSnackBar('Failed to add visitor: ${errorData['message'] ?? 'Unknown error'}');
        } catch (parseError) {
          debugPrint('Failed to parse error response: $parseError');
          if (response.body.contains('html')) {
            _showErrorSnackBar('Server returned HTML instead of JSON. Check API endpoint.');
          } else {
            _showErrorSnackBar('Failed to add visitor (Status: ${response.statusCode})');
          }
        }
      }
      
      client.close();
      
    } catch (e, stackTrace) {
      debugPrint('=== ERROR in _addVisitor ===');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error Message: $e');
      debugPrint('StackTrace: $stackTrace');
      _showErrorSnackBar('Failed to add visitor: $e');
    }
  }

  bool _validateForm() {
    debugPrint('=== Validating Form ===');
    debugPrint('Name: "${nameController.text}" (Empty: ${nameController.text.trim().isEmpty})');
    debugPrint('About: "${aboutController.text}" (Empty: ${aboutController.text.trim().isEmpty})');
    debugPrint('Email: "${emailController.text}" (Empty: ${emailController.text.trim().isEmpty})');
    debugPrint('Phone: "${phoneController.text}" (Empty: ${phoneController.text.trim().isEmpty})');
    debugPrint('Selected Meeting ID: $selectedMeetingId (Null: ${selectedMeetingId == null})');
    debugPrint('User ID: "$userId" (Valid: ${userId != null && userId!.isNotEmpty})');
    debugPrint('Group ID: "$groupId" (Valid: ${groupId != null && groupId!.isNotEmpty})');
    
    if (nameController.text.trim().isEmpty ||
        aboutController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        selectedMeetingId == null) {
      debugPrint('VALIDATION FAILED: One or more fields are empty');
      _showErrorSnackBar('Please fill all fields');
      return false;
    }
    
    // Basic email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(emailController.text.trim())) {
      debugPrint('VALIDATION FAILED: Invalid email format');
      _showErrorSnackBar('Please enter a valid email address');
      return false;
    }
    
    // Validate user authentication data
    if (userId == null || userId!.isEmpty) {
      debugPrint('VALIDATION FAILED: User ID is missing');
      _showErrorSnackBar('User authentication failed. Please login again.');
      return false;
    }
    
    debugPrint('VALIDATION PASSED: All required fields are filled and valid');
    return true;
  }

  void _clearForm() {
    debugPrint('=== Clearing Form ===');
    nameController.clear();
    aboutController.clear();
    emailController.clear();
    phoneController.clear();
    selectedMeetingId = null;
    debugPrint('Form cleared successfully');
  }

  void _showErrorSnackBar(String message) {
    debugPrint('=== SHOWING ERROR SNACKBAR ===');
    debugPrint('Error Message: $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            debugPrint('Retry button pressed from error snackbar');
            _fetchData();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    debugPrint('=== SHOWING SUCCESS SNACKBAR ===');
    debugPrint('Success Message: $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAddVisitorBottomSheet() {
    debugPrint('=== Opening Add Visitor Bottom Sheet ===');
    debugPrint('Available meetings: ${meetings.length}');
    debugPrint('Current user data - ID: "$userId", Group: "$groupId"');
    debugPrint('Valid G_IDs available: $validGroupIds');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Visitor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ), 
                  if (validGroupIds.isNotEmpty) ...[
                    const SizedBox(height: 4),  
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTextField('Name', nameController),
                            const SizedBox(height: 16),
                            _buildTextField('About', aboutController),
                            const SizedBox(height: 16),
                            _buildTextField('Email', emailController, 
                                keyboardType: TextInputType.emailAddress),
                            const SizedBox(height: 16),
                            _buildTextField('Phone', phoneController, 
                                keyboardType: TextInputType.phone),
                            const SizedBox(height: 16),
                            _buildMeetingDropdown(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              debugPrint('Cancel button pressed - closing bottom sheet');
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Colors.grey),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              debugPrint('Add Visitor button pressed');
                              _addVisitor();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Add Visitor',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, 
      {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: (value) {
            debugPrint('$label field changed: "$value"');
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeetingDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Meeting',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedMeetingId,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          hint: const Text('Select a meeting'),
          items: meetings.map((meeting) {
            return DropdownMenuItem<String>(
              value: meeting['M_C_Id'].toString(),
              child: Text(
                '${meeting['Meeting_Date']} - ${meeting['Place']}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            debugPrint('Meeting dropdown changed: $value');
            setState(() {
              selectedMeetingId = value;
            });
          },
        ),
      ],
    );
  }

  void _showVisitorDetails(Map<String, dynamic> visitor) {
    debugPrint('=== Showing Visitor Details ===');
    debugPrint('Visitor Data: $visitor');
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Text(
                'Visitor Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Name', visitor['Visitor_Name'] ?? ''),
                  _buildDetailRow('About', visitor['About_Visitor'] ?? ''),
                  _buildDetailRow('Email', visitor['Visitor_Email'] ?? ''),
                  _buildDetailRow('Phone', visitor['Visitor_Phone'] ?? ''),
                  _buildDetailRow('Visitor ID', visitor['vis_inv_id']?.toString() ?? ''),
                  _buildDetailRow('Meeting ID', visitor['M_C_Id']?.toString() ?? ''),
                  _buildDetailRow('User ID', visitor['M_ID']?.toString() ?? ''),
                  _buildDetailRow('Group ID', visitor['G_ID']?.toString() ?? ''),
                  _buildDetailRow('Added Date', visitor['created_at'] ?? ''),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        debugPrint('Visitor details dialog closed');
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('=== Building VisitorManagementScreen ===');
    debugPrint('Current state - isLoading: $isLoading, visitors count: ${visitors.length}');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Visitor Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: Platform.isIOS 
          ? IconButton(
              icon: const Icon(CupertinoIcons.back, color: Colors.white),
              onPressed: () {
                debugPrint('iOS back button pressed');
                Navigator.of(context).pop();
              },
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                debugPrint('Android back button pressed');
                Navigator.of(context).pop();
              },
            ),
      ),
      body: Column(
        children: [
          // Add Visitor Button Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: ElevatedButton.icon(
              onPressed: () {
                debugPrint('Add Visitor button pressed from main screen');
                _showAddVisitorBottomSheet();
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Visitor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
          // Main Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : visitors.isEmpty
                    ? _buildEmptyState()
                    : _buildVisitorList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    debugPrint('Building empty state widget');
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No visitors yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Click the "Add Visitor" button to invite someone',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                debugPrint('Retry button pressed from empty state');
                setState(() {
                  isLoading = true;
                });
                _fetchData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Retry Loading',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitorList() {
    debugPrint('Building visitor list with ${visitors.length} visitors');
    
    return RefreshIndicator(
      onRefresh: () {
        debugPrint('Pull-to-refresh triggered');
        return _fetchData();
      },
      color: Colors.black,
      child: Column(
        children: [
          // Visitors count header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Text(
              'My Visitors (${visitors.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          // Visitors list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visitors.length,
              itemBuilder: (context, index) {
                final visitor = visitors[index];
                debugPrint('Building visitor card for index $index: ${visitor['Visitor_Name']}');
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      debugPrint('Visitor card tapped: ${visitor['Visitor_Name']}');
                      _showVisitorDetails(visitor);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  visitor['Visitor_Name'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'ID: ${visitor['vis_inv_id'] ?? 'N/A'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                visitor['About_Visitor'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.email, size: 20, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      visitor['Visitor_Email'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 20, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    visitor['Visitor_Phone'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              if (visitor['created_at'] != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 20, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Added: ${visitor['created_at']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('=== VisitorManagementScreen: dispose called ===');
    nameController.dispose();
    aboutController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}