import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

// Models
class Meeting {
  final String circleId;
  final String? place;
  final String? date;
  final String? time;
  final String status;
  final String gId;
  final String fromMId;
  final List<ToMember>? toMId;
  final FromMember? fromMember;
  final List<ToMember>? toMembers;
  final List<String>? images;

  Meeting({
    required this.circleId,
    this.place,
    this.date,
    this.time,
    required this.status,
    required this.gId,
    required this.fromMId,
    this.toMId,
    this.fromMember,
    this.toMembers,
    this.images,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      circleId: json['Circle_ID']?.toString() ?? json['id']?.toString() ?? '',
      place: json['place'],
      date: json['date'],
      time: json['time'],
      status: json['Status']?.toString() ?? json['status']?.toString() ?? '0',
      gId: json['G_ID']?.toString() ?? json['g_id']?.toString() ?? '',
      fromMId: json['From_M_ID']?.toString() ?? json['from_m_id']?.toString() ?? '',
      toMId: json['To_M_ID'] != null
          ? (json['To_M_ID'] as List)
              .map((e) => ToMember.fromJson(e))
              .toList()
          : null,
      fromMember: json['from_member'] != null
          ? FromMember.fromJson(json['from_member'])
          : null,
      toMembers: json['toMembers'] != null
          ? (json['toMembers'] as List)
              .map((e) => ToMember.fromJson(e))
              .toList()
          : null,
      images: json['images'] != null
          ? List<String>.from(json['images'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'place': place,
      'date': date,
      'time': time,
      'Status': status,
      'G_ID': gId,
      'From_M_ID': fromMId,
      'To_M_ID': toMId?.map((e) => e.toJson()).toList(),
      if (images != null) 'images': images,
    };
  }
}

class ToMember {
  final String id;
  final String mId;
  final String? name;
  final String? email;
  final int cirlMtStatus;

  ToMember({
    required this.id,
    required this.mId,
    this.name,
    this.email,
    required this.cirlMtStatus,
  });

  factory ToMember.fromJson(Map<String, dynamic> json) {
    return ToMember(
      id: json['id']?.toString() ?? json['M_ID']?.toString() ?? '',
      mId: json['M_ID']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Name'] ?? json['name'],
      email: json['email'],
      cirlMtStatus: json['cirl_mt_status'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'M_ID': mId,
      'name': name,
      'email': email,
      'cirl_mt_status': cirlMtStatus,
    };
  }
}

class FromMember {
  final String? name;
  final String? email;

  FromMember({this.name, this.email});

  factory FromMember.fromJson(Map<String, dynamic> json) {
    return FromMember(
      name: json['Name'] ?? json['name'],
      email: json['email'],
    );
  }
}

class Member {
  final String mId;
  final String? name;
  final String? email;
  final String? number;
  final String? gropCode;
  final String status;
  final String gId;

  Member({
    required this.mId,
    this.name,
    this.email,
    this.number,
    this.gropCode,
    required this.status,
    required this.gId,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      mId: json['M_ID']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Name'] ?? json['name'],
      email: json['email'],
      number: json['number'],
      gropCode: json['Grop_code'] ?? json['group_code'],
      status: json['status']?.toString() ?? '0',
      gId: json['G_ID']?.toString() ?? json['g_id']?.toString() ?? '',
    );
  }
}

// Services
class SharedPreferencesService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Updated to use member_id as the key
  static String get memberId => _prefs?.getString('member_id') ?? '';
  static String get userName => _prefs?.getString('user_name') ?? '';
  static String get userPhone => _prefs?.getString('user_phone') ?? '';
  static String get userEmail => _prefs?.getString('user_email') ?? '';
  static int get userRole => _prefs?.getInt('user_role') ?? 0;
  static String get groupCode => _prefs?.getString('group_code') ?? '';
  static String get groupId => _prefs?.getString('group_id') ?? '';

  static Future<void> saveUserData({
    required String memberId,
    required String userName,
    required String userPhone,
    required String userEmail,
    required int userRole,
    required String groupCode,
    String? groupId,
  }) async {
    await _prefs?.setString('member_id', memberId);
    await _prefs?.setString('user_name', userName);
    await _prefs?.setString('user_phone', userPhone);
    await _prefs?.setString('user_email', userEmail);
    await _prefs?.setInt('user_role', userRole);
    await _prefs?.setString('group_code', groupCode);
    if (groupId != null) {
      await _prefs?.setString('group_id', groupId);
    }
  }

  static Future<void> clearUserData() async {
    await _prefs?.clear();
  }
}

class ApiService {
  static const String baseUrl = 'https://tagai.caxis.ca/public/api';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<List<Meeting>> fetchMeetings() async {
    try {
      print('Fetching meetings from: $baseUrl/circle-meetings');
      
      final response = await http.get(
        Uri.parse('$baseUrl/circle-meetings'),
        headers: _headers,
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final meetingsData = data['meetings'] ?? data['data'] ?? data;

        if (meetingsData is List) {
          return meetingsData.map((json) => Meeting.fromJson(json)).toList();
        }
      }
      throw Exception('Failed to fetch meetings: ${response.statusCode}');
    } catch (e) {
      print('Error fetching meetings: $e');
      throw Exception('Error fetching meetings: $e');
    }
  }

  static Future<List<Member>> fetchMembers() async {
    try {
      print('Fetching members from: $baseUrl/member');
      
      final response = await http.get(
        Uri.parse('$baseUrl/member'),
        headers: _headers,
      );

      print('Members response status: ${response.statusCode}');
      print('Members response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['members'] is List) {
          return (data['members'] as List)
              .map((json) => Member.fromJson(json))
              .toList();
        } else if (data is List) {
          return data.map((json) => Member.fromJson(json)).toList();
        }
      }
      throw Exception('Failed to fetch members: ${response.statusCode}');
    } catch (e) {
      print('Error fetching members: $e');
      throw Exception('Error fetching members: $e');
    }
  }

  static Future<bool> updateMeetingResponse(String meetingId, String memberId, int status) async {
    try {
      final payload = {
        'To_M_ID': [
          {
            'id': memberId,
            'cirl_mt_status': status,
          }
        ]
      };

      print('Updating meeting response: $meetingId');
      print('Payload: ${json.encode(payload)}');

      final response = await http.put(
        Uri.parse('$baseUrl/circle-meetings/$meetingId'),
        headers: _headers,
        body: json.encode(payload),
      );

      print('Update response status: ${response.statusCode}');
      print('Update response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating meeting response: $e');
      throw Exception('Error updating meeting response: $e');
    }
  }

  static Future<bool> markMeetingCompleted(String meetingId, {String? imageUrl}) async {
    try {
      final payload = {
        'Status': '1',
        if (imageUrl != null) 'images': [imageUrl],
      };

      print('Marking meeting completed: $meetingId');
      print('Payload: ${json.encode(payload)}');

      final response = await http.put(
        Uri.parse('$baseUrl/circle-meetings/$meetingId'),
        headers: _headers,
        body: json.encode(payload),
      );

      print('Complete response status: ${response.statusCode}');
      print('Complete response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('Error marking meeting as completed: $e');
      throw Exception('Error marking meeting as completed: $e');
    }
  }

  static Future<String?> uploadImage(File imageFile) async {
    try {
      print('Uploading image: ${imageFile.path}');
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-image'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final response = await request.send();
      print('Upload response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        print('Upload response data: $responseData');
        final data = json.decode(responseData);
        return data['imageUrl'] ?? data['url'] ?? data['image_url'];
      }
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Error uploading image: $e');
    }
  }

  static Future<bool> createMeeting({
    required String place,
    required String date,
    required String time,
    required String gId,
    required String fromMId,
    required List<String> toMemberIds,
  }) async {
    try {
      final payload = {
        'place': place,
        'date': date,
        'time': time,
        'Status': '0',
        'G_ID': gId,
        'From_M_ID': fromMId,
        'To_M_ID': toMemberIds,
      };

      print('Creating meeting...');
      print('URL: $baseUrl/circle-meetings');
      print('Headers: $_headers');
      print('Payload: ${json.encode(payload)}');
      print('Current member ID: $fromMId');
      print('Group ID: $gId');

      final response = await http.post(
        Uri.parse('$baseUrl/circle-meetings'),
        headers: _headers,
        body: json.encode(payload),
      );

      print('Create meeting response status: ${response.statusCode}');
      print('Create meeting response body: ${response.body}');
      print('Create meeting response headers: ${response.headers}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print('Failed to create meeting. Status: ${response.statusCode}');
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create meeting');
      }
    } catch (e) {
      print('Error creating meeting: $e');
      throw Exception('Error creating meeting: $e');
    }
  }
}

// Main Screen
class CircleMeetingScreen extends StatefulWidget {
  const CircleMeetingScreen({super.key});

  @override
  State<CircleMeetingScreen> createState() => _CircleMeetingScreenState();
}

class _CircleMeetingScreenState extends State<CircleMeetingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Meeting> meetings = [];
  List<Member> members = [];
  bool isLoading = true;
  String? error;

  final List<String> tabLabels = [
    'All',
    'Pending',
    'Sent',
    'Scheduled',
    'Rejected',
    'Completed'
  ];

  final List<IconData> tabIcons = [
    Icons.calendar_month,
    Icons.access_time,
    Icons.upload,
    Icons.check_circle,
    Icons.cancel,
    Icons.task_alt,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    await SharedPreferencesService.init();
    print('Current member ID: ${SharedPreferencesService.memberId}');
    print('Current group ID: ${SharedPreferencesService.groupId}');
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.fetchMeetings(),
        ApiService.fetchMembers(),
      ]);

