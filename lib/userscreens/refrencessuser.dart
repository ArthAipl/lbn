import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReferencesPage extends StatefulWidget {
  const ReferencesPage({Key? key}) : super(key: key);

  @override
  State<ReferencesPage> createState() => _ReferencesPageState();
}

class _ReferencesPageState extends State<ReferencesPage> with SingleTickerProviderStateMixin {
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
  List<dynamic> _thankNotes = [];
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
    _tabController = TabController(length: 4, vsync: this);
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
        _fetchThankNotes(),
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
    setState(() {
      _isMembersLoading = true;
    });
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
        }

        Set<String> validGroupIds = {};
        String? userGroupId;

        for (var member in allMembers) {
          if (member['G_ID'] != null) {
            String gId = member['G_ID'].toString();
            validGroupIds.add(gId);

            if (member['M_ID']?.toString() == _currentUserId) {
              userGroupId = gId;
            }
          }
        }

        if (userGroupId != null && userGroupId != _currentGroupId) {
          print('DEBUG: _fetchMembers - Updating G_ID from $_currentGroupId to $userGroupId');
          setState(() {
            _currentGroupId = userGroupId;
          });
          await prefs.setString('G_ID', userGroupId);
        }

        if (_currentGroupId == null || !validGroupIds.contains(_currentGroupId)) {
          if (validGroupIds.isNotEmpty) {
            String fallbackGroupId = validGroupIds.first;
            setState(() {
              _currentGroupId = fallbackGroupId;
            });
            await prefs.setString('G_ID', fallbackGroupId);
          }
        }

        List<dynamic> filteredMembers = allMembers.where((member) {
          String memberStatus = member['status']?.toString() ?? '0';
          return memberStatus == '1' && member['M_ID']?.toString() != _currentUserId;
        }).toList();

        setState(() {
          _members = filteredMembers;
        });
      } else {
        print('ERROR: _fetchMembers - Failed to fetch members - Status: ${response.statusCode}');
        _showErrorSnackBar('Failed to fetch members: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('ERROR: _fetchMembers - Exception while fetching members: $e');
      _showErrorSnackBar('Failed to fetch members: Network error. Please try again.');
    } finally {
      setState(() {
        _isMembersLoading = false;
      });
    }
  }

  Future<void> _fetchReferences() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
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
        setState(() {
          _references = data is List ? data : [];
        });
        print('DEBUG: _fetchReferences - References loaded: ${_references.length} items');
      } else {
        print('ERROR: _fetchReferences - Failed to fetch references - Status: ${response.statusCode}');
        _showErrorSnackBar('Failed to fetch references: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('ERROR: _fetchReferences - Exception while fetching references: $e');
      _showErrorSnackBar('Failed to fetch references: Network error. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchThankNotes() async {
    if (!mounted || _currentUserId == null) return;
    setState(() {
      _isLoading = true;
    });
    try {
      print('DEBUG: _fetchThankNotes - Starting to fetch thank notes');
      // Fetch references where From_MID matches current user (references given by the user)
      final refResponse = await _retryHttpRequest(
        () => http.get(
          Uri.parse('https://tagai.caxis.ca/public/api/ref-tracks'),
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (refResponse.statusCode != 200) {
        print('ERROR: _fetchThankNotes - Failed to fetch references - Status: ${refResponse.statusCode}');
        _showErrorSnackBar('Failed to fetch references: HTTP ${refResponse.statusCode}');
        return;
      }

      final refData = json.decode(refResponse.body);
      List<dynamic> references = refData is List ? refData : [];

      // Filter references where From_MID matches current user
      List<dynamic> givenReferences = references.where((ref) {
        return ref['From_MID']?.toString() == _currentUserId;
      }).toList();

      print('DEBUG: _fetchThankNotes - Given references count: ${givenReferences.length}');

      // Fetch thank notes
      final thankResponse = await _retryHttpRequest(
        () => http.get(
          Uri.parse('https://tagai.caxis.ca/public/api/thnk-tracks'),
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      print('DEBUG: _fetchThankNotes - Thank notes API Status Code: ${thankResponse.statusCode}');

      if (thankResponse.statusCode == 200) {
        final thankData = json.decode(thankResponse.body);
        List<dynamic> thankNotes = thankData is List ? thankData : [];

        // Filter thank notes where ref_track_Id matches given references
        List<dynamic> filteredThankNotes = thankNotes.where((thankNote) {
          String? refTrackId;
          List<String> possibleIdFields = ['ref_track_Id', 'ref_track_id', 'id', 'ID', 'Ref_Track_Id', 'RT_ID'];

          for (String field in possibleIdFields) {
            if (thankNote.containsKey(field) && thankNote[field] != null) {
              refTrackId = thankNote[field].toString();
              break;
            }
          }

          if (refTrackId == null) {
            print('DEBUG: _fetchThankNotes - Skipping thank note, no valid ref_track_Id found');
            return false;
          }

          // Check if ref_track_Id matches any given reference
          return givenReferences.any((ref) {
            for (String field in possibleIdFields) {
              if (ref.containsKey(field) && ref[field] != null) {
                return ref[field].toString() == refTrackId;
              }
            }
            return false;
          });
        }).toList();

        setState(() {
          _thankNotes = filteredThankNotes;
        });
        print('DEBUG: _fetchThankNotes - Received thank notes loaded: ${filteredThankNotes.length} items');
      } else {
        print('ERROR: _fetchThankNotes - Failed to fetch thank notes - Status: ${thankResponse.statusCode}');
        _showErrorSnackBar('Failed to fetch thank notes: HTTP ${thankResponse.statusCode}');
      }
    } catch (e) {
      print('ERROR: _fetchThankNotes - Exception while fetching thank notes: $e');
      _showErrorSnackBar('Failed to fetch thank notes: Network error. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar('Reference created successfully');
        _clearForm();
        _fetchReferences();
        _tabController.animateTo(1);
      } else {
        print('ERROR: _createReference - Failed to create reference - Status: ${response.statusCode}');
        _showErrorSnackBar('Failed to create reference: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('ERROR: _createReference - Exception while creating reference: $e');
      _showErrorSnackBar('Error creating reference: Network error. Please try again.');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _sendThankNote(dynamic reference) async {
    print('DEBUG: _sendThankNote - Starting thank note process');

    String? businessAmount = await _showBusinessAmountDialog();

    if (businessAmount == null || businessAmount.isEmpty) {
      print('DEBUG: _sendThankNote - User cancelled or entered empty amount');
      return;
    }

    double? amount = double.tryParse(businessAmount);
    if (amount == null || amount <= 0) {
      print('ERROR: _sendThankNote - Invalid amount: $businessAmount');
      _showErrorSnackBar('Please enter a valid business amount');
      return;
    }

    setState(() {
      _isSendingThankNote = true;
    });

    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        _showErrorSnackBar('Error: User ID not found. Please restart the app.');
        return;
      }

      dynamic refTrackId;
      List<String> possibleIdFields = ['id', 'ID', 'ref_track_id', 'ref_track_Id', 'Ref_Track_Id', 'RT_ID'];

      for (String field in possibleIdFields) {
        if (reference.containsKey(field) && reference[field] != null) {
          refTrackId = reference[field];
          break;
        }
      }

      if (refTrackId == null) {
        print('ERROR: _sendThankNote - Could not find reference ID');
        _showErrorSnackBar('Error: Could not find reference ID');
        return;
      }

      final payload = {
        'Amount': amount,
        'ref_track_Id': refTrackId,
        'M_C_Id': null,
        'G_ID': _currentGroupId,
        'M_ID': _currentUserId,
      };

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

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar('Thank note sent successfully!');
        await _fetchReferences();
        await _fetchThankNotes();
      } else {
        String errorMessage = 'Failed to send thank note. Please try again.';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          print('DEBUG: _sendThankNote - Could not parse error response: $e');
        }
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      print('ERROR: _sendThankNote - Exception while sending thank note: $e');
      _showErrorSnackBar('Error sending thank note: Network error. Please try again.');
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
    setState(() {
      _selectedMemberId = null;
    });
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
      return fromMID == _currentUserId;
    }).toList();
  }

  List<dynamic> get _receivedReferences {
    if (_currentUserId == null) return [];

    return _references.where((reference) {
      String toMID = reference['To_MID']?.toString() ?? '';
      return toMID == _currentUserId;
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
              isScrollable: true, // Enable scrollable tabs
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[400],
              labelStyle: const TextStyle(
                fontSize: 12, // Reduced font size for better fit
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12, // Reduced font size for unselected tabs
              ),
              tabs: const [
                Tab(text: 'Send Reference'),
                Tab(text: 'Given Reference'),
                Tab(text: 'Received Reference'),
                Tab(text: 'Received Thank Notes'),
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
          _buildReceivedThankNotesTab(),
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
              'This is where you\'ll see references you\'ve given to others.',
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
              'This is where you\'ll see references others have given to you.',
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

  Widget _buildReceivedThankNotesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_thankNotes.isEmpty) {
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
                Icons.favorite_border,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No thank notes received',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thank notes for your given references will appear here',
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
      onRefresh: _fetchThankNotes,
      color: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _thankNotes.length,
        itemBuilder: (context, index) {
          final thankNote = _thankNotes[index];

          // Find the corresponding reference
          dynamic reference = _references.firstWhere(
            (ref) => ref['ref_track_id']?.toString() == thankNote['ref_track_Id']?.toString(),
            orElse: () => null,
          );

          // Find the member who sent the thank note (M_ID from thankNote)
          dynamic thankNoteSender = _members.firstWhere(
            (member) => member['M_ID']?.toString() == thankNote['M_ID']?.toString(),
            orElse: () => null,
          );

          return _buildThankNoteCard(thankNote, reference, thankNoteSender);
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

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReferenceDetailPage(
              data: reference,
              isThankNote: false,
            ),
          ),
        );
      },
      child: Container(
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
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
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
      ),
    );
  }

  Widget _buildThankNoteCard(dynamic thankNote, dynamic reference, dynamic thankNoteSender) {
    String displayName = reference?['Name']?.toString() ?? 'Unknown';
    String displayEmail = reference?['Email']?.toString() ?? '';
    String displayAbout = reference?['About']?.toString() ?? '';
    String displayPhone = reference?['Phone']?.toString() ?? '';
    String senderName = thankNoteSender?['Name']?.toString() ?? 'Unknown';
    String status = reference?['Status']?.toString() ?? '0';
    String amount = thankNote['Amount']?.toString() ?? '0';

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

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReferenceDetailPage(
              data: thankNote,
              isThankNote: true,
              associatedReference: reference,
              fromMember: thankNoteSender,
            ),
          ),
        );
      },
      child: Container(
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
                        displayName.substring(0, 1).toUpperCase(),
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
                          displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Thank Note Sent By: $senderName',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple[400]!, Colors.purple[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Thank Note',
                      style: TextStyle(
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
                  displayAbout,
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
                      Icons.email,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    displayEmail,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                    displayPhone,
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.monetization_on,
                        size: 16,
                        color: Colors.purple[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Business Amount: \$${amount}',
                      style: TextStyle(
                        color: Colors.purple[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                                    setState(() {
                                      _selectedMemberId = value;
                                    });
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
                    maxLines: null,
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
    int? maxLines = 1,
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
        maxLength: label == 'Email Address' ? 100 : null,
        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      ),
    );
  }
}

class ReferenceDetailPage extends StatelessWidget {
  final dynamic data;
  final bool isThankNote;
  final dynamic associatedReference;
  final dynamic fromMember;

  const ReferenceDetailPage({
    Key? key,
    required this.data,
    required this.isThankNote,
    this.associatedReference,
    this.fromMember,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String displayName = isThankNote
        ? (associatedReference != null ? associatedReference['Name']?.toString() ?? 'Unknown' : 'Unknown')
        : data['Name']?.toString() ?? 'Unknown';
    String displayEmail = isThankNote
        ? (associatedReference != null ? associatedReference['Email']?.toString() ?? '' : '')
        : data['Email']?.toString() ?? '';
    String displayPhone = isThankNote
        ? (associatedReference != null ? associatedReference['Phone']?.toString() ?? '' : '')
        : data['Phone']?.toString() ?? '';
    String displayAbout = isThankNote
        ? (associatedReference != null ? associatedReference['About']?.toString() ?? '' : '')
        : data['About']?.toString() ?? '';
    String displayFromMID = isThankNote
        ? (associatedReference != null ? associatedReference['From_MID']?.toString() ?? 'N/A' : 'N/A')
        : data['From_MID']?.toString() ?? 'N/A';
    String displayFromName = isThankNote
        ? (fromMember != null ? fromMember['Name']?.toString() ?? 'Unknown' : 'Unknown')
        : 'N/A';
    String displayToMID = isThankNote
        ? (associatedReference != null ? associatedReference['To_MID']?.toString() ?? 'N/A' : 'N/A')
        : data['To_MID']?.toString() ?? 'N/A';
    String status = isThankNote
        ? (associatedReference != null ? associatedReference['Status']?.toString() ?? '0' : '0')
        : data['Status']?.toString() ?? '0';
    dynamic amount = isThankNote ? data['Amount'] : null;

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

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          isThankNote ? 'Thank Note Details' : 'Reference Details',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black, Colors.grey[800]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            displayName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
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
                              displayName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isThankNote ? 'Thank Note' : 'Reference',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isThankNote) ...[
                    _buildDetailRow(
                      icon: Icons.person,
                      label: 'From Member',
                      value: displayFromName,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildDetailRow(
                    icon: Icons.person,
                    label: 'From Member ID',
                    value: displayFromMID,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.person,
                    label: 'To Member ID',
                    value: displayToMID,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.email,
                    label: 'Email',
                    value: displayEmail,
                    isMultiLine: true,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.phone,
                    label: 'Phone',
                    value: displayPhone,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.description,
                    label: 'About',
                    value: displayAbout,
                    isMultiLine: true,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: statusIcon,
                    label: 'Status',
                    value: statusText,
                    valueColor: statusColor,
                  ),
                  if (isThankNote && amount != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      icon: Icons.monetization_on,
                      label: 'Business Amount',
                      value: '\$${amount.toString()}',
                      valueColor: Colors.purple[700],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isMultiLine = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: valueColor ?? Colors.grey[600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'N/A' : value,
                  style: TextStyle(
                    fontSize: 16,
                    color: valueColor ?? Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: isMultiLine ? null : 1,
                  overflow: isMultiLine ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}