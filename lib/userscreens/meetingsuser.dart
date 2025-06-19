import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

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
      
      // Get user data from SharedPreferences
      String? groupCode = prefs.getString('group_code');
      String? uId = prefs.getString('user_id');
      String? uName = prefs.getString('user_name');
      
      print('Found group_code: $groupCode');
      print('Found user_id: $uId');
      print('Found user_name: $uName');
      
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
      setState(() {
        isLoading = false;
      });
      print('Error loading user data: $e');
      showErrorMessage('Error loading user data');
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

      print('Fetching meetings for group_code: $userGroupCode');

      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/meeting-cals'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      print('API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        final dynamic responseData = json.decode(responseBody);
        
        List<dynamic> data = [];
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'] as List;
        } else {
          throw Exception('Invalid response format');
        }

        print('Total meetings from API: ${data.length}');

        List<Meeting> meetings = [];
        int matchedCount = 0;
        
        for (var item in data) {
          try {
            Meeting meeting = Meeting.fromJson(item as Map<String, dynamic>);
            
            // Debug first few meetings
            if (meetings.length < 3) {
              print('Meeting ${meetings.length + 1}:');
              print('  - Group Code: ${meeting.group?.gropCode}');
              print('  - Group Name: ${meeting.group?.name}');
              print('  - Place: ${meeting.place}');
              print('  - Date: ${meeting.meetingDate}');
            }
            
            // Filter by group code only (since we don't have G_ID)
            bool matchesGroupCode = meeting.group?.gropCode == userGroupCode;
            
            if (matchesGroupCode) {
              meetings.add(meeting);
              matchedCount++;
            }
          } catch (e) {
            print('Error parsing meeting: $e');
            continue;
          }
        }

        print('Matched meetings: $matchedCount');

        // Sort meetings - today's first, then by date
        meetings.sort((a, b) {
          DateTime now = DateTime.now();
          DateTime dateA = DateTime.parse(a.meetingDate);
          DateTime dateB = DateTime.parse(b.meetingDate);
          
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
        throw Exception('Failed to load meetings: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });
        print('Error fetching meetings: $e');
        showErrorMessage('Failed to load meetings: ${e.toString()}');
      }
    }
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
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

    // Apply date filter
    if (selectedFilter != 'All') {
      DateTime now = DateTime.now();
      
      switch (selectedFilter) {
        case 'Today':
          filtered = filtered.where((meeting) {
            DateTime meetingDate = DateTime.parse(meeting.meetingDate);
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

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((meeting) {
        return meeting.place.toLowerCase().contains(searchQuery) ||
               meeting.gLocation.toLowerCase().contains(searchQuery) ||
               meeting.meetCate.toLowerCase().contains(searchQuery) ||
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
          backgroundColor: Colors.red,
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Meetings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: searchController.text.isNotEmpty 
                          ? Colors.black 
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search meetings...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 18,
                                color: Colors.grey[600],
                              ),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    style: const TextStyle(fontSize: 15),
                    onChanged: onSearchChanged,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Filters Row with Results Count
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
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1F2937), Color(0xFF111827)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Meetings List
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.5,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading meetings...',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  )
                : filteredMeetings.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: Colors.black,
                        onRefresh: onRefresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected 
              ? const LinearGradient(
                  colors: [Color(0xFF1F2937), Color(0xFF111827)],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          filter,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 13,
            fontWeight: FontWeight.w500,
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
              allMeetings.isEmpty 
                  ? 'No meetings found'
                  : 'No matching meetings',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              allMeetings.isEmpty
                  ? 'No meetings found for your group'
                  : 'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (allMeetings.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRefresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
    DateTime meetingDate = DateTime.parse(meeting.meetingDate);
    DateTime now = DateTime.now();
    bool isToday = meetingDate.year == now.year &&
                   meetingDate.month == now.month &&
                   meetingDate.day == now.day;
    
    bool isPast = meetingDate.isBefore(now) && !isToday;
    bool isUpcoming = meetingDate.isAfter(now);

    // Define colors based on meeting status
    Color primaryColor = isToday 
        ? const Color(0xFF10B981) 
        : isUpcoming 
            ? const Color(0xFF3B82F6)
            : const Color(0xFF6B7280);
    
    Color lightColor = isToday 
        ? const Color(0xFFECFDF5) 
        : isUpcoming 
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFF9FAFB);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            lightColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Status Header Bar
            if (isToday || isUpcoming)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      primaryColor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isToday ? Icons.today : Icons.schedule,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isToday ? 'TODAY\'S MEETING' : 'UPCOMING MEETING',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row with Category and Status
                  Row(
                    children: [
                      // Category Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: meeting.meetCate.toLowerCase() == 'compulsory'
                                ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                : [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (meeting.meetCate.toLowerCase() == 'compulsory'
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF8B5CF6)).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          meeting.meetCate.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Status Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: meeting.attnStatus == '1' 
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: meeting.attnStatus == '1'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: meeting.attnStatus == '1' 
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              meeting.attnStatus == '1' ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 11,
                                color: meeting.attnStatus == '1' 
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF991B1B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Date Section
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, primaryColor.withOpacity(0.8)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Meeting Date',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatDate(meetingDate),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Location Section
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                meeting.place,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (meeting.gLocation.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  meeting.gLocation,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  if (meeting.group != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.group,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Group',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  meeting.group!.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  String formatDate(DateTime date) {
    const List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const List<String> weekdays = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];
    
    String weekday = weekdays[date.weekday - 1];
    String month = months[date.month - 1];
    
    return '$weekday, ${date.day} $month ${date.year}';
  }
}

// Data Models (unchanged)
class Meeting {
  final int mcId;
  final String meetingDate;
  final String place;
  final String gLocation;
  final String attnStatus;
  final String meetCate;
  final String? image;
  final String gId;
  final String? mId;
  final String createdAt;
  final String updatedAt;
  final Group? group;

  Meeting({
    required this.mcId,
    required this.meetingDate,
    required this.place,
    required this.gLocation,
    required this.attnStatus,
    required this.meetCate,
    this.image,
    required this.gId,
    this.mId,
    required this.createdAt,
    required this.updatedAt,
    this.group,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      mcId: json['M_C_Id'] ?? 0,
      meetingDate: json['Meeting_Date'] ?? '',
      place: json['Place'] ?? '',
      gLocation: json['G_Location'] ?? '',
      attnStatus: json['Attn_Status']?.toString() ?? '0',
      meetCate: json['Meet_Cate'] ?? '',
      image: json['Image'],
      gId: json['G_ID']?.toString() ?? '0',
      mId: json['M_ID']?.toString(),
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
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
      gId: json['G_ID'] ?? 0,
      name: json['name'] ?? '',
      shortGroupName: json['short_group_name'] ?? '',
      groupName: json['group_name'] ?? '',
      email: json['email'] ?? '',
      number: json['number'] ?? '',
      gropCode: json['Grop_code'] ?? '',
      panNum: json['pan_num'] ?? '',
      roleId: json['role_id']?.toString() ?? '0',
      status: json['status']?.toString() ?? '0',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}