import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<dynamic> meetings = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchMeetings();
  }

  // Retrieve G_ID from SharedPreferences
  Future<String?> getGId() async {
    final prefs = await SharedPreferences.getInstance();
    final gId = prefs.getString('G_ID');
    debugPrint('Retrieved G_ID: $gId');
    return gId;
  }

  // Fetch meetings from the API
  Future<void> fetchMeetings() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final gId = await getGId();
      if (gId == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'G_ID not found in SharedPreferences';
        });
        debugPrint('Error: $errorMessage');
        return;
      }

      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/meeting-cals'),
      );

      debugPrint('Meeting API Response Status: ${response.statusCode}');
      debugPrint('Meeting API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> meetingList;

        // Handle different API response formats
        if (data is List) {
          meetingList = data;
        } else if (data is Map && data.containsKey('data')) {
          if (data['data'] is List) {
            meetingList = data['data'];
          } else {
            throw Exception('Data field is not a list');
          }
        } else {
          throw Exception('Invalid API response format');
        }

        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        debugPrint('Today\'s Date: $today');

        // Filter meetings for today and matching G_ID
        final filteredMeetings = meetingList.where((meeting) {
          final meetingDate = meeting['Meeting_Date'] is String &&
                  meeting['Meeting_Date'].length >= 10
              ? meeting['Meeting_Date'].substring(0, 10)
              : null;
          final matchesDate = meetingDate == today;
          final matchesGId = meeting['G_ID']?.toString() == gId;
          debugPrint(
              'Meeting: ${meeting['group']?['name'] ?? 'No Name'}, Date: $meetingDate, G_ID: ${meeting['G_ID']}, Matches: $matchesDate && $matchesGId');
          return matchesDate && matchesGId;
        }).toList();

        setState(() {
          meetings = filteredMeetings;
          isLoading = false;
          if (meetings.isEmpty) {
            errorMessage = 'No meetings found for today ($today) with G_ID: $gId';
          }
        });
        debugPrint('Filtered Meetings: $filteredMeetings');
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load meetings: ${response.statusCode}';
        });
        debugPrint('Error: $errorMessage');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching meetings: $e';
      });
      debugPrint('Error: $errorMessage');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Today\'s Meetings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: fetchMeetings,
        color: Colors.black,
        backgroundColor: Colors.white,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty && meetings.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'No meetings scheduled for today.',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : errorMessage.isNotEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                errorMessage,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: fetchMeetings,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: meetings.length,
                        itemBuilder: (context, index) {
                          final meeting = meetings[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MeetingAttendancePage(meeting: meeting),
                                ),
                              );
                            },
                            child: Card(
                              elevation: 8,
                              margin: const EdgeInsets.symmetric(vertical: 10.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Meeting Details',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      Icons.calendar_today,
                                      'Date',
                                      meeting['Meeting_Date'] ?? 'N/A',
                                      Colors.blue.shade700,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                      Icons.access_time,
                                      'Time',
                                      meeting['Meeting_Time'] ?? 'N/A',
                                      Colors.blue.shade700,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                      Icons.location_on,
                                      'Location',
                                      meeting['Place'] ?? 'N/A',
                                      Colors.blue.shade700,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                      Icons.category,
                                      'Category',
                                      meeting['Meet_Cate'] ?? 'N/A',
                                      Colors.blue.shade700,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  // Helper method to build info rows with icons
  Widget _buildInfoRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: iconColor,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class MeetingAttendancePage extends StatefulWidget {
  final dynamic meeting;

  const MeetingAttendancePage({super.key, required this.meeting});

  @override
  State<MeetingAttendancePage> createState() => _MeetingAttendancePageState();
}

class _MeetingAttendancePageState extends State<MeetingAttendancePage> {
  List<dynamic> members = [];
  List<dynamic> attendanceRecords = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchMembersAndAttendance();
  }

  // Retrieve G_ID from SharedPreferences
  Future<String?> getGId() async {
    final prefs = await SharedPreferences.getInstance();
    final gId = prefs.getString('G_ID');
    debugPrint('Retrieved G_ID: $gId');
    return gId;
  }

  // Fetch members and attendance records
  Future<void> fetchMembersAndAttendance() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final gId = await getGId();
      if (gId == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'G_ID not found in SharedPreferences';
        });
        debugPrint('Error: $errorMessage');
        return;
      }

      final mCId = widget.meeting['M_C_Id']?.toString();
      if (mCId == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Meeting ID not found';
        });
        debugPrint('Error: $errorMessage');
        return;
      }

      // Fetch members
      final memberResponse = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/member'),
      );

      debugPrint('Member API Response Status: ${memberResponse.statusCode}');
      debugPrint('Member API Response Body: ${memberResponse.body}');

      if (memberResponse.statusCode == 200) {
        final memberData = jsonDecode(memberResponse.body);
        List<dynamic> memberList;

        // Handle different API response formats
        if (memberData is List) {
          memberList = memberData;
        } else if (memberData is Map && memberData.containsKey('members')) {
          if (memberData['members'] is List) {
            memberList = memberData['members'];
          } else {
            throw Exception('Members field is not a list');
          }
        } else if (memberData is Map && memberData.containsKey('data')) {
          if (memberData['data'] is List) {
            memberList = memberData['data'];
          } else {
            throw Exception('Data field is not a list');
          }
        } else {
          throw Exception('Invalid API response format');
        }

        // Filter members by G_ID and status == "1"
        final filteredMembers = memberList.where((member) {
          final matchesGId = member['G_ID']?.toString() == gId;
          final isActive = member['status']?.toString() == '1';
          debugPrint(
              'Member: ${member['Name'] ?? 'No Name'}, G_ID: ${member['G_ID']}, Status: ${member['status']}, Matches: $matchesGId && $isActive');
          return matchesGId && isActive;
        }).toList();

        // Fetch attendance records
        final attendanceResponse = await http.get(
          Uri.parse('https://tagai.caxis.ca/public/api/attan-tracks?M_C_Id=$mCId&G_ID=$gId'),
        );

        debugPrint('Attendance API Response Status: ${attendanceResponse.statusCode}');
        debugPrint('Attendance API Response Body: ${attendanceResponse.body}');

        List<dynamic> attendanceList = [];
        if (attendanceResponse.statusCode == 200) {
          final attendanceData = jsonDecode(attendanceResponse.body);
          if (attendanceData is List) {
            attendanceList = attendanceData;
          } else if (attendanceData is Map && attendanceData.containsKey('data')) {
            if (attendanceData['data'] is List) {
              attendanceList = attendanceData['data'];
            } else {
              throw Exception('Attendance data field is not a list');
            }
          } else {
            throw Exception('Invalid attendance API response format');
          }
        } else {
          throw Exception('Failed to load attendance records: ${attendanceResponse.statusCode}');
        }

        // Filter out members who already have attendance recorded
        final membersWithAttendance = attendanceList.map((attn) => attn['M_ID']?.toString()).toSet();
        final filteredMembersWithoutAttendance = filteredMembers.where((member) {
          final memberId = member['M_ID']?.toString();
          final hasAttendance = membersWithAttendance.contains(memberId);
          debugPrint('Member ID: $memberId, Has Attendance: $hasAttendance');
          return !hasAttendance;
        }).toList();

        setState(() {
          members = filteredMembersWithoutAttendance;
          attendanceRecords = attendanceList;
          isLoading = false;
          if (members.isEmpty) {
            errorMessage = 'No active members without attendance found for G_ID: $gId';
          }
        });
        debugPrint('Filtered Members Without Attendance: $filteredMembersWithoutAttendance');
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load members: ${memberResponse.statusCode}';
        });
        debugPrint('Error: $errorMessage');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching data: $e';
      });
      debugPrint('Error: $errorMessage');
    }
  }

  // Save attendance status to the API
  Future<void> saveAttendance(String mId, String attnStatus) async {
    final gId = await getGId();
    if (gId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: G_ID not found'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    final mCId = widget.meeting['M_C_Id']?.toString();
    if (mCId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Meeting ID not found'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://tagai.caxis.ca/public/api/attan-tracks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'Attn_Status': attnStatus,
          'M_C_Id': mCId,
          'G_ID': gId,
          'M_ID': mId,
        }),
      );

      debugPrint('Attendance API Response Status: ${response.statusCode}');
      debugPrint('Attendance API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Attendance marked successfully for ${members.firstWhere((m) => m['M_ID'].toString() == mId)['Name'] ?? 'Member'}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );

        // Remove the member from the list after marking attendance
        setState(() {
          members = members.where((member) => member['M_ID'].toString() != mId).toList();
          if (members.isEmpty) {
            errorMessage = 'No active members without attendance found for G_ID: $gId';
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark attendance: ${response.statusCode}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking attendance: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      debugPrint('Error marking attendance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Attendance',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'ATTENDANCE'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ATTENDANCE Tab
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty && members.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              errorMessage,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: fetchMembersAndAttendance,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchMembersAndAttendance,
                        color: Colors.black,
                        backgroundColor: Colors.white,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final member = members[index];
                            return Card(
                              elevation: 6,
                              margin: const EdgeInsets.symmetric(vertical: 10.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 2,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member['Name'] ?? 'N/A',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Email: ${member['email'] ?? 'N/A'}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Number: ${member['number'] ?? 'N/A'}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          _buildAttendanceButton(
                                            context,
                                            'Present',
                                            Colors.green.shade600,
                                            member,
                                            '1',
                                          ),
                                          const SizedBox(width: 8),
                                          _buildAttendanceButton(
                                            context,
                                            'Absent',
                                            Colors.red.shade600,
                                            member,
                                            '0',
                                          ),
                                          const SizedBox(width: 8),
                                          _buildAttendanceButton(
                                            context,
                                            'Late',
                                            Colors.orange.shade600,
                                            member,
                                            '2',
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
                      ),
          ],
        ),
      ),
    );
  }

  // Helper method to build attendance buttons
  Widget _buildAttendanceButton(
      BuildContext context, String label, Color color, dynamic member, String attnStatus) {
    return ElevatedButton(
      onPressed: () async {
        await saveAttendance(member['M_ID'].toString(), attnStatus);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(100, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}