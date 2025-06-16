import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Event Model
class Event {
  final int id;
  final String title;
  final String description;
  final String date;
  final String time;
  final String location;
  final String groupCode;
  final int evCalId;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    required this.groupCode,
    required this.evCalId,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      groupCode: json['group_code']?.toString() ?? '',
      evCalId: int.tryParse(json['ev_cal_id'].toString()) ?? 0,
    );
  }
}

// API Service
class ApiService {
  static const String baseUrl = 'https://tagai.caxis.ca/public/api';

  static Future<void> initializePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final groupCode = prefs.getString('Group_code');
    print('initializePreferences: Group_code = $groupCode');

    // Fallback: Check for common key variations if Group_code is not set
    if (groupCode == null || groupCode.isEmpty) {
      final possibleKeys = ['group_code', 'GroupCode', 'GROUP_CODE'];
      for (var key in possibleKeys) {
        final value = prefs.getString(key);
        if (value != null && value.isNotEmpty) {
          await prefs.setString('Group_code', value);
          print('Found Group_code under key $key: $value. Set to Group_code.');
          return;
        }
      }

      // If no group code found, set a default or throw an error
      // Replace 'DEFAULT_GROUP_CODE' with your actual default or remove if not applicable
      await prefs.setString('Group_code', 'DEFAULT_GROUP_CODE');
      print('No Group_code found. Set default: DEFAULT_GROUP_CODE');
    }
  }

  static Future<List<Event>> fetchEvents() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/event-cals'),
        headers: {'Content-Type': 'application/json'},
      );

      print('fetchEvents Response status: ${response.statusCode}');
      print('fetchEvents Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => Event.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load events: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchEvents: $e');
      throw Exception('Error fetching events: $e');
    }
  }

  static Future<List<Event>> fetchFilteredEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupCode = prefs.getString('Group_code') ?? '';
      print('fetchFilteredEvents: Group_code = $groupCode');

      if (groupCode.isEmpty) {
        // Log all keys in SharedPreferences for debugging
        final allKeys = prefs.getKeys();
        print('SharedPreferences keys: $allKeys');
        for (var key in allKeys) {
          print('Key $key: ${prefs.get(key)}');
        }
        throw Exception('Group code not found in preferences');
      }

      final allEvents = await fetchEvents();
      return allEvents.where((event) => event.groupCode == groupCode).toList();
    } catch (e) {
      print('Error in fetchFilteredEvents: $e');
      throw Exception('Error fetching filtered events: $e');
    }
  }

  static Future<bool> saveEventResponse({
    required int mId,
    required int evCalId,
    required bool attending,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/event-tracks'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'M_ID': mId,
          'Ev_Cal_Id': evCalId,
          'attending': attending,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      print('saveEventResponse Response status: ${response.statusCode}');
      print('saveEventResponse Response body: ${response.body}');

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error saving event response: $e');
      return false;
    }
  }
}

// Events Page
class EventsPage extends StatefulWidget {
  const EventsPage({Key? key}) : super(key: key);

  @override
  _EventsPageState createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<Event> events = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  Future<void> fetchEvents() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      // Ensure preferences are initialized
      await ApiService.initializePreferences();

      final fetchedEvents = await ApiService.fetchFilteredEvents();
      setState(() {
        events = fetchedEvents;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load events. Please check your connection and try again.';
        isLoading = false;
      });
      print('Error in EventsPage fetchEvents: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Events',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchEvents,
          ),
        ],
      ),
      body: isLoading
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
                      const Text(
                        'Error loading events',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
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
                        onPressed: fetchEvents,
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
                            Icons.event_busy,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No events found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Check back later for new events',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchEvents,
                      color: Colors.black,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return EventCard(
                            event: event,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EventDetailsPage(event: event),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}

// Event Card Widget
class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const EventCard({
    Key? key,
    required this.event,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      event.date,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                event.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                event.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    event.time,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
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
  }
}

// Event Details Page
class EventDetailsPage extends StatefulWidget {
  final Event event;

  const EventDetailsPage({Key? key, required this.event}) : super(key: key);

  @override
  _EventDetailsPageState createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  bool isLoading = false;
  bool? selectedResponse;

  Future<void> saveResponse(bool attending) async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final mId = prefs.getInt('M_ID') ?? 0;
      print('Member ID: $mId');

      if (mId == 0) {
        throw Exception('Member ID not found in preferences');
      }

      final success = await ApiService.saveEventResponse(
        mId: mId,
        evCalId: widget.event.evCalId,
        attending: attending,
      );

      if (success) {
        setState(() {
          selectedResponse = attending;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              attending
                  ? 'Successfully registered for the event!'
                  : 'Response saved successfully!',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception('Failed to save response');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      print('Error in saveResponse: $e');
    } finally {
      setState(() {
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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Event Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.event.date,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.event.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.event.time,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.event.location,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Event Description
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.event.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Attendance Options
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Will you attend this meeting?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (selectedResponse != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedResponse! ? Colors.green[50] : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selectedResponse! ? Colors.green[200]! : Colors.red[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedResponse! ? Icons.check_circle : Icons.cancel,
                            color: selectedResponse! ? Colors.green[600] : Colors.red[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedResponse!
                                ? 'You have confirmed your attendance'
                                : 'You have declined this event',
                            style: TextStyle(
                              color: selectedResponse! ? Colors.green[700] : Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (selectedResponse == null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () => saveResponse(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Yes, I\'ll attend',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () => saveResponse(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'No, I can\'t attend',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}