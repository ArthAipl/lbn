import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class CircleMeetingPage extends StatefulWidget {
  @override
  _CircleMeetingPageState createState() => _CircleMeetingPageState();
}

class _CircleMeetingPageState extends State<CircleMeetingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Circle Meetings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Create'),
            Tab(text: 'Requests'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CreateMeetingTab(),
          RequestsTab(),
          HistoryTab(),
        ],
      ),
    );
  }
}

class CreateMeetingTab extends StatefulWidget {
  @override
  _CreateMeetingTabState createState() => _CreateMeetingTabState();
}

class _CreateMeetingTabState extends State<CreateMeetingTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  List<String> _selectedParticipants = [];
  
  // Sample participants list
  final List<String> _availableParticipants = [
    'John Smith',
    'Sarah Johnson',
    'Mike Davis',
    'Emily Brown',
    'David Wilson',
    'Lisa Anderson',
    'Chris Taylor',
    'Amanda White',
    'Robert Garcia',
    'Jennifer Martinez',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Meeting Details'),
            SizedBox(height: 16),
            _buildTextField(
              controller: _titleController,
              label: 'Meeting Title',
              hint: 'Enter meeting title',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter meeting title';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Enter meeting description',
              maxLines: 3,
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: _locationController,
              label: 'Location',
              hint: 'Enter meeting location',
            ),
            SizedBox(height: 24),
            
            _buildSectionTitle('Date & Time'),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateSelector(),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildTimeSelector(),
                ),
              ],
            ),
            SizedBox(height: 24),
            
            _buildSectionTitle('Participants'),
            SizedBox(height: 16),
            _buildParticipantSelector(),
            SizedBox(height: 16),
            _buildSelectedParticipants(),
            SizedBox(height: 32),
            
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return InkWell(
      onTap: _selectTime,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              _selectedTime.format(context),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text('Select Participants'),
        children: _availableParticipants.map((participant) {
          return CheckboxListTile(
            title: Text(participant),
            value: _selectedParticipants.contains(participant),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedParticipants.add(participant);
                } else {
                  _selectedParticipants.remove(participant);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedParticipants() {
    if (_selectedParticipants.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No participants selected',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedParticipants.map((participant) {
        return Chip(
          label: Text(participant),
          deleteIcon: Icon(Icons.close, size: 18),
          onDeleted: () {
            setState(() {
              _selectedParticipants.remove(participant);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _createMeeting,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Create Circle Meeting',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _createMeeting() {
    if (_formKey.currentState!.validate()) {
      if (_selectedParticipants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select at least one participant')),
        );
        return;
      }

      // Here you would typically save the meeting to your database
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Circle meeting created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      setState(() {
        _selectedParticipants.clear();
        _selectedDate = DateTime.now();
        _selectedTime = TimeOfDay.now();
      });
    }
  }
}

class RequestsTab extends StatefulWidget {
  @override
  _RequestsTabState createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  // Sample meeting requests
  final List<MeetingRequest> _meetingRequests = [
    MeetingRequest(
      id: '1',
      title: 'Q4 Business Review',
      organizer: 'John Smith',
      date: DateTime.now().add(Duration(days: 3)),
      time: '10:00 AM',
      location: 'Conference Room A',
      participants: ['You', 'Sarah Johnson', 'Mike Davis'],
      status: RequestStatus.pending,
    ),
    MeetingRequest(
      id: '2',
      title: 'Product Strategy Meeting',
      organizer: 'Emily Brown',
      date: DateTime.now().add(Duration(days: 5)),
      time: '2:00 PM',
      location: 'Virtual Meeting',
      participants: ['You', 'David Wilson', 'Lisa Anderson'],
      status: RequestStatus.pending,
    ),
    MeetingRequest(
      id: '3',
      title: 'Team Building Session',
      organizer: 'Chris Taylor',
      date: DateTime.now().add(Duration(days: 7)),
      time: '4:00 PM',
      location: 'Outdoor Venue',
      participants: ['You', 'Amanda White', 'Robert Garcia'],
      status: RequestStatus.accepted,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _meetingRequests.length,
      itemBuilder: (context, index) {
        return _buildRequestCard(_meetingRequests[index]);
      },
    );
  }

  Widget _buildRequestCard(MeetingRequest request) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(request.status),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Organized by ${request.organizer}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  '${request.date.day}/${request.date.month}/${request.date.year}',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  request.time,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  request.location,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Participants: ${request.participants.join(', ')}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            if (request.status == RequestStatus.pending) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _respondToRequest(request.id, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red),
                      ),
                      child: Text(
                        'Decline',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _respondToRequest(request.id, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: Text(
                        'Accept',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(RequestStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case RequestStatus.pending:
        color = Colors.orange;
        text = 'Pending';
        break;
      case RequestStatus.accepted:
        color = Colors.green;
        text = 'Accepted';
        break;
      case RequestStatus.declined:
        color = Colors.red;
        text = 'Declined';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _respondToRequest(String requestId, bool accept) {
    setState(() {
      final index = _meetingRequests.indexWhere((req) => req.id == requestId);
      if (index != -1) {
        _meetingRequests[index] = _meetingRequests[index].copyWith(
          status: accept ? RequestStatus.accepted : RequestStatus.declined,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(accept ? 'Meeting accepted!' : 'Meeting declined!'),
        backgroundColor: accept ? Colors.green : Colors.red,
      ),
    );
  }
}

class HistoryTab extends StatelessWidget {
  // Sample meeting history
  final List<MeetingHistory> _meetingHistory = [
    MeetingHistory(
      id: '1',
      title: 'Monthly Team Sync',
      date: DateTime.now().subtract(Duration(days: 7)),
      time: '9:00 AM',
      location: 'Conference Room B',
      participants: ['John Smith', 'Sarah Johnson', 'Mike Davis', 'You'],
      status: MeetingStatus.completed,
      duration: '1h 30m',
    ),
    MeetingHistory(
      id: '2',
      title: 'Client Presentation',
      date: DateTime.now().subtract(Duration(days: 14)),
      time: '3:00 PM',
      location: 'Virtual Meeting',
      participants: ['Emily Brown', 'David Wilson', 'You'],
      status: MeetingStatus.completed,
      duration: '45m',
    ),
    MeetingHistory(
      id: '3',
      title: 'Project Kickoff',
      date: DateTime.now().subtract(Duration(days: 21)),
      time: '11:00 AM',
      location: 'Main Hall',
      participants: ['Lisa Anderson', 'Chris Taylor', 'Amanda White', 'You'],
      status: MeetingStatus.cancelled,
      duration: 'N/A',
    ),
    MeetingHistory(
      id: '4',
      title: 'Budget Review',
      date: DateTime.now().subtract(Duration(days: 28)),
      time: '2:00 PM',
      location: 'Finance Office',
      participants: ['Robert Garcia', 'Jennifer Martinez', 'You'],
      status: MeetingStatus.completed,
      duration: '2h 15m',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _meetingHistory.length,
      itemBuilder: (context, index) {
        return _buildHistoryCard(_meetingHistory[index]);
      },
    );
  }

  Widget _buildHistoryCard(MeetingHistory meeting) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    meeting.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildMeetingStatusChip(meeting.status),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  '${meeting.date.day}/${meeting.date.month}/${meeting.date.year}',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  meeting.time,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  meeting.location,
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(width: 16),
                Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  meeting.duration,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Participants: ${meeting.participants.join(', ')}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    // View meeting details
                  },
                  icon: Icon(Icons.visibility, size: 16),
                  label: Text('View Details'),
                ),
                if (meeting.status == MeetingStatus.completed)
                  TextButton.icon(
                    onPressed: () {
                      // Download meeting notes/summary
                    },
                    icon: Icon(Icons.download, size: 16),
                    label: Text('Download'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingStatusChip(MeetingStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case MeetingStatus.completed:
        color = Colors.green;
        text = 'Completed';
        break;
      case MeetingStatus.cancelled:
        color = Colors.red;
        text = 'Cancelled';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Data Models
class MeetingRequest {
  final String id;
  final String title;
  final String organizer;
  final DateTime date;
  final String time;
  final String location;
  final List<String> participants;
  final RequestStatus status;

  MeetingRequest({
    required this.id,
    required this.title,
    required this.organizer,
    required this.date,
    required this.time,
    required this.location,
    required this.participants,
    required this.status,
  });

  MeetingRequest copyWith({
    String? id,
    String? title,
    String? organizer,
    DateTime? date,
    String? time,
    String? location,
    List<String>? participants,
    RequestStatus? status,
  }) {
    return MeetingRequest(
      id: id ?? this.id,
      title: title ?? this.title,
      organizer: organizer ?? this.organizer,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      participants: participants ?? this.participants,
      status: status ?? this.status,
    );
  }
}

class MeetingHistory {
  final String id;
  final String title;
  final DateTime date;
  final String time;
  final String location;
  final List<String> participants;
  final MeetingStatus status;
  final String duration;

  MeetingHistory({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.participants,
    required this.status,
    required this.duration,
  });
}

enum RequestStatus { pending, accepted, declined }
enum MeetingStatus { completed, cancelled }
