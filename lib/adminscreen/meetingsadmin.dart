import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class MeetingAdminPage extends StatefulWidget {
  const MeetingAdminPage({super.key});

  @override
  State<MeetingAdminPage> createState() => _MeetingAdminPageState();
}

class _MeetingAdminPageState extends State<MeetingAdminPage> with SingleTickerProviderStateMixin {
  List<dynamic> meetings = [];
  String? gId;
  bool isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    debugPrint('Initializing MeetingAdminPage, calling _loadUserData');
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    debugPrint('Disposing MeetingAdminPage');
    super.dispose();
  }

  Future<void> _loadUserData() async {
    debugPrint('Starting _loadUserData');
    try {
      final prefs = await SharedPreferences.getInstance();
      debugPrint('Saving user data to SharedPreferences');

      // TODO: Replace with actual API call to fetch user data
      // Example:
      // final userData = await fetchUserDataFromApi();
      final userData = {
        'name': 'John Doe',
        'email': 'john.doe@example.com',
        'number': '1234567890',
        'group_code': 'GRP123',
        'g_id': '1', // Set to '1' to match API response for testing
        'role_id': '2', // Admin role
        'm_id': 'member123', // Only used if role_id is '3'
        'group_name': 'Aark Infosoft Pvt Ltd', // Match API response
        'short_group_name': 'Aark', // Match API response
      };

      // Save user data to SharedPreferences
      String roleId = userData['role_id']?.toString() ?? '';
      String? mId = userData['m_id']?.toString();
      await prefs.setString('Name', userData['name']?.toString() ?? '');
      await prefs.setString('email', userData['email']?.toString() ?? '');
      await prefs.setString('number', userData['number']?.toString() ?? '');
      await prefs.setString('Grop_code', userData['group_code']?.toString() ?? '');
      await prefs.setString('G_ID', userData['g_id']?.toString() ?? '');
      await prefs.setString('role_id', roleId);

      if (roleId == '3') {
        await prefs.setString('M_ID', mId ?? '');
        debugPrint('Saved M_ID: $mId for member role');
      }
      if (roleId == '2') {
        await prefs.setString('group_name', userData['group_name']?.toString() ?? '');
        await prefs.setString('short_group_name', userData['short_group_name']?.toString() ?? '');
        debugPrint('Saved admin fields: group_name and short_group_name');
      }

      // Log all SharedPreferences for debugging
      final allKeys = prefs.getKeys();
      debugPrint('SharedPreferences contents:');
      for (var key in allKeys) {
        debugPrint('$key: ${prefs.getString(key)}');
      }

      setState(() {
        gId = prefs.getString('G_ID');
        debugPrint('Retrieved G_ID: $gId');
      });

      if (gId == null) {
        debugPrint('Error: G_ID not found in SharedPreferences');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group ID not found. Please log in again.')),
          );
        }
        setState(() {
          isLoading = false;
        });
        return;
      }

      debugPrint('G_ID found, proceeding to fetch meetings');
      await _fetchMeetings();
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user data: $e')),
        );
      }
    }
  }

  Future<void> _fetchMeetings() async {
    debugPrint('Starting _fetchMeetings with G_ID: $gId');
    try {
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/meeting-cals'),
      );

      debugPrint('Received response with status code: ${response.statusCode}');
      debugPrint('Raw API response: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Parsed API response data: $data');
        setState(() {
          meetings = data.where((meeting) {
            final meetingGId = meeting['G_ID']?.toString();
            debugPrint('Checking meeting G_ID: $meetingGId against $gId');
            return meetingGId == gId;
          }).toList();
          isLoading = false;
        });
        debugPrint('Meetings fetched successfully: ${meetings.length} found');
        debugPrint('Filtered meetings: $meetings');
      } else {
        throw Exception('Failed to load meetings. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching meetings: $e');
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading meetings: $e')),
        );
      }
    }
  }

  void _onMeetingCreated() {
    debugPrint('Meeting created, refreshing meetings');
    _fetchMeetings();
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building MeetingAdminPage, isLoading: $isLoading, gId: $gId');
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Meetings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Create Meeting'),
            Tab(text: 'All Meetings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CreateMeetingTab(gId: gId, onMeetingCreated: _onMeetingCreated),
          AllMeetingsTab(meetings: meetings, isLoading: isLoading, onRefresh: _fetchMeetings),
        ],
      ),
    );
  }
}

