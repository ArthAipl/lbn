import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Events',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      home: const EventsAdminPage(),
    );
  }
}

class EventsAdminPage extends StatefulWidget {
  const EventsAdminPage({super.key});

  @override
  State<EventsAdminPage> createState() => _EventsAdminPageState();
}

class _EventsAdminPageState extends State<EventsAdminPage> with SingleTickerProviderStateMixin {
  List<dynamic> events = [];
  bool isLoading = true;
  String? gropCode;
  String? gId;
  
  // Create Event Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _eventNameController = TextEditingController();
  final _eventDateController = TextEditingController();
  final _eventModeController = TextEditingController();
  final _placeController = TextEditingController();
  String? _selectedFeesCatId;
  List<dynamic> _feesCategories = [];
  bool isCreating = false;
  bool _isFetchingFees = true;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchEvents();
    _fetchFeesCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventNameController.dispose();
    _eventDateController.dispose();
    _eventModeController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> fetchEvents() async {
    final prefs = await SharedPreferences.getInstance();
    gropCode = prefs.getString('Grop_code');
    gId = prefs.getString('user_id');

    print('Retrieved Grop_code: $gropCode');
    print('Retrieved G_ID: $gId');

    if (gId == null || gId!.isEmpty) {
      print('Error: G_ID is null or empty');
      setState(() {
        isLoading = false;
        events = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID not found. Please log in again.')),
      );
      return;
    }

    bool useGropCode = gropCode != null && gropCode!.isNotEmpty;

    try {
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/event-cals'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('API response: $data');

        setState(() {
          events = data
              .where((event) {
                bool matchesGId = event['G_ID'].toString() == gId;
                bool matchesGropCode = useGropCode
                    ? event['group_master']['Grop_code']?.toString() == gropCode
                    : true;
                return matchesGId && matchesGropCode;
              })
              .toList();
          isLoading = false;
        });

        print('Filtered events: $events');
      } else {
        print('API error: Status code ${response.statusCode}, Response: ${response.body}');
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load events')),
        );
      }
    } catch (e) {
      print('Error fetching events: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred while fetching events')),
      );
    }
  }

  Future<void> _fetchFeesCategories() async {
    try {
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/fees-categories'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Fees categories response: $data');

        setState(() {
          _feesCategories = data;
          _isFetchingFees = false;
        });
      } else {
        print('Failed to fetch fees categories: Status code ${response.statusCode}, Response: ${response.body}');
        setState(() {
          _isFetchingFees = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load fees categories')),
        );
      }
    } catch (e) {
      print('Error fetching fees categories: $e');
      setState(() {
        _isFetchingFees = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching fees categories')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
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

    if (picked != null) {
      setState(() {
        _eventDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isCreating = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final gId = prefs.getString('user_id');
    final gropCode = prefs.getString('Grop_code');

    print('Creating event with G_ID: $gId, Grop_code: $gropCode');

    if (gId == null || gId.isEmpty) {
      print('Error: Missing user_id in SharedPreferences');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID not found')),
      );
      setState(() {
        isCreating = false;
      });
      return;
    }

    final payload = {
      'Event_Name': _eventNameController.text,
      'Event_Date': _eventDateController.text,
      'Event_Mode': _eventModeController.text,
      'Place': _placeController.text,
      'fees_cat_id': _selectedFeesCatId,
      'G_ID': gId,
      'M_ID': null,
    };

    print('Create event payload: $payload');

    try {
      final response = await http.post(
        Uri.parse('https://tagai.caxis.ca/public/api/event-cals'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        print('Event created successfully');
        
        // Clear form
        _eventNameController.clear();
        _eventDateController.clear();
        _eventModeController.clear();
        _placeController.clear();
        setState(() {
          _selectedFeesCatId = null;
        });
        
        // Switch to events tab and refresh
        _tabController.animateTo(1);
        fetchEvents();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully')),
        );
      } else {
        print('Failed to create event: Status code ${response.statusCode}, Response: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create event')),
        );
      }
    } catch (e) {
      print('Error creating event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred')),
      );
    } finally {
      setState(() {
        isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Events',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(
             
              text: 'Create Event',
            ),
            Tab(
              
              text: 'All Events',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Create Event Tab
          _buildCreateEventTab(),
          // All Events Tab
          _buildAllEventsTab(),
        ],
      ),
    );
  }

  Widget _buildCreateEventTab() {
    return _isFetchingFees
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.event_available, color: Colors.white, size: 24),
                              SizedBox(width: 12),
                              Text(
                                'Create New Event',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _eventNameController,
                          decoration: const InputDecoration(
                            labelText: 'Event Name',
                            prefixIcon: Icon(Icons.event, color: Colors.black),
                            hintText: 'Enter event name',
                          ),
                          validator: (value) =>
                              value!.isEmpty ? 'Enter event name' : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _eventDateController,
                          decoration: const InputDecoration(
                            labelText: 'Event Date',
                            prefixIcon: Icon(Icons.calendar_today, color: Colors.black),
                            suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.black),
                            hintText: 'Select event date',
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context),
                          validator: (value) =>
                              value!.isEmpty ? 'Select event date' : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _eventModeController,
                          decoration: const InputDecoration(
                            labelText: 'Event Mode',
                            prefixIcon: Icon(Icons.settings, color: Colors.black),
                            hintText: 'Enter event mode',
                          ),
                          validator: (value) =>
                              value!.isEmpty ? 'Enter event mode' : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _placeController,
                          decoration: const InputDecoration(
                            labelText: 'Place',
                            prefixIcon: Icon(Icons.location_on, color: Colors.black),
                            hintText: 'Enter event location',
                          ),
                          validator: (value) =>
                              value!.isEmpty ? 'Enter place' : null,
                        ),
                        const SizedBox(height: 20),
