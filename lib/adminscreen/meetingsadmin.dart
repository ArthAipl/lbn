import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MeetingsAdmin extends StatefulWidget {
  @override
  _MeetingsAdminState createState() => _MeetingsAdminState();
}

class _MeetingsAdminState extends State<MeetingsAdmin> {
  List<dynamic> _meetings = [];
  List<dynamic> _filteredMeetings = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  
  // User data from shared preferences
  String? _gId;
  String? _groupCode;
  String? _userName;
  String? _groupName;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchMeetings();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _gId = prefs.getString('G_ID') ?? '33';
      _groupCode = prefs.getString('Grop_code') ?? '572334';
      _userName = prefs.getString('name') ?? 'Shyamal Odedara';
      _groupName = prefs.getString('group_name') ?? 'tata';
    });
  }

  Future<void> _fetchMeetings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/meeting-cals'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> allMeetings = json.decode(response.body);
        
        // Filter meetings by user's group code
        List<dynamic> filteredMeetings = allMeetings.where((meeting) {
          return meeting['group'] != null && 
                 meeting['group']['Grop_code'] == _groupCode;
        }).toList();

        // Sort meetings - today's first, then by date
        filteredMeetings.sort((a, b) {
          DateTime now = DateTime.now();
          DateTime dateA = DateTime.parse(a['Meeting_Date']);
          DateTime dateB = DateTime.parse(b['Meeting_Date']);
          
          bool isAToday = _isSameDay(dateA, now);
          bool isBToday = _isSameDay(dateB, now);
          
          if (isAToday && !isBToday) return -1;
          if (!isAToday && isBToday) return 1;
          
          return dateB.compareTo(dateA);
        });
        
        setState(() {
          _meetings = filteredMeetings;
        });
        _applyFilters();
      } else {
        throw Exception('Failed to load meetings');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading meetings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  void _applyFilters() {
    List<dynamic> filtered = List.from(_meetings);

    // Apply date filter
    if (_selectedFilter != 'All') {
      DateTime now = DateTime.now();
      
      switch (_selectedFilter) {
        case 'Today':
          filtered = filtered.where((meeting) {
            DateTime meetingDate = DateTime.parse(meeting['Meeting_Date']);
            return _isSameDay(meetingDate, now);
          }).toList();
          break;
        case 'Last Week':
          DateTime weekAgo = now.subtract(const Duration(days: 7));
          filtered = filtered.where((meeting) {
            DateTime createdAt = DateTime.parse(meeting['created_at'] ?? meeting['Meeting_Date']);
            return createdAt.isAfter(weekAgo);
          }).toList();
          break;
        case 'Last Month':
          DateTime monthAgo = now.subtract(const Duration(days: 30));
          filtered = filtered.where((meeting) {
            DateTime createdAt = DateTime.parse(meeting['created_at'] ?? meeting['Meeting_Date']);
            return createdAt.isAfter(monthAgo);
          }).toList();
          break;
        case 'Last Year':
          DateTime yearAgo = now.subtract(const Duration(days: 365));
          filtered = filtered.where((meeting) {
            DateTime createdAt = DateTime.parse(meeting['created_at'] ?? meeting['Meeting_Date']);
            return createdAt.isAfter(yearAgo);
          }).toList();
          break;
      }
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((meeting) {
        return (meeting['Place']?.toLowerCase()?.contains(_searchQuery) ?? false) ||
               (meeting['G_Location']?.toLowerCase()?.contains(_searchQuery) ?? false) ||
               (meeting['Meet_Cate']?.toLowerCase()?.contains(_searchQuery) ?? false) ||
               (meeting['group']?['group_name']?.toLowerCase()?.contains(_searchQuery) ?? false);
      }).toList();
    }

    setState(() {
      _filteredMeetings = filtered;
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.toLowerCase();
    });
    _applyFilters();
  }

  void _navigateToCreateMeeting() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateMeetingPage(),
      ),
    );
    
    if (result == true) {
      _fetchMeetings(); // Refresh meetings if a new one was created
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Meetings Admin',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Create Meeting Button Section
          Container(
            width: double.infinity,
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
            child: ElevatedButton.icon(
              onPressed: _navigateToCreateMeeting,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Create New Meeting',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),

          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _searchController.text.isNotEmpty 
                          ? Colors.black 
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
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
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 18,
                                color: Colors.grey[600],
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                                _applyFilters();
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
                    onChanged: _onSearchChanged,
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
                      child: Text(
                        '${_filteredMeetings.length} found',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Meetings List
          Expanded(
            child: RefreshIndicator(
              color: Colors.black,
              onRefresh: _fetchMeetings,
              child: _isLoading
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
                  : _filteredMeetings.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredMeetings.length,
                          itemBuilder: (context, index) {
                            return _buildMeetingCard(_filteredMeetings[index]);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
        _applyFilters();
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
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                _meetings.isEmpty ? Icons.event_busy : Icons.search_off,
                size: 60,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _meetings.isEmpty ? 'No meetings yet' : 'No matching meetings',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _meetings.isEmpty
                  ? 'Create your first meeting to get started'
                  : 'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (_meetings.isEmpty) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _navigateToCreateMeeting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Create Meeting',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingCard(dynamic meeting) {
    DateTime meetingDate = DateTime.parse(meeting['Meeting_Date']);
    DateTime now = DateTime.now();
    bool isToday = _isSameDay(meetingDate, now);
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

            // Image Section
            if (meeting['Image'] != null)
              Container(
                height: 180,
                width: double.infinity,
                child: Image.network(
                  meeting['Image'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[400],
                          size: 48,
                        ),
                      ),
                    );
                  },
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
                            colors: (meeting['Meet_Cate']?.toLowerCase() == 'compulsory')
                                ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                : [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: ((meeting['Meet_Cate']?.toLowerCase() == 'compulsory')
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF8B5CF6)).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          (meeting['Meet_Cate'] ?? 'Meeting').toUpperCase(),
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
                          color: meeting['Attn_Status'] == '1' 
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: meeting['Attn_Status'] == '1'
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
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
                                color: meeting['Attn_Status'] == '1' 
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              meeting['Attn_Status'] == '1' ? 'Required' : 'Optional',
                              style: TextStyle(
                                fontSize: 11,
                                color: meeting['Attn_Status'] == '1' 
                                    ? const Color(0xFF991B1B)
                                    : const Color(0xFF065F46),
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
                                _formatDate(meetingDate),
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
                                meeting['Place'] ?? '',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((meeting['G_Location'] ?? '').isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  meeting['G_Location'] ?? '',
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
                  
                  if (meeting['group'] != null) ...[
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
                                  meeting['group']['group_name'] ?? '',
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

  String _formatDate(DateTime date) {
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class CreateMeetingPage extends StatefulWidget {
  @override
  _CreateMeetingPageState createState() => _CreateMeetingPageState();
}

class _CreateMeetingPageState extends State<CreateMeetingPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  
  String _selectedAttendanceStatus = '1';
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  
  bool _isCreating = false;
  
  // User data from shared preferences
  String? _gId;
  String? _groupCode;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _gId = prefs.getString('G_ID') ?? '33';
      _groupCode = prefs.getString('Grop_code') ?? '572334';
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
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
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Select Image',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildImageOption(
                    Icons.camera_alt,
                    'Camera',
                    () => _getImage(ImageSource.camera),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildImageOption(
                    Icons.photo_library,
                    'Gallery',
                    () => _getImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.black),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    Navigator.pop(context);
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://tagai.caxis.ca/public/api/upload-image'),
      );
      
      request.files.add(
        await http.MultipartFile.fromPath('image', image.path),
      );
      
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonData = json.decode(responseData);
        return jsonData['image_url'];
      }
    } catch (e) {
      print('Image upload error: $e');
    }
    return null;
  }

  Future<void> _createMeeting() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!);
      }

      final Map<String, dynamic> meetingData = {
        'Meeting_Date': _dateController.text,
        'Place': _placeController.text,
        'G_Location': _locationController.text,
        'Attn_Status': _selectedAttendanceStatus,
        'Meet_Cate': _categoryController.text,
        'G_ID': _gId,
        'Grop_code': _groupCode,
        if (imageUrl != null) 'Image': imageUrl,
      };

      final response = await http.post(
        Uri.parse('https://tagai.caxis.ca/public/api/meeting-cals'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(meetingData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Meeting created successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        throw Exception('Failed to create meeting: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error creating meeting: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Create Meeting',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meeting Date
                _buildFormField(
                  controller: _dateController,
                  label: 'Meeting Date',
                  icon: Icons.calendar_today,
                  readOnly: true,
                  onTap: _selectDate,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a meeting date';
                    }
                    return null;
                  },
                ),
                
                SizedBox(height: 20),
                
                // Place
                _buildFormField(
                  controller: _placeController,
                  label: 'Place',
                  icon: Icons.place,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the place';
                    }
                    return null;
                  },
                ),
                
                SizedBox(height: 20),
                
                // Location
                _buildFormField(
                  controller: _locationController,
                  label: 'Location Details',
                  icon: Icons.location_on,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter location details';
                    }
                    return null;
                  },
                ),
                
                SizedBox(height: 20),
                
                // Meeting Category
                _buildFormField(
                  controller: _categoryController,
                  label: 'Meeting Category',
                  icon: Icons.category,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter meeting category';
                    }
                    return null;
                  },
                ),
                
                SizedBox(height: 20),
                
                // Attendance Status
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedAttendanceStatus,
                    decoration: InputDecoration(
                      labelText: 'Attendance Status',
                      prefixIcon: Container(
                        margin: EdgeInsets.all(12),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.people,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '1',
                        child: Text('Required'),
                      ),
                      DropdownMenuItem(
                        value: '0',
                        child: Text('Optional'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedAttendanceStatus = value!;
                      });
                    },
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Image Selection
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            margin: EdgeInsets.only(right: 12),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.image,
                              size: 20,
                              color: Colors.grey[600],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _selectedImage != null 
                                  ? 'Image selected' 
                                  : 'Select Meeting Image',
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedImage != null 
                                    ? Colors.green[700] 
                                    : Colors.grey[600],
                                fontWeight: _selectedImage != null 
                                    ? FontWeight.w500 
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                if (_selectedImage != null) ...[
                  SizedBox(height: 20),
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImage = null;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                
                SizedBox(height: 40),
                
                // Create Button
                Container(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createMeeting,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isCreating
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Create Meeting',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
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

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Container(
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.grey[600],
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _placeController.dispose();
    _locationController.dispose();
    _categoryController.dispose();
    super.dispose();
  }
}