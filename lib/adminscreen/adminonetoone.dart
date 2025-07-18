import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Meeting {
  final String one2oneId;
  final String place;
  final String date;
  final String time;
  final String status;
  final Member fromMember;
  final Member toMember;
  final String groupName;
  final String createdAt;
  final String updatedAt;

  Meeting({
    required this.one2oneId,
    required this.place,
    required this.date,
    required this.time,
    required this.status,
    required this.fromMember,
    required this.toMember,
    required this.groupName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      one2oneId: json['one2one_id'].toString(),
      place: json['Place'] ?? '',
      date: json['Date'] ?? '',
      time: json['Time'] ?? '',
      status: json['Status'].toString(),
      fromMember: Member.fromJson(json['from_member']),
      toMember: Member.fromJson(json['to_member']),
      groupName: json['group']?['group_name'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

class Member {
  final String mId;
  final String name;
  final String email;
  final int meetingCount;

  Member({
    required this.mId,
    required this.name,
    required this.email,
    this.meetingCount = 0,
  });

  factory Member.fromJson(Map<String, dynamic> json, {int meetingCount = 0}) {
    return Member(
      mId: json['M_ID'].toString(),
      name: json['Name'] ?? '',
      email: json['email'] ?? '',
      meetingCount: meetingCount,
    );
  }
}

class OneToOneAdmin extends StatefulWidget {
  const OneToOneAdmin({super.key});

  @override
  State<OneToOneAdmin> createState() => _OneToOneAdminState();
}

class _OneToOneAdminState extends State<OneToOneAdmin> {
  List<Meeting> meetings = [];
  List<Member> members = [];
  bool isLoading = true;
  String? error;
  bool _hasFetched = false;

  final Map<String, Map<String, dynamic>> statusMap = {
    '0': {'text': 'Pending', 'color': const Color(0xFFFFA726), 'textColor': Colors.white},
    '1': {'text': 'Accepted', 'color': const Color(0xFF66BB6A), 'textColor': Colors.white},
    '2': {'text': 'Rejected', 'color': const Color(0xFFEF5350), 'textColor': Colors.white},
    '3': {'text': 'Completed', 'color': const Color(0xFF9E9E9E), 'textColor': Colors.white},
    '110': {'text': 'Custom Status', 'color': Colors.blue, 'textColor': Colors.white},
  };

  @override
  void initState() {
    super.initState();
    debugPrint('OneToOneAdmin: initState called for widget hash: ${hashCode}');
    fetchData();
  }

  Future<void> fetchData() async {
    if (_hasFetched) {
      debugPrint('fetchData: Already fetched, skipping');
      return;
    }
    _hasFetched = true;

    debugPrint('fetchData: Starting data fetch');
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final groupId = prefs.getString('G_ID');
      final groupCode = prefs.getString('Grop_code');
      if (groupId == null) {
        debugPrint('fetchData: Error: G_ID not found in SharedPreferences');
        throw Exception('Please log in to continue (G_ID missing)');
      }
      debugPrint('fetchData: Group ID: $groupId, Group Code: $groupCode');

      // Fetch meetings
      debugPrint('fetchData: Fetching meetings from API');
      final meetingsResponse = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/one2one'));
      if (meetingsResponse.statusCode != 200) {
        debugPrint('fetchData: Error fetching meetings: ${meetingsResponse.statusCode}');
        throw Exception('Failed to fetch meetings: ${meetingsResponse.statusCode}');
      }
      final meetingsData = jsonDecode(meetingsResponse.body) as List;

      // Filter and parse meetings
      final List<Meeting> allMeetings = meetingsData
          .where((meeting) => meeting['group'] != null && meeting['group']['G_ID'] != null)
          .map((meeting) => Meeting.fromJson(meeting))
          .toList();

      // Filter meetings by G_ID (and optionally Grop_code)
      final filteredMeetings = allMeetings.where((meeting) {
        final rawMeetingData = meetingsData.firstWhere((m) => m['one2one_id'].toString() == meeting.one2oneId);
        final actualMeetingGroupId = rawMeetingData['group']?['G_ID']?.toString();
        final actualGroupCode = rawMeetingData['group']?['Grop_code']?.toString();
        if (groupCode != null && actualGroupCode != groupCode) {
          debugPrint('fetchData: Grop_code mismatch for meeting ${meeting.one2oneId}: Expected $groupCode, Got $actualGroupCode');
        }
        // Uncomment to enable Grop_code filtering
        // final matches = actualMeetingGroupId == groupId && (groupCode == null || actualGroupCode == groupCode);
        final matches = actualMeetingGroupId == groupId;
        debugPrint('fetchData: Meeting ID: ${meeting.one2oneId}, G_ID: $actualMeetingGroupId, Matches: $matches');
        return matches;
      }).toList();
      debugPrint('fetchData: Fetched ${filteredMeetings.length} meetings');

      // Fetch members
      debugPrint('fetchData: Fetching members from API');
      final membersResponse = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/member'));
      if (membersResponse.statusCode != 200) {
        debugPrint('fetchData: Error fetching members: ${membersResponse.statusCode}');
        throw Exception('Failed to fetch members: ${membersResponse.statusCode}');
      }
      final membersData = jsonDecode(membersResponse.body)['members'] as List? ?? [];

      // Filter and parse members
      final List<Member> fetchedMembers = [];
      for (var memberJson in membersData) {
        final memberGroupId = memberJson['G_ID']?.toString();
        final memberStatus = memberJson['status']?.toString() ?? memberJson['Status']?.toString();
        if (memberGroupId == groupId && memberStatus == '1') {
          final meetingCount = filteredMeetings
              .where((meeting) =>
                  meeting.fromMember.mId == memberJson['M_ID'].toString() ||
                  meeting.toMember.mId == memberJson['M_ID'].toString())
              .length;
          fetchedMembers.add(Member.fromJson(memberJson, meetingCount: meetingCount));
        }
      }
      debugPrint('fetchData: Fetched ${fetchedMembers.length} members');

      setState(() {
        meetings = filteredMeetings;
        members = fetchedMembers;
        isLoading = false;
        debugPrint('Fetched Members: ${members.map((m) => m.name).toList()}');
        debugPrint('Fetched Meetings: ${meetings.map((m) => "${m.one2oneId}: ${m.place}").toList()}');
      });
      debugPrint('fetchData: Data fetch completed successfully');
    } catch (e) {
      debugPrint('fetchData: Error: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void showMemberMeetings(Member member) {
    try {
      final memberMeetings = meetings
          .where((meeting) =>
              meeting.fromMember.mId == member.mId || meeting.toMember.mId == member.mId)
          .toList();
      debugPrint('showMemberMeetings: Navigating to MemberMeetingsPage for ${member.name} with ${memberMeetings.length} meetings');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MemberMeetingsPage(
            member: member,
            meetings: memberMeetings,
            statusMap: statusMap,
          ),
        ),
      );
    } catch (e) {
      debugPrint('showMemberMeetings: Error: $e');
      setState(() {
        error = 'Failed to show member meetings: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('OneToOneAdmin: Building UI, isLoading: $isLoading, error: $error');
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            'One-to-One Admin',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 3,
              ),
              SizedBox(height: 24),
              Text(
                'Loading members...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (error != null) {
      final isAuthError = error!.contains('Please log in to continue');
      debugPrint('OneToOneAdmin: Displaying error: $error, isAuthError: $isAuthError');
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            'One-to-One Admin',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Error Occurred',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      try {
                        if (isAuthError) {
                          debugPrint('OneToOneAdmin: Error button pressed, navigating to /login');
                          Navigator.pushReplacementNamed(context, '/login');
                        } else {
                          debugPrint('OneToOneAdmin: Error button pressed, retrying fetchData');
                          setState(() {
                            isLoading = true;
                            error = null;
                            _hasFetched = false;
                          });
                          fetchData();
                        }
                      } catch (e) {
                        debugPrint('OneToOneAdmin: Error in error button: $e');
                        setState(() {
                          error = 'Failed to handle error: $e';
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      isAuthError ? 'Log In' : 'Try Again',
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
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
          'One-to-One Admin',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Colors.grey[800]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'View members and their scheduled meetings',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: members.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No members found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      debugPrint('Building member card: ${member.name}, index: $index');
                      return Card(
                        elevation: 6,
                        shadowColor: Colors.black.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: InkWell(
                          onTap: () => showMemberMeetings(member),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [Colors.white, Colors.grey[50]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
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
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  member.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${member.meetingCount} meeting${member.meetingCount != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
}

class MemberMeetingsPage extends StatelessWidget {
  final Member member;
  final List<Meeting> meetings;
  final Map<String, Map<String, dynamic>> statusMap;

  const MemberMeetingsPage({
    super.key,
    required this.member,
    required this.meetings,
    required this.statusMap,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('MemberMeetingsPage: Building for ${member.name} with ${meetings.length} meetings');
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          '${member.name}\'s Meetings',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            debugPrint('MemberMeetingsPage: Back button pressed');
            Navigator.pop(context);
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Colors.grey[800]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${meetings.length} meeting${meetings.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: meetings.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No meetings found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'This member has no scheduled meetings',
                            style: TextStyle(
                              color: Colors.black38,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: meetings.length,
                    itemBuilder: (context, index) {
                      final meeting = meetings[index];
                      debugPrint('Building meeting card: ${meeting.place}, index: $index');
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      meeting.place,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusMap[meeting.status]?['color'] ?? Colors.grey,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (statusMap[meeting.status]?['color'] ?? Colors.grey).withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      statusMap[meeting.status]?['text'] ?? 'Unknown',
                                      style: TextStyle(
                                        color: statusMap[meeting.status]?['textColor'] ?? Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Date',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            meeting.date,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Time',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            meeting.time,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Meeting with',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      meeting.fromMember.mId == member.mId
                                          ? meeting.toMember.name
                                          : meeting.fromMember.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
}