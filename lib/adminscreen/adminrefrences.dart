import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


class Reference {
  final String referenceId;
  final String place;
  final String date;
  final String time;
  final String status;
  final Member invitee;
  final Member inviter;
  final String groupName;
  final String createdAt;
  final String updatedAt;
  final String referenceName;
  final String aboutReference;
  final String referenceEmail;
  final String referencePhone;
  final String toMid;
  final String? thankNoteGiverName;
  final String? thankNoteAmount;

  Reference({
    required this.referenceId,
    required this.place,
    required this.date,
    required this.time,
    required this.status,
    required this.invitee,
    required this.inviter,
    required this.groupName,
    required this.createdAt,
    required this.updatedAt,
    required this.referenceName,
    required this.aboutReference,
    required this.referenceEmail,
    required this.referencePhone,
    required this.toMid,
    this.thankNoteGiverName,
    this.thankNoteAmount,
  });

  factory Reference.fromJson(Map<dynamic, dynamic> json, {String? thankNoteGiverName, String? thankNoteAmount}) {
    final jsonStringKeys = json.map((key, value) => MapEntry(key.toString(), value));
    final meeting = jsonStringKeys['meeting'] as Map<dynamic, dynamic>? ?? {};
    final group = jsonStringKeys['group'] as Map<dynamic, dynamic>? ?? {};
    final fromMember = jsonStringKeys['from_member'] as Map<dynamic, dynamic>? ?? {};
    final toMember = jsonStringKeys['to_member'] as Map<dynamic, dynamic>? ?? {};

    return Reference(
      referenceId: jsonStringKeys['ref_track_id']?.toString() ?? '',
      place: meeting['Place']?.toString() ?? '',
      date: meeting['Meeting_Date']?.toString() ?? '',
      time: meeting['Meeting_Time']?.toString() ?? '',
      status: jsonStringKeys['Status']?.toString() ?? '0',
      invitee: Member.fromJson(toMember, visitCount: 0),
      inviter: Member.fromJson(fromMember, visitCount: 0),
      groupName: group['group_name']?.toString() ?? '',
      createdAt: jsonStringKeys['created_at']?.toString() ?? '',
      updatedAt: jsonStringKeys['updated_at']?.toString() ?? '',
      referenceName: jsonStringKeys['Name']?.toString() ?? '',
      aboutReference: jsonStringKeys['About']?.toString() ?? '',
      referenceEmail: jsonStringKeys['Email']?.toString() ?? '',
      referencePhone: jsonStringKeys['Phone']?.toString() ?? '',
      toMid: jsonStringKeys['To_MID']?.toString() ?? '',
      thankNoteGiverName: thankNoteGiverName,
      thankNoteAmount: thankNoteAmount,
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

  factory Member.fromJson(Map<dynamic, dynamic> json, {int visitCount = 0}) {
    final jsonStringKeys = json.map((key, value) => MapEntry(key.toString(), value));
    return Member(
      mId: jsonStringKeys['M_ID']?.toString() ?? jsonStringKeys['From_MID']?.toString() ?? '',
      name: jsonStringKeys['Name']?.toString() ?? '',
      email: jsonStringKeys['email']?.toString() ?? jsonStringKeys['Email']?.toString() ?? '',
      visitCount: visitCount,
    );
  }
}

class ReferencesAdmin extends StatefulWidget {
  const ReferencesAdmin({super.key});

  @override
  State<ReferencesAdmin> createState() => _ReferencesAdminState();
}

class _ReferencesAdminState extends State<ReferencesAdmin> {
  List<Reference> references = [];
  List<Member> members = [];
  bool isLoading = true;
  String? error;
  List<dynamic> rawReferencesData = [];

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
    debugPrint('ReferencesAdmin: initState called, fetching data');
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

      // Fetch references
      debugPrint('fetchData: Fetching references from API');
      final referencesResponse = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/ref-tracks'));
      if (referencesResponse.statusCode != 200) {
        debugPrint('Error fetching references: ${referencesResponse.statusCode} - ${referencesResponse.reasonPhrase}');
        throw Exception('Failed to fetch references: ${referencesResponse.statusCode}');
      }
      debugPrint('fetchData: References API raw response: ${referencesResponse.body}');
      final referencesJson = jsonDecode(referencesResponse.body);
      rawReferencesData = (referencesJson is List)
          ? referencesJson
          : (referencesJson['data'] as List? ?? referencesJson['references'] as List? ?? []);
      debugPrint('fetchData: References API decoded: $rawReferencesData');

      // Fetch thank notes
      debugPrint('fetchData: Fetching thank notes from API');
      final thankNotesResponse = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/thnk-tracks'));
      if (thankNotesResponse.statusCode != 200) {
        debugPrint('Error fetching thank notes: ${thankNotesResponse.statusCode} - ${thankNotesResponse.reasonPhrase}');
        throw Exception('Failed to fetch thank notes: ${thankNotesResponse.statusCode}');
      }
      debugPrint('fetchData: Thank Notes API raw response: ${thankNotesResponse.body}');
      final thankNotesJson = jsonDecode(thankNotesResponse.body);
      final thankNotesData = (thankNotesJson is List)
          ? thankNotesJson
          : (thankNotesJson['data'] as List? ?? thankNotesJson['thnk-tracks'] as List? ?? []);
      debugPrint('fetchData: Thank Notes API decoded: $thankNotesData');

      final List<Reference> allReferences = rawReferencesData.map((reference) {
        if (reference is! Map) {
          debugPrint('Invalid reference data: $reference');
          throw Exception('Invalid reference data format');
        }
        // Find matching thank note
        final matchingThankNote = thankNotesData.firstWhere(
          (thankNote) => thankNote['ref_track_Id']?.toString() == reference['ref_track_id']?.toString(),
          orElse: () => null,
        );
        String? thankNoteGiverName;
        String? thankNoteAmount;
        if (matchingThankNote != null) {
          final memberData = matchingThankNote['member'] as Map<dynamic, dynamic>? ?? {};
          thankNoteGiverName = memberData['Name']?.toString();
          thankNoteAmount = matchingThankNote['Amount']?.toString();
        }
        return Reference.fromJson(
          reference,
          thankNoteGiverName: thankNoteGiverName,
          thankNoteAmount: thankNoteAmount,
        );
      }).toList();

      final filteredReferences = allReferences.where((reference) {
        final rawReferenceData = rawReferencesData.firstWhere(
          (v) => v['ref_track_id']?.toString() == reference.referenceId,
          orElse: () => {},
        );
        final actualReferenceGroupId = rawReferenceData['G_ID']?.toString();
        final matches = actualReferenceGroupId == groupId;
        debugPrint('fetchData: Reference G_ID: $actualReferenceGroupId, Expected: $groupId, Matches: $matches');
        return matches;
      }).toList();
      debugPrint('fetchData: Fetched ${filteredReferences.length} references');

      // Fetch members
      debugPrint('fetchData: Fetching members from API');
      final membersResponse = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/member'));
      if (membersResponse.statusCode != 200) {
        debugPrint('Error fetching members: ${membersResponse.statusCode} - ${membersResponse.reasonPhrase}');
        throw Exception('Failed to fetch members: ${membersResponse.statusCode}');
      }
      debugPrint('fetchData: Members API raw response: ${membersResponse.body}');
      final membersJson = jsonDecode(membersResponse.body);
      final membersData = (membersJson is List)
          ? membersJson
          : (membersJson['members'] as List? ?? []);
      debugPrint('fetchData: Members API decoded: $membersData');

      final List<Member> fetchedMembers = [];
      for (var memberJson in membersData) {
        if (memberJson is! Map) {
          debugPrint('Invalid member data: $memberJson');
          continue;
        }
        final memberGroupId = memberJson['G_ID']?.toString();
        final memberStatus = memberJson['status']?.toString() ?? memberJson['Status']?.toString();
        if (memberGroupId == groupId && memberStatus == '1') {
          final referenceCount = filteredReferences
              .where((reference) =>
                  reference.invitee.mId == memberJson['M_ID']?.toString() ||
                  reference.inviter.mId == memberJson['M_ID']?.toString())
              .length;
          fetchedMembers.add(Member.fromJson(memberJson, visitCount: referenceCount));
        }
      }
      debugPrint('fetchData: Fetched ${fetchedMembers.length} members');

      setState(() {
        references = filteredReferences;
        members = fetchedMembers;
        isLoading = false;
      });
      debugPrint('fetchData: Data fetch completed successfully');
    } catch (e) {
      debugPrint('Error in fetchData: $e');
      setState(() {
        error = e.toString().contains('Map')
            ? 'Failed to load data. Please try again.'
            : e.toString();
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

  void showMemberReferences(Member member) {
    try {
      final memberReferences = references.where((reference) {
        final rawReferenceData = rawReferencesData.firstWhere(
          (v) => v['ref_track_id']?.toString() == reference.referenceId,
          orElse: () => {},
        );
        final fromMid = rawReferenceData['From_MID']?.toString();
        final matches = fromMid == member.mId;
        debugPrint('showMemberReferences: Checking reference ${reference.referenceId}, From_MID: $fromMid, Member M_ID: ${member.mId}, Matches: $matches');
        return matches;
      }).toList();
      debugPrint('showMemberReferences: Navigating to MemberReferencesPage for ${member.name} with ${memberReferences.length} References');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MemberReferencesPage(
            member: member,
            references: memberReferences,
            statusMap: statusMap,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error in showMemberReferences: $e');
      setState(() {
        error = 'Failed to show member References: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('ReferencesAdmin: Building UI, isLoading: $isLoading, error: $error');
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            'References Admin',
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
      debugPrint('ReferencesAdmin: Displaying error: $error, isAuthError: $isAuthError');
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            'References Admin',
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
                  error!.contains('Map') ? 'Failed to load data. Please try again.' : error!,
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
                          debugPrint('ReferencesAdmin: Error button pressed, navigating to /login');
                          Navigator.pushReplacementNamed(context, '/login');
                        } else {
                          debugPrint('ReferencesAdmin: Error button pressed, retrying fetchData');
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
          'References Admin',
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
                  'View members and their reference invites',
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
                          onTap: () => showMemberReferences(member),
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
                                    '${member.visitCount} Reference${member.visitCount != 1 ? 's' : ''}',
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

class MemberReferencesPage extends StatelessWidget {
  final Member member;
  final List<Reference> references;
  final Map<String, Map<String, dynamic>> statusMap;

  const MemberReferencesPage({
    super.key,
    required this.member,
    required this.references,
    required this.statusMap,
  });

  @override
  Widget build(context) {
    debugPrint('MemberReferencesPage: Building for ${member.name} with ${references.length} References');
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          '${member.name}\'s References',
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
            debugPrint('MemberReferencesPage: Back button pressed');
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
                        '${references.length} Reference${references.length != 1 ? 's' : ''}',
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
            child: references.isEmpty
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
                            'No References found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'This member has no scheduled References',
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
                    itemCount: references.length,
                    itemBuilder: (context, index) {
                      final reference = references[index];
                      debugPrint('Building reference card: ${reference.referenceName}, index: $index');
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(3, 5),
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
                                      reference.referenceName,
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
                                      color: statusMap[reference.status]?['color'] ?? Colors.grey,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (statusMap[reference.status]?['color'] ?? Colors.grey).withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      statusMap[reference.status]?['text'] ?? 'Unknown',
                                      style: TextStyle(
                                        color: statusMap[reference.status]?['textColor'] ?? Colors.white,
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
                                      'To Reference',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Name: ${reference.referenceName}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'About Reference: ${reference.aboutReference}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Email: ${reference.referenceEmail}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Phone: ${reference.referencePhone}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Thank Note Details',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Giver: ${reference.thankNoteGiverName ?? 'N/A'}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Receiver: ${reference.inviter.name}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Amount: ${reference.thankNoteAmount ?? 'N/A'}',
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