DropdownButtonFormField<String>(
  value: _selectedFeesCatId,
  decoration: const InputDecoration(
    labelText: 'Fees Category',
    prefixIcon: Icon(Icons.currency_rupee, color: Colors.black),
    hintText: 'Select fees category',
  ),
  items: _feesCategories.map<DropdownMenuItem<String>>((category) {
    return DropdownMenuItem<String>(
      value: category['fees_cat_id'].toString(),
      child: Text(
        '${category['Desc'] ?? 'Unknown'} - ₹${category['Amount'] ?? '0'}',
        style: const TextStyle(fontSize: 14),
      ),
    );
  }).toList(),
  onChanged: (value) {
    setState(() {
      _selectedFeesCatId = value;
    });
  },
  validator: (value) =>
      value == null ? 'Select a fees category' : null,
),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isCreating ? null : createEvent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: isCreating
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Create Event',
                                    style: TextStyle(
                                      color: Colors.white,
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
              ),
            ),
          );
  }

  Widget _buildAllEventsTab() {
    return RefreshIndicator(
      color: Colors.black,
      onRefresh: fetchEvents,
      child: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : events.isEmpty
              ? ListView(
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.event_busy,
                              size: 64,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'No events found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create your first event using the Create Event tab',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[200]!, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header with black background
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20.0),
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.event,
                                    color: Colors.black,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    event['Event_Name'] ?? 'No Name',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Content with white background
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                _buildEventDetailRow(
                                  Icons.calendar_today,
                                  'Date',
                                  event['Event_Date'] ?? 'N/A',
                                  Colors.black,
                                ),
                                const SizedBox(height: 16),
                                _buildEventDetailRow(
                                  Icons.settings,
                                  'Mode',
                                  event['Event_Mode'] ?? 'N/A',
                                  Colors.black,
                                ),
                                const SizedBox(height: 16),
                                _buildEventDetailRow(
                                  Icons.location_on,
                                  'Place',
                                  event['Place'] ?? 'N/A',
                                  Colors.black,
                                ),
                                const SizedBox(height: 16),
                                _buildEventDetailRow(
                                  Icons.currency_rupee,
                                  'Fees',
                                  '₹${event['fees_category']['Amount'] ?? 'N/A'}',
                                  Colors.black,
                                ),
                                const SizedBox(height: 16),
                                _buildEventDetailRow(
                                  Icons.group,
                                  'Group',
                                  event['group_master']['group_name'] ?? 'N/A',
                                  Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEventDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}