class CreateMeetingTab extends StatefulWidget {
  final String? gId;
  final VoidCallback onMeetingCreated;

  const CreateMeetingTab({super.key, required this.gId, required this.onMeetingCreated});

  @override
  State<CreateMeetingTab> createState() => _CreateMeetingTabState();
}

class _CreateMeetingTabState extends State<CreateMeetingTab> {
  final _formKey = GlobalKey<FormState>();
  final _placeController = TextEditingController();
  final _locationController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  int? _selectedSlot;
  String? _selectedSchedule;
  final List<String> schedules = ['weekly', 'fortnight', 'monthly'];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    debugPrint('Initializing CreateMeetingTab, gId: ${widget.gId}');
  }

  Future<void> _selectDate(BuildContext context) async {
    debugPrint('Opening date picker');
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.black, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
        debugPrint('Selected date: ${_dateController.text}');
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    debugPrint('Opening time picker');
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.black, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        final now = DateTime.now();
        _timeController.text = DateFormat('HH:mm').format(
          DateTime(now.year, now.month, now.day, picked.hour, picked.minute),
        );
        debugPrint('Selected time: ${_timeController.text}');
      });
    }
  }

  Future<void> _createMeeting() async {
    debugPrint('Attempting to create meeting');
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);
      final meetingData = {
        'G_ID': widget.gId,
        'M_ID': null,
        'Meeting_Date': _dateController.text,
        'Meeting_Time': _timeController.text,
        'Place': _placeController.text,
        'G_Location': _locationController.text,
        'Meet_Cate': 'General',
        'slot': _selectedSlot?.toString(),
        'schedule': _selectedSchedule ?? 'weekly',
        'Attn_Status': '1',
      };
      debugPrint('Meeting Data Payload: ${jsonEncode(meetingData)}');
      try {
        final response = await http.post(
          Uri.parse('https://tagai.caxis.ca/public/api/meeting-cals'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(meetingData),
        );
        debugPrint('Create meeting response: ${response.statusCode}, Body: ${response.body}');
        setState(() => isLoading = false);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Meeting created successfully'),
                backgroundColor: Colors.green,
              ),
            );
            _placeController.clear();
            _locationController.clear();
            _dateController.clear();
            _timeController.clear();
            setState(() {
              _selectedSlot = null;
              _selectedSchedule = null;
            });
            widget.onMeetingCreated();
          }
        } else {
          throw Exception('Failed to create meeting. Status: ${response.statusCode}, Body: ${response.body}');
        }
      } catch (e) {
        debugPrint('Error creating meeting: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating meeting: $e'), backgroundColor: Colors.red),
          );
        }
        setState(() => isLoading = false);
      }
    } else {
      debugPrint('Form validation failed');
    }
  }

  @override
  void dispose() {
    debugPrint('Disposing CreateMeetingTab');
    _placeController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building CreateMeetingTab, gId: ${widget.gId}');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _placeController,
              decoration: const InputDecoration(
                labelText: 'Meeting Place',
                icon: Icon(Icons.place),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? 'Enter a place' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location Details',
                icon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? 'Enter a location' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              onTap: () => _selectDate(context),
              decoration: const InputDecoration(
                labelText: 'Meeting Date',
                icon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? 'Select a date' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _timeController,
              readOnly: true,
              onTap: () => _selectTime(context),
              decoration: const InputDecoration(
                labelText: 'Meeting Time',
                icon: Icon(Icons.access_time),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? 'Select a time' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSchedule,
              hint: const Text('Select schedule'),
              items: schedules
                  .map((schedule) => DropdownMenuItem(value: schedule, child: Text(schedule)))
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedSchedule = value;
                debugPrint('Selected schedule: $value');
              }),
              decoration: const InputDecoration(
                labelText: 'Schedule',
                icon: Icon(Icons.schedule),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null ? 'Select a schedule' : null,
            ),
            const SizedBox(height: 16),
            const Text('Presentation Slots', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<int>(
                    value: 1,
                    groupValue: _selectedSlot,
                    onChanged: (value) => setState(() {
                      _selectedSlot = value;
                      debugPrint('Selected slot: $value');
                    }),
                    title: const Text('1'),
                  ),
                ),
                Expanded(
                  child: RadioListTile<int>(
                    value: 2,
                    groupValue: _selectedSlot,
                    onChanged: (value) => setState(() {
                      _selectedSlot = value;
                      debugPrint('Selected slot: $value');
                    }),
                    title: const Text('2'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : _createMeeting,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Create Meeting'),
            ),
          ],
        ),
      ),
    );
  }
}

