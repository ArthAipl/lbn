import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class EventsAdminPage extends StatefulWidget {
  const EventsAdminPage({Key? key}) : super(key: key);

  @override
  State<EventsAdminPage> createState() => _EventsAdminPageState();
}

class _EventsAdminPageState extends State<EventsAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? userGId;
  String? mId;
  String? name;
  String? email;
  String? number;
  String? groupCode;
  String? roleId;
  String? groupName;
  String? shortGroupName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        userGId = prefs.getString('G_ID');
        mId = prefs.getString('M_ID');
        name = prefs.getString('Name');
        email = prefs.getString('email');
        number = prefs.getString('number');
        groupCode = prefs.getString('Grop_code');
        roleId = prefs.getString('role_id');
        groupName = prefs.getString('group_name');
        shortGroupName = prefs.getString('short_group_name');
      });
      debugPrint('Loaded user data: G_ID=$userGId, M_ID=$mId, Name=$name, Email=$email, Number=$number, Group_Code=$groupCode, Role_ID=$roleId, Group_Name=$groupName, Short_Group_Name=$shortGroupName');
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Events Admin',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4CAF50),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Create Event'),
            Tab(text: 'All Events'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CreateEventTab(userGId: userGId),
          AllEventsTab(userGId: userGId),
        ],
      ),
    );
  }
}

class CreateEventTab extends StatefulWidget {
  final String? userGId;
  const CreateEventTab({Key? key, this.userGId}) : super(key: key);

  @override
  State<CreateEventTab> createState() => _CreateEventTabState();
}

