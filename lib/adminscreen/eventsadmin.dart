import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ==================== MODEL CLASSES ====================

class Event {
  final int? evCalId;
  final String eventName;
  final String eventDate;
  final String eventMode;
  final String place;
  final String feesCatId;
  final String gId;
  final String mId;
  final String? createdAt;
  final String? updatedAt;
  final FeesCategory? feesCategory;
  final GroupMaster? groupMaster;
  final Member? member;

  Event({
    this.evCalId,
    required this.eventName,
    required this.eventDate,
    required this.eventMode,
    required this.place,
    required this.feesCatId,
    required this.gId,
    required this.mId,
    this.createdAt,
    this.updatedAt,
    this.feesCategory,
    this.groupMaster,
    this.member,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      evCalId: json['Ev_Cal_Id'],
      eventName: json['Event_Name'],
      eventDate: json['Event_Date'],
      eventMode: json['Event_Mode'],
      place: json['Place'],
      feesCatId: json['fees_cat_id'].toString(),
      gId: json['G_ID'].toString(),
      mId: json['M_ID'].toString(),
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      feesCategory: json['fees_category'] != null
          ? FeesCategory.fromJson(json['fees_category'])
          : null,
      groupMaster: json['group_master'] != null
          ? GroupMaster.fromJson(json['group_master'])
          : null,
      member: json['member'] != null ? Member.fromJson(json['member']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Event_Name': eventName,
      'Event_Date': eventDate,
      'Event_Mode': eventMode,
      'Place': place,
      'fees_cat_id': feesCatId,
      'G_ID': gId,
      'M_ID': mId,
    };
  }
}

class FeesCategory {
  final int feesCatId;
  final String? gId;
  final String? mId;
  final String desc;
  final String amount;
  final String lateCharge;
  final String? createdAt;
  final String? updatedAt;

  FeesCategory({
    required this.feesCatId,
    this.gId,
    this.mId,
    required this.desc,
    required this.amount,
    required this.lateCharge,
    this.createdAt,
    this.updatedAt,
  });

