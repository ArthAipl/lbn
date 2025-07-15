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
    // Run heavy initialization off the main thread
    Future.microtask(_loadUserData);
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
      String? stringValue = prefs.getString(key);
      if (stringValue != null && stringValue.isNotEmpty) {
        print('DEBUG: _getStringValue - Key: $key, String Value: $stringValue');
        return stringValue;
      }
      
      int? intValue = prefs.getInt(key);
      if (intValue != null) {
        print('DEBUG: _getStringValue - Key: $key, Int Value: $intValue');
        return intValue.toString();
      }
      
      double? doubleValue = prefs.getDouble(key);
      if (doubleValue != null) {
        print('DEBUG: _getStringValue - Key: $key, Double Value: $doubleValue');
        return doubleValue.toString();
      }
      
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
      
      print('DEBUG: _loadUserData - All SharedPreferences keys: ${prefs.getKeys()}');
      
      for (String key in prefs.getKeys()) {
        dynamic value = prefs.get(key);
        print('DEBUG: _loadUserData - Key: $key, Value: $value, Type: ${value.runtimeType}');
      }
      
      // Load all user data from SharedPreferences
      String? userId = _getStringValue(prefs, 'M_ID');
      String? groupId = _getStringValue(prefs, 'G_ID');
      String? name = _getStringValue(prefs, 'Name');
      String? email = _getStringValue(prefs, 'email');
      String? number = _getStringValue(prefs, 'number');
      String? groupCode = _getStringValue(prefs, 'group_code');
      String? roleId = _getStringValue(prefs, 'role_id');
      
      print('DEBUG: _loadUserData - Found user ID (M_ID): $userId');
      print('DEBUG: _loadUserData - Found group ID (G_ID): $groupId');
      print('DEBUG: _loadUserData - Found name: $name');
      print('DEBUG: _loadUserData - Found email: $email');
      print('DEBUG: _loadUserData - Found number: $number');
      print('DEBUG: _loadUserData - Found group code (group_code): $groupCode');
      print('DEBUG: _loadUserData - Found role ID: $roleId');
      
      if (mounted) {
        setState(() {
          _currentUserId = userId;
          _currentGroupId = groupId;
        });
      }
      
      await Future.wait([
        _fetchMembers(),
        _fetchReferences(),
      ]);
    } catch (e) {
      print('ERROR: _loadUserData - Failed to load user data: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load user data. Please check your network and try again.');
      }
    }
  }

  Future<void> _fetchMembers() async {
    if (!mounted) return;
    if (mounted) {
      setState(() {
        _isMembersLoading = true;
      });
    }
    try {
      print('DEBUG: _fetchMembers - Starting to fetch members');
      final response = await _retryHttpRequest(
        () => http.get(
          Uri.parse('https://tagai.caxis.ca/public/api/member'),
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      print('DEBUG: _fetchMembers - API Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('DEBUG: _fetchMembers - Raw members data type: ${data.runtimeType}');
        
        List<dynamic> allMembers = [];
        
        if (data is Map && data.containsKey('members')) {
          allMembers = data['members'] is List ? data['members'] : [];
        } else if (data is List) {
          allMembers = data;
        } else {
          print('ERROR: _fetchMembers - Unexpected API response structure');
          allMembers = [];
        }
        
        print('DEBUG: _fetchMembers - All members count: ${allMembers.length}');
        
        // Update SharedPreferences with user data if found
        final prefs = await SharedPreferences.getInstance();
        dynamic userData;
        for (var member in allMembers) {
          if (member['M_ID']?.toString() == _currentUserId) {
            userData = member;
            break;
          }
        }
        
        if (userData != null) {
          await prefs.setString('M_ID', userData['M_ID']?.toString() ?? '');
          await prefs.setString('Name', userData['Name']?.toString() ?? '');
          await prefs.setString('email', userData['email']?.toString() ?? '');
          await prefs.setString('number', userData['number']?.toString() ?? '');
          await prefs.setString('group_code', userData['group_code']?.toString() ?? '');
          await prefs.setString('G_ID', userData['G_ID']?.toString() ?? '');
          await prefs.setString('role_id', userData['role_id']?.toString() ?? '');
          
          print('DEBUG: _fetchMembers - Updated SharedPreferences with user data');
          print('DEBUG: _fetchMembers - Saved M_ID: ${userData['M_ID']}');
          print('DEBUG: _fetchMembers - Saved Name: ${userData['Name']}');
          print('DEBUG: _fetchMembers - Saved email: ${userData['email']}');
          print('DEBUG: _fetchMembers - Saved number: ${userData['number']}');
          print('DEBUG: _fetchMembers - Saved group_code: ${userData['group_code']}');
          print('DEBUG: _fetchMembers - Saved G_ID: ${userData['G_ID']}');
          print('DEBUG: _fetchMembers - Saved role_id: ${userData['role_id']}');
        } else {
          print('DEBUG: _fetchMembers - No user data found for M_ID: $_currentUserId');
        }
        
        Set<String> validGroupIds = {};
        String? userGroupId;
        
        for (var member in allMembers) {
          if (member['G_ID'] != null) {
            String gId = member['G_ID'].toString();
            validGroupIds.add(gId);
            
            if (member['M_ID']?.toString() == _currentUserId) {
              userGroupId = gId;
              print('DEBUG: _fetchMembers - Found current user in members with G_ID: $userGroupId');
            }
          }
        }
        
        print('DEBUG: _fetchMembers - All valid G_IDs from API: $validGroupIds');
        print('DEBUG: _fetchMembers - Current stored G_ID: $_currentGroupId');
        print('DEBUG: _fetchMembers - User\'s actual G_ID from members: $userGroupId');
        
        if (userGroupId != null && userGroupId != _currentGroupId) {
          print('DEBUG: _fetchMembers - Updating G_ID from $_currentGroupId to $userGroupId');
          if (mounted) {
            setState(() {
              _currentGroupId = userGroupId;
            });
          }
          await prefs.setString('G_ID', userGroupId);
          print('DEBUG: _fetchMembers - Saved correct G_ID to SharedPreferences');
        }
        
        if (_currentGroupId == null || !validGroupIds.contains(_currentGroupId)) {
          if (validGroupIds.isNotEmpty) {
            String fallbackGroupId = validGroupIds.first;
            print('DEBUG: _fetchMembers - Using fallback G_ID: $fallbackGroupId');
            if (mounted) {
              setState(() {
                _currentGroupId = fallbackGroupId;
              });
            }
            await prefs.setString('G_ID', fallbackGroupId);
          }
        }
        
        List<dynamic> filteredMembers = allMembers.where((member) {
          String memberStatus = member['status']?.toString() ?? '0';
          return memberStatus == '1';
        }).toList();
        
        print('DEBUG: _fetchMembers - Filtered active members count: ${filteredMembers.length}');
        print('DEBUG: _fetchMembers - Final G_ID to use: $_currentGroupId');
        
        if (mounted) {
          setState(() {
            _members = filteredMembers;
          });
        }
      } else {
        print('ERROR: _fetchMembers - Failed to fetch members - Status: ${response.statusCode}');
        print('ERROR: _fetchMembers - Response body: ${response.body}');
        if (mounted) {
          _showErrorSnackBar('Failed to fetch members: HTTP ${response.statusCode}');
        }
      }
    } catch (e) {
      print('ERROR: _fetchMembers - Exception while fetching members: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to fetch members: Network error. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMembersLoading = false;
        });
      }
    }
  }

  Future<void> _fetchReferences() async {
    if (!mounted) return;
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      print('DEBUG: _fetchReferences - Starting to fetch references');
      final response = await _retryHttpRequest(
        () => http.get(
          Uri.parse('https://tagai.caxis.ca/public/api/ref-tracks'),
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      print('DEBUG: _fetchReferences - API Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _references = data is List ? data : [];
          });
        }
        print('DEBUG: _fetchReferences - References loaded: ${_references.length} items');
        print('DEBUG: _fetchReferences - Given references count: ${_givenReferences.length}');
        print('DEBUG: _fetchReferences - Received references count: ${_receivedReferences.length}');
      } else {
        print('ERROR: _fetchReferences - Failed to fetch references - Status: ${response.statusCode}');
        if (mounted) {
          _showErrorSnackBar('Failed to fetch references: HTTP ${response.statusCode}');
        }
      }
    } catch (e) {
      print('ERROR: _fetchReferences - Exception while fetching references: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to fetch references: Network error. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Retry logic for HTTP requests
  Future<http.Response> _retryHttpRequest(Future<http.Response> Function() request) async {
    const maxRetries = 3;
    for (int i = 0; i < maxRetries; i++) {
      try {
        final response = await request().timeout(const Duration(seconds: 10));
        return response;
      } catch (e) {
        if (i == maxRetries - 1) rethrow;
        print('DEBUG: _retryHttpRequest - Retry ${i + 1}/$maxRetries failed: $e');
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }
    throw Exception('Failed to complete request after $maxRetries retries');
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

    if (!mounted) return;
    if (mounted) {
      setState(() {
        _isSubmitting = true;
      });
    }

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

      final response = await _retryHttpRequest(
        () => http.post(
          Uri.parse('https://tagai.caxis.ca/public/api/ref-tracks'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode(payload),
        ),
      );

      print('DEBUG: _createReference - API Status Code: ${response.statusCode}');
      print('DEBUG: _createReference - API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _showSuccessSnackBar('Reference created successfully');
          _clearForm();
          _fetchReferences();
          _tabController.animateTo(1);
        }
      } else {
        print('ERROR: _createReference - Failed to create reference - Status: ${response.statusCode}');
        if (mounted) {
          _showErrorSnackBar('Failed to create reference: HTTP ${response.statusCode}');
        }
      }
    } catch (e) {
      print('ERROR: _createReference - Exception while creating reference: $e');
      if (mounted) {
        _showErrorSnackBar('Error creating reference: Network error. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _sendThankNote(dynamic reference) async {
    print('DEBUG: _sendThankNote - Starting thank note process');
    print('DEBUG: _sendThankNote - Reference data: ${json.encode(reference)}');
    
    String? businessAmount = await _showBusinessAmountDialog();
    
    if (businessAmount == null || businessAmount.isEmpty) {
      print('DEBUG: _sendThankNote - User cancelled or entered empty amount');
      return;
    }

    print('DEBUG: _sendThankNote - Business amount entered: $businessAmount');

    double? amount = double.tryParse(businessAmount);
    if (amount == null || amount <= 0) {
      print('ERROR: _sendThankNote - Invalid amount: $businessAmount');
      if (mounted) {
        _showErrorSnackBar('Please enter a valid business amount');
      }
      return;
    }

    print('DEBUG: _sendThankNote - Parsed amount: $amount');

    if (!mounted) return;
    if (mounted) {
      setState(() {
        _isSendingThankNote = true;
      });
    }

    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        if (mounted) {
          _showErrorSnackBar('Error: User ID not found. Please restart the app.');
        }
        return;
      }
      
      if (_currentGroupId == null || _currentGroupId!.isEmpty) {
        if (mounted) {
          _showErrorSnackBar('Error: Group ID not found. Please restart the app.');
        }
        return;
      }

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
        if (mounted) {
          _showErrorSnackBar('Error: Could not find reference ID');
        }
        return;
      }

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

      final payload = {
        'Amount': amount,
        'ref_track_Id': refTrackId,
        'M_C_Id': null,
        'G_ID': groupId,
        'M_ID': userId,
      };

      print('DEBUG: _sendThankNote - Thank note payload: ${json.encode(payload)}');
      print('DEBUG: _sendThankNote - Payload details:');
      print('  - Amount: ${amount.runtimeType} = $amount');
      print('  - ref_track_Id: ${refTrackId.runtimeType} = $refTrackId');
      print('  - M_C_Id: null');
      print('  - G_ID: ${groupId.runtimeType} = $groupId');
      print('  - M_ID: ${userId.runtimeType} = $userId');

      final response = await _retryHttpRequest(
        () => http.post(
          Uri.parse('https://tagai.caxis.ca/public/api/thnk-tracks'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(payload),
        ),
      );

      print('DEBUG: _sendThankNote - API Status Code: ${response.statusCode}');
      print('DEBUG: _sendThankNote - API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('SUCCESS: _sendThankNote - Thank note sent successfully');
        if (mounted) {
          _showSuccessSnackBar('Thank note sent successfully!');
          await _fetchReferences();
        }
      } else {
        print('ERROR: _sendThankNote - Failed to send thank note - Status: ${response.statusCode}');
        
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
        
        if (mounted) {
          _showErrorSnackBar(errorMessage);
        }
      }
    } catch (e) {
      print('ERROR: _sendThankNote - Exception while sending thank note: $e');
      if (mounted) {
        _showErrorSnackBar('Error sending thank note: Network error. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingThankNote = false;
        });
      }
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
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[400]!, Colors.green[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.monetization_on,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Send Thank Note',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
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
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _businessAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Business Amount',
                    hintText: 'Enter amount (e.g., 1200)',
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.attach_money,
                        color: Colors.green[700],
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  autofocus: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[400]!, Colors.green[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(_businessAmountController.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Send Thank Note',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
    if (mounted) {
      setState(() {
        _selectedMemberId = null;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<dynamic> get _givenReferences {
    if (_currentUserId == null) return [];
    
    return _references.where((reference) {
      String fromMID = reference['From_MID']?.toString() ?? '';
      String currentUID = _currentUserId.toString();
      return fromMID == currentUID;
    }).toList();
  }

  List<dynamic> get _receivedReferences {
    if (_currentUserId == null) return [];
    
    return _references.where((reference) {
      String toMID = reference['To_MID']?.toString() ?? '';
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
        elevation: 0,
        title: const Text(
          'References',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.black,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[400],
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  text: 'Send Reference',
                ),
                Tab(
                  text: 'Given Reference',
                ),
                Tab(
                  text: 'Received Reference',
                ),
              ],
            ),
          ),
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
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    if (_givenReferences.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No given references found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'References you\'ve given to others will appear here',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchReferences,
      color: Colors.black,
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
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    if (_receivedReferences.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No received references found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'References others have given to you will appear here',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchReferences,
      color: Colors.black,
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
    String status = reference['Status']?.toString() ?? '0';
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (status) {
      case '0':
        statusColor = Colors.orange;
        statusText = 'Pending';
        statusIcon = Icons.schedule;
        break;
      case '1':
        statusColor = Colors.green;
        statusText = 'Approved';
        statusIcon = Icons.check_circle;
        break;
      case '2':
        statusColor = Colors.red;
        statusText = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
        statusIcon = Icons.help;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black, Colors.grey[800]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: Text(
                      reference['Name']?.substring(0, 1).toUpperCase() ?? 'R',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reference['Name']?.toString() ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reference['Email']?.toString() ?? '',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isGiven 
                        ? [Colors.blue[400]!, Colors.blue[600]!]
                        : [Colors.green[400]!, Colors.green[600]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isGiven ? 'Given' : 'Received',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                reference['About']?.toString() ?? '',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.phone,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  reference['Phone']?.toString() ?? '',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (!isGiven) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isSendingThankNote
                      ? [Colors.grey[400]!, Colors.grey[500]!]
                      : [Colors.green[400]!, Colors.green[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isSendingThankNote ? null : () => _sendThankNote(reference),
                  icon: _isSendingThankNote
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.favorite, size: 18),
                  label: Text(
                    _isSendingThankNote ? 'Sending...' : 'Send Thank Note',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
            // Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.grey[800]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Text(
                    'Send Reference',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Help someone by providing a reference',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Form Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('1', 'Select Member', Icons.people),
                  const SizedBox(height: 16),
                  
                  // Member Selection Dropdown
                  _isMembersLoading
                    ? Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedMemberId,
                          decoration: InputDecoration(
                            labelText: 'Choose Member',
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.person_search,
                                color: Colors.black,
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
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.black, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          hint: Text(
                            _members.isEmpty ? 'No members available' : 'Select a member to give reference',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          isExpanded: true,
                          itemHeight: 58,
                          items: _members.isNotEmpty
                            ? _members.map<DropdownMenuItem<String>>((member) {
                                return DropdownMenuItem<String>(
                                  value: member['M_ID']?.toString(),
                                  child: Container(
                                    height: 50,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Colors.black, Colors.grey[700]!],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Center(
                                            child: Text(
                                              member['Name']?.substring(0, 1).toUpperCase() ?? 'M',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            member['Name']?.toString() ?? 'Unknown Member',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                              height: 1.0,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
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
                                if (mounted) {
                                  setState(() {
                                    _selectedMemberId = value;
                                  });
                                }
                              }
                            : null,
                        ),
                      ),
                  
                  const SizedBox(height: 32),
                  
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
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: (_isSubmitting || _members.isEmpty) ? null : _createReference,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSubmitting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Creating Reference...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Send Reference',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildSectionHeader(String step, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Colors.grey[700]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.black,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.black),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(
            color: Colors.grey[700],
            fontSize: 16,
          ),
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
          ),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
    );
  }
}