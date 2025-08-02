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
      debugPrint('Retrieving user data from SharedPreferences');
      // Retrieve user data from SharedPreferences (assuming set during login)
      final name = prefs.getString('Name') ?? '';
      final email = prefs.getString('email') ?? '';
      final number = prefs.getString('number') ?? '';
      final groupCode = prefs.getString('Grop_code') ?? '';
      final gId = prefs.getString('G_ID');
      final roleId = prefs.getString('role_id') ?? '';
      final mId = prefs.getString('M_ID');
      final groupName = prefs.getString('group_name') ?? '';
      final shortGroupName = prefs.getString('short_group_name') ?? '';

      // Log all SharedPreferences for debugging
      final allKeys = prefs.getKeys();
      debugPrint('SharedPreferences contents:');
      for (var key in allKeys) {
        debugPrint('$key: ${prefs.getString(key)}');
      }

      setState(() {
        this.gId = gId;
        debugPrint('Retrieved G_ID: $gId');
      });

      if (gId == null || gId.isEmpty) {
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
        // Log all G_IDs in the response to help identify valid ones
        final gIds = data.map((meeting) => meeting['G_ID']?.toString()).toSet().toList();
        debugPrint('Available G_IDs in API response: $gIds');
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Meetings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
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
      if (widget.gId == null || widget.gId!.isEmpty) {
        debugPrint('Error: G_ID is null or empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group ID is missing. Please log in again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => isLoading = true);
      final meetingData = {
        'G_ID': int.tryParse(widget.gId!) ?? widget.gId, // Try integer, fallback to string
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
          final errorBody = jsonDecode(response.body);
          final errorMessage = errorBody['message']?['G_ID']?.join(', ') ?? errorBody['error'] ?? 'Unknown error';
          debugPrint('Error creating meeting: Status: ${response.statusCode}, Message: $errorMessage');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to create meeting: $errorMessage. Please verify the Group ID.'),
                backgroundColor: Colors.red,
              ),
            );
          }
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
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _placeController,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Place',
                    prefixIcon: Icon(Icons.place, color: Colors.black54),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  validator: (value) => value!.isEmpty ? 'Enter a place' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location Details',
                    prefixIcon: Icon(Icons.location_on, color: Colors.black54),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
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
                    prefixIcon: Icon(Icons.calendar_today, color: Colors.black54),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
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
                    prefixIcon: Icon(Icons.access_time, color: Colors.black54),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
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
                    prefixIcon: Icon(Icons.schedule, color: Colors.black54),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  validator: (value) => value == null ? 'Select a schedule' : null,
                ),
                const SizedBox(height: 24),
                const Text('Presentation Slots', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                        activeColor: Colors.black,
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
                        activeColor: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : _createMeeting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Meeting', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
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
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        onTap: () {
                          debugPrint('Navigating to MeetingDetailsPage for meeting ${meeting['M_C_Id']}');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MeetingDetailsPage(
                                meeting: meeting,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.event, color: Colors.black87),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      meeting['Place'] ?? 'Unknown Place',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: meeting['Attn_Status'] == '1' ? Colors.green[100] : Colors.orange[100],
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      meeting['Attn_Status'] == '1' ? 'Confirmed' : 'Pending',
                                      style: TextStyle(
                                        color: meeting['Attn_Status'] == '1' ? Colors.green[800] : Colors.orange[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                                  const SizedBox(width: 5),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                                  ),
                                  const SizedBox(width: 15),
                                  const Icon(Icons.access_time, size: 16, color: Colors.black54),
                                  const SizedBox(width: 5),
                                  Text(
                                    meeting['Meeting_Time'] ?? 'N/A',
                                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16, color: Colors.black54),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      meeting['G_Location'] ?? 'No location details',
                                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                                      overflow: TextOverflow.ellipsis,
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
}

class MeetingDetailsPage extends StatefulWidget {
  final dynamic meeting;
  const MeetingDetailsPage({super.key, required this.meeting});

  @override
  State<MeetingDetailsPage> createState() => _MeetingDetailsPageState();
}

class _MeetingDetailsPageState extends State<MeetingDetailsPage> with SingleTickerProviderStateMixin {
  List<dynamic> visitors = [];
  List<dynamic> presentations = [];
  bool isLoadingVisitors = true;
  bool isLoadingPresentations = true;
  late TabController _detailTabController;

  @override
  void initState() {
    super.initState();
    _detailTabController = TabController(length: 2, vsync: this);
    debugPrint('Initializing MeetingDetailsPage for meetingId: ${widget.meeting['M_C_Id']}');
    _fetchVisitors();
    _fetchPresentations();
  }

  @override
  void dispose() {
    _detailTabController.dispose();
    super.dispose();
  }

  Future<void> _fetchVisitors() async {
    debugPrint('Starting _fetchVisitors for meetingId: ${widget.meeting['M_C_Id']}');
    try {
      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/visitor-invites'));
      debugPrint('Visitors response status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          visitors = data.where((visitor) => visitor['M_C_Id'].toString() == widget.meeting['M_C_Id'].toString()).toList();
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

  Future<void> _fetchPresentations() async {
    debugPrint('Starting _fetchPresentations for meetingId: ${widget.meeting['M_C_Id']}');
    try {
      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/pres-tracks'));
      debugPrint('Presentations response status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          presentations = data.where((pres) => pres['M_C_Id'].toString() == widget.meeting['M_C_Id'].toString()).toList();
          isLoadingPresentations = false;
        });
        debugPrint('Presentations fetched successfully: ${presentations.length} found');
        debugPrint('Filtered presentations: $presentations');
      } else {
        throw Exception('Failed to load presentations. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching presentations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading presentations: $e')));
      }
      setState(() => isLoadingPresentations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = 'N/A';
    try {
      formattedDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(widget.meeting['Meeting_Date']));
    } catch (e) {
      debugPrint('Error parsing date for meeting details: $e');
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _detailTabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Visitors'),
            Tab(text: 'Presentations'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.meeting['Place'] ?? 'Unknown Place',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20, color: Colors.black54),
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                        const SizedBox(width: 20),
                        const Icon(Icons.access_time, size: 20, color: Colors.black54),
                        const SizedBox(width: 8),
                        Text(
                          widget.meeting['Meeting_Time'] ?? 'N/A',
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 20, color: Colors.black54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.meeting['G_Location'] ?? 'No location details provided.',
                            style: const TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 20, color: Colors.black54),
                        const SizedBox(width: 8),
                        Text(
                          'Schedule: ${widget.meeting['schedule'] ?? 'N/A'}',
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                        const SizedBox(width: 20),
                        const Icon(Icons.slideshow, size: 20, color: Colors.black54),
                        const SizedBox(width: 8),
                        Text(
                          'Slot: ${widget.meeting['slot'] ?? 'N/A'}',
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20, color: Colors.black54),
                        const SizedBox(width: 8),
                        Text(
                          'Status: ${widget.meeting['Attn_Status'] == '1' ? 'Confirmed' : 'Pending'}',
                          style: TextStyle(
                            fontSize: 16,
                            color: widget.meeting['Attn_Status'] == '1' ? Colors.green[700] : Colors.orange[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _detailTabController,
              children: [
                isLoadingVisitors
                    ? const Center(child: CircularProgressIndicator())
                    : visitors.isEmpty
                        ? const Center(child: Text('No visitors found for this meeting.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: visitors.length,
                            itemBuilder: (context, index) {
                              final visitor = visitors[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Colors.black,
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                  title: Text(
                                    visitor['Visitor_Name'] ?? 'Unknown Visitor',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(visitor['Visitor_Email'] ?? 'No email provided'),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: visitor['Status'] == 'Confirmed' ? Colors.green[100] : Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      visitor['Status'] ?? 'Pending',
                                      style: TextStyle(
                                        color: visitor['Status'] == 'Confirmed' ? Colors.green[800] : Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                isLoadingPresentations
                    ? const Center(child: CircularProgressIndicator())
                    : presentations.isEmpty
                        ? const Center(child: Text('No presentations found for this meeting.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: presentations.length,
                            itemBuilder: (context, index) {
                              final presentation = presentations[index];
                              final member = presentation['member'];
                              final presenterName = member != null ? member['Name'] ?? 'Unknown Presenter' : 'Unknown Presenter';
                              final presenterEmail = member != null ? member['email'] ?? 'N/A' : 'N/A';
                              final presenterNumber = member != null ? member['number'] ?? 'N/A' : 'N/A';
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Colors.black,
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                  title: Text(
                                    presenterName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Email: $presenterEmail'),
                                      Text('Number: $presenterNumber'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}