class _CreateEventTabState extends State<CreateEventTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _eventDescController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _eventMode = 'Compulsory';
  String? _selectedFeesCatId;

  List<Map<String, dynamic>> _feesCategories = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchFeesCategories();
  }

  Future<void> _fetchFeesCategories() async {
    setState(() {
      _isLoading = true;
    });
    try {
      debugPrint('Fetching fees categories from API...');
      final http.Response response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/fees-categories'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      debugPrint('Fees categories response status: ${response.statusCode}');
      debugPrint('Fees categories response body: ${response.body}');
      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'];
        } else {
          throw Exception('Unexpected response format');
        }
        setState(() {
          _feesCategories = data.cast<Map<String, dynamic>>();
        });
        debugPrint('Loaded ${_feesCategories.length} fees categories');
      } else {
        debugPrint('Failed to load fees categories: ${response.statusCode}');
        _showErrorSnackBar('Failed to load fees categories: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading fees categories: $e');
      _showErrorSnackBar('Error loading fees categories: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A1A1A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      debugPrint('Selected date: ${DateFormat('yyyy-MM-dd').format(picked)}');
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A1A1A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
      debugPrint('Selected time: ${picked.format(context)}');
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('Form validation failed');
      return;
    }
    if (_selectedDate == null) {
      debugPrint('No date selected');
      _showErrorSnackBar('Please select event date');
      return;
    }
    if (_selectedTime == null) {
      debugPrint('No time selected');
      _showErrorSnackBar('Please select event time');
      return;
    }
    if (_selectedFeesCatId == null) {
      debugPrint('No fees category selected');
      _showErrorSnackBar('Please select fees category');
      return;
    }
    if (widget.userGId == null) {
      debugPrint('User G_ID is null');
      _showErrorSnackBar('User ID not found. Please login again.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final String timeString = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

      debugPrint('Formatted time string: $timeString');

      final Map<String, dynamic> eventData = {
        'Event_Name': _eventNameController.text.trim(),
        'Event_Date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'Event_time': timeString,
        'Event_Mode': _eventMode,
        'Event_desc': _eventDescController.text.trim(),
        'Place': _placeController.text.trim(),
        'fees_cat_id': int.parse(_selectedFeesCatId!),
        'G_ID': int.parse(widget.userGId!),
        'M_ID': null,
      };

      debugPrint('Creating event with data: ${json.encode(eventData)}');

      final http.Response response = await http.post(
        Uri.parse('https://tagai.caxis.ca/public/api/event-cals'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(eventData),
      );

      debugPrint('Create event response status: ${response.statusCode}');
      debugPrint('Create event response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Event created successfully');
        _showSuccessSnackBar('Event created successfully!');
        _clearForm();
      } else if (response.statusCode == 422) {
        try {
          final dynamic errorData = json.decode(response.body);
          debugPrint('Validation errors: $errorData');

          String errorMessage = 'Validation failed:\n';
          if (errorData is Map) {
            if (errorData.containsKey('errors')) {
              final Map<String, dynamic> errors = errorData['errors'];
              errors.forEach((field, messages) {
                if (messages is List) {
                  errorMessage += '• $field: ${messages.join(', ')}\n';
                }
              });
            } else if (errorData.containsKey('message')) {
              errorMessage = errorData['message'];
            }
          }
          _showErrorSnackBar(errorMessage);
        } catch (e) {
          debugPrint('Error parsing validation response: $e');
          _showErrorSnackBar('Validation failed. Please check all fields.');
        }
      } else {
        String errorMessage = 'Failed to create event (Status: ${response.statusCode})';
        try {
          final dynamic errorData = json.decode(response.body);
          if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }
        debugPrint('Failed to create event: $errorMessage');
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      debugPrint('Exception creating event: $e');
      _showErrorSnackBar('Error creating event: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _clearForm() {
    _eventNameController.clear();
    _eventDescController.clear();
    _placeController.clear();
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
      _eventMode = 'Compulsory';
      _selectedFeesCatId = null;
    });
    debugPrint('Form cleared');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53E3E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF38A169),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffixIcon,
          labelStyle: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 14,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE53E3E)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE53E3E), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDateTimeField({
    required String label,
    required String value,
    required VoidCallback onTap,
    required IconData icon,
    String? errorText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorText != null ? const Color(0xFFE53E3E) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF6B7280), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: value.contains('Select') ? const Color(0xFF9CA3AF) : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        errorText,
                        style: const TextStyle(
                          color: Color(0xFFE53E3E),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Event',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fill in the details below to create a new event',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 32),

              _buildTextField(
                controller: _eventNameController,
                label: 'Event Name *',
                hint: 'Enter event name',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter event name';
                  }
                  return null;
                },
              ),

              _buildDateTimeField(
                label: 'Event Date *',
                value: _selectedDate != null
                    ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                    : 'Select Date',
                onTap: _selectDate,
                icon: Icons.calendar_today,
                errorText: _selectedDate == null && _isSubmitting ? 'Please select date' : null,
              ),

              _buildDateTimeField(
                label: 'Event Time *',
                value: _selectedTime != null
                    ? _selectedTime!.format(context)
                    : 'Select Time',
                onTap: _selectTime,
                icon: Icons.access_time,
                errorText: _selectedTime == null && _isSubmitting ? 'Please select time' : null,
              ),

              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: DropdownButtonFormField<String>(
                  value: _eventMode,
                  decoration: InputDecoration(
                    labelText: 'Event Mode *',
                    labelStyle: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  items: ['Compulsory', 'Optional'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _eventMode = newValue!;
                    });
                    debugPrint('Selected event mode: $newValue');
                  },
                ),
              ),

              _buildTextField(
                controller: _eventDescController,
                label: 'Event Description *',
                hint: 'Enter event description',
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter event description';
                  }
                  return null;
                },
              ),

              _buildTextField(
                controller: _placeController,
                label: 'Place *',
                hint: 'Enter event location',
                suffixIcon: const Icon(Icons.location_on, color: Color(0xFF6B7280)),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter place';
                  }
                  return null;
                },
              ),

              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: _isLoading
                    ? Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 16),
                            Text('Loading fees categories...'),
                          ],
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        value: _selectedFeesCatId,
                        decoration: InputDecoration(
                          labelText: 'Fees Category *',
                          labelStyle: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        hint: const Text('Select fees category'),
                        items: _feesCategories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category['fees_cat_id'].toString(),
                            child: Text(
                              '${category['Desc']} - ₹${category['Amount']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedFeesCatId = newValue;
                          });
                          debugPrint('Selected fees category ID: $newValue');
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select fees category';
                          }
                          return null;
                        },
                      ),
              ),

              if (_feesCategories.isEmpty && !_isLoading)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE69C)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Color(0xFFB45309)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No fees categories available. Please check your internet connection.',
                          style: TextStyle(color: Color(0xFFB45309)),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _createEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Creating Event...'),
                          ],
                        )
                      : const Text(
                          'Create Event',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _eventDescController.dispose();
    _placeController.dispose();
    super.dispose();
  }
}