      final fetchedMeetings = results[0] as List<Meeting>;
      final fetchedMembers = results[1] as List<Member>;

      setState(() {
        meetings = fetchedMeetings;
        members = fetchedMembers
            .where((member) =>
                member.status == '1' &&
                member.mId != SharedPreferencesService.memberId)
            .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  List<Meeting> _getFilteredMeetings(int tabIndex) {
    final currentMemberId = SharedPreferencesService.memberId;

    switch (tabIndex) {
      case 0: // All
        return meetings.where((meeting) =>
            meeting.fromMId == currentMemberId ||
            (meeting.toMId?.any((member) => member.id == currentMemberId) ?? false)).toList();

      case 1: // Pending
        return meetings.where((meeting) =>
            meeting.toMId?.any((member) =>
                member.id == currentMemberId && member.cirlMtStatus == 0) ?? false).toList();

      case 2: // Sent
        return meetings.where((meeting) =>
            meeting.fromMId == currentMemberId && meeting.status == '0').toList();

      case 3: // Scheduled
        return meetings.where((meeting) =>
            meeting.status == '0' &&
            (meeting.toMId?.any((member) =>
                member.id == currentMemberId && member.cirlMtStatus == 1) ?? false)).toList();

      case 4: // Rejected
        return meetings.where((meeting) =>
            meeting.toMId?.any((member) =>
                member.id == currentMemberId && member.cirlMtStatus == 2) ?? false).toList();

      case 5: // Completed
        return meetings.where((meeting) =>
            meeting.status == '1' &&
            (meeting.fromMId == currentMemberId ||
             (meeting.toMId?.any((member) => member.id == currentMemberId) ?? false))).toList();

      default:
        return [];
    }
  }

  int _getTabCount(int tabIndex) {
    return _getFilteredMeetings(tabIndex).length;
  }

  Future<void> _handleMeetingResponse(String meetingId, int status) async {
    try {
      final success = await ApiService.updateMeetingResponse(
        meetingId,
        SharedPreferencesService.memberId,
        status,
      );

      if (success) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status == 1 ? 'Meeting accepted' : 'Meeting declined'),
              backgroundColor: status == 1 ? Colors.green : Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleMarkCompleted(String meetingId, {String? imageUrl}) async {
    try {
      final success = await ApiService.markMeetingCompleted(meetingId, imageUrl: imageUrl);

      if (success) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meeting marked as completed'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateMeetingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateMeetingModal(
        members: members,
        onMeetingCreated: () async {
          Navigator.pop(context);
          await _loadData();
        },
      ),
    );
  }

  void _showMeetingDetails(Meeting meeting) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MeetingDetailsModal(meeting: meeting),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  bool _isPastMeeting(String? date, String? time) {
    if (date == null || time == null) return false;
    try {
      final meetingDateTime = DateTime.parse('$date $time');
      return meetingDateTime.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  Color _getStatusColor(int tabIndex) {
    switch (tabIndex) {
      case 1: return const Color(0xFFF59E0B); // Pending - Amber
      case 2: return const Color(0xFF3B82F6); // Sent - Blue
      case 3: return const Color(0xFF10B981); // Scheduled - Green
      case 4: return const Color(0xFFEF4444); // Rejected - Red
      case 5: return const Color(0xFF6B7280); // Completed - Gray
      default: return const Color(0xFF6366F1); // All - Indigo
    }
  }

  String _getStatusText(int tabIndex) {
    switch (tabIndex) {
      case 1: return 'Pending';
      case 2: return 'Sent';
      case 3: return 'Scheduled';
      case 4: return 'Rejected';
      case 5: return 'Completed';
      default: return 'Active';
    }
  }

  Future<void> _pickAndUploadImage(BuildContext context, String meetingId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        final imageUrl = await ApiService.uploadImage(File(pickedFile.path));
        await _handleMarkCompleted(meetingId, imageUrl: imageUrl);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Color(0xFFDC2626),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                ),
                SizedBox(height: 24),
                Text(
                  'Loading meetings...',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please wait while we fetch your data',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF14171D),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Circle Meetings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showCreateMeetingModal,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          tabs: List.generate(6, (index) {
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tabIcons[index], size: 16),
                  const SizedBox(width: 4),
                  Text(tabLabels[index]),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_getTabCount(index)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(6, (index) {
          final filteredMeetings = _getFilteredMeetings(index);

          if (filteredMeetings.isEmpty) {
            return _buildEmptyState(index);
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredMeetings.length,
              itemBuilder: (context, itemIndex) {
                final meeting = filteredMeetings[itemIndex];
                return _buildMeetingCard(meeting, index);
              },
            ),
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateMeetingModal,
        backgroundColor: const Color(0xFF14171D),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMeetingCard(Meeting meeting, int tabIndex) {
    final statusColor = _getStatusColor(tabIndex);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.place ?? 'Location not specified',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by ${meeting.fromMember?.name ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _getStatusText(tabIndex),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Meeting Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.orange.shade600),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(meeting.date),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        meeting.time ?? 'Time not specified',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.blue.shade500),
                const SizedBox(width: 8),
                Text(
                  '${meeting.toMembers?.length ?? 0} members',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showMeetingDetails(meeting),
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 16, color: Colors.blue.shade800),
                      const SizedBox(width: 4),
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          if (tabIndex == 1) // Pending
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleMeetingResponse(meeting.circleId, 1),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleMeetingResponse(meeting.circleId, 2),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Decline'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Mark as Completed Section
          if (tabIndex == 3 && _isPastMeeting(meeting.date, meeting.time) && meeting.status == '0')
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade50, Colors.orange.shade50],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.amber.shade600, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Meeting completed - Mark as done',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickAndUploadImage(context, meeting.circleId),
                          icon: const Icon(Icons.upload, size: 16),
                          label: const Text('Upload Photo & Complete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _handleMarkCompleted(meeting.circleId),
                          icon: const Icon(Icons.skip_next, size: 16),
                          label: const Text('Complete Without Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B7280),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Sent Meeting Responses
          if (tabIndex == 2 && meeting.toMembers != null && meeting.toMembers!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Responses:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...meeting.toMembers!.take(3).map((member) {
                    Color statusColor;
                    String statusText;

                    switch (member.cirlMtStatus) {
                      case 1:
                        statusColor = Colors.green;
                        statusText = 'Accepted';
                        break;
                      case 2:
                        statusColor = Colors.red;
                        statusText = 'Declined';
                        break;
                      default:
                        statusColor = Colors.grey;
                        statusText = 'Pending';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blue.shade500,
                            child: Text(
                              (member.name?.isNotEmpty == true)
                                  ? member.name![0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              member.name ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

          // Completed Meeting Images
          if (tabIndex == 5 && meeting.images != null && meeting.images!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meeting Photos:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: meeting.images!.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              meeting.images![index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(int tabIndex) {
    final emptyStates = [
      {'icon': Icons.calendar_month, 'title': 'No meetings scheduled', 'subtitle': 'You don\'t have any meetings yet. Create your first meeting to get started.', 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.access_time, 'title': 'No pending meetings', 'subtitle': 'You\'re all caught up!', 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.upload, 'title': 'No sent meetings', 'subtitle': 'Create a meeting to get started', 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.check_circle, 'title': 'No scheduled meetings', 'subtitle': 'Your accepted meetings will appear here', 'color': const Color(0xFF10B981)},
      {'icon': Icons.cancel, 'title': 'No rejected meetings', 'subtitle': 'Declined meetings will appear here', 'color': const Color(0xFFEF4444)},
      {'icon': Icons.task_alt, 'title': 'No completed meetings', 'subtitle': 'Your meeting history will appear here', 'color': const Color(0xFF6B7280)},
    ];

    final state = emptyStates[tabIndex];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (state['color'] as Color).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                state['icon'] as IconData,
                color: state['color'] as Color,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              state['title'] as String,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state['subtitle'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// Create Meeting Modal
class CreateMeetingModal extends StatefulWidget {
  final List<Member> members;
  final VoidCallback onMeetingCreated;

  const CreateMeetingModal({
    super.key,
    required this.members,
    required this.onMeetingCreated,
  });

  @override
  State<CreateMeetingModal> createState() => _CreateMeetingModalState();
}

class _CreateMeetingModalState extends State<CreateMeetingModal> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _placeController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  List<String> _selectedMembers = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _placeController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      _dateController.text = date.toIso8601String().split('T')[0];
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      _timeController.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
    }
  }

  Future<void> _createMeeting() async {
    if (_placeController.text.isEmpty ||
        _dateController.text.isEmpty ||
        _timeController.text.isEmpty ||
        _selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields and select at least one member'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentMemberId = SharedPreferencesService.memberId;
      final groupId = SharedPreferencesService.groupId;
      
      print('Creating meeting with:');
      print('Member ID: $currentMemberId');
      print('Group ID: $groupId');
      print('Selected members: $_selectedMembers');

      final success = await ApiService.createMeeting(
        place: _placeController.text.trim(),
        date: _dateController.text,
        time: _timeController.text,
        gId: groupId.isNotEmpty ? groupId : currentMemberId, // Use group_id if available, otherwise member_id
        fromMId: currentMemberId,
        toMemberIds: _selectedMembers,
      );

      if (success) {
        widget.onMeetingCreated();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meeting created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create meeting. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (_currentPage == 1)
                  IconButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentPage == 0 ? 'Select Members' : 'Meeting Details',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        _currentPage == 0
                            ? 'Choose who to invite to the meeting'
                            : 'Set the meeting location, date and time',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                // Member Selection Page
                _buildMemberSelectionPage(),

                // Meeting Details Page
                _buildMeetingDetailsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSelectionPage() {
    if (widget.members.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Color(0xFF6B7280),
              ),
              SizedBox(height: 16),
              Text(
                'No members available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'There are no other members in your group to invite.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.members.length,
            itemBuilder: (context, index) {
              final member = widget.members[index];
              final isSelected = _selectedMembers.contains(member.mId);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? const Color(0xFF3B82F6) : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.05) : Colors.white,
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedMembers.add(member.mId);
                      } else {
                        _selectedMembers.remove(member.mId);
                      }
                    });
                  },
                  title: Text(
                    member.name ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  subtitle: Text(
                    member.email ?? 'No email',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  secondary: CircleAvatar(
                    backgroundColor: const Color(0xFF3B82F6),
                    child: Text(
                      (member.name?.isNotEmpty == true)
                          ? member.name![0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  activeColor: const Color(0xFF3B82F6),
                  checkColor: Colors.white,
                ),
              );
            },
          ),
        ),

        // Bottom Button
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedMembers.isEmpty ? null : () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text(
                    'Next (${_selectedMembers.length} selected)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeetingDetailsPage() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location Field
                const Text(
                  'Meeting Location *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _placeController,
                  decoration: InputDecoration(
                    hintText: 'Enter meeting location',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),

                const SizedBox(height: 20),

                // Date Field
                const Text(
                  'Meeting Date *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: _selectDate,
                  decoration: InputDecoration(
                    hintText: 'Select meeting date',
                    suffixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),

                const SizedBox(height: 20),

                // Time Field
                const Text(
                  'Meeting Time *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _timeController,
                  readOnly: true,
                  onTap: _selectTime,
                  decoration: InputDecoration(
                    hintText: 'Select meeting time',
                    suffixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Button
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createMeeting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Send Meeting Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Meeting Details Modal
class MeetingDetailsModal extends StatelessWidget {
  final Meeting meeting;

  const MeetingDetailsModal({
    super.key,
    required this.meeting,
  });

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.place ?? 'Unknown Location',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        'Meeting organized by ${meeting.fromMember?.name ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meeting Info Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.calendar_today,
                          iconColor: Colors.blue.shade600,
                          title: 'Date',
                          value: _formatDate(meeting.date),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.access_time,
                          iconColor: Colors.green.shade600,
                          title: 'Time',
                          value: meeting.time ?? 'N/A',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.location_on,
                          iconColor: Colors.purple.shade600,
                          title: 'Location',
                          value: meeting.place ?? 'N/A',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.people,
                          iconColor: Colors.orange.shade600,
                          title: 'Participants',
                          value: '${meeting.toMembers?.length ?? 0} members',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Organizer Section
                  const Text(
                    'Organizer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF3B82F6),
                          child: Text(
                            (meeting.fromMember?.name?.isNotEmpty == true)
                                ? meeting.fromMember!.name![0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meeting.fromMember?.name ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                meeting.fromMember?.email ?? 'No email',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Invited Members Section
                  const Text(
                    'Invited Members',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (meeting.toMembers != null && meeting.toMembers!.isNotEmpty)
                    ...meeting.toMembers!.map((member) {
                      Color statusColor;
                      String statusText;

                      switch (member.cirlMtStatus) {
                        case 1:
                          statusColor = Colors.green;
                          statusText = 'Accepted';
                          break;
                        case 2:
                          statusColor = Colors.red;
                          statusText = 'Declined';
                          break;
                        default:
                          statusColor = Colors.grey;
                          statusText = 'Pending';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.purple.shade500,
                              child: Text(
                                (member.name?.isNotEmpty == true)
                                    ? member.name![0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.name ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  Text(
                                    member.email ?? 'No email',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList()
                  else
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'No members invited',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Close Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.grey.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Main App
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferencesService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Circle Meetings',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const CircleMeetingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}