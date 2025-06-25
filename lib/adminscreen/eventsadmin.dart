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
      title: 'Events Admin',
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
            borderSide: const BorderSide(color: Colors.blue, width: 2),
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

class _EventsAdminPageState extends State<EventsAdminPage> {
  List<dynamic> events = [];
  bool isLoading = true;
  String? gropCode;
  String? gId;

  @override
  void initState() {
    super.initState();
    fetchEvents();
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

    // Fallback to G_ID filtering if Grop_code is missing
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
          'Events Admin',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Create Event Button Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateEventPage(),
                  ),
                ).then((_) => fetchEvents());
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Create New Event',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
          // Events List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No events found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
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
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Event Name with Icon
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.event,
                                          color: Colors.blue[600],
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          event['Event_Name'] ?? 'No Name',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Event Details
                                  _buildEventDetailRow(
                                    Icons.calendar_today,
                                    'Date',
                                    event['Event_Date'] ?? 'N/A',
                                    Colors.green,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildEventDetailRow(
                                    Icons.settings,
                                    'Mode',
                                    event['Event_Mode'] ?? 'N/A',
                                    Colors.orange,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildEventDetailRow(
                                    Icons.location_on,
                                    'Place',
                                    event['Place'] ?? 'N/A',
                                    Colors.red,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildEventDetailRow(
                                    Icons.currency_rupee,
                                    'Fees',
                                    '₹${event['fees_category']['Amount'] ?? 'N/A'}',
                                    Colors.purple,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildEventDetailRow(
                                    Icons.group,
                                    'Group',
                                    event['group_master']['group_name'] ?? 'N/A',
                                    Colors.teal,
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

  Widget _buildEventDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
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
            ),
          ),
        ),
      ],
    );
  }
}

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _eventNameController = TextEditingController();
  final _eventDateController = TextEditingController();
  final _eventModeController = TextEditingController();
  final _placeController = TextEditingController();
  String? _selectedFeesCatId;
  List<dynamic> _feesCategories = [];
  bool isLoading = false;
  bool _isFetchingFees = true;

  @override
  void initState() {
    super.initState();
    _fetchFeesCategories();
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
              primary: Colors.blue[600]!,
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
      isLoading = true;
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
        isLoading = false;
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
        Navigator.pop(context);
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
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _eventDateController.dispose();
    _eventModeController.dispose();
    _placeController.dispose();
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
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Event',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isFetchingFees
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
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
                          const Text(
                            'Event Details',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _eventNameController,
                            decoration: const InputDecoration(
                              labelText: 'Event Name',
                              prefixIcon: Icon(Icons.event),
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
                              prefixIcon: Icon(Icons.calendar_today),
                              suffixIcon: Icon(Icons.arrow_drop_down),
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
                              prefixIcon: Icon(Icons.settings),
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
                              prefixIcon: Icon(Icons.location_on),
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
                              prefixIcon: Icon(Icons.currency_rupee),
                              hintText: 'Select fees category',
                            ),
                            items: _feesCategories.map((category) {
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
                              onPressed: isLoading ? null : createEvent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: isLoading
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
            ),
    );
  }
}