class AllEventsTab extends StatefulWidget {
  final String? userGId;
  const AllEventsTab({Key? key, this.userGId}) : super(key: key);

  @override
  State<AllEventsTab> createState() => _AllEventsTabState();
}

class _AllEventsTabState extends State<AllEventsTab> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    if (widget.userGId == null) {
      debugPrint('Cannot fetch events: User G_ID is null');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Fetching events for G_ID: ${widget.userGId}');
      final http.Response response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/event-cals'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      debugPrint('Events response status: ${response.statusCode}');
      debugPrint('Events response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'];
        } else {
          throw Exception('Unexpected response format');
        }

        final List<Map<String, dynamic>> filteredEvents = data
            .cast<Map<String, dynamic>>()
            .where((event) => event['G_ID'].toString() == widget.userGId)
            .toList();

        setState(() {
          _events = filteredEvents;
        });

        debugPrint('Total events from API: ${data.length}');
        debugPrint('Filtered events for user: ${_events.length}');
      } else {
        debugPrint('Failed to load events: ${response.statusCode}');
        _showErrorSnackBar('Failed to load events: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading events: $e');
      _showErrorSnackBar('Error loading events: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53E3E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _openEventDetails(Map<String, dynamic> event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsPage(event: event),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF1A1A1A)),
            SizedBox(height: 16),
            Text(
              'Loading events...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.event_busy,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No events found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first event to get started',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchEvents,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchEvents,
      color: const Color(0xFF1A1A1A),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final Map<String, dynamic> event = _events[index];
          final Map<String, dynamic>? feesCategory = event['fees_category'];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
              child: InkWell(
                onTap: () => _openEventDetails(event),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event['Event_Name'] ?? 'No Name',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: event['Event_Mode'] == 'Compulsory'
                                  ? const Color(0xFFEF4444).withOpacity(0.1)
                                  : const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              event['Event_Mode'] ?? 'No Mode',
                              style: TextStyle(
                                color: event['Event_Mode'] == 'Compulsory'
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Date and Time Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              event['Event_Date'] != null
                                  ? DateFormat('MMM dd, yyyy').format(DateTime.parse(event['Event_Date']))
                                  : 'No Date',
                              style: const TextStyle(
                                color: Color(0xFF374151),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              event['Event_time'] ?? 'No Time',
                              style: const TextStyle(
                                color: Color(0xFF374151),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Location Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              event['Place'] ?? 'No Place',
                              style: const TextStyle(
                                color: Color(0xFF374151),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(
                        event['Event_desc'] ?? 'No Description',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (feesCategory != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF10B981).withOpacity(0.1),
                                const Color(0xFF059669).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  feesCategory['Desc'] ?? 'No Category',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF374151),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '₹${feesCategory['Amount'] ?? '0'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tap to view details',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Color(0xFF9CA3AF),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class EventDetailsPage extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailsPage({Key? key, required this.event}) : super(key: key);

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  List<Map<String, dynamic>> _attendingMembers = [];
  List<Map<String, dynamic>> _notAttendingMembers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchEventTracks();
  }

  Future<void> _fetchEventTracks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String? eventCalId = widget.event['Ev_Cal_Id']?.toString();
      debugPrint('Fetching event tracks for Ev_Cal_Id: $eventCalId');

      final http.Response response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/event-tracks'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      debugPrint('Event tracks response status: ${response.statusCode}');
      debugPrint('Event tracks response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'];
        } else {
          throw Exception('Unexpected response format');
        }

        final List<Map<String, dynamic>> filteredTracks = data
            .cast<Map<String, dynamic>>()
            .where((track) => track['Ev_Cal_Id'].toString() == eventCalId)
            .toList();

        final List<Map<String, dynamic>> attending = filteredTracks
            .where((track) => track['Status'].toString() == '1')
            .toList();

        final List<Map<String, dynamic>> notAttending = filteredTracks
            .where((track) => track['Status'].toString() == '2')
            .toList();

        setState(() {
          _attendingMembers = attending;
          _notAttendingMembers = notAttending;
        });

        debugPrint('Total tracks: ${filteredTracks.length}');
        debugPrint('Attending: ${attending.length}');
        debugPrint('Not attending: ${notAttending.length}');
      } else {
        debugPrint('Failed to load event tracks: ${response.statusCode}');
        _showErrorSnackBar('Failed to load event tracks: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading event tracks: $e');
      _showErrorSnackBar('Error loading event tracks: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53E3E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, bool isAttending) {
    final Map<String, dynamic>? memberData = member['member'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAttending
              ? const Color(0xFF10B981).withOpacity(0.3)
              : const Color(0xFFEF4444).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isAttending
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.person,
              color: isAttending ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memberData != null ? (memberData['Name'] ?? 'Unknown Member') : 'Unknown Member',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (memberData != null && memberData['Mobile'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    memberData['Mobile'].toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isAttending
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAttending ? 'Attending' : 'Not Attending',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? feesCategory = widget.event['fees_category'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Event Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Info Card
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.event['Event_Name'] ?? 'No Name',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.event['Event_Mode'] == 'Compulsory'
                              ? const Color(0xFFEF4444).withOpacity(0.1)
                              : const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.event['Event_Mode'] ?? 'No Mode',
                          style: TextStyle(
                            color: widget.event['Event_Mode'] == 'Compulsory'
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Date and Time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Date',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              widget.event['Event_Date'] != null
                                  ? DateFormat('MMM dd, yyyy').format(DateTime.parse(widget.event['Event_Date']))
                                  : 'No Date',
                              style: const TextStyle(
                                color: Color(0xFF374151),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.access_time,
                          size: 20,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Time',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              widget.event['Event_time'] ?? 'No Time',
                              style: const TextStyle(
                                color: Color(0xFF374151),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          size: 20,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Location',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              widget.event['Place'] ?? 'No Place',
                              style: const TextStyle(
                                color: Color(0xFF374151),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Description',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.event['Event_desc'] ?? 'No Description',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF374151),
                      height: 1.6,
                    ),
                  ),

                  if (feesCategory != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withOpacity(0.1),
                            const Color(0xFF059669).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Fees Category',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  feesCategory['Desc'] ?? 'No Category',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Color(0xFF374151),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '₹${feesCategory['Amount'] ?? '0'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Attendance Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Attending: ${_attendingMembers.length}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Not Attending: ${_notAttendingMembers.length}',
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_isLoading) ...[
              const SizedBox(height: 40),
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A1A1A)),
              ),
            ] else ...[
              // Attending Members
              if (_attendingMembers.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: const Text(
                    'Attending Members',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: _attendingMembers
                        .map((member) => _buildMemberCard(member, true))
                        .toList(),
                  ),
                ),
              ],

              // Not Attending Members
              if (_notAttendingMembers.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: const Text(
                    'Not Attending Members',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: _notAttendingMembers
                        .map((member) => _buildMemberCard(member, false))
                        .toList(),
                  ),
                ),
              ],

              if (_attendingMembers.isEmpty && _notAttendingMembers.isEmpty) ...[
                Container(
                  margin: const EdgeInsets.all(40),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Color(0xFF9CA3AF),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No attendance data available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