class AllMeetingsTab extends StatelessWidget {
  final List<dynamic> meetings;
  final bool isLoading;
  final VoidCallback onRefresh;

  const AllMeetingsTab({super.key, required this.meetings, required this.isLoading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    debugPrint('Building AllMeetingsTab, meetings count: ${meetings.length}, isLoading: $isLoading');
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : meetings.isEmpty
              ? const Center(child: Text('No meetings found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: meetings.length,
                  itemBuilder: (context, index) {
                    final meeting = meetings[index];
                    String formattedDate = 'N/A';
                    try {
                      formattedDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(meeting['Meeting_Date']));
                    } catch (e) {
                      debugPrint('Error parsing date for meeting ${meeting['M_C_Id']}: $e');
                    }
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.event),
                        title: Text(meeting['Place'] ?? 'Unknown Place'),
                        subtitle: Text(formattedDate),
                        trailing: Text(meeting['Attn_Status'] == '1' ? 'Confirmed' : 'Pending'),
                        onTap: () {
                          debugPrint('Navigating to VisitorsPage for meeting ${meeting['M_C_Id']}');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VisitorsPage(
                                meetingId: meeting['M_C_Id'].toString(),
                                meetingTitle: meeting['Place'] ?? 'Meeting',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

class VisitorsPage extends StatefulWidget {
  final String meetingId;
  final String meetingTitle;

  const VisitorsPage({super.key, required this.meetingId, required this.meetingTitle});

  @override
  State<VisitorsPage> createState() => _VisitorsPageState();
}

class _VisitorsPageState extends State<VisitorsPage> {
  List<dynamic> visitors = [];
  bool isLoadingVisitors = true;

  @override
  void initState() {
    super.initState();
    debugPrint('Initializing VisitorsPage for meetingId: ${widget.meetingId}');
    _fetchVisitors();
  }

  Future<void> _fetchVisitors() async {
    debugPrint('Starting _fetchVisitors for meetingId: ${widget.meetingId}');
    try {
      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/visitor-invites'));
      debugPrint('Visitors response status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          visitors = data.where((visitor) => visitor['M_C_Id'].toString() == widget.meetingId).toList();
          isLoadingVisitors = false;
        });
        debugPrint('Visitors fetched successfully: ${visitors.length} found');
        debugPrint('Filtered visitors: $visitors');
      } else {
        throw Exception('Failed to load visitors. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching visitors: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading visitors: $e')));
      }
      setState(() => isLoadingVisitors = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building VisitorsPage, isLoadingVisitors: $isLoadingVisitors');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Visitors'),
      ),
      body: isLoadingVisitors
          ? const Center(child: CircularProgressIndicator())
          : visitors.isEmpty
              ? const Center(child: Text('No visitors found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: visitors.length,
                  itemBuilder: (context, index) {
                    final visitor = visitors[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(visitor['Visitor_Name'] ?? 'Unknown'),
                        subtitle: Text(visitor['Visitor_Email'] ?? 'No email'),
                        trailing: Text(visitor['Status'] ?? 'Pending'),
                      ),
                    );
                  },
                ),
    );
  }
}