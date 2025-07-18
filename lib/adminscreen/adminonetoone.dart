import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final allKeys = prefs.getKeys();
  debugPrint('SharedPreferences keys at startup: $allKeys');
  for (var key in allKeys) {
    debugPrint('Key: $key, Value: ${prefs.get(key)}');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('MyApp: Building app with initial route /check-auth');
    return MaterialApp(
      title: 'One-to-One Admin',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: CardTheme(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      initialRoute: '/check-auth',
      routes: {
        '/check-auth': (context) => const AuthCheckPage(),
        '/one-to-one-admin': (context) => const OneToOneAdmin(),
    
      },
    );
  }
}

class AuthCheckPage extends StatelessWidget {
  const AuthCheckPage({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('AuthCheckPage: Checking authentication');
    return FutureBuilder<bool>(
      future: _checkAuth(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('AuthCheckPage: Waiting for auth check');
          return const Scaffold(
            backgroundColor: Color(0xFFF8F9FA),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Loading...',
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
        if (snapshot.hasData && snapshot.data == true) {
          debugPrint('AuthCheckPage: User authenticated, navigating to /one-to-one-admin');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/one-to-one-admin');
          });
        } else {
          debugPrint('AuthCheckPage: No user data, navigating to /login');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/login');
          });
        }
        return const Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Center(
            child: CircularProgressIndicator(
              color: Colors.black,
              strokeWidth: 3,
            ),
          ),
        );
      },
    );
  }

  Future<bool> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    debugPrint('AuthCheck: User ID exists: ${userId != null}, Value: $userId');
    return userId != null;
  }
}

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
      groupName: json['group']['group_name'] ?? '',
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
    required this.meetingCount,
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

  final Map<String, Map<String, dynamic>> statusMap = {
    '0': {'text': 'Pending', 'color': const Color(0xFFFFA726), 'textColor': Colors.white},
    '1': {'text': 'Accepted', 'color': const Color(0xFF66BB6A), 'textColor': Colors.white},
    '2': {'text': 'Rejected', 'color': const Color(0xFFEF5350), 'textColor': Colors.white},
    '3': {'text': 'Completed', 'color': const Color(0xFF9E9E9E), 'textColor': Colors.white},
  };

  @override
  void initState() {
    super.initState();
    debugPrint('OneToOneAdmin: initState called, fetching data');
    fetchData();
  }

  Future<void> fetchData() async {
    debugPrint('fetchData: Starting data fetch');
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      debugPrint('SharedPreferences keys in fetchData: $allKeys');
      for (var key in allKeys) {
        debugPrint('Key: $key, Value: ${prefs.get(key)}');
      }

      final gId = prefs.getString('Grop_code');
      if (gId == null) {
        debugPrint('Error: Group code not found in SharedPreferences');
        throw Exception('Please log in to continue');
      }
      debugPrint('fetchData: Group code found: $gId');

      // Fetch meetings
      debugPrint('fetchData: Fetching meetings from API');
      final meetingsResponse = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/one2one'));
      if (meetingsResponse.statusCode != 200) {
        debugPrint('Error fetching meetings: ${meetingsResponse.statusCode} - ${meetingsResponse.reasonPhrase}');
        throw Exception('Failed to fetch meetings: ${meetingsResponse.statusCode}');
      }
      debugPrint('fetchData: Meetings API raw response: ${meetingsResponse.body}');
      final meetingsData = jsonDecode(meetingsResponse.body) as List;
      debugPrint('fetchData: Meetings API decoded: $meetingsData');
      final filteredMeetings = meetingsData
          .where((meeting) {
            final groupCode = meeting['group']?['Grop_code']?.toString();
            final matches = groupCode == gId;
            debugPrint('fetchData: Meeting group code: $groupCode, Expected: $gId, Matches: $matches');
            return matches;
          })
          .map((meeting) => Meeting.fromJson(meeting))
          .toList();
      debugPrint('fetchData: Fetched ${filteredMeetings.length} meetings');

      // Fetch members
      debugPrint('fetchData: Fetching members from API');
      final membersResponse = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/member'));
      if (membersResponse.statusCode != 200) {
        debugPrint('Error fetching members: ${membersResponse.statusCode} - ${membersResponse.reasonPhrase}');
        throw Exception('Failed to fetch members: ${membersResponse.statusCode}');
      }
      debugPrint('fetchData: Members API raw response: ${membersResponse.body}');
      final membersData = jsonDecode(membersResponse.body)['members'] as List? ?? jsonDecode(membersResponse.body) as List;
      debugPrint('fetchData: Members API decoded: $membersData');
      final filteredMembers = membersData
          .where((member) {
            final groupCode = member['Grop_code']?.toString();
            final status = member['status']?.toString() ?? member['Status']?.toString();
            final matches = groupCode == gId && status == '1';
            debugPrint('fetchData: Member group code: $groupCode, Status: $status, Expected group_code: $gId, Status: 1, Matches: $matches');
            return matches;
          })
          .map((member) {
            final meetingCount = filteredMeetings
                .where((meeting) =>
                    meeting.fromMember.mId == member['M_ID'].toString() ||
                    meeting.toMember.mId == member['M_ID'].toString())
                .length;
            return Member.fromJson(member, meetingCount: meetingCount);
          })
          .toList();
      debugPrint('fetchData: Fetched ${filteredMembers.length} members');

      setState(() {
        meetings = filteredMeetings;
        members = filteredMembers;
        isLoading = false;
      });
      debugPrint('fetchData: Data fetch completed successfully');
    } catch (e) {
      debugPrint('Error in fetchData: $e');
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
      debugPrint('Error in showMemberMeetings: $e');
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
                          });
                          fetchData();
                        }
                      } catch (e) {
                        debugPrint('Error in error button: $e');
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
                                      color: statusMap[meeting.status]!['color'],
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: statusMap[meeting.status]!['color'].withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      statusMap[meeting.status]!['text'],
                                      style: TextStyle(
                                        color: statusMap[meeting.status]!['textColor'],
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