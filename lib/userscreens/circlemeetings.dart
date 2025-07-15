
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CircleMeetingsPage extends StatefulWidget {
  @override
  _CircleMeetingsPageState createState() => _CircleMeetingsPageState();
}

class _CircleMeetingsPageState extends State<CircleMeetingsPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final _formKey = GlobalKey<FormState>();
  final _placeController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  List<Map<String, dynamic>> members = [];
  List<int> selectedMemberIds = [];
  String? gId;
  String? fromMId;
  String? groupCode;
  List<Map<String, dynamic>> scheduledMeetings = [];
  List<Map<String, dynamic>> historyMeetings = [];
  List<Map<String, dynamic>> meetingRequests = [];
  List<Map<String, dynamic>> myMeetings = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSharedPreferences();
    _fetchMembers();
    _fetchMeetings();
  }

  Future<void> _loadSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      gId = prefs.getString('G_ID') ?? '';
      fromMId = prefs.getString('M_ID') ?? '';
      groupCode = prefs.getString('Grop_code') ?? '';
    });
  }

  Future<void> _fetchMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final gId = prefs.getString('G_ID') ?? '';
    final groupCode = prefs.getString('Grop_code') ?? '';
    try {
      final response = await http.get(
        Uri.parse(
            'https://tagai.caxis.ca/public/api/member?Group_code=$groupCode&G_ID=$gId&status=1'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          members = List<Map<String, dynamic>>.from(data['members'] ?? []);
        });
      } else {
        debugPrint('Failed to load members: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load members: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Error fetching members: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching members: $e')),
      );
    }
  }

  Future<String> _getMemberName(String mId) async {
    final member = members.firstWhere(
      (m) => m['M_ID'].toString() == mId,
      orElse: () => {'Name': 'Unknown (ID: $mId)'},
    );
    return member['Name'] ?? 'Unknown (ID: $mId)';
  }

  Future<void> _fetchMeetings() async {
    final prefs = await SharedPreferences.getInstance();
    final userMId = prefs.getString('M_ID') ?? '';
    try {
      var uri = Uri.parse('https://tagai.caxis.ca/public/api/circle-meetings/');
      var response = await http.get(uri);
      if (response.statusCode == 301 || response.statusCode == 302) {
        final newUrl = response.headers['location'];
        if (newUrl != null) {
          debugPrint('Following redirect to: $newUrl');
          uri = Uri.parse(newUrl);
          response = await http.get(uri);
        } else {
          debugPrint('Redirect location not found in 301 response');
        }
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final allMeetings = List<Map<String, dynamic>>.from(data['meetings'] ?? []);
        setState(() {
          meetingRequests = allMeetings.where((meeting) {
            final toMIds = List<dynamic>.from(meeting['To_M_ID'] ?? []);
            return toMIds.any((item) => item['id'].toString() == userMId && item['cirl_mt_status'].toString() == '0');
          }).toList();
          scheduledMeetings = allMeetings.where((meeting) {
            final fromMId = meeting['From_M_ID'].toString();
            final toMIds = List<dynamic>.from(meeting['To_M_ID'] ?? []);
            final isFromUserWithAccepted = fromMId == userMId && toMIds.any((item) => item['cirl_mt_status'].toString() == '1');
            final isToUserWithStatus1 = toMIds.any((item) => item['id'].toString() == userMId && item['cirl_mt_status'].toString() == '1');
            return meeting['Status'] == '0' && (isFromUserWithAccepted || isToUserWithStatus1);
          }).toList();
          historyMeetings = allMeetings.where((meeting) {
            final fromMId = meeting['From_M_ID'].toString();
            final toMIds = List<dynamic>.from(meeting['To_M_ID'] ?? [])
                .map((item) => item['id'].toString())
                .toList();
            return (meeting['Status'] == '1' || meeting['Status'] == '2') &&
                (fromMId == userMId || toMIds.contains(userMId));
          }).toList();
          myMeetings = allMeetings.where((meeting) {
            return meeting['From_M_ID'].toString() == userMId && meeting['Status'] == '0';
          }).toList();
        });
      } else {
        debugPrint('Failed to load meetings: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load meetings: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Error fetching meetings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching meetings: $e')),
      );
    }
  }

  bool _isMeetingPassed(Map<String, dynamic> meeting) {
    final meetingDateStr = meeting['date'] ?? '';
    final meetingTimeStr = meeting['time'] ?? '';
    if (meetingDateStr.isEmpty || meetingTimeStr.isEmpty) {
      return false;
    }
    final meetingDateTimeStr = '$meetingDateStr $meetingTimeStr';
    final meetingDateTime = DateTime.tryParse(meetingDateTimeStr);
    if (meetingDateTime == null) {
      return false;
    }
    final now = DateTime.now();
    return meetingDateTime.isBefore(now);
  }

  // Hypothetical function to upload image and get URL
  Future<String?> _uploadImage(XFile image) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://tagai.caxis.ca/public/api/upload-image'), // Replace with actual endpoint
      );
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        image.path,
        filename: 'uploaded_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      debugPrint('Sending image upload request to ${request.url}');
      var response = await request.send();
      final responseBody = await response.stream.bytesToString();
      debugPrint('Image Upload Response: Status ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(responseBody);
        return data['url'] ?? data['image_url']; // Adjust based on actual response structure
      } else {
        debugPrint('Failed to upload image: ${response.statusCode} - $responseBody');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: ${response.statusCode}')),
        );
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }

  Future<void> _showMarkAsCompletedDialog(Map<String, dynamic> meeting) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark as Completed'),
        content: Text('Choose an option:'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _markAsCompleteWithImage(meeting);
            },
            child: Text('Completed with Image'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _markAsCompleteSkipImage(meeting);
            },
            child: Text('Skip Image'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsCompleteWithImage(Map<String, dynamic> meeting) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null) {
        debugPrint('Image selection cancelled');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image selection cancelled')),
        );
        return;
      }
      // Upload image to get URL
      final imageUrl = await _uploadImage(image);
      if (imageUrl == null) {
        debugPrint('Image upload failed, aborting meeting update');
        return;
      }
      final payload = {
        'Circle_ID': meeting['Circle_ID'].toString(),
        'Status': '1',
        'images': [imageUrl],
      };
      var uri = Uri.parse('https://tagai.caxis.ca/public/api/circle-meetings/${meeting['Circle_ID']}');
      debugPrint('Sending PUT request to $uri with payload: ${jsonEncode(payload)}');
      var response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 301 || response.statusCode == 302) {
        final newUrl = response.headers['location'];
        if (newUrl != null) {
          debugPrint('Following redirect to: $newUrl');
          uri = Uri.parse(newUrl);
          response = await http.put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );
        } else {
          debugPrint('Redirect location not found in ${response.statusCode} response');
        }
      }
      debugPrint('PUT Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Meeting marked as complete with image')),
        );
        await _fetchMeetings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to mark meeting as complete: ${response.statusCode} - ${response.body}')),
        );
      }
    } catch (e) {
      debugPrint('Error marking meeting as complete with image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking meeting as complete: $e')),
      );
    }
  }

  Future<void> _markAsCompleteSkipImage(Map<String, dynamic> meeting) async {
    try {
      final payload = {
        'Circle_ID': meeting['Circle_ID'].toString(),
        'Status': '1',
        'images': [],
      };
      var uri = Uri.parse('https://tagai.caxis.ca/public/api/circle-meetings/${meeting['Circle_ID']}');
      debugPrint('Sending PUT request to $uri with payload: ${jsonEncode(payload)}');
      var response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 301 || response.statusCode == 302) {
        final newUrl = response.headers['location'];
        if (newUrl != null) {
          debugPrint('Following redirect to: $newUrl');
          uri = Uri.parse(newUrl);
          response = await http.put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );
        } else {
          debugPrint('Redirect location not found in ${response.statusCode} response');
        }
      }
      debugPrint('PUT Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Meeting marked as complete')),
        );
        await _fetchMeetings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to mark meeting as complete: ${response.statusCode} - ${response.body}')),
        );
      }
    } catch (e) {
      debugPrint('Error marking meeting as complete without image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking meeting as complete: $e')),
      );
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final time = _timeController.text.split(':').take(2).join(':');
      final payload = {
        'place': _placeController.text,
        'date': _dateController.text,
        'time': time,
        'Status': '0',
        'cirl_mt_status': '0',
        'G_ID': gId,
        'From_M_ID': fromMId,
        'To_M_ID': selectedMemberIds,
        'images': [],
      };
      try {
        var uri = Uri.parse('https://tagai.caxis.ca/public/api/circle-meetings/');
        debugPrint('Sending POST request to $uri with payload: ${jsonEncode(payload)}');
        var response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (response.statusCode == 301 || response.statusCode == 302) {
          final newUrl = response.headers['location'];
          if (newUrl != null) {
            debugPrint('Following redirect to: $newUrl');
            uri = Uri.parse(newUrl);
            response = await http.post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            );
          } else {
            debugPrint('Redirect location not found in ${response.statusCode} response');
          }
        }
        debugPrint('POST Response: Status ${response.statusCode}, Body: ${response.body}');
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Meeting created successfully')),
          );
          _placeController.clear();
          _dateController.clear();
          _timeController.clear();
          setState(() {
            selectedMemberIds.clear();
          });
          await _fetchMeetings();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to create meeting: ${response.statusCode} - ${response.body}')),
          );
        }
      } catch (e) {
        debugPrint('Error creating meeting: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating meeting: $e')),
        );
      }
    }
  }

  Future<void> _cancelMeeting(Map<String, dynamic> meeting) async {
    try {
      final payload = {
        'Circle_ID': meeting['Circle_ID'].toString(),
        'Status': '2',
        'cirl_mt_status': '2',
        'images': meeting['images'] ?? [],
      };
      var uri = Uri.parse('https://tagai.caxis.ca/public/api/circle-meetings/${meeting['Circle_ID']}');
      debugPrint('Sending PUT request to $uri with payload: ${jsonEncode(payload)}');
      var response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 301 || response.statusCode == 302) {
        final newUrl = response.headers['location'];
        if (newUrl != null) {
          debugPrint('Following redirect to: $newUrl');
          uri = Uri.parse(newUrl);
          response = await http.put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );
        } else {
          debugPrint('Redirect location not found in ${response.statusCode} response');
        }
      }
      debugPrint('PUT Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Meeting cancelled successfully')),
        );
        await _fetchMeetings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel meeting: ${response.statusCode} - ${response.body}')),
        );
      }
    } catch (e) {
      debugPrint('Error cancelling meeting: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling meeting: $e')),
      );
    }
  }

  Future<void> _acceptMeeting(Map<String, dynamic> meeting) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userMId = prefs.getString('M_ID') ?? '1';
      final updatedToMIds = List<Map<String, dynamic>>.from(meeting['To_M_ID'] ?? []);
      for (var item in updatedToMIds) {
        if (item['id'].toString() == userMId) {
          item['cirl_mt_status'] = 1;
        }
      }
      final payload = {
        'Circle_ID': meeting['Circle_ID'].toString(),
        'To_M_ID': updatedToMIds,
      };
      var uri = Uri.parse('https://tagai.caxis.ca/public/api/circle-meetings/${meeting['Circle_ID']}');
      debugPrint('Sending PUT request to $uri with payload: ${jsonEncode(payload)}');
      var response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 301 || response.statusCode == 302) {
        final newUrl = response.headers['location'];
        if (newUrl != null) {
          debugPrint('Following redirect to: $newUrl');
          uri = Uri.parse(newUrl);
          response = await http.put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );
        } else {
          debugPrint('Redirect location not found in ${response.statusCode} response');
        }
      }
      debugPrint('PUT Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Meeting accepted successfully')),
        );
        await _fetchMeetings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept meeting: ${response.statusCode} - ${response.body}')),
        );
      }
    } catch (e) {
      debugPrint('Error accepting meeting: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting meeting: $e')),
      );
    }
  }

  Future<void> _rejectMeeting(Map<String, dynamic> meeting) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userMId = prefs.getString('M_ID') ?? '1';
      final updatedToMIds = List<Map<String, dynamic>>.from(meeting['To_M_ID'] ?? []);
      for (var item in updatedToMIds) {
        if (item['id'].toString() == userMId) {
          item['cirl_mt_status'] = 2;
        }
      }
      final payload = {
        'Circle_ID': meeting['Circle_ID'].toString(),
        'To_M_ID': updatedToMIds,
      };
      var uri = Uri.parse('https://tagai.caxis.ca/public/api/circle-meetings/${meeting['Circle_ID']}');
      debugPrint('Sending PUT request to $uri with payload: ${jsonEncode(payload)}');
      var response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 301 || response.statusCode == 302) {
        final newUrl = response.headers['location'];
        if (newUrl != null) {
          debugPrint('Following redirect to: $newUrl');
          uri = Uri.parse(newUrl);
          response = await http.put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );
        } else {
          debugPrint('Redirect location not found in ${response.statusCode} response');
        }
      }
      debugPrint('PUT Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Meeting rejected successfully')),
        );
        await _fetchMeetings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject meeting: ${response.statusCode} - ${response.body}')),
        );
      }
    } catch (e) {
      debugPrint('Error rejecting meeting: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting meeting: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black, // Black app bar
        title: Text(
          'Circle Meetings',
          style: TextStyle(color: Colors.white), // White text
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white), // White back arrow
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60.0), // Adjusted height for single-line tabs
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[400], // Lighter grey for unselected
            indicatorColor: Colors.white, // White indicator
            isScrollable: true,
            labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold), // Slightly larger font
            unselectedLabelStyle: TextStyle(fontSize: 13),
            indicatorWeight: 3.0, // Thicker indicator
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, size: 20),
                    SizedBox(width: 6), // Space between icon and text
                    Text('New'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mail_outline, size: 20),
                    SizedBox(width: 6),
                    Text('Requests'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_note, size: 20),
                    SizedBox(width: 6),
                    Text('My Meetings'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today, size: 20),
                    SizedBox(width: 6),
                    Text('Scheduled'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 20),
                    SizedBox(width: 6),
                    Text('History'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateMeetingTab(),
          _buildRequestsTab(),
          _buildMyMeetingsTab(),
          _buildScheduleMeetingsTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildCreateMeetingTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Card(
        elevation: 8, // Increased elevation
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // More rounded corners
        margin: EdgeInsets.zero,
        color: Colors.white, // White background
        child: Padding(
          padding: EdgeInsets.all(24.0), // Increased padding
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Schedule a New Meeting',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87, // Darker text for contrast
                      ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                TextFormField(
                  controller: _placeController,
                  decoration: InputDecoration(
                    labelText: 'Place',
                    hintText: 'e.g., Conference Room A',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), // Slightly more rounded input
                    ),
                    prefixIcon: Icon(Icons.location_on, color: Colors.black), // Black icon
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a place';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _dateController,
                  decoration: InputDecoration(
                    labelText: 'Date (YYYY-MM-DD)',
                    hintText: 'Select a date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.calendar_today, color: Colors.black), // Black icon
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a date';
                    }
                    return null;
                  },
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.black, // Header background color
                              onPrimary: Colors.white, // Header text color
                              onSurface: Colors.black87, // Body text color
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black, // Button text color
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      _dateController.text =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    }
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _timeController,
                  decoration: InputDecoration(
                    labelText: 'Time (HH:MM)',
                    hintText: 'Select a time',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.access_time, color: Colors.black), // Black icon
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a time';
                    }
                    return null;
                  },
                  onTap: () async {
                    TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.black, // Header background color
                              onPrimary: Colors.white, // Header text color
                              onSurface: Colors.black87, // Body text color
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black, // Button text color
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      _timeController.text =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    }
                  },
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'Select Members',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.people, color: Colors.black), // Black icon
                  ),
                  isExpanded: true,
                  items: members
                      .where((member) =>
                          member['status'] == '1' &&
                          member['M_ID'].toString() != fromMId)
                      .map((member) {
                    final memberId = int.parse(member['M_ID'].toString());
                    return DropdownMenuItem<int>(
                      value: memberId,
                      child: Row(
                        children: [
                          Checkbox(
                            value: selectedMemberIds.contains(memberId),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  if (!selectedMemberIds.contains(memberId)) {
                                    selectedMemberIds.add(memberId);
                                  }
                                } else {
                                  selectedMemberIds.remove(memberId);
                                }
                              });
                            },
                            activeColor: Colors.black, // Black checkbox
                          ),
                          Expanded(child: Text(member['Name'] ?? 'Unknown')),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {},
                  validator: (value) {
                    if (selectedMemberIds.isEmpty) {
                      return 'Please select at least one member';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                Text(
                  'Selected Members:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[50], // Light background for selected chips
                  ),
                  constraints: BoxConstraints(minHeight: 80),
                  child: selectedMemberIds.isEmpty
                      ? Center(
                          child: Text(
                            'No members selected',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: selectedMemberIds.map((memberId) {
                            final member = members.firstWhere(
                              (m) => int.parse(m['M_ID'].toString()) == memberId,
                              orElse: () => {
                                'Name': 'Unknown',
                                'M_ID': memberId,
                              },
                            );
                            return Chip(
                              label: Text(member['Name'] ?? 'Unknown'),
                              deleteIcon: Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  selectedMemberIds.remove(memberId);
                                });
                              },
                              backgroundColor: Colors.black.withOpacity(0.1), // Light black background
                              labelStyle: TextStyle(color: Colors.black87),
                              side: BorderSide(color: Colors.black.withOpacity(0.3)),
                            );
                          }).toList(),
                        ),
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: Icon(Icons.send),
                  label: Text('Create Meeting'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black, // Black button
                    foregroundColor: Colors.white, // White text
                    padding: EdgeInsets.symmetric(vertical: 14), // Slightly larger padding
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingList(List<Map<String, dynamic>> meetings, {bool showActions = true}) {
    return RefreshIndicator(
      onRefresh: _fetchMeetings,
      color: Colors.black, // Black refresh indicator
      child: meetings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 60, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'No meetings found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16.0),
              itemCount: meetings.length,
              itemBuilder: (context, index) {
                final meeting = meetings[index];
                final isCompleted = meeting['Status'] == '1';
                final isCancelled = meeting['Status'] == '2';

                Color textColor;
                IconData statusIcon;

                if (isCompleted) {
                  textColor = Colors.green[800]!; // Dark green for completed text
                  statusIcon = Icons.check_circle_outline;
                } else if (isCancelled) {
                  textColor = Colors.red[800]!; // Dark red for cancelled text
                  statusIcon = Icons.cancel_outlined;
                } else {
                  // Scheduled or Pending
                  textColor = Colors.black87; // Dark text for scheduled/pending
                  statusIcon = Icons.pending_actions;
                }

                return Card(
                  elevation: 6, // Increased elevation
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // More rounded corners
                  margin: EdgeInsets.symmetric(vertical: 10.0), // Increased margin
                  color: Colors.white, // White background for all cards
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MeetingDetailsPage(
                            meeting: meeting,
                            getMemberName: _getMemberName,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: EdgeInsets.all(16.0), // Increased padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: textColor, size: 24), // Larger icon
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  meeting['place'] ?? 'Unknown Place',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87, // Always dark text for title
                                      ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Date: ${meeting['date'] ?? 'N/A'}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                          ),
                          Text(
                            'Time: ${meeting['time'] ?? 'N/A'}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                          ),
                          if (showActions && !isCompleted && !isCancelled) ...[
                            SizedBox(height: 16),
                            Divider(color: Colors.grey[300]),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (_isMeetingPassed(meeting) && meeting['From_M_ID'].toString() == fromMId)
                                  ElevatedButton.icon(
                                    onPressed: () => _showMarkAsCompletedDialog(meeting),
                                    icon: Icon(Icons.done_all, size: 18),
                                    label: Text('Complete'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[700], // Green button
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      textStyle: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _cancelMeeting(meeting),
                                  icon: Icon(Icons.cancel, size: 18),
                                  label: Text('Cancel'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[700], // Red button
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    textStyle: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildRequestsTab() {
    return RefreshIndicator(
      onRefresh: _fetchMeetings,
      color: Colors.black,
      child: meetingRequests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 60, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'No pending meeting requests',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16.0),
              itemCount: meetingRequests.length,
              itemBuilder: (context, index) {
                final meeting = meetingRequests[index];
                return Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: EdgeInsets.symmetric(vertical: 10.0),
                  color: Colors.white, // White background
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MeetingDetailsPage(
                            meeting: meeting,
                            getMemberName: _getMemberName,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notification_important, color: Colors.black87, size: 24), // Dark icon
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  meeting['place'] ?? 'Unknown Place',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87, // Dark text
                                      ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Date: ${meeting['date'] ?? 'N/A'}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                          ),
                          Text(
                            'Time: ${meeting['time'] ?? 'N/A'}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                          ),
                          SizedBox(height: 16),
                          Divider(color: Colors.grey[300]),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _acceptMeeting(meeting),
                                icon: Icon(Icons.check, size: 18),
                                label: Text('Accept'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: TextStyle(fontSize: 13),
                                ),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _rejectMeeting(meeting),
                                icon: Icon(Icons.close, size: 18),
                                label: Text('Reject'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: TextStyle(fontSize: 13),
                                ),
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
    );
  }

  Widget _buildMyMeetingsTab() {
    return _buildMeetingList(myMeetings, showActions: true);
  }

  Widget _buildScheduleMeetingsTab() {
    return _buildMeetingList(scheduledMeetings, showActions: true);
  }

  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: _fetchMeetings,
      color: Colors.black,
      child: historyMeetings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive, size: 60, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'No past meetings in history',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16.0),
              itemCount: historyMeetings.length,
              itemBuilder: (context, index) {
                final meeting = historyMeetings[index];
                final isCompleted = meeting['Status'] == '1';
                final isCancelled = meeting['Status'] == '2';

                Color textColor = isCompleted
                    ? Colors.green[800]!
                    : Colors.red[800]!;
                IconData statusIcon = isCompleted ? Icons.check_circle : Icons.cancel;

                return Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: EdgeInsets.symmetric(vertical: 10.0),
                  color: Colors.white, // White background
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MeetingDetailsPage(
                            meeting: meeting,
                            getMemberName: _getMemberName,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: textColor, size: 24),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  meeting['place'] ?? 'Unknown Place',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Date: ${meeting['date'] ?? 'N/A'}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                          ),
                          Text(
                            'Time: ${meeting['time'] ?? 'N/A'}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Status: ${isCompleted ? 'Completed' : 'Cancelled'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _placeController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }
}

class MeetingDetailsPage extends StatelessWidget {
  final Map<String, dynamic> meeting;
  final Future<String> Function(String) getMemberName;

  const MeetingDetailsPage({
    Key? key,
    required this.meeting,
    required this.getMemberName,
  }) : super(key: key);

  Future<List<Map<String, String>>> _buildMemberNames() async {
    List<Map<String, String>> memberData = [];
    String statusText;
    // Add the "From" member
    final fromName = await getMemberName(meeting['From_M_ID'].toString());
    memberData.add({'name': fromName, 'status': ''}); // No status for From member
    // Add the "To" members with their status
    final toMIds = List<dynamic>.from(meeting['To_M_ID'] ?? []);
    for (var item in toMIds) {
      final mId = item['id'].toString();
      final status = item['cirl_mt_status'].toString();
      switch (status) {
        case '0':
          statusText = 'Pending';
          break;
        case '1':
          statusText = 'Accepted';
          break;
        case '2':
          statusText = 'Rejected';
          break;
        default:
          statusText = 'Unknown';
      }
      final name = await getMemberName(mId);
      memberData.add({'name': name, 'status': statusText});
    }
    return memberData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black, // Black app bar
        title: Text(
          'Meeting Details',
          style: TextStyle(color: Colors.white), // White text
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white), // White back arrow
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: FutureBuilder<List<Map<String, String>>>(
          future: _buildMemberNames(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: Colors.black)); // Black indicator
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text(
                'Error loading member names: ${snapshot.error}',
                style: TextStyle(color: Colors.red),
              ));
            }
            final memberData = snapshot.data ?? [];
            final fromMember = memberData.isNotEmpty ? memberData[0] : null;
            final toMembers = memberData.length > 1 ? memberData.sublist(1) : [];

            return ListView(
              children: [
                Card(
                  elevation: 6, // Increased elevation
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // More rounded corners
                  margin: EdgeInsets.only(bottom: 16),
                  color: Colors.white, // White background
                  child: Padding(
                    padding: EdgeInsets.all(20.0), // Increased padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meeting Information',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black, // Black title
                              ),
                        ),
                        Divider(color: Colors.grey[300]), // Lighter divider
                        _buildDetailRow(context, Icons.location_on, 'Place', meeting['place'] ?? 'N/A'),
                        _buildDetailRow(context, Icons.calendar_today, 'Date', meeting['date'] ?? 'N/A'),
                        _buildDetailRow(context, Icons.access_time, 'Time', meeting['time'] ?? 'N/A'),
                        _buildDetailRow(
                          context,
                          Icons.info_outline,
                          'Status',
                          meeting['Status'] == '1'
                              ? 'Completed'
                              : meeting['Status'] == '2'
                                  ? 'Cancelled'
                                  : 'Scheduled',
                          color: meeting['Status'] == '1'
                              ? Colors.green[700]
                              : meeting['Status'] == '2'
                                  ? Colors.red[700]
                                  : Colors.black, // Black for scheduled
                        ),
                        _buildDetailRow(context, Icons.group, 'Group ID', meeting['G_ID'] ?? 'N/A'),
                        _buildDetailRow(context, Icons.meeting_room, 'Circle ID', meeting['Circle_ID']?.toString() ?? 'N/A'),
                      ],
                    ),
                  ),
                ),
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: EdgeInsets.only(bottom: 16),
                  color: Colors.white, // White background
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Participants',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                        ),
                        Divider(color: Colors.grey[300]),
                        if (fromMember != null)
                          _buildParticipantRow(context, 'From', fromMember['name'] ?? 'N/A', null),
                        if (toMembers.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            'To:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          SizedBox(height: 4),
                          ...toMembers.map((data) => _buildParticipantRow(
                                context,
                                '',
                                data['name'] ?? 'N/A',
                                data['status'],
                              )),
                        ] else
                          _buildDetailRow(context, Icons.person_off, 'To', 'None'),
                      ],
                    ),
                  ),
                ),
                if (meeting['images'] != null && meeting['images'].isNotEmpty)
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.white, // White background
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meeting Images',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                          ),
                          Divider(color: Colors.grey[300]),
                          SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: meeting['images'].length,
                            itemBuilder: (context, index) {
                              final image = meeting['images'][index];
                              return image is String
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10), // Rounded image corners
                                      child: Image.network(
                                        image,
                                        height: 100,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey[200],
                                          child: Center(
                                            child: Icon(Icons.broken_image, color: Colors.grey[600]),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey[200],
                                      child: Center(
                                        child: Text('Invalid image format', style: TextStyle(color: Colors.red)),
                                      ),
                                    );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String title, String subtitle, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color ?? Colors.grey[700], size: 22), // Darker grey icons
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87, // Darker text
                      ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: color ?? Colors.black54, // Slightly lighter for subtitle
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantRow(BuildContext context, String label, String name, String? status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      child: Row(
        children: [
          Icon(Icons.person, size: 20, color: Colors.grey[700]),
          SizedBox(width: 8),
          if (label.isNotEmpty)
            Text(
              '$label: ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
          ),
          if (status != null && status.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                borderRadius: BorderRadius.circular(8), // More rounded status chip
              ),
              child: Text(
                status,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange[700]!;
      case 'Accepted':
        return Colors.green[700]!;
      case 'Rejected':
        return Colors.red[700]!;
      default:
        return Colors.grey[700]!;
    }
  }
}