  factory FeesCategory.fromJson(Map<String, dynamic> json) {
    return FeesCategory(
      feesCatId: json['fees_cat_id'],
      gId: json['G_ID']?.toString(),
      mId: json['M_ID']?.toString(),
      desc: json['Desc'],
      amount: json['Amount'],
      lateCharge: json['LateCharge'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}

class GroupMaster {
  final int gId;
  final String name;
  final String shortGroupName;
  final String groupName;
  final String email;
  final String number;
  final String gropCode;
  final String panNum;
  final String roleId;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  GroupMaster({
    required this.gId,
    required this.name,
    required this.shortGroupName,
    required this.groupName,
    required this.email,
    required this.number,
    required this.gropCode,
    required this.panNum,
    required this.roleId,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory GroupMaster.fromJson(Map<String, dynamic> json) {
    return GroupMaster(
      gId: json['G_ID'],
      name: json['name'],
      shortGroupName: json['short_group_name'],
      groupName: json['group_name'],
      email: json['email'],
      number: json['number'],
      gropCode: json['Grop_code'],
      panNum: json['pan_num'],
      roleId: json['role_id'],
      status: json['status'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}

class Member {
  final String mId;
  final String name;
  final String email;
  final String number;
  final String gropCode;
  final String password;
  final String roleId;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  Member({
    required this.mId,
    required this.name,
    required this.email,
    required this.number,
    required this.gropCode,
    required this.password,
    required this.roleId,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      mId: json['M_ID'].toString(),
      name: json['Name'],
      email: json['email'],
      number: json['number'],
      gropCode: json['Grop_code'],
      password: json['password'],
      roleId: json['role_id'],
      status: json['status'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}

// ==================== SERVICE CLASSES ====================

class ApiService {
  static const String baseUrl = 'https://tagai.caxis.ca/public/api';
  static const String eventsEndpoint = '$baseUrl/event-cals';
  static const String feesCategoriesEndpoint = '$baseUrl/fees-categories';

  // Get all events
  static Future<List<Event>> getEvents() async {
    try {
      final response = await http.get(
        Uri.parse(eventsEndpoint),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => Event.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load events: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching events: $e');
    }
  }

  // Get events filtered by group code
  static Future<List<Event>> getEventsByGroupCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupCode = prefs.getString('Grop_code') ?? '';
      
      final allEvents = await getEvents();
      
      // Filter events by group code if available
      if (groupCode.isNotEmpty) {
        return allEvents.where((event) => 
          event.groupMaster?.gropCode == groupCode ||
          event.member?.gropCode == groupCode
        ).toList();
      }
      
      return allEvents;
    } catch (e) {
      throw Exception('Error fetching events by group code: $e');
    }
  }

  // Get fees categories
  static Future<List<FeesCategory>> getFeesCategories() async {
    try {
      final response = await http.get(
        Uri.parse(feesCategoriesEndpoint),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => FeesCategory.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load fees categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching fees categories: $e');
    }
  }

  // Create new event
  static Future<bool> createEvent(Event event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gId = prefs.getString('G_ID') ?? '33'; // Keep default for G_ID as in original
      final mId = prefs.getString('M_ID'); // No default, allow null

      final eventData = event.toJson();
      eventData['G_ID'] = gId;
      eventData['M_ID'] = mId; // Will be null if not set in SharedPreferences

      print('Sending payload: ${jsonEncode(eventData)}'); // Debug log

      final response = await http.post(
        Uri.parse(eventsEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(eventData),
      );

      print('API Response [${response.statusCode}]: ${response.body}'); // Debug log

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print('Failed to create event: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error creating event: $e');
      return false;
    }
  }
}

class SharedPreferencesService {
  static Future<void> saveUserData({
    required String gId,
    required String? mId,
    required String gropCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('G_ID', gId);
    if (mId != null) {
      await prefs.setString('M_ID', mId);
    } else {
      await prefs.remove('M_ID');
    }
    await prefs.setString('Grop_code', gropCode);
  }

  static Future<Map<String, String?>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'G_ID': prefs.getString('G_ID'),
      'M_ID': prefs.getString('M_ID'),
      'Grop_code': prefs.getString('Grop_code'),
    };
  }

  static Future<String?> getGroupCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('Grop_code');
  }
}

// ==================== WIDGET CLASSES ====================

class EventsHomePage extends StatefulWidget {
  const EventsHomePage({Key? key}) : super(key: key);

  @override
  State<EventsHomePage> createState() => _EventsHomePageState();
}

class _EventsHomePageState extends State<EventsHomePage> {
  List<Event> events = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final fetchedEvents = await ApiService.getEventsByGroupCode();
      
      setState(() {
        events = fetchedEvents;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Events Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: loadEvents,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading events',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: loadEvents,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_note,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No events found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first event to get started',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: event.eventMode == 'Compulsary'
                                              ? Colors.red[100]
                                              : Colors.blue[100],
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          event.eventMode,
                                          style: TextStyle(
                                            color: event.eventMode == 'Compulsary'
                                                ? Colors.red[700]
                                                : Colors.blue[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        event.eventDate,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    event.eventName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        event.place,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (event.feesCategory != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.payment,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${event.feesCategory!.desc} - ₹${event.feesCategory!.amount}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (event.groupMaster != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.group,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Organized by: ${event.groupMaster!.name}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateEventPage(),
            ),
          );
          
          if (result == true) {
            loadEvents(); // Refresh the events list
          }
        },
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Event'),
      ),
    );
  }
}

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({Key? key}) : super(key: key);

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _eventNameController = TextEditingController();
  final _placeController = TextEditingController();
  
  DateTime? _selectedDate;
  String _selectedEventMode = 'Compulsary';
  FeesCategory? _selectedFeesCategory;
  List<FeesCategory> _feesCategories = [];
  bool _isLoading = false;
  bool _isLoadingCategories = true;

  final List<String> _eventModes = ['Compulsary', 'Optional'];

  @override
  void initState() {
    super.initState();
    _loadFeesCategories();
  }

  Future<void> _loadFeesCategories() async {
    try {
      final categories = await ApiService.getFeesCategories();
      setState(() {
        _feesCategories = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
      _showErrorSnackBar('Failed to load fees categories: $e');
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
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      _showErrorSnackBar('Please select an event date');
      return;
    }

    if (_selectedFeesCategory == null) {
      _showErrorSnackBar('Please select a fees category');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final event = Event(
        eventName: _eventNameController.text.trim(),
        eventDate: _selectedDate!.toIso8601String().split('T')[0],
        eventMode: _selectedEventMode,
        place: _placeController.text.trim(),
        feesCatId: _selectedFeesCategory!.feesCatId.toString(),
        gId: '33', // Will be overridden by API service
        mId: '1',  // Will be overridden by API service
      );

      final success = await ApiService.createEvent(event);

      if (success) {
        _showSuccessSnackBar('Event created successfully!');
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        _showErrorSnackBar('Failed to create event. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('Error creating event: $e');
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
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Create Event',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoadingCategories
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Event Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Event Name
                            TextFormField(
                              controller: _eventNameController,
                              decoration: InputDecoration(
                                labelText: 'Event Name',
                                hintText: 'Enter event name',
                                prefixIcon: const Icon(Icons.event, color: Colors.black54),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.black, width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter event name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Event Date
                            InkWell(
                              onTap: _selectDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, color: Colors.black54),
                                    const SizedBox(width: 12),
                                    Text(
                                      _selectedDate == null
                                          ? 'Select Event Date'
                                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: _selectedDate == null ? Colors.grey[600] : Colors.black87,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.arrow_drop_down, color: Colors.black54),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Event Mode
                            DropdownButtonFormField<String>(
                              value: _selectedEventMode,
                              decoration: InputDecoration(
                                labelText: 'Event Mode',
                                prefixIcon: const Icon(Icons.mode_edit, color: Colors.black54),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.black, width: 2),
                                ),
                              ),
                              items: _eventModes.map((mode) {
                                return DropdownMenuItem<String>(
                                  value: mode,
                                  child: Text(mode),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedEventMode = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Place
                            TextFormField(
                              controller: _placeController,
                              decoration: InputDecoration(
                                labelText: 'Place',
                                hintText: 'Enter event location',
                                prefixIcon: const Icon(Icons.location_on, color: Colors.black54),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.black, width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter event location';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Fees Category
                            DropdownButtonFormField<FeesCategory>(
                              value: _selectedFeesCategory,
                              decoration: InputDecoration(
                                labelText: 'Fees Category',
                                prefixIcon: const Icon(Icons.payment, color: Colors.black54),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.black, width: 2),
                                ),
                              ),
                              hint: const Text('Select fees category'),
                              isExpanded: true, // Allow dropdown to use available width
                              items: _feesCategories.map((category) {
                                return DropdownMenuItem<FeesCategory>(
                                  value: category,
                                  child: SizedBox(
                                    width: double.infinity, // Use available width
                                    child: Text(
                                      '${category.desc} (₹${category.amount}, Late: ₹${category.lateCharge})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedFeesCategory = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select a fees category';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Create Event Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Create Event',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
