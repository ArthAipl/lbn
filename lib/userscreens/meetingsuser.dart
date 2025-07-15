import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

// Data Models
class Meeting {
  final String mcId;
  final String gId;
  final String place;
  final String groupLocation;
  final String meetingCategory;
  final String date;
  final String createdAt;
  final String attendanceStatus;
  final Group? group;

  Meeting({
    required this.mcId,
    required this.gId,
    required this.place,
    required this.groupLocation,
    required this.meetingCategory,
    required this.date,
    required this.createdAt,
    required this.attendanceStatus,
    this.group,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      mcId: json['M_C_Id']?.toString() ?? '',
      gId: json['G_ID']?.toString() ?? '',
      place: json['Place']?.toString() ?? '',
      groupLocation: json['G_Location']?.toString() ?? '',
      meetingCategory: json['Meet_Cate']?.toString() ?? '',
      date: json['Meeting_Date']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      attendanceStatus: json['Attn_Status']?.toString() ?? '',
      group: json['group'] != null ? Group.fromJson(json['group']) : null,
    );
  }
}

class Group {
  final String name;

  Group({required this.name});

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(name: json['name']?.toString() ?? '');
  }
}

class Visitor {
  final String mcId;
  final String visitorName;
  final String visitorEmail;
  final String aboutVisitor;
  final String visitorPhone;

  Visitor({
    required this.mcId,
    required this.visitorName,
    required this.visitorEmail,
    required this.aboutVisitor,
    required this.visitorPhone,
  });

  factory Visitor.fromJson(Map<String, dynamic> json) {
    return Visitor(
      mcId: json['M_C_Id']?.toString() ?? '',
      visitorName: json['Visitor_Name']?.toString() ?? '',
      visitorEmail: json['Visitor_Email']?.toString() ?? '',
      aboutVisitor: json['About_Visitor']?.toString() ?? '',
      visitorPhone: json['Visitor_Phone']?.toString() ?? '',
    );
  }
}

class Presentation {
  final String mcId;
  final String memberId;
  final String presStatus;

  Presentation({required this.mcId, required this.memberId, required this.presStatus});

  factory Presentation.fromJson(Map<String, dynamic> json) {
    return Presentation(
      mcId: json['M_C_Id']?.toString() ?? '',
      memberId: json['M_ID']?.toString() ?? '',
      presStatus: json['Pres_Status']?.toString() ?? '',
    );
  }
}

// Function to save user data to SharedPreferences
Future<void> saveUserData(Map<String, dynamic> userData) async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    print('DEBUG: Saving userData: $userData');
    await prefs.setString('M_ID', userData['M_ID']?.toString() ?? '');
    await prefs.setString('Name', userData['Name']?.toString() ?? '');
    await prefs.setString('email', userData['email']?.toString() ?? '');
    await prefs.setString('number', userData['number']?.toString() ?? '');
    await prefs.setString('Grop_code', userData['Grop_code']?.toString() ?? '');
    await prefs.setString('G_ID', userData['G_ID']?.toString() ?? '');
    await prefs.setString('role_id', userData['role_id']?.toString() ?? '');
    print('DEBUG: Successfully saved user data - M_ID: ${userData['M_ID']}, Name: ${userData['Name']}, email: ${userData['email']}, number: ${userData['number']}, Grop_code: ${userData['Grop_code']}, G_ID: ${userData['G_ID']}, role_id: ${userData['role_id']}');
    print('DEBUG: Verified M_ID in SharedPreferences: ${prefs.getString('M_ID')}');
  } catch (e) {
    print('DEBUG ERROR: Failed to save user data in SharedPreferences: $e');
  }
}

