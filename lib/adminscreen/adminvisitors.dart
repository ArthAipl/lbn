import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class Visitor {
  final String visitorId;
  final String place;
  final String date;
  final String time;
  final String status;
  final Member invitee;
  final Member inviter;
  final String groupName;
  final String createdAt;
  final String updatedAt;
  final String visitorName;
  final String aboutVisitor;
  final String visitorEmail;
  final String visitorPhone;

  Visitor({
    required this.visitorId,
    required this.place,
    required this.date,
    required this.time,
    required this.status,
    required this.invitee,
    required this.inviter,
    required this.groupName,
    required this.createdAt,
    required this.updatedAt,
    required this.visitorName,
    required this.aboutVisitor,
    required this.visitorEmail,
    required this.visitorPhone,
  });

  factory Visitor.fromJson(Map<String, dynamic> json) {
    final meeting = json['meeting'] ?? {};
    final group = json['group'] ?? {};
    final member = json['member'] ?? {};

    return Visitor(
      visitorId: json['vis_inv_id']?.toString() ?? '',
      place: meeting['Place'] ?? '',
      date: meeting['Meeting_Date'] ?? '',
      time: meeting['Meeting_Time'] ?? '',
      status: json['Visitor_Status']?.toString() ?? '0',
      invitee: Member.fromJson(json, visitCount: 0), // Visitor as invitee
      inviter: Member.fromJson(member, visitCount: 0), // Member as inviter
      groupName: group['group_name'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      visitorName: json['Visitor_Name'] ?? '',
      aboutVisitor: json['About_Visitor'] ?? '',
      visitorEmail: json['Visitor_Email'] ?? '',
      visitorPhone: json['Visitor_Phone'] ?? '',
    );
  }
}

class Member {
  final String mId;
  final String name;
  final String email;
  final int visitCount;

  Member({
    required this.mId,
    required this.name,
    required this.email,
    this.visitCount = 0,
  });

  factory Member.fromJson(Map<String, dynamic> json, {int visitCount = 0}) {
    return Member(
      mId: json['M_ID']?.toString() ?? '',
      name: json['Name'] ?? json['Visitor_Name'] ?? '',
      email: json['email'] ?? json['Visitor_Email'] ?? '',
      visitCount: visitCount,
    );
  }
}

class VisitorsAdmin extends StatefulWidget {
  const VisitorsAdmin({super.key});

  @override
  State<VisitorsAdmin> createState() => _VisitorsAdminState();
}

class _VisitorsAdminState extends State<VisitorsAdmin> {
  List<Visitor> visitors = [];
  List<Member> members = [];
  bool isLoading = true;
  String? error;

  final Map<String, Map<String, dynamic>> statusMap = {
    '0': {'text': 'Pending', 'color': const Color(0xFFFFA726), 'textColor': Colors.white},
    '1': {'text': 'Accepted', 'color': const Color(0xFF66BB6A), 'textColor': Colors.white},
    '2': {'text': 'Rejected', 'color': const Color(0xFFEF5350), 'textColor': Colors.white},
    '3': {'text': 'Completed', 'color': const Color(0xFF9E9E9E), 'textColor': Colors.white},
    '110': {'text': 'Unknown Status', 'color': Colors.blueGrey, 'textColor': Colors.white},
  };

  @override
  void initState() {
    super.initState();
    debugPrint('VisitorsAdmin: initState called, fetching data');
    fetchData();
  }

  Future<void> fetchData() async {
    debugPrint('fetchData: Starting data fetch');
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      // Clear unnecessary SharedPreferences keys
      await prefs.remove('Name');
      await prefs.remove('email');
      await prefs.remove('number');
      await prefs.remove('Grop_code');
      await prefs.remove('role_id');
      await prefs.remove('group_name');
      await prefs.remove('short_group_name');

      final groupId = prefs.getString('G_ID');
      if (groupId == null) {
        debugPrint('Error: G_ID not found in SharedPreferences');
        throw Exception('Please log in to continue (G_ID missing)');
      }
      debugPrint('fetchData: Group ID found: $groupId');

      // Fetch visitors
      debugPrint('fetchData: Fetching visitors from API');
      final visitorsResponse = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/visitor-invites'));
      if (visitorsResponse.statusCode != 200) {
        debugPrint('Error fetching visitors: ${visitorsResponse.statusCode} - ${visitorsResponse.reasonPhrase}');
        throw Exception('Failed to fetch visitors: ${visitorsResponse.statusCode}');
      }
      debugPrint('fetchData: Visitors API raw response: ${visitorsResponse.body}');
      final visitorsData = jsonDecode(visitorsResponse.body) as List;
      debugPrint('fetchData: Visitors API decoded: $visitorsData');

      final List<Visitor> allVisitors = visitorsData.map((visitor) => Visitor.fromJson(visitor)).toList();

      final filteredVisitors = allVisitors.where((visitor) {
        final rawVisitorData = visitorsData.firstWhere(
          (v) => v['vis_inv_id'].toString() == visitor.visitorId,
          orElse: () => {},
        );
        final actualVisitorGroupId = rawVisitorData['group']?['G_ID']?.toString();
        final matches = actualVisitorGroupId == groupId;
        debugPrint('fetchData: Visitor G_ID: $actualVisitorGroupId, Expected: $groupId, Matches: $matches');
        return matches;
      }).toList();
      debugPrint('fetchData: Fetched ${filteredVisitors.length} visitors');

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

      final List<Member> fetchedMembers = [];
      for (var memberJson in membersData) {
        final memberGroupId = memberJson['G_ID']?.toString();
        final memberStatus = memberJson['status']?.toString() ?? memberJson['Status']?.toString();
        if (memberGroupId == groupId && memberStatus == '1') {
          final visitCount = filteredVisitors
              .where((visitor) =>
                  visitor.invitee.mId == memberJson['M_ID'].toString() ||
                  visitor.inviter.mId == memberJson['M_ID'].toString())
              .length;
          fetchedMembers.add(Member.fromJson(memberJson, visitCount: visitCount));
        }
      }
      debugPrint('fetchData: Fetched ${fetchedMembers.length} members');

      setState(() {
        visitors = filteredVisitors;
        members = fetchedMembers;
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

  Future<void> logout() async {
    debugPrint('logout: Clearing SharedPreferences');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('Name');
    await prefs.remove('email');
    await prefs.remove('number');
    await prefs.remove('Grop_code');
    await prefs.remove('role_id');
    await prefs.remove('group_name');
    await prefs.remove('short_group_name');
    debugPrint('logout: Navigating to login screen');
    Navigator.pushReplacementNamed(context, '/login');
  }

  void showMemberVisits(Member member) {
    try {
      final memberVisits = visitors
          .where((visitor) =>
              visitor.invitee.mId == member.mId || visitor.inviter.mId == member.mId)
          .toList();
      debugPrint('showMemberVisits: Navigating to MemberVisitsPage for ${member.name} with ${memberVisits.length} Visitors');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MemberVisitsPage(
            member: member,
            visitors: memberVisits,
            statusMap: statusMap,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error in showMemberVisits: $e');
      setState(() {
        error = 'Failed to show member Visitors: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('VisitorsAdmin: Building UI, isLoading: $isLoading, error: $error');
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            'Visitors Admin',
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
      debugPrint('VisitorsAdmin: Displaying error: $error, isAuthError: $isAuthError');
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            'Visitors Admin',
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
                          debugPrint('VisitorsAdmin: Error button pressed, navigating to /login');
                          Navigator.pushReplacementNamed(context, '/login');
                        } else {
                          debugPrint('VisitorsAdmin: Error button pressed, retrying fetchData');
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
          'Visitors Admin',
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
                  'View members and their visitor invites',
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
                          onTap: () => showMemberVisits(member),
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
                                    '${member.visitCount} visit${member.visitCount != 1 ? 's' : ''}',
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

class MemberVisitsPage extends StatelessWidget {
  final Member member;
  final List<Visitor> visitors;
  final Map<String, Map<String, dynamic>> statusMap;

  const MemberVisitsPage({
    super.key,
    required this.member,
    required this.visitors,
    required this.statusMap,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('MemberVisitsPage: Building for ${member.name} with ${visitors.length} Visitors');
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          '${member.name}\'s Visitors',
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
            debugPrint('MemberVisitsPage: Back button pressed');
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
                        '${visitors.length} Visitors${visitors.length != 1 ? 's' : ''}',
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
            child: visitors.isEmpty
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
                            'No Visitors found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'This member has no scheduled Visitors',
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
                    itemCount: visitors.length,
                    itemBuilder: (context, index) {
                      final visitor = visitors[index];
                      debugPrint('Building visitor card: ${visitor.place}, index: $index');
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
                                      visitor.place,
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
                                      color: statusMap[visitor.status]?['color'] ?? Colors.grey,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (statusMap[visitor.status]?['color'] ?? Colors.grey).withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      statusMap[visitor.status]?['text'] ?? 'Unknown',
                                      style: TextStyle(
                                        color: statusMap[visitor.status]?['textColor'] ?? Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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
                                      'Meeting Location',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      visitor.place,
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
                                            visitor.date,
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
                                            visitor.time,
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
                                      'Invited',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      visitor.visitorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'About: ${visitor.aboutVisitor}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Email: ${visitor.visitorEmail}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Phone: ${visitor.visitorPhone}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
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