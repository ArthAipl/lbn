import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class CircleMeetingPage extends StatefulWidget {
  @override
  _CircleMeetingPageState createState() => _CircleMeetingPageState();
}

class _CircleMeetingPageState extends State<CircleMeetingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Platform.isIOS
              ? Icon(CupertinoIcons.back, color: Colors.white)
              : Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Circle Meetings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          isScrollable: true,
          tabs: [
            Tab(text: 'Create Meeting'),
            Tab(text: 'Requests'),
            Tab(text: 'All Meetings'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CreateMeetingTab(),
          RequestsTab(),
          AllMeetingsTab(),
          HistoryTab(),
        ],
      ),
    );
  }
}

class CreateMeetingTab extends StatefulWidget {
  @override
  _CreateMeetingTabState createState() => _CreateMeetingTabState();
}

class _CreateMeetingTabState extends State<CreateMeetingTab> {
  final _formKey = GlobalKey<FormState>();
  final _placeController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  
  List<Member> _allMembers = [];
  List<Member> _selectedMembers = [];
  
  bool _isLoading = false;
  bool _isFetchingMembers = false;
  String? _gId;
  String? _fromMId;
  String _memberError = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _loadUserData();
    await _fetchMembers();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _gId = prefs.getString('user_id');
          _fromMId = prefs.getString('user_id');
        });
        print('Loaded user data: G_ID=$_gId, From_M_ID=$_fromMId');
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _fetchMembers() async {
    if (mounted) {
      setState(() {
        _isFetchingMembers = true;
        _memberError = '';
      });
    }

    try {
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/member'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('API response status: ${response.statusCode}');
      print('API response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        List<Member> fetchedMembers = [];
        
        // Handle different API response structures
        if (data is Map) {
          if (data.containsKey('members') && data['members'] is List) {
            fetchedMembers = (data['members'] as List)
                .map((member) => Member.fromJson(member))
                .toList();
          } else if (data.containsKey('data') && data['data'] is List) {
            fetchedMembers = (data['data'] as List)
                .map((member) => Member.fromJson(member))
                .toList();
          }
        } else if (data is List) {
          fetchedMembers = (data as List)
              .map((member) => Member.fromJson(member))
              .toList();
        }

        print('Fetched members count: ${fetchedMembers.length}');

        // UPDATED FILTERING LOGIC - Show all members with matching G_ID except current user
        List<Member> filteredMembers = fetchedMembers.where((member) {
          // Check if G_ID matches (this is the main criteria)
          bool hasMatchingGId = _gId != null && member.gId == _gId;
          
          // Exclude current user
          bool isNotCurrentUser = _fromMId != null && member.mId != _fromMId;
          
          // Only apply these filters - removed status filter to show all members
          return hasMatchingGId && isNotCurrentUser && member.mId.isNotEmpty;
        }).toList();

        // Remove duplicates based on M_ID
        Map<String, Member> uniqueMembers = {};
        for (Member member in filteredMembers) {
          if (member.mId.isNotEmpty) {
            uniqueMembers[member.mId] = member;
          }
        }

        List<Member> finalMembers = uniqueMembers.values.toList();

        // Sort members by name for better UX
        finalMembers.sort((a, b) => a.name.compareTo(b.name));

        print('Final filtered members count: ${finalMembers.length}');
        for (var member in finalMembers) {
          print('Member: ${member.name}, M_ID: ${member.mId}, G_ID: ${member.gId}, Status: ${member.status}');
        }

        if (mounted) {
          setState(() {
            _allMembers = finalMembers;
          });
        }

        if (finalMembers.isEmpty && mounted) {
          setState(() {
            _memberError = 'No members found in your group.';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _memberError = 'Failed to load members: HTTP ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      print('Error fetching members: $e');
      if (mounted) {
        setState(() {
          _memberError = 'Network error occurred: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingMembers = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime && mounted) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _toggleMemberSelection(Member member) {
    setState(() {
      if (_selectedMembers.any((m) => m.mId == member.mId)) {
        _selectedMembers.removeWhere((m) => m.mId == member.mId);
      } else {
        _selectedMembers.add(member);
      }
    });
  }

  Future<void> _createMeeting() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one member'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      String formattedTime = "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}";
      
      final payload = {
        "place": _placeController.text.trim(),
        "date": "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
        "time": formattedTime,
        "Status": "0",
        "G_ID": _gId,
        "From_M_ID": _fromMId,
        "To_M_ID": _selectedMembers.map((member) => int.tryParse(member.mId) ?? 0).toList(),
      };

      print('Creating meeting with payload: ${json.encode(payload)}');

      final response = await http.post(
        Uri.parse('https://tagai.caxis.ca/public/api/circle-meetings'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(payload),
      );

      print('Create meeting response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Meeting created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _resetForm();
        }
      } else {
        final errorData = json.decode(response.body);
        String errorMessage = 'Failed to create meeting';
        if (errorData['message'] != null) {
          errorMessage = errorData['message'];
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error creating meeting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetForm() {
    _placeController.clear();
    if (mounted) {
      setState(() {
        _selectedDate = DateTime.now();
        _selectedTime = TimeOfDay.now();
        _selectedMembers.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                Text(
                  'Create New Meeting',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 30),
                
                // Place Field
                TextFormField(
                  controller: _placeController,
                  decoration: InputDecoration(
                    labelText: 'Meeting Place *',
                    labelStyle: TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                    prefixIcon: Icon(Icons.location_on, color: Colors.black54),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter meeting place';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),

                // Date Field
                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.black54),
                        SizedBox(width: 12),
                        Text(
                          'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                        Spacer(),
                        Icon(Icons.arrow_drop_down, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Time Field
                InkWell(
                  onTap: _selectTime,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.black54),
                        SizedBox(width: 12),
                        Text(
                          'Time: ${_selectedTime.format(context)}',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                        Spacer(),
                        Icon(Icons.arrow_drop_down, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 30),

                // Members Selection Section
                Row(
                  children: [
                    Text(
                      'Select Members *',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Spacer(),
                    if (_isFetchingMembers)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      ),
                    if (!_isFetchingMembers && _allMembers.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.black54),
                        onPressed: _fetchMembers,
                        tooltip: 'Refresh members list',
                      ),
                  ],
                ),
                SizedBox(height: 15),

                // Members List with Checkboxes
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: _memberError.isNotEmpty
                      ? Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red, size: 32),
                              SizedBox(height: 8),
                              Text(
                                _memberError,
                                style: TextStyle(color: Colors.red, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _fetchMembers,
                                child: Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _allMembers.isEmpty && !_isFetchingMembers
                          ? Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(Icons.people_outline, size: 32, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'No members available to select',
                                    style: TextStyle(color: Colors.grey, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _fetchMembers,
                                    child: Text('Refresh'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                Text(
                                  'Available Members (${_allMembers.length})',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 12),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: _allMembers.length,
                                  itemBuilder: (context, index) {
                                    final member = _allMembers[index];
                                    final isSelected = _selectedMembers.any((m) => m.mId == member.mId);
                                    
                                    return Container(
                                      margin: EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected ? Colors.green : Colors.grey.shade300,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: CheckboxListTile(
                                        value: isSelected,
                                        onChanged: (bool? value) {
                                          _toggleMemberSelection(member);
                                        },
                                        title: Text(
                                          member.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (member.email.isNotEmpty)
                                              Text(
                                                member.email,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            if (member.number.isNotEmpty)
                                              Text(
                                                member.number,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            // Show member status
                                            Container(
                                              margin: EdgeInsets.only(top: 4),
                                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: member.status == "1" ? Colors.green.shade100 : Colors.orange.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                member.status == "1" ? 'Active' : 'Inactive',
                                                style: TextStyle(
                                                  color: member.status == "1" ? Colors.green.shade700 : Colors.orange.shade700,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        secondary: CircleAvatar(
                                          radius: 20,
                                          backgroundColor: isSelected ? Colors.green.shade100 : Colors.grey.shade100,
                                          child: Text(
                                            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                        activeColor: Colors.green,
                                        checkColor: Colors.white,
                                        controlAffinity: ListTileControlAffinity.trailing,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                ),

                // Selected Members Summary
                if (_selectedMembers.isNotEmpty) ...[
                  SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.green.shade50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Members (${_selectedMembers.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _selectedMembers.map((member) {
                            return Chip(
                              label: Text(
                                member.name,
                                style: TextStyle(fontSize: 12),
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: Colors.green.shade200),
                              deleteIcon: Icon(Icons.close, size: 16),
                              onDeleted: () => _toggleMemberSelection(member),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 40),

                // Create Meeting Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createMeeting,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Creating Meeting...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Create Meeting',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Requests Tab
class RequestsTab extends StatefulWidget {
  @override
  _RequestsTabState createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  List<MeetingRequest> _requests = [];
  bool _isLoading = false;
  String? _currentUserId;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getString('user_id');
      });
    }
    await _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    try {
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/circle-meetings'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'success' && data['meetings'] != null) {
          List<MeetingRequest> allRequests = (data['meetings'] as List)
              .map((meeting) => MeetingRequest.fromJson(meeting))
              .toList();

          // Filter meetings where current user is in toMembers with cirl_mt_status = "0" (Pending)
          List<MeetingRequest> userRequests = [];
          
          for (var request in allRequests) {
            for (var member in request.toMembers) {
              if (member.mId == _currentUserId && member.cirlMtStatus == "0") {
                userRequests.add(request);
                break;
              }
            }
          }

          if (mounted) {
            setState(() {
              _requests = userRequests;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load requests';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network error occurred';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateRequestStatus(int circleId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('https://tagai.caxis.ca/public/api/circle-meetings/$circleId/member-status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'M_ID': _currentUserId,
          'cirl_mt_status': status,
        }),
      );

      if (response.statusCode == 200) {
        String statusText = status == '1' ? 'accepted' : 'rejected';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Meeting request $statusText!'),
              backgroundColor: status == '1' ? Colors.green : Colors.red,
            ),
          );
        }
        await _fetchRequests(); // Refresh the list
      } else {
        throw Exception('Failed to update request status');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update request status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRequests,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(_error, style: TextStyle(fontSize: 16, color: Colors.red)),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchRequests,
                      child: Text('Retry'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                    ),
                  ],
                ),
              ),
            ] else if (_requests.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No Meeting Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                    Text('You have no pending meeting requests', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ] else ...[
              // Display requests
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  final request = _requests[index];
                  
                  // Find the current user in toMembers to get their specific status
                  ToMember? currentUserMember = request.toMembers.firstWhere(
                    (member) => member.mId == _currentUserId,
                    orElse: () => ToMember(
                      mId: '',
                      name: '',
                      email: '',
                      number: '',
                      gropCode: '',
                      cirlMtStatus: '0',
                    ),
                  );

                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  request.fromMember.name.isNotEmpty
                                      ? request.fromMember.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Meeting Request from ${request.fromMember.name}',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                    ),
                                    Text(
                                      request.fromMember.email,
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Pending',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                                    SizedBox(width: 4),
                                    Text('Place: ${request.place}', style: TextStyle(fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                    SizedBox(width: 4),
                                    Text('Date: ${request.date}'),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                    SizedBox(width: 4),
                                    Text('Time: ${request.time}'),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                                    SizedBox(width: 4),
                                    Text('Participants: ${request.toMembers.length}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          // Show Accept/Reject buttons only if current user's status is "0" (Pending)
                          if (currentUserMember.cirlMtStatus == "0") ...[
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _updateRequestStatus(request.circleId, '1'),
                                    icon: Icon(Icons.check, color: Colors.white),
                                    label: Text('Accept'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _updateRequestStatus(request.circleId, '2'),
                                    icon: Icon(Icons.close, color: Colors.white),
                                    label: Text('Reject'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // Show status if already responded
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: currentUserMember.cirlMtStatus == "1"
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: currentUserMember.cirlMtStatus == "1"
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    currentUserMember.cirlMtStatus == "1"
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: currentUserMember.cirlMtStatus == "1"
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    currentUserMember.cirlMtStatus == "1"
                                        ? 'You have accepted this meeting'
                                        : 'You have rejected this meeting',
                                    style: TextStyle(
                                      color: currentUserMember.cirlMtStatus == "1"
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// All Meetings Tab
class AllMeetingsTab extends StatefulWidget {
  @override
  _AllMeetingsTabState createState() => _AllMeetingsTabState();
}

class _AllMeetingsTabState extends State<AllMeetingsTab> {
  List<MeetingRequest> _meetings = [];
  bool _isLoading = false;
  String? _currentUserId;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getString('user_id');
      });
    }
    await _fetchMeetings();
  }

  Future<void> _fetchMeetings() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    try {
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/circle-meetings'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'success' && data['meetings'] != null) {
          List<MeetingRequest> allMeetings = (data['meetings'] as List)
              .map((meeting) => MeetingRequest.fromJson(meeting))
              .toList();

          List<MeetingRequest> userMeetings = allMeetings.where((meeting) {
            return meeting.fromMId == _currentUserId && meeting.status == "0";
          }).toList();

          if (mounted) {
            setState(() {
              _meetings = userMeetings;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load meetings';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network error occurred';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateMeetingStatus(int circleId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('https://tagai.caxis.ca/public/api/circle-meetings/$circleId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'Status': status,
        }),
      );

      if (response.statusCode == 200) {
        String statusText = status == '1' ? 'completed' : 'cancelled';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Meeting marked as $statusText!'),
              backgroundColor: status == '1' ? Colors.green : Colors.red,
            ),
          );
        }
        await _fetchMeetings();
      } else {
        throw Exception('Failed to update meeting status');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update meeting status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case '0':
        return 'Pending';
      case '1':
        return 'Completed';
      case '2':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '0':
        return Colors.orange;
      case '1':
        return Colors.green;
      case '2':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchMeetings,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(_error, style: TextStyle(fontSize: 16, color: Colors.red)),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchMeetings,
                    child: Text('Retry'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_meetings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchMeetings,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No Pending Meetings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  Text('You have no pending meetings', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMeetings,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _meetings.length,
        itemBuilder: (context, index) {
          final meeting = _meetings[index];
          return Card(
            margin: EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MeetingDetailPage(meeting: meeting),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meeting.place,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(meeting.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(meeting.status),
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                        SizedBox(width: 4),
                        Text('${meeting.date}', style: TextStyle(color: Colors.grey.shade700)),
                        SizedBox(width: 16),
                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                        SizedBox(width: 4),
                        Text('${meeting.time}', style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                        SizedBox(width: 4),
                        Text('${meeting.toMembers.length} participants', style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _updateMeetingStatus(meeting.circleId, '1'),
                            icon: Icon(Icons.check_circle, color: Colors.white),
                            label: Text('Mark Complete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _updateMeetingStatus(meeting.circleId, '2'),
                            icon: Icon(Icons.cancel, color: Colors.white),
                            label: Text('Cancel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// History Tab
class HistoryTab extends StatefulWidget {
  @override
  _HistoryTabState createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<MeetingRequest> _meetings = [];
  bool _isLoading = false;
  String? _currentUserId;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getString('user_id');
      });
    }
    await _fetchMeetings();
  }

  Future<void> _fetchMeetings() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    try {
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/circle-meetings'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'success' && data['meetings'] != null) {
          List<MeetingRequest> allMeetings = (data['meetings'] as List)
              .map((meeting) => MeetingRequest.fromJson(meeting))
              .toList();

          List<MeetingRequest> userMeetings = allMeetings.where((meeting) {
            return meeting.fromMId == _currentUserId && (meeting.status == "1" || meeting.status == "2");
          }).toList();

          if (mounted) {
            setState(() {
              _meetings = userMeetings;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load meeting history';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network error occurred';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case '0':
        return 'Pending';
      case '1':
        return 'Completed';
      case '2':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '0':
        return Colors.orange;
      case '1':
        return Colors.green;
      case '2':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchMeetings,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(_error, style: TextStyle(fontSize: 16, color: Colors.red)),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchMeetings,
                    child: Text('Retry'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_meetings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchMeetings,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No Meeting History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  Text('You have no completed or cancelled meetings', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMeetings,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _meetings.length,
        itemBuilder: (context, index) {
          final meeting = _meetings[index];
          return Card(
            margin: EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MeetingDetailPage(meeting: meeting),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meeting.place,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(meeting.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(meeting.status),
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                        SizedBox(width: 4),
                        Text('${meeting.date}', style: TextStyle(color: Colors.grey.shade700)),
                        SizedBox(width: 16),
                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                        SizedBox(width: 4),
                        Text('${meeting.time}', style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                        SizedBox(width: 4),
                        Text('${meeting.toMembers.length} participants', style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Meeting Detail Page
class MeetingDetailPage extends StatelessWidget {
  final MeetingRequest meeting;

  const MeetingDetailPage({Key? key, required this.meeting}) : super(key: key);

  String _getStatusText(String status) {
    switch (status) {
      case '0':
        return 'Pending';
      case '1':
        return 'Completed';
      case '2':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '0':
        return Colors.orange;
      case '1':
        return Colors.green;
      case '2':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Platform.isIOS
              ? Icon(CupertinoIcons.back, color: Colors.white)
              : Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Meeting Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meeting Info Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meeting.place,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(meeting.status),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _getStatusText(meeting.status),
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.black54),
                        SizedBox(width: 8),
                        Text(
                          'Date: ${meeting.date}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.black54),
                        SizedBox(width: 8),
                        Text(
                          'Time: ${meeting.time}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.black54),
                        SizedBox(width: 8),
                        Text(
                          'Place: ${meeting.place}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Organizer Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meeting Organizer',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            meeting.fromMember.name.isNotEmpty
                                ? meeting.fromMember.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meeting.fromMember.name,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                meeting.fromMember.email,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                              ),
                              Text(
                                meeting.fromMember.number,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Participants Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meeting Participants (${meeting.toMembers.length})',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: meeting.toMembers.length,
                      separatorBuilder: (context, index) => Divider(height: 20),
                      itemBuilder: (context, index) {
                        final participant = meeting.toMembers[index];
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.green.shade100,
                              child: Text(
                                participant.name.isNotEmpty
                                    ? participant.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    participant.name,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    participant.email,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                  ),
                                  Text(
                                    participant.number,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: participant.cirlMtStatus == "1"
                                    ? Colors.green
                                    : participant.cirlMtStatus == "2"
                                        ? Colors.red
                                        : Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                participant.cirlMtStatus == "1"
                                    ? 'Accepted'
                                    : participant.cirlMtStatus == "2"
                                        ? 'Rejected'
                                        : 'Pending',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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
}

// Model Classes
class Member {
  final String mId;
  final String name;
  final String email;
  final String number;
  final String gropCode;
  final String gId;
  final String status;

  Member({
    required this.mId,
    required this.name,
    required this.email,
    required this.number,
    required this.gropCode,
    required this.gId,
    required this.status,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      mId: json['M_ID']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Name'] ?? json['name'] ?? 'Unknown',
      email: json['email'] ?? '',
      number: json['number'] ?? json['phone'] ?? '',
      gropCode: json['Grop_code'] ?? json['group_code'] ?? '',
      gId: json['G_ID']?.toString() ?? json['group_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '0',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Member && runtimeType == other.runtimeType && mId == other.mId;

  @override
  int get hashCode => mId.hashCode;
}

class ToMember {
  final String mId;
  final String name;
  final String email;
  final String number;
  final String gropCode;
  final String cirlMtStatus;

  ToMember({
    required this.mId,
    required this.name,
    required this.email,
    required this.number,
    required this.gropCode,
    required this.cirlMtStatus,
  });

  factory ToMember.fromJson(Map<String, dynamic> json) {
    return ToMember(
      mId: json['M_ID']?.toString() ?? '',
      name: json['Name'] ?? '',
      email: json['email'] ?? '',
      number: json['number'] ?? '',
      gropCode: json['Grop_code'] ?? '',
      cirlMtStatus: json['cirl_mt_status']?.toString() ?? '0',
    );
  }
}

class FromMember {
  final String mId;
  final String name;
  final String email;
  final String number;
  final String gropCode;
  final String gId;

  FromMember({
    required this.mId,
    required this.name,
    required this.email,
    required this.number,
    required this.gropCode,
    required this.gId,
  });

  factory FromMember.fromJson(Map<String, dynamic> json) {
    return FromMember(
      mId: json['M_ID']?.toString() ?? '',
      name: json['Name'] ?? '',
      email: json['email'] ?? '',
      number: json['number'] ?? '',
      gropCode: json['Grop_code'] ?? '',
      gId: json['G_ID']?.toString() ?? '',
    );
  }
}

class MeetingRequest {
  final int circleId;
  final String place;
  final String date;
  final String time;
  final String status;
  final String gId;
  final String fromMId;
  final List<int> toMId;
  final List<ToMember> toMembers;
  final FromMember fromMember;

  MeetingRequest({
    required this.circleId,
    required this.place,
    required this.date,
    required this.time,
    required this.status,
    required this.gId,
    required this.fromMId,
    required this.toMId,
    required this.toMembers,
    required this.fromMember,
  });

  factory MeetingRequest.fromJson(Map<String, dynamic> json) {
    return MeetingRequest(
      circleId: json['Circle_ID'] ?? 0,
      place: json['place'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      status: json['Status']?.toString() ?? '0',
      gId: json['G_ID']?.toString() ?? '',
      fromMId: json['From_M_ID']?.toString() ?? '',
      toMId: (json['To_M_ID'] as List?)?.map((e) => int.tryParse(e.toString()) ?? 0).toList() ?? [],
      toMembers: (json['toMembers'] as List?)?.map((e) => ToMember.fromJson(e)).toList() ?? [],
      fromMember: FromMember.fromJson(json['from_member'] ?? {}),
    );
  }
}