// Function to show presentation dialog
Future<void> _showPresentationDialog(BuildContext context, Meeting meeting) async {
  try {
    print('DEBUG: Checking presentation slots for meeting M_C_Id: ${meeting.mcId}');
    final slotResponse = await http.get(
      Uri.parse('https://tagai.caxis.ca/public/api/pres-tracks?M_C_Id=${meeting.mcId}'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 30));

    if (slotResponse.statusCode == 200) {
      final data = json.decode(slotResponse.body);
      print('DEBUG: Presentation slots response: $data');
      List<dynamic> presentationData = data is List ? data : data['data'] ?? [];
      int presentationCount = presentationData
          .where((item) => item['M_C_Id'].toString() == meeting.mcId.toString())
          .length;
      print('DEBUG: Presentation count for M_C_Id ${meeting.mcId}: $presentationCount');

      const int maxSlots = 3;
      if (presentationCount >= maxSlots) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Presentation slots are full for this meeting'),
              backgroundColor: Colors.black,
              duration: Duration(seconds: 3),
            ),
          );
        }
        print('DEBUG: Presentation slots are full for meeting M_C_Id: ${meeting.mcId}');
        return;
      }
    } else {
      print('DEBUG ERROR: Failed to check presentation slots: Status Code ${slotResponse.statusCode}, Response Body: ${slotResponse.body}');
      throw Exception('Failed to check presentation slots: ${slotResponse.statusCode}');
    }

    // Show dialog if slots are available
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            'Give Presentation?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          content: const Text(
            'Would you like to give a presentation in this meeting?',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'No',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _submitPresentationStatus(context, meeting, '1');
              },
            ),
            TextButton(
              child: const Text(
                'Yes',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _submitPresentationStatus(context, meeting, '0');
              },
            ),
          ],
        );
      },
    );
  } catch (e) {
    print('DEBUG ERROR: Error checking presentation slots for M_C_Id ${meeting.mcId}: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking presentation slots: ${e.toString()}'),
          backgroundColor: Colors.black,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

// Function to submit presentation status
Future<void> _submitPresentationStatus(BuildContext context, Meeting meeting, String presStatus) async {
  try {
    print('DEBUG: Submitting presentation status for M_C_Id: ${meeting.mcId}, Pres_Status: $presStatus');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? memberId = prefs.getString('M_ID');
    String? groupId = prefs.getString('G_ID');
    String? token = prefs.getString('auth_token');

    print('DEBUG: SharedPreferences state - M_ID: $memberId, G_ID: $groupId, auth_token: $token');

    if (memberId == null || memberId.isEmpty) {
      print('DEBUG ERROR: Missing or empty M_ID in SharedPreferences for M_C_Id: ${meeting.mcId}');
      try {
        final userResponse = await http.get(
          Uri.parse('https://tagai.caxis.ca/public/api/user'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 15));
        print('DEBUG: User API response - Status Code: ${userResponse.statusCode}, Body: ${userResponse.body}');
        if (userResponse.statusCode == 200) {
          final userData = json.decode(userResponse.body);
          memberId = userData['M_ID']?.toString();
          if (memberId != null && memberId.isNotEmpty) {
            await prefs.setString('M_ID', memberId);
            print('DEBUG: Refreshed M_ID from API: $memberId');
          } else {
            throw Exception('Invalid M_ID in user API response: $memberId');
          }
        } else {
          throw Exception('Failed to fetch user data: ${userResponse.statusCode} - ${userResponse.body}');
        }
      } catch (e) {
        print('DEBUG ERROR: Failed to fetch M_ID from API: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User ID is missing or invalid. Please log out and log in again.'),
              backgroundColor: Colors.black,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    }

    print('DEBUG: Using M_ID: $memberId for M_C_Id: ${meeting.mcId}, G_ID: ${meeting.gId}');

    final now = DateTime.now().toIso8601String();
    final payload = {
      'M_C_Id': meeting.mcId.toString(),
      'G_ID': meeting.gId,
      'M_ID': memberId,
      'Pres_Status': presStatus,
      'created_at': now,
      'updated_at': now,
    };

    print('DEBUG: Submitting presentation status with payload: ${json.encode(payload)}');

    final response = await http.post(
      Uri.parse('https://tagai.caxis.ca/public/api/pres-tracks'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 30));

    print('DEBUG: Presentation status response - Status Code: ${response.statusCode}, Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Presentation status updated successfully (${presStatus == '0' ? 'Yes' : 'No'})'),
            backgroundColor: Colors.black,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      print('DEBUG: Presentation status updated successfully for M_C_Id: ${meeting.mcId}, Status Code: ${response.statusCode}');
    } else {
      print('DEBUG ERROR: Failed to update presentation status: Status Code ${response.statusCode}, Response Body: ${response.body}');
      throw Exception('Failed to update presentation status: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('DEBUG ERROR: Error updating presentation status for M_C_Id: ${meeting.mcId}: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating presentation status: ${e.toString()}. Please try logging in again.'),
          backgroundColor: Colors.black,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

// Meetings Page
class MeetingsPage extends StatefulWidget {
  const MeetingsPage({Key? key}) : super(key: key);

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  List<Meeting> allMeetings = [];
  List<Meeting> filteredMeetings = [];
  String searchQuery = '';
  String selectedFilter = 'All';
  bool isLoading = true;
  bool isRefreshing = false;
  String userGroupId = '';
  String userId = '';
  String userName = '';

  final TextEditingController searchController = TextEditingController();
  Timer? debounceTimer;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void dispose() {
    searchController.dispose();
    debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> loadUserData() async {
    try {
      print('DEBUG: Loading user data from SharedPreferences');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? groupId = prefs.getString('G_ID');
      String? uId = prefs.getString('M_ID');
      String? uName = prefs.getString('Name');

      print('DEBUG: Retrieved G_ID: $groupId, M_ID: $uId, Name: $uName');

      if (groupId != null && groupId.isNotEmpty) {
        setState(() {
          userGroupId = groupId;
          userId = uId ?? '';
          userName = uName ?? '';
        });
        await fetchMeetings();
      } else {
        setState(() {
          isLoading = false;
        });
        showErrorMessage('Group ID not found. Please login again.');
        print('DEBUG ERROR: G_ID not found in SharedPreferences');
      }
    } catch (e) {
      print('DEBUG ERROR: Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
      showErrorMessage('Error loading user data: ${e.toString()}');
    }
  }

  Future<void> fetchMeetings() async {
    if (!mounted) return;

    try {
      print('DEBUG: Fetching meetings from API');
      if (!isRefreshing) {
        setState(() {
          isLoading = true;
        });
      }

      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/meeting-cals'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        print('DEBUG: Meetings API response: $responseData');
        List<dynamic> data = responseData is List ? responseData : responseData['data'] ?? [];

        List<Meeting> meetings = [];
        for (var item in data) {
          print('DEBUG: Raw meeting JSON: $item');
          Meeting meeting = Meeting.fromJson(item as Map<String, dynamic>);
          print('DEBUG: Processing meeting - M_C_Id: ${meeting.mcId}, G_ID: ${meeting.gId}, Meet_Cate: ${meeting.meetingCategory}');
          if (meeting.gId == userGroupId && meeting.meetingCategory.toLowerCase() == 'general') {
            meetings.add(meeting);
          }
        }
        print('DEBUG: Filtered ${meetings.length} general meetings for group ID: $userGroupId');

        meetings.sort((a, b) {
          DateTime now = DateTime.now();
          DateTime dateA = DateTime.parse(a.date);
          DateTime dateB = DateTime.parse(b.date);
          bool isAToday = isSameDay(dateA, now);
          bool isBToday = isSameDay(dateB, now);
          if (isAToday && !isBToday) return -1;
          if (!isAToday && isBToday) return 1;
          return dateB.compareTo(dateA);
        });

        if (mounted) {
          setState(() {
            allMeetings = meetings;
            isLoading = false;
            isRefreshing = false;
          });
          applyFilters();
        }
      } else {
        print('DEBUG ERROR: Failed to load meetings: Status Code ${response.statusCode}, Response Body: ${response.body}');
        throw Exception('Failed to load meetings: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG ERROR: Error fetching meetings: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });
        showErrorMessage('Failed to load meetings: ${e.toString()}');
      }
    }
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  void onSearchChanged(String value) {
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          searchQuery = value.toLowerCase();
        });
        applyFilters();
        print('DEBUG: Search query updated: $searchQuery');
      }
    });
  }

  void applyFilters() {
    if (!mounted) return;

    List<Meeting> filtered = List.from(allMeetings);

    if (selectedFilter != 'All') {
      DateTime now = DateTime.now();
      switch (selectedFilter) {
        case 'Today':
          filtered = filtered.where((meeting) {
            DateTime meetingDate = DateTime.parse(meeting.date);
            return isSameDay(meetingDate, now);
          }).toList();
          break;
        case 'Last Week':
          DateTime weekAgo = now.subtract(const Duration(days: 7));
          filtered = filtered.where((meeting) {
            DateTime createdAt = DateTime.parse(meeting.createdAt);
            return createdAt.isAfter(weekAgo);
          }).toList();
          break;
        case 'Last Month':
          DateTime monthAgo = now.subtract(const Duration(days: 30));
          filtered = filtered.where((meeting) {
            DateTime createdAt = DateTime.parse(meeting.createdAt);
            return createdAt.isAfter(monthAgo);
          }).toList();
          break;
        case 'Last Year':
          DateTime yearAgo = now.subtract(const Duration(days: 365));
          filtered = filtered.where((meeting) {
            DateTime createdAt = DateTime.parse(meeting.createdAt);
            return createdAt.isAfter(yearAgo);
          }).toList();
          break;
      }
      print('DEBUG: Applied filter: $selectedFilter, ${filtered.length} meetings found');
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((meeting) {
        return meeting.place.toLowerCase().contains(searchQuery) ||
            meeting.groupLocation.toLowerCase().contains(searchQuery) ||
            meeting.meetingCategory.toLowerCase().contains(searchQuery) ||
            (meeting.group?.name.toLowerCase().contains(searchQuery) ?? false);
      }).toList();
      print('DEBUG: Applied search query: $searchQuery, ${filtered.length} meetings found');
    }

    if (mounted) {
      setState(() {
        filteredMeetings = filtered;
      });
    }
  }

  void showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.black,
          duration: const Duration(seconds: 3),
        ),
      );
      print('DEBUG: Showing error message: $message');
    }
  }

  Future<void> onRefresh() async {
    setState(() {
      isRefreshing = true;
    });
    print('DEBUG: Refreshing meetings');
    await fetchMeetings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
            print('DEBUG: Navigating back from MeetingsPage');
          },
        ),
        title: const Text(
          'Meetings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey[300],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: searchController.text.isNotEmpty ? Colors.black : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search meetings...',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey[600], size: 20),
                              onPressed: () {
                                searchController.clear();
                                setState(() {
                                  searchQuery = '';
                                });
                                applyFilters();
                                print('DEBUG: Cleared search query');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    style: const TextStyle(fontSize: 15),
                    onChanged: onSearchChanged,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['All', 'Today', 'Last Week', 'Last Month', 'Last Year']
                              .map((filter) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _buildFilterChip(filter),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                        SizedBox(height: 16),
                        Text('Loading meetings...', style: TextStyle(fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                  )
                : filteredMeetings.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: Colors.black,
                        onRefresh: onRefresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredMeetings.length,
                          itemBuilder: (context, index) {
                            return MeetingCard(
                              meeting: filteredMeetings[index],
                              key: ValueKey(filteredMeetings[index].mcId),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = filter;
        });
        applyFilters();
        print('DEBUG: Selected filter: $filter');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Text(
          filter,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              allMeetings.isEmpty ? Icons.event_busy : Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              allMeetings.isEmpty ? 'No meetings found' : 'No matching meetings',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              allMeetings.isEmpty ? 'No general meetings found for your group' : 'Try adjusting your search or filters',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (allMeetings.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRefresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Refresh'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Meeting Card Widget
class MeetingCard extends StatelessWidget {
  final Meeting meeting;

  const MeetingCard({Key? key, required this.meeting}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    DateTime meetingDate = DateTime.parse(meeting.date);
    DateTime now = DateTime.now();
    bool isToday = isSameDay(meetingDate, now);
    bool isPast = meetingDate.isBefore(now) && !isToday;
    bool isUpcoming = meetingDate.isAfter(now);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingDetailsPage(meeting: meeting),
          ),
        );
        print('DEBUG: Navigating to MeetingDetailsPage for M_C_Id: ${meeting.mcId}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.black,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isToday
                    ? Colors.black
                    : isUpcoming
                        ? Colors.grey[100]
                        : Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isToday ? Colors.white : Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday ? Colors.black : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isToday
                              ? Icons.today
                              : isUpcoming
                                  ? Icons.schedule
                                  : Icons.history,
                          color: isToday ? Colors.black : Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isToday
                              ? 'TODAY'
                              : isUpcoming
                                  ? 'UPCOMING'
                                  : 'PAST',
                          style: TextStyle(
                            color: isToday ? Colors.black : Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.black,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      meeting.meetingCategory.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    formatDate(meetingDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildCompactInfoRow(
                    icon: Icons.location_on_outlined,
                    content: meeting.place,
                    subtitle: meeting.groupLocation.isNotEmpty ? meeting.groupLocation : null,
                  ),
                  const SizedBox(height: 8),
                  _buildCompactInfoRow(
                    icon: Icons.people_outline,
                    content: meeting.attendanceStatus == '1' ? 'Active' : 'Inactive',
                    isStatus: true,
                    statusActive: meeting.attendanceStatus == '1',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 0.5,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactActionButton(
                          context: context,
                          label: 'VISITOR',
                          icon: Icons.person_add_outlined,
                          isPrimary: false,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddVisitorPage(meeting: meeting),
                              ),
                            );
                            print('DEBUG: Navigating to AddVisitorPage for M_C_Id: ${meeting.mcId}');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCompactActionButton(
                          context: context,
                          label: 'PRESENTATION',
                          icon: Icons.present_to_all_outlined,
                          isPrimary: true,
                          onPressed: () {
                            _showPresentationDialog(context, meeting);
                            print('DEBUG: Opening presentation dialog for M_C_Id: ${meeting.mcId}');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactInfoRow({
    required IconData icon,
    required String content,
    String? subtitle,
    bool isStatus = false,
    bool statusActive = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[300]!, width: 0.5),
          ),
          child: Icon(icon, color: Colors.black, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isStatus) ...[
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusActive ? Colors.black : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        content,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: statusActive ? Colors.black : Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.black : Colors.white,
          foregroundColor: isPrimary ? Colors.white : Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.black, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String formatDate(DateTime date) {
    const List<String> months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    const List<String> weekdays = [
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN'
    ];
    String weekday = weekdays[date.weekday - 1];
    String month = months[date.month - 1];
    return '$weekday, ${date.day} $month ${date.year}';
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

// Meeting Details Page
class MeetingDetailsPage extends StatefulWidget {
  final Meeting meeting;

  const MeetingDetailsPage({Key? key, required this.meeting}) : super(key: key);

  @override
  State<MeetingDetailsPage> createState() => _MeetingDetailsPageState();
}

class _MeetingDetailsPageState extends State<MeetingDetailsPage> {
  List<Visitor> visitors = [];
  List<Presentation> presentations = [];
  bool isLoadingVisitors = true;
  bool isLoadingPresentations = true;
  bool hasVisitorError = false;
  bool hasPresentationError = false;

  @override
  void initState() {
    super.initState();
    fetchVisitors();
    fetchPresentations();
  }

  Future<void> fetchVisitors() async {
    try {
      print('DEBUG: Fetching visitors for M_C_Id: ${widget.meeting.mcId}');
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/visitor-invites?M_C_Id=${widget.meeting.mcId}'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('DEBUG: Visitor API Response for M_C_Id ${widget.meeting.mcId}: $data');
        List<dynamic> visitorData = data is List ? data : data['data'] ?? [];

        List<Visitor> fetchedVisitors = visitorData
            .map((item) => Visitor.fromJson(item))
            .where((visitor) => visitor.mcId == widget.meeting.mcId)
            .toList();

        fetchedVisitors.sort((a, b) => a.visitorName.toLowerCase().compareTo(b.visitorName.toLowerCase()));

        if (mounted) {
          setState(() {
            visitors = fetchedVisitors;
            isLoadingVisitors = false;
          });
          print('DEBUG: Filtered ${visitors.length} visitors for M_C_Id ${widget.meeting.mcId}');
        }
      } else {
        print('DEBUG ERROR: Failed to load visitors: Status Code ${response.statusCode}, Response Body: ${response.body}');
        throw Exception('Failed to load visitors: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG ERROR: Error fetching visitors for M_C_Id ${widget.meeting.mcId}: $e');
      if (mounted) {
        setState(() {
          isLoadingVisitors = false;
          hasVisitorError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading visitors: ${e.toString()}'),
            backgroundColor: Colors.black,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> fetchPresentations() async {
    try {
      print('DEBUG: Fetching presentations for M_C_Id: ${widget.meeting.mcId}');
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/pres-tracks?M_C_Id=${widget.meeting.mcId}'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('DEBUG: Presentation API Response for M_C_Id ${widget.meeting.mcId}: $data');
        List<dynamic> presentationData = data is List ? data : data['data'] ?? [];

        List<Presentation> fetchedPresentations = presentationData
            .map((item) => Presentation.fromJson(item))
            .where((presentation) => presentation.mcId == widget.meeting.mcId)
            .toList();

        if (mounted) {
          setState(() {
            presentations = fetchedPresentations;
            isLoadingPresentations = false;
          });
          print('DEBUG: Filtered ${presentations.length} presentations for M_C_Id ${widget.meeting.mcId}');
        }
      } else {
        print('DEBUG ERROR: Failed to load presentations: Status Code ${response.statusCode}, Response Body: ${response.body}');
        throw Exception('Failed to load presentations: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG ERROR: Error fetching presentations for M_C_Id ${widget.meeting.mcId}: $e');
      if (mounted) {
        setState(() {
          isLoadingPresentations = false;
          hasPresentationError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading presentations: ${e.toString()}'),
            backgroundColor: Colors.black,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
            print('DEBUG: Navigating back from MeetingDetailsPage for M_C_Id: ${widget.meeting.mcId}');
          },
        ),
        title: const Text(
          'Meeting Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDate(DateTime.parse(widget.meeting.date)),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.meeting.place,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              if (widget.meeting.groupLocation.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.meeting.groupLocation,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Status: ${widget.meeting.attendanceStatus == '1' ? 'Active' : 'Inactive'}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: widget.meeting.attendanceStatus == '1' ? Colors.black : Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Visitors',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              isLoadingVisitors
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : hasVisitorError
                      ? const Text(
                          'Failed to load visitors',
                          style: TextStyle(color: Colors.red),
                        )
                      : visitors.isEmpty
                          ? const Text('No visitors found')
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: visitors.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text(visitors[index].visitorName),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(visitors[index].visitorEmail),
                                      if (visitors[index].aboutVisitor.isNotEmpty)
                                        Text('About: ${visitors[index].aboutVisitor}'),
                                      if (visitors[index].visitorPhone.isNotEmpty)
                                        Text('Phone: ${visitors[index].visitorPhone}'),
                                    ],
                                  ),
                                );
                              },
                            ),
              const SizedBox(height: 16),
              const Text(
                'Presentations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              isLoadingPresentations
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : hasPresentationError
                      ? const Text(
                          'Failed to load presentations',
                          style: TextStyle(color: Colors.red),
                        )
                      : presentations.isEmpty
                          ? const Text('No presentations found')
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: presentations.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text('Member ID: ${presentations[index].memberId}'),
                                  subtitle: Text(
                                      'Status: ${presentations[index].presStatus == '0' ? 'Presenting' : 'Not Presenting'}'),
                                );
                              },
                            ),
            ],
          ),
        ),
      ),
    );
  }

  String formatDate(DateTime date) {
    const List<String> months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    const List<String> weekdays = [
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN'
    ];
    String weekday = weekdays[date.weekday - 1];
    String month = months[date.month - 1];
    return '$weekday, ${date.day} $month ${date.year}';
  }
}

// Add Visitor Page
class AddVisitorPage extends StatefulWidget {
  final Meeting meeting;

  const AddVisitorPage({Key? key, required this.meeting}) : super(key: key);

  @override
  State<AddVisitorPage> createState() => _AddVisitorPageState();
}

class _AddVisitorPageState extends State<AddVisitorPage> {
  final TextEditingController visitorNameController = TextEditingController();
  final TextEditingController visitorEmailController = TextEditingController();
  final TextEditingController aboutVisitorController = TextEditingController();
  final TextEditingController visitorPhoneController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    visitorNameController.dispose();
    visitorEmailController.dispose();
    aboutVisitorController.dispose();
    visitorPhoneController.dispose();
    super.dispose();
  }

  Future<void> addVisitor() async {
    if (visitorNameController.text.isEmpty || visitorEmailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in Visitor Name and Visitor Email fields'),
          backgroundColor: Colors.black,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      print('DEBUG: Adding visitor for M_C_Id: ${widget.meeting.mcId}');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');
      String? memberId = prefs.getString('M_ID');

      if (memberId == null || memberId.isEmpty) {
        print('DEBUG ERROR: Missing or empty M_ID in SharedPreferences for M_C_Id: ${widget.meeting.mcId}');
        try {
          final userResponse = await http.get(
            Uri.parse('https://tagai.caxis.ca/public/api/user'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 15));
          print('DEBUG: User API response - Status Code: ${userResponse.statusCode}, Body: ${userResponse.body}');
          if (userResponse.statusCode == 200) {
            final userData = json.decode(userResponse.body);
            memberId = userData['M_ID']?.toString();
            if (memberId != null && memberId.isNotEmpty) {
              await prefs.setString('M_ID', memberId);
              print('DEBUG: Refreshed M_ID from API: $memberId');
            } else {
              throw Exception('Invalid M_ID in user API response: $memberId');
            }
          } else {
            throw Exception('Failed to fetch user data: ${userResponse.statusCode} - ${userResponse.body}');
          }
        } catch (e) {
          print('DEBUG ERROR: Failed to fetch M_ID from API: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User ID is missing or invalid. Please log out and log in again.'),
                backgroundColor: Colors.black,
                duration: Duration(seconds: 5),
              ),
            );
          }
          setState(() {
            isLoading = false;
          });
          return;
        }
      }

      final now = DateTime.now().toIso8601String();
      final payload = {
        'M_C_Id': widget.meeting.mcId,
        'G_ID': widget.meeting.gId,
        'M_ID': memberId,
        'Visitor_Name': visitorNameController.text,
        'Visitor_Email': visitorEmailController.text,
        'About_Visitor': aboutVisitorController.text,
        'Visitor_Phone': visitorPhoneController.text,
        'created_at': now,
        'updated_at': now,
      };

      print('DEBUG: Visitor payload: ${json.encode(payload)}');

      final response = await http.post(
        Uri.parse('https://tagai.caxis.ca/public/api/visitor-invites'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));

      print('DEBUG: Add visitor response - Status Code: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visitor added successfully'),
              backgroundColor: Colors.black,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        print('DEBUG ERROR: Failed to add visitor: Status Code ${response.statusCode}, Response Body: ${response.body}');
        throw Exception('Failed to add visitor: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG ERROR: Error adding visitor for M_C_Id ${widget.meeting.mcId}: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding visitor: ${e.toString()}'),
            backgroundColor: Colors.black,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
            print('DEBUG: Navigating back from AddVisitorPage for M_C_Id: ${widget.meeting.mcId}');
          },
        ),
        title: const Text(
          'Add Visitor',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: visitorNameController,
                decoration: InputDecoration(
                  labelText: 'Visitor Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: visitorEmailController,
                decoration: InputDecoration(
                  labelText: 'Visitor Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: aboutVisitorController,
                decoration: InputDecoration(
                  labelText: 'About Visitor',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: visitorPhoneController,
                decoration: InputDecoration(
                  labelText: 'Visitor Phone',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isLoading ? null : addVisitor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Add Visitor',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Login Page
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.black,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      print('DEBUG: Attempting login with email: ${emailController.text}');
      final response = await http.post(
        Uri.parse('https://tagai.caxis.ca/public/api/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'email': emailController.text,
          'password': passwordController.text,
        }),
      ).timeout(const Duration(seconds: 30));

      print('DEBUG: Login response - Status Code: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String? token = data['token'];
        Map<String, dynamic> userData = data['user'] ?? {};

        if (token != null && userData.isNotEmpty) {
          await saveUserData(userData);
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          print('DEBUG: Login successful, token saved: $token, userData: $userData');

          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MeetingsPage()),
            );
          }
        } else {
          throw Exception('Invalid login response: Missing token or user data');
        }
      } else {
        print('DEBUG ERROR: Login failed: Status Code ${response.statusCode}, Response Body: ${response.body}');
        throw Exception('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG ERROR: Error during login: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: Colors.black,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Login',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Login',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}