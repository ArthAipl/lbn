import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReferencesPage extends StatefulWidget {
  const ReferencesPage({Key? key}) : super(key: key);

  @override
  State<ReferencesPage> createState() => _ReferencesPageState();
}

class _ReferencesPageState extends State<ReferencesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Form controllers
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessAmountController = TextEditingController();
  
  // Data variables
  List<dynamic> _references = [];
  List<dynamic> _members = [];
  String? _selectedMemberId;
  String? _currentUserId;
  String? _currentGroupId;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isMembersLoading = false;
  bool _isSendingThankNote = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _aboutController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _businessAmountController.dispose();
    super.dispose();
  }

  // Helper method to safely get string value from SharedPreferences
  String? _getStringValue(SharedPreferences prefs, String key) {
    try {
      // Try to get as string first
      String? stringValue = prefs.getString(key);
      if (stringValue != null && stringValue.isNotEmpty) {
        print('DEBUG: _getStringValue - Key: $key, String Value: $stringValue');
        return stringValue;
      }
      
      // Try to get as int and convert to string
      int? intValue = prefs.getInt(key);
      if (intValue != null) {
        print('DEBUG: _getStringValue - Key: $key, Int Value: $intValue');
        return intValue.toString();
      }
      
      // Try to get as double and convert to string
      double? doubleValue = prefs.getDouble(key);
      if (doubleValue != null) {
        print('DEBUG: _getStringValue - Key: $key, Double Value: $doubleValue');
        return doubleValue.toString();
      }
      
      // Try to get as bool and convert to string
      bool? boolValue = prefs.getBool(key);
      if (boolValue != null) {
        print('DEBUG: _getStringValue - Key: $key, Bool Value: $boolValue');
        return boolValue.toString();
      }
      
      print('DEBUG: _getStringValue - Key: $key, No value found');
      return null;
    } catch (e) {
      print('ERROR: _getStringValue - Failed to get value for key $key: $e');
      return null;
    }
  }

  Future<void> _loadUserData() async {
    try {
      print('DEBUG: _loadUserData - Starting to load user data');
      final prefs = await SharedPreferences.getInstance();
      
      // Print all keys and values to debug
      print('DEBUG: _loadUserData - All SharedPreferences keys: ${prefs.getKeys()}');
      
      // Print all stored values with their types
      for (String key in prefs.getKeys()) {
        dynamic value = prefs.get(key);
        print('DEBUG: _loadUserData - Key: $key, Value: $value, Type: ${value.runtimeType}');
      }
      
      // Enhanced key search for User ID
      List<String> userIdKeys = [
        'user_id', 'M_ID', 'id', 'userId', 'User_ID', 'member_id', 
        'memberId', 'user', 'uid', 'ID'
      ];
      
      // Enhanced key search for Group ID - prioritize exact matches
      List<String> groupIdKeys = [
        'G_ID',           // Exact match first
        'group_id', 
        'groupId', 
        'Group_ID', 
        'group_code', 
        'group', 
        'gid',
        'g_id'
      ];
      
      String? userId;
      String? groupId;
      
      // Try to find user ID (M_ID)
      for (String key in userIdKeys) {
        userId = _getStringValue(prefs, key);
        if (userId != null && userId.isNotEmpty) {
          print('DEBUG: _loadUserData - Found user ID with key: $key, value: $userId');
          break;
        }
      }
      
      // Try to find group ID (G_ID) - be more specific
      for (String key in groupIdKeys) {
        groupId = _getStringValue(prefs, key);
        if (groupId != null && groupId.isNotEmpty) {
          print('DEBUG: _loadUserData - Found group ID with key: $key, value: $groupId');
          break;
        }
      }
      
      // If still no G_ID found, try a broader search
      if (groupId == null || groupId.isEmpty) {
        print('DEBUG: _loadUserData - No G_ID found with standard keys, trying broader search');
        for (String key in prefs.getKeys()) {
          String lowerKey = key.toLowerCase();
          if (lowerKey.contains('group') || lowerKey.contains('g_') || lowerKey == 'gid') {
            String? potentialGroupId = _getStringValue(prefs, key);
            if (potentialGroupId != null && potentialGroupId.isNotEmpty) {
              groupId = potentialGroupId;
              print('DEBUG: _loadUserData - Found potential group ID with key: $key, value: $groupId');
              break;
            }
          }
        }
      }
      
      print('DEBUG: _loadUserData - Final User ID (M_ID): $userId');
      print('DEBUG: _loadUserData - Final Group ID (G_ID): $groupId');
      
      setState(() {
        _currentUserId = userId;
        _currentGroupId = groupId;
      });
      
      // Load data after user data is loaded
      await _fetchMembers(); // Fetch members first to validate G_ID
      await _fetchReferences();
    } catch (e) {
      print('ERROR: _loadUserData - Failed to load user data: $e');
    }
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isMembersLoading = true;
    });
    try {
      print('DEBUG: _fetchMembers - Starting to fetch members');
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/member'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      print('DEBUG: _fetchMembers - API Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('DEBUG: _fetchMembers - Raw members data type: ${data.runtimeType}');
        
        List<dynamic> allMembers = [];
        
        // Handle the API response structure
        if (data is Map && data.containsKey('members')) {
          allMembers = data['members'] is List ? data['members'] : [];
        } else if (data is List) {
          allMembers = data;
        } else {
          print('ERROR: _fetchMembers - Unexpected API response structure');
          allMembers = [];
        }
        
        print('DEBUG: _fetchMembers - All members count: ${allMembers.length}');
        
        // Extract all unique G_IDs from members to validate our current G_ID
        Set<String> validGroupIds = {};
        String? userGroupId;
        
        for (var member in allMembers) {
          if (member['G_ID'] != null) {
            String gId = member['G_ID'].toString();
            validGroupIds.add(gId);
            
            // If this member matches our current user, get their G_ID
            if (member['M_ID'].toString() == _currentUserId) {
              userGroupId = gId;
              print('DEBUG: _fetchMembers - Found current user in members with G_ID: $userGroupId');
            }
          }
        }
        
        print('DEBUG: _fetchMembers - All valid G_IDs from API: $validGroupIds');
        print('DEBUG: _fetchMembers - Current stored G_ID: $_currentGroupId');
        print('DEBUG: _fetchMembers - User\'s actual G_ID from members: $userGroupId');
        
        // Update G_ID if we found the user's actual G_ID
        if (userGroupId != null && userGroupId != _currentGroupId) {
          print('DEBUG: _fetchMembers - Updating G_ID from $_currentGroupId to $userGroupId');
          setState(() {
            _currentGroupId = userGroupId;
          });
          
          // Save the correct G_ID to SharedPreferences for future use
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('G_ID', userGroupId);
          print('DEBUG: _fetchMembers - Saved correct G_ID to SharedPreferences');
        }
        
        // If we still don't have a valid G_ID, use the first available one
        if (_currentGroupId == null || !validGroupIds.contains(_currentGroupId)) {
          if (validGroupIds.isNotEmpty) {
            String fallbackGroupId = validGroupIds.first;
            print('DEBUG: _fetchMembers - Using fallback G_ID: $fallbackGroupId');
            setState(() {
              _currentGroupId = fallbackGroupId;
            });
          }
        }
        
        // Filter active members
        List<dynamic> filteredMembers = allMembers.where((member) {
          String memberStatus = member['status'].toString();
          return memberStatus == '1';
        }).toList();
        
        print('DEBUG: _fetchMembers - Filtered active members count: ${filteredMembers.length}');
        print('DEBUG: _fetchMembers - Final G_ID to use: $_currentGroupId');
        
        setState(() {
          _members = filteredMembers;
        });
        
      } else {
        print('ERROR: _fetchMembers - Failed to fetch members - Status: ${response.statusCode}');
        print('ERROR: _fetchMembers - Response body: ${response.body}');
      }
    } catch (e) {
      print('ERROR: _fetchMembers - Exception while fetching members: $e');
    } finally {
      setState(() {
        _isMembersLoading = false;
      });
    }
  }

  Future<void> _fetchReferences() async {
    setState(() {
      _isLoading = true;
    });
    try {
      print('DEBUG: _fetchReferences - Starting to fetch references');
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/ref-tracks'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      print('DEBUG: _fetchReferences - API Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _references = data is List ? data : [];
        });
        print('DEBUG: _fetchReferences - References loaded: ${_references.length} items');
        print('DEBUG: _fetchReferences - Given references count: ${_givenReferences.length}');
        print('DEBUG: _fetchReferences - Received references count: ${_receivedReferences.length}');
      } else {
        print('ERROR: _fetchReferences - Failed to fetch references - Status: ${response.statusCode}');
        _showErrorSnackBar('Failed to fetch references');
      }
    } catch (e) {
      print('ERROR: _fetchReferences - Exception while fetching references: $e');
      _showErrorSnackBar('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createReference() async {
    if (_nameController.text.isEmpty ||
        _aboutController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedMemberId == null) {
      _showErrorSnackBar('Please fill all fields');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final payload = {
        'From_MID': _currentUserId,
        'To_MID': _selectedMemberId,
        'Name': _nameController.text,
        'About': _aboutController.text,
        'Email': _emailController.text,
        'Phone': _phoneController.text,
        'G_ID': _currentGroupId,
      };

      print('DEBUG: _createReference - Creating reference with payload: ${json.encode(payload)}');

      final response = await http.post(
        Uri.parse('https://tagai.caxis.ca/public/api/ref-tracks'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      print('DEBUG: _createReference - API Status Code: ${response.statusCode}');
      print('DEBUG: _createReference - API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar('Reference created successfully');
        _clearForm();
        _fetchReferences();
        _tabController.animateTo(1);
      } else {
        print('ERROR: _createReference - Failed to create reference - Status: ${response.statusCode}');
        _showErrorSnackBar('Failed to create reference');
      }
    } catch (e) {
      print('ERROR: _createReference - Exception while creating reference: $e');
      _showErrorSnackBar('Error: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _sendThankNote(dynamic reference) async {
    print('DEBUG: _sendThankNote - Starting thank note process');
    print('DEBUG: _sendThankNote - Reference data: ${json.encode(reference)}');
    
    // Show dialog to enter business amount
    String? businessAmount = await _showBusinessAmountDialog();
    
    if (businessAmount == null || businessAmount.isEmpty) {
      print('DEBUG: _sendThankNote - User cancelled or entered empty amount');
      return;
    }

    print('DEBUG: _sendThankNote - Business amount entered: $businessAmount');

    // Validate amount
    double? amount = double.tryParse(businessAmount);
    if (amount == null || amount <= 0) {
      print('ERROR: _sendThankNote - Invalid amount: $businessAmount');
      _showErrorSnackBar('Please enter a valid business amount');
      return;
    }

    print('DEBUG: _sendThankNote - Parsed amount: $amount');

    setState(() {
      _isSendingThankNote = true;
    });

    try {
      // Validate required data before proceeding
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        _showErrorSnackBar('Error: User ID not found. Please restart the app.');
        return;
      }
      
      if (_currentGroupId == null || _currentGroupId!.isEmpty) {
        _showErrorSnackBar('Error: Group ID not found. Please restart the app.');
        return;
      }

      // Try to find the reference ID from different possible field names
      dynamic refTrackId;
      List<String> possibleIdFields = ['id', 'ID', 'ref_track_id', 'ref_track_Id', 'Ref_Track_Id', 'RT_ID'];
      
      for (String field in possibleIdFields) {
        if (reference.containsKey(field) && reference[field] != null) {
          refTrackId = reference[field];
          print('DEBUG: _sendThankNote - Found reference ID with field: $field, value: $refTrackId');
          break;
        }
      }
      
      if (refTrackId == null) {
        print('ERROR: _sendThankNote - Could not find reference ID in reference data');
        print('ERROR: _sendThankNote - Available fields: ${reference.keys.toList()}');
        _showErrorSnackBar('Error: Could not find reference ID');
        return;
      }

      // Prepare the payload with proper data types
      // Convert to integers if they are numeric strings
      dynamic groupId = _currentGroupId;
      dynamic userId = _currentUserId;
      
      if (_currentGroupId != null) {
        int? groupIdInt = int.tryParse(_currentGroupId!);
        if (groupIdInt != null) {
          groupId = groupIdInt;
          print('DEBUG: _sendThankNote - Converted group ID to int: $groupId');
        }
      }
      
      if (_currentUserId != null) {
        int? userIdInt = int.tryParse(_currentUserId!);
        if (userIdInt != null) {
          userId = userIdInt;
          print('DEBUG: _sendThankNote - Converted user ID to int: $userId');
        }
      }

      // IMPORTANT: Set M_C_Id to null as requested
      final payload = {
        'Amount': amount,
        'ref_track_Id': refTrackId,
        'M_C_Id': null, // Explicitly set to null as requested
        'G_ID': groupId,
        'M_ID': userId,
      };

      print('DEBUG: _sendThankNote - Thank note payload: ${json.encode(payload)}');
      print('DEBUG: _sendThankNote - Payload details:');
      print('  - Amount: ${amount.runtimeType} = $amount');
      print('  - ref_track_Id: ${refTrackId.runtimeType} = $refTrackId');
      print('  - M_C_Id: null (explicitly set to null as requested)');
      print('  - G_ID: ${groupId.runtimeType} = $groupId');
      print('  - M_ID: ${userId.runtimeType} = $userId');

      final response = await http.post(
        Uri.parse('https://tagai.caxis.ca/public/api/thnk-tracks'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(payload),
      );

      print('DEBUG: _sendThankNote - API Status Code: ${response.statusCode}');
      print('DEBUG: _sendThankNote - API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('SUCCESS: _sendThankNote - Thank note sent successfully');
        _showSuccessSnackBar('Thank note sent successfully!');
        await _fetchReferences();
      } else {
        print('ERROR: _sendThankNote - Failed to send thank note - Status: ${response.statusCode}');
        
        // Parse error message from response
        String errorMessage = 'Failed to send thank note. Please try again.';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'];
          } else if (errorData is Map && errorData.containsKey('errors')) {
            Map<String, dynamic> errors = errorData['errors'];
            List<String> errorMessages = [];
            errors.forEach((key, value) {
              if (value is List) {
                errorMessages.addAll(value.cast<String>());
              }
            });
            if (errorMessages.isNotEmpty) {
              errorMessage = errorMessages.join(', ');
            }
          }
        } catch (e) {
          print('DEBUG: _sendThankNote - Could not parse error response: $e');
        }
        
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      print('ERROR: _sendThankNote - Exception while sending thank note: $e');
      _showErrorSnackBar('Error sending thank note: $e');
    } finally {
      setState(() {
        _isSendingThankNote = false;
      });
    }
  }

  Future<String?> _showBusinessAmountDialog() async {
    _businessAmountController.clear();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.monetization_on,
                  color: Colors.green[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Send Thank Note',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the business amount for this thank note:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _businessAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Business Amount',
                  hintText: 'Enter amount (e.g., 1200)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(_businessAmountController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Send Thank Note',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clearForm() {
    _nameController.clear();
    _aboutController.clear();
    _emailController.clear();
    _phoneController.clear();
    setState(() {
      _selectedMemberId = null;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Filter references for given references
  List<dynamic> get _givenReferences {
    if (_currentUserId == null) return [];
    
    return _references.where((reference) {
      String fromMID = reference['From_MID'].toString();
      String currentUID = _currentUserId.toString();
      return fromMID == currentUID;
    }).toList();
  }

  // Filter references for received references
  List<dynamic> get _receivedReferences {
    if (_currentUserId == null) return [];
    
    return _references.where((reference) {
      String toMID = reference['To_MID'].toString();
      String currentUID = _currentUserId.toString();
      return toMID == currentUID;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'References',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          isScrollable: true,
          tabs: const [
            Tab(text: 'Give Reference'),
            Tab(text: 'Given References'),
            Tab(text: 'Received References'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateReferenceTab(),
          _buildGivenReferencesTab(),
          _buildReceivedReferencesTab(),
        ],
      ),
    );
  }

  Widget _buildGivenReferencesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_givenReferences.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.send_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No given references found', style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('References you\'ve given to others will appear here', 
                 style: TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchReferences,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _givenReferences.length,
        itemBuilder: (context, index) {
          final reference = _givenReferences[index];
          return _buildReferenceCard(reference, isGiven: true);
        },
      ),
    );
  }

  Widget _buildReceivedReferencesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_receivedReferences.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No received references found', style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('References others have given to you will appear here', 
                 style: TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchReferences,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _receivedReferences.length,
        itemBuilder: (context, index) {
          final reference = _receivedReferences[index];
          return _buildReferenceCard(reference, isGiven: false);
        },
      ),
    );
  }

  Widget _buildReferenceCard(dynamic reference, {required bool isGiven}) {
    String status = reference['Status'].toString();
    Color statusColor;
    String statusText;
    
    switch (status) {
      case '0':
        statusColor = Colors.orange;
        statusText = 'Pending';
        break;
      case '1':
        statusColor = Colors.green;
        statusText = 'Approved';
        break;
      case '2':
        statusColor = Colors.red;
        statusText = 'Rejected';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black,
                  radius: 24,
                  child: Text(
                    reference['Name']?.substring(0, 1).toUpperCase() ?? 'R',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reference['Name'] ?? 'Unknown', 
                           style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(reference['Email'] ?? '', 
                           style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isGiven ? Colors.blue : Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isGiven ? 'Given' : 'Received',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                reference['About'] ?? '',
                style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(reference['Phone'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            
            // Add Thank Note button for received references
            if (!isGiven) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSendingThankNote ? null : () => _sendThankNote(reference),
                  icon: _isSendingThankNote 
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Icon(Icons.favorite, size: 18),
                  label: Text(
                    _isSendingThankNote ? 'Sending...' : 'Send Thank Note',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreateReferenceTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[50]!, Colors.white],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.grey[800]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.person_add, color: Colors.white, size: 32),
                  const SizedBox(height: 12),
                  const Text('Give Reference', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Help someone by providing a reference', 
                       style: TextStyle(fontSize: 14, color: Colors.grey[300]), textAlign: TextAlign.center),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Form Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: Select Member
                  _buildSectionHeader('1', 'Select Member', Icons.people),
                  const SizedBox(height: 16),
                  
                  _isMembersLoading
                      ? Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedMemberId,
                            decoration: InputDecoration(
                              labelText: 'Choose Member',
                              prefixIcon: const Icon(Icons.person_search, color: Colors.black),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            hint: Text(
                              _members.isEmpty ? 'No members available' : 'Select a member to give reference',
                              style: TextStyle(color: Colors.grey[600], fontSize: 11),
                            ),
                            items: _members.isNotEmpty
                                ? _members.map<DropdownMenuItem<String>>((member) {
                                    return DropdownMenuItem<String>(
                                      value: member['M_ID'].toString(),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: Colors.black,
                                              child: Text(
                                                member['Name']?.substring(0, 1).toUpperCase() ?? 'M',
                                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Flexible(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    member['Name']?.toString() ?? 'Unknown Member',
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    member['email']?.toString() ?? '',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList()
                                : null,
                            onChanged: _members.isNotEmpty
                                ? (String? value) {
                                    setState(() {
                                      _selectedMemberId = value;
                                    });
                                  }
                                : null,
                          ),
                        ),
                  
                  const SizedBox(height: 32),
                  
                  // Step 2: Reference Details
                  _buildSectionHeader('2', 'Reference Details', Icons.description),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Enter the person\'s full name',
                    icon: Icons.person,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _aboutController,
                    label: 'About / Description',
                    hint: 'Describe the person and your relationship',
                    icon: Icons.info,
                    maxLines: 4,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'Enter email address',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: 'Enter phone number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Submit Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: (_isSubmitting || _members.isEmpty) 
                            ? [Colors.grey[400]!, Colors.grey[500]!]
                            : [Colors.black, Colors.grey[800]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: (_isSubmitting || _members.isEmpty) ? null : _createReference,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                                SizedBox(width: 12),
                                Text('Creating Reference...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            )
                          : const Text('Give Reference', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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

  Widget _buildSectionHeader(String step, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 12),
        Icon(icon, color: Colors.black, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.black),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 2)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(color: Colors.grey[700]),
          hintStyle: TextStyle(color: Colors.grey[500]),
        ),
      ),
    );
  }
}