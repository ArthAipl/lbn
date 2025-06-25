import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

Future<void> _showPresentationDialog(BuildContext context, Meeting meeting) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // User must tap a button to close
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
              Navigator.of(dialogContext).pop(); // Close dialog
              _submitPresentationStatus(context, meeting, '1'); // Pres_Status = 1 for No
            },
          ),
          TextButton(
            child: const Text(
              'Yes',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Close dialog
              _submitPresentationStatus(context, meeting, '0'); // Pres_Status = 0 for Yes
            },
          ),
        ],
      );
    },
  );
}

Future<void> _submitPresentationStatus(BuildContext context, Meeting meeting, String presStatus) async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id'); // M_ID

    if (userId == null) {
      throw Exception('Missing user_id in SharedPreferences');
    }

    // Format current timestamp for created_at and updated_at
    final now = DateTime.now().toIso8601String();
    final payload = {
      'M_C_Id': meeting.mcId.toString(),
      'G_ID': meeting.gId,
      'M_ID': userId,
      'Pres_Status': presStatus,
      'created_at': now,
      'updated_at': now,
    };

    // Log the payload for debugging
    print('Submitting presentation status with payload: ${json.encode(payload)}');

    final response = await http.post(
      Uri.parse('https://tagai.caxis.ca/public/api/pres-tracks'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 30));

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
      print('Presentation status updated successfully: Status Code ${response.statusCode}');
    } else {
      // Log error details
      print('Failed to update presentation status: Status Code ${response.statusCode}');
      print('Response Body: ${response.body}');
      throw Exception('Failed to update presentation status: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    // Log exception details
    print('Error updating presentation status: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating presentation status: ${e.toString()}'),
          backgroundColor: Colors.black,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

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
  String userGroupCode = '';
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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? groupCode = prefs.getString('group_code');
      String? uId = prefs.getString('user_id');
      String? uName = prefs.getString('user_name');

      if (groupCode != null && groupCode.isNotEmpty) {
        setState(() {
          userGroupCode = groupCode;
          userId = uId ?? '';
          userName = uName ?? '';
        });
        await fetchMeetings();
      } else {
        setState(() {
          isLoading = false;
        });
        showErrorMessage('Group code not found. Please login again.');
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
      showErrorMessage('Error loading user data: ${e.toString()}');
    }
  }

  Future<void> fetchMeetings() async {
    if (!mounted) return;

    try {
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
        List<dynamic> data = responseData is List ? responseData : responseData['data'] ?? [];

        List<Meeting> meetings = [];
        for (var item in data) {
          Meeting meeting = Meeting.fromJson(item as Map<String, dynamic>);
          if (meeting.group?.gropCode == userGroupCode) {
            meetings.add(meeting);
          }
        }

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
        print('Failed to load meetings: Status Code ${response.statusCode}, Response Body: ${response.body}');
        throw Exception('Failed to load meetings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching meetings: $e');
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
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((meeting) {
        return meeting.place.toLowerCase().contains(searchQuery) ||
            meeting.groupLocation.toLowerCase().contains(searchQuery) ||
            meeting.meetingCategory.toLowerCase().contains(searchQuery) ||
            (meeting.group?.name.toLowerCase().contains(searchQuery) ?? false);
      }).toList();
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
    }
  }

  Future<void> onRefresh() async {
    setState(() {
      isRefreshing = true;
    });
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
            Navigator.pop(context); // Go back when pressed
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
              allMeetings.isEmpty ? 'No meetings found for your group' : 'Try adjusting your search or filters',
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

class MeetingCard extends StatelessWidget {
  final Meeting meeting;

  const MeetingCard({Key? key, required this.meeting}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    DateTime meetingDate = DateTime.parse(meeting.date);
    DateTime now = DateTime.now();
    bool isToday = meetingDate.year == now.year && meetingDate.month == now.month && meetingDate.day == now.day;
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
            // Compact Header Section
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
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isToday 
                          ? Colors.white 
                          : Colors.black,
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
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: meeting.meetingCategory.toLowerCase() == 'compulsory'
                          ? Colors.black
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.black,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      meeting.meetingCategory.toUpperCase(),
                      style: TextStyle(
                        color: meeting.meetingCategory.toLowerCase() == 'compulsory'
                            ? Colors.white
                            : Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Compact Content Section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Date Display
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
                  
                  // Location Info
                  _buildCompactInfoRow(
                    icon: Icons.location_on_outlined,
                    content: meeting.place,
                    subtitle: meeting.groupLocation.isNotEmpty ? meeting.groupLocation : null,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Attendance Status
                  _buildCompactInfoRow(
                    icon: Icons.people_outline,
                    content: meeting.attendanceStatus == '1' ? 'Active' : 'Inactive',
                    isStatus: true,
                    statusActive: meeting.attendanceStatus == '1',
                  ),
                  
                  // Compact Action Buttons for Today/Upcoming meetings
                  if (isToday || isUpcoming) ...[
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
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactActionButton(
                            context: context,
                            label: 'PRESENT',
                            icon: Icons.present_to_all_outlined,
                            isPrimary: true,
                            onPressed: () {
                              _showPresentationDialog(context, meeting);
                            },
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
                  maxLines: 1,
                ),
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
}

String formatDate(DateTime date) {
  const List<String> months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  const List<String> weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  String weekday = weekdays[date.weekday - 1];
  String month = months[date.month - 1];
  return '$weekday, ${date.day} $month ${date.year}';
}

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
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/visitor-invites?M_C_Id=${widget.meeting.mcId}'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> visitorData = data is List ? data : data['data'] ?? [];

        print('Visitor API Response for M_C_Id ${widget.meeting.mcId}: $visitorData');

        List<Visitor> fetchedVisitors = visitorData
            .map((item) => Visitor.fromJson(item))
            .where((visitor) => visitor.mcId == widget.meeting.mcId)
            .toList();

        fetchedVisitors.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (mounted) {
          setState(() {
            visitors = fetchedVisitors;
            isLoadingVisitors = false;
          });
        }

        print('Filtered Visitors for M_C_Id ${widget.meeting.mcId}: ${visitors.length}');
      } else {
        print('Failed to load visitors: Status Code ${response.statusCode}, Response Body: ${response.body}');
        throw Exception('Failed to load visitors: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching visitors for M_C_Id ${widget.meeting.mcId}: $e');
      if (mounted) {
        setState(() {
          isLoadingVisitors = false;
          hasVisitorError = true;
        });
      }
    }
  }

  Future<void> fetchPresentations() async {
    try {
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/pres-tracks?M_C_Id=${widget.meeting.mcId}'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> presentationData = data is List ? data : data['data'] ?? [];

        print('Presentation API Response for M_C_Id ${widget.meeting.mcId}: $presentationData');

        List<Presentation> fetchedPresentations = presentationData
            .map((item) => Presentation.fromJson(item as Map<String, dynamic>))
            .where((presentation) => presentation.mcId == widget.meeting.mcId)
            .toList();

        fetchedPresentations.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (mounted) {
          setState(() {
            presentations = fetchedPresentations;
            isLoadingPresentations = false;
          });
        }

        print('Filtered Presentations for M_C_Id ${widget.meeting.mcId}: ${presentations.length}');
      } else {
        print('Failed to load presentations: Status Code ${response.statusCode}, Response Body: ${response.body}');
        throw Exception('Failed to load presentations: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching presentations for M_C_Id ${widget.meeting.mcId}: $e');
      if (mounted) {
        setState(() {
          isLoadingPresentations = false;
          hasPresentationError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime meetingDate = DateTime.parse(widget.meeting.date);
    bool isToday = meetingDate.year == DateTime.now().year &&
        meetingDate.month == DateTime.now().month &&
        meetingDate.day == DateTime.now().day;
    bool isUpcoming = meetingDate.isAfter(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey[300],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MEETING INFORMATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'DATE',
                    value: formatDate(meetingDate),
                  ),
                  const SizedBox(height: 14),
                  _buildDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'LOCATION',
                    value: '${widget.meeting.place}${widget.meeting.groupLocation.isNotEmpty ? '\n${widget.meeting.groupLocation}' : ''}',
                  ),
                  const SizedBox(height: 14),
                  _buildDetailRow(
                    icon: Icons.category_outlined,
                    label: 'CATEGORY',
                    value: widget.meeting.meetingCategory.toUpperCase(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'VISITORS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            isLoadingVisitors
                ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                : hasVisitorError
                    ? Center(
                        child: Column(
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            const Text(
                              'Failed to load visitors',
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          ],
                        ),
                      )
                    : visitors.isEmpty
                        ? const Center(
                            child: Text(
                              'No visitors registered for this meeting',
                              style: TextStyle(fontSize: 14, color: Colors.black54),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: visitors.length,
                            itemBuilder: (context, index) {
                              return _buildVisitorCard(visitors[index]);
                            },
                          ),
            const SizedBox(height: 24),
            const Text(
              'PRESENTATIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            isLoadingPresentations
                ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                : hasPresentationError
                    ? Center(
                        child: Column(
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            const Text(
                              'Failed to load presentations',
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          ],
                        ),
                      )
                    : presentations.isEmpty
                        ? const Center(
                            child: Text(
                              'No presentations registered for this meeting',
                              style: TextStyle(fontSize: 14, color: Colors.black54),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: presentations.length,
                            itemBuilder: (context, index) {
                              return _buildPresentationCard(presentations[index]);
                            },
                          ),
            if (isToday || isUpcoming) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddVisitorPage(meeting: widget.meeting),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Colors.black, width: 1.5),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add_outlined, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'ADD VISITOR',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          _showPresentationDialog(context, widget.meeting);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.present_to_all_outlined, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'PRESENTATION',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!, width: 0.5),
          ),
          child: Icon(icon, color: Colors.black, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVisitorCard(Visitor visitor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  visitor.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            visitor.about,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.email_outlined, color: Colors.grey[600], size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  visitor.email,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.phone_outlined, color: Colors.grey[600], size: 14),
              const SizedBox(width: 6),
              Text(
                visitor.phone,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresentationCard(Presentation presentation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.present_to_all, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  presentation.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.email_outlined, color: Colors.grey[600], size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  presentation.email,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.phone_outlined, color: Colors.grey[600], size: 14),
              const SizedBox(width: 6),
              Text(
                presentation.number,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AddVisitorPage extends StatefulWidget {
  final Meeting meeting;

  const AddVisitorPage({Key? key, required this.meeting}) : super(key: key);

  @override
  State<AddVisitorPage> createState() => _AddVisitorPageState();
}

class _AddVisitorPageState extends State<AddVisitorPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> submitVisitor() async {
    if (_nameController.text.isEmpty ||
        _aboutController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty) {
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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? groupCode = prefs.getString('group_code');
      String? userId = prefs.getString('user_id');

      if (groupCode == null || userId == null) {
        throw Exception('Missing group_code or user_id');
      }

      final payload = {
        'Visitor_Name': _nameController.text.trim(),
        'About_Visitor': _aboutController.text.trim(),
        'Visitor_Email': _emailController.text.trim(),
        'Visitor_Phone': _phoneController.text.trim(),
        'M_C_Id': widget.meeting.mcId,
        'G_ID': widget.meeting.gId,
        'M_ID': userId,
      };

      print('Submitting visitor with payload: ${json.encode(payload)}');

      final response = await http.post(
        Uri.parse('https://tagai.caxis.ca/public/api/visitor-invites'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visitor added successfully'),
              backgroundColor: Colors.black,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pop(context);
        }
        print('Visitor added successfully: Status Code ${response.statusCode}');
      } else {
        print('Failed to add visitor: Status Code ${response.statusCode}, Response Body: ${response.body}');
        throw Exception('Failed to add visitor: ${response.statusCode}');
      }
    } catch (e) {
      print('Error adding visitor: $e');
      if (mounted) {
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey[300],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'VISITOR DETAILS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _nameController,
              label: 'VISITOR NAME',
              hint: 'Enter visitor name',
              icon: Icons.person_outlined,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _aboutController,
              label: 'ABOUT VISITOR',
              hint: 'Enter details about the visitor',
              icon: Icons.info_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _emailController,
              label: 'VISITOR EMAIL',
              hint: 'Enter visitor email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _phoneController,
              label: 'VISITOR PHONE',
              hint: 'Enter visitor phone number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : submitVisitor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'SUBMIT',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: controller.text.isNotEmpty ? Colors.black : Colors.grey[300]!,
          width: controller.text.isNotEmpty ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: Colors.grey[600], size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),
        onChanged: (value) => setState(() {}),
      ),
    );
  }
}

// Keep all your existing model classes unchanged
class Visitor {
  final String name;
  final String about;
  final String email;
  final String phone;
  final int? mcId;

  Visitor({
    required this.name,
    required this.about,
    required this.email,
    required this.phone,
    this.mcId,
  });

  factory Visitor.fromJson(Map<String, dynamic> json) {
    return Visitor(
      name: json['Visitor_Name']?.toString() ?? '',
      about: json['About_Visitor']?.toString() ?? '',
      email: json['Visitor_Email']?.toString() ?? '',
      phone: json['Visitor_Phone']?.toString() ?? '',
      mcId: json['M_C_Id'] != null ? int.tryParse(json['M_C_Id'].toString()) : null,
    );
  }
}

class Presentation {
  final int presTrackId;
  final int? mcId;
  final String? mId;
  final String name;
  final String email;
  final String number;

  Presentation({
    required this.presTrackId,
    this.mcId,
    this.mId,
    required this.name,
    required this.email,
    required this.number,
  });

  factory Presentation.fromJson(Map<String, dynamic> json) {
    return Presentation(
      presTrackId: json['pres_track_id'] != null ? int.parse(json['pres_track_id'].toString()) : 0,
      mcId: json['M_C_Id'] != null ? int.tryParse(json['M_C_Id'].toString()) : null,
      mId: json['M_ID']?.toString(),
      name: json['member'] != null ? json['member']['Name']?.toString() ?? 'Unknown' : 'Unknown',
      email: json['member'] != null ? json['member']['email']?.toString() ?? '' : '',
      number: json['member'] != null ? json['member']['number']?.toString() ?? '' : '',
    );
  }
}

class Meeting {
  final int mcId;
  final String date;
  final String place;
  final String groupLocation;
  final String attendanceStatus;
  final String meetingCategory;
  final String? image;
  final String gId;
  final String? mId;
  final String createdAt;
  final String updatedAt;
  final Group? group;

  Meeting({
    required this.mcId,
    required this.date,
    required this.place,
    required this.groupLocation,
    required this.attendanceStatus,
    required this.meetingCategory,
    this.image,
    required this.gId,
    this.mId,
    required this.createdAt,
    required this.updatedAt,
    this.group,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      mcId: json['M_C_Id'] != null ? int.parse(json['M_C_Id'].toString()) : 0,
      date: json['Meeting_Date']?.toString() ?? '',
      place: json['Place']?.toString() ?? '',
      groupLocation: json['G_Location']?.toString() ?? '',
      attendanceStatus: json['Attn_Status']?.toString() ?? '0',
      meetingCategory: json['Meet_Cate']?.toString() ?? '',
      image: json['Image']?.toString(),
      gId: json['G_ID']?.toString() ?? '0',
      mId: json['M_ID']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      group: json['group'] != null ? Group.fromJson(json['group']) : null,
    );
  }
}

class Group {
  final int gId;
  final String name;
  final String shortGroupName;
  final String groupName;
  final String email;
  final String number;
  final String gropCode;
  final String panNum;
  final String roleId;
  final String status;
  final String createdAt;
  final String updatedAt;

  Group({
    required this.gId,
    required this.name,
    required this.shortGroupName,
    required this.groupName,
    required this.email,
    required this.number,
    required this.gropCode,
    required this.panNum,
    required this.roleId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      gId: json['G_ID'] != null ? int.parse(json['G_ID'].toString()) : 0,
      name: json['name']?.toString() ?? '',
      shortGroupName: json['short_group_name']?.toString() ?? '',
      groupName: json['group_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      gropCode: json['Grop_code']?.toString() ?? '',
      panNum: json['pan_num']?.toString() ?? '',
      roleId: json['role_id']?.toString() ?? '0',
      status: json['status']?.toString() ?? '0',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}