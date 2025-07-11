import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Event Model with booking status
class Event {
  final int id;
  final String title;
  final String description;
  final String date;
  final String time;
  final String location;
  final String groupCode;
  final int evCalId;
  final String eventMode;
  bool? bookingStatus; // null = not responded, true = attending, false = not attending

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    required this.groupCode,
    required this.evCalId,
    required this.eventMode,
    this.bookingStatus,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: int.tryParse(json['Ev_Cal_Id'].toString()) ?? 0,
      title: json['Event_Name']?.toString() ?? '',
      description: json['fees_category']?['Desc']?.toString() ?? 'No description available',
      date: json['Event_Date']?.toString() ?? '',
      time: json['time']?.toString() ?? 'Not specified',
      location: json['Place']?.toString() ?? '',
      groupCode: json['group_master']?['Grop_code']?.toString() ?? '',
      evCalId: int.tryParse(json['Ev_Cal_Id'].toString()) ?? 0,
      eventMode: json['Event_Mode']?.toString() ?? 'Standard',
    );
  }

  @override
  String toString() {
    return 'Event(id: $id, title: $title, groupCode: $groupCode, eventMode: $eventMode, bookingStatus: $bookingStatus)';
  }
}

// API Service with booking status management
class ApiService {
  static const String baseUrl = 'https://tagai.caxis.ca/public/api';
  static final client = http.Client(); // Use Client to handle redirects

  static Future<void> initializePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final groupCode = prefs.getString('group_code');
    print('initializePreferences: group_code = $groupCode');

    if (groupCode == null || groupCode.isEmpty) {
      final possibleKeys = ['group_code', 'GroupCode', 'GROUP_CODE', 'Grop_code'];
      for (var key in possibleKeys) {
        final value = prefs.getString(key);
        if (value != null && value.isNotEmpty) {
          await prefs.setString('group_code', value);
          print('Found group_code under key $key: $value. Set to group_code.');
          return;
        }
      }
      await prefs.setString('group_code', '572334');
      print('No group_code found. Set default: 572334');
    }
  }

  static Future<List<Event>> fetchEvents() async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/event-cals'),
        headers: {'Content-Type': 'application/json'},
      );

      print('fetchEvents Response status: ${response.statusCode}');
      print('fetchEvents Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        print('Parsed JSON data: ${jsonData.length} items');
        final events = jsonData.map((json) => Event.fromJson(json)).toList();

        // Load booking statuses from local storage
        await _loadBookingStatuses(events);

        print('Parsed Events: $events');
        return events;
      } else {
        throw Exception('Failed to load events: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchEvents: $e');
      throw Exception('Error fetching events: $e');
    }
  }

  static Future<void> _loadBookingStatuses(List<Event> events) async {
    final prefs = await SharedPreferences.getInstance();
    for (var event in events) {
      final statusKey = 'booking_status_${event.evCalId}';
      final status = prefs.getInt(statusKey);
      if (status != null) {
        event.bookingStatus = status == 1; // 1 = attending, 2 = not attending
      }
    }
  }

  static Future<void> _saveBookingStatus(int evCalId, bool attending) async {
    final prefs = await SharedPreferences.getInstance();
    final statusKey = 'booking_status_$evCalId';
    await prefs.setInt(statusKey, attending ? 1 : 2);
  }

  static Future<List<Event>> fetchFilteredEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupCode = prefs.getString('group_code') ?? '';
      print('fetchFilteredEvents: group_code = $groupCode');

      if (groupCode.isEmpty) {
        final allKeys = prefs.getKeys();
        print('SharedPreferences keys: $allKeys');
        for (var key in allKeys) {
          print('Key $key: ${prefs.get(key)}');
        }
        throw Exception('Group code not found in preferences');
      }

      final allEvents = await fetchEvents();
      final filteredEvents = allEvents.where((event) => event.groupCode == groupCode).toList();
      print('Filtered Events: $filteredEvents');
      return filteredEvents;
    } catch (e) {
      print('Error in fetchFilteredEvents: $e');
      throw Exception('Error fetching filtered events: $e');
    }
  }

  static Future<List<Event>> fetchBookedEvents(int mId) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/event-tracks?M_ID=$mId&status=1'),
        headers: {'Content-Type': 'application/json'},
      );

      print('fetchBookedEvents Response status: ${response.statusCode}');
      print('fetchBookedEvents Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        print('Parsed booked events JSON data: ${jsonData.length} items');

        final allEvents = await fetchEvents();
        final bookedEvents = jsonData
            .map((track) => allEvents.firstWhere(
                  (e) => e.evCalId == int.tryParse(track['Ev_Cal_Id'].toString()),
                  orElse: () => null as Event,
                ))
            .whereType<Event>()
            .toList();

        print('Parsed Booked Events: $bookedEvents');
        return bookedEvents;
      } else {
        throw Exception('Failed to load booked events: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchBookedEvents: $e');
      throw Exception('Error fetching booked events: $e');
    }
  }

  static Future<bool> saveEventResponse({
    required int mId,
    required int evCalId,
    required int status,
  }) async {
    try {
      final requestBody = json.encode({
        'M_ID': mId,
        'Ev_Cal_Id': evCalId,
        'Status': status,
        'timestamp': DateTime.now().toIso8601String(),
      });

      print('saveEventResponse Request body: $requestBody');

      // Follow redirects manually if needed
      final response = await client.post(
        Uri.parse('$baseUrl/event-tracks'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      print('saveEventResponse Response status: ${response.statusCode}');
      print('saveEventResponse Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print('saveEventResponse Parsed response: $responseData');

        // Save booking status locally
        await _saveBookingStatus(evCalId, status == 1);

        if (responseData['Status'] != null && responseData['Status'].toString() != status.toString()) {
          print('Warning: Response Status (${responseData['Status']}) does not match sent Status ($status)');
        }
        return true;
      } else {
        throw Exception('Failed to save event response: ${response.statusCode}');
      }
    } catch (e) {
      print('Error saving event response: $e');
      return false;
    }
  }

  // Clean up the client when done
  static void dispose() {
    client.close();
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
  void dispose() {
    ApiService.dispose();
    super.dispose();
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.event_available_rounded,
                      color: Colors.blue[600],
                    ),
                  ),
                  title: const Text(
                    'Booked Events',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text('View your confirmed events'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BookedEventsPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showMenu,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Loading events...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : errorMessage.isNotEmpty
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: Colors.red[400],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Oops! Something went wrong',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black, Colors.grey[800]!],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: fetchEvents,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              'Try Again',
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
                )
              : events.isEmpty
                  ? Center(
                      child: Container(
                        margin: const EdgeInsets.all(32),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Icon(
                                Icons.event_busy_rounded,
                                size: 48,
                                color: Colors.blue[400],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'No events available',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Check back later for exciting new events',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchEvents,
                      color: Colors.black,
                      backgroundColor: Colors.white,
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
                              ).then((_) {
                                // Refresh the list when returning from details page
                                setState(() {});
                              });
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}

// Booked Events Page
class BookedEventsPage extends StatefulWidget {
  const BookedEventsPage({Key? key}) : super(key: key);

  @override
  _BookedEventsPageState createState() => _BookedEventsPageState();
}

class _BookedEventsPageState extends State<BookedEventsPage> {
  List<Event> bookedEvents = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchBookedEvents();
  }

  Future<void> fetchBookedEvents() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final prefs = await SharedPreferences.getInstance();
      final memberIdString = prefs.getString('member_id');
      final mId = int.tryParse(memberIdString ?? '') ?? 0;

      if (mId == 0) {
        throw Exception('Member ID (member_id) not found in preferences. Please log in again.');
      }

      final fetchedEvents = await ApiService.fetchBookedEvents(mId);
      setState(() {
        bookedEvents = fetchedEvents;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load booked events. Please check your connection and try again.';
        isLoading = false;
      });
      print('Error in BookedEventsPage fetchBookedEvents: $e');
    }
  }

  @override
  void dispose() {
    ApiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Booked Events',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Loading booked events...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : errorMessage.isNotEmpty
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: Colors.red[400],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Error loading booked events',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black, Colors.grey[800]!],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: fetchBookedEvents,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              'Try Again',
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
                )
              : bookedEvents.isEmpty
                  ? Center(
                      child: Container(
                        margin: const EdgeInsets.all(32),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Icon(
                                Icons.event_busy_rounded,
                                size: 48,
                                color: Colors.orange[400],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'No booked events',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'You haven\'t booked any events yet.\nStart exploring and book your first event!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchBookedEvents,
                      color: Colors.black,
                      backgroundColor: Colors.white,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: bookedEvents.length,
                        itemBuilder: (context, index) {
                          final event = bookedEvents[index];
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

// ENHANCED Event Card Widget - SMALLER AND MORE COMPACT
class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const EventCard({
    Key? key,
    required this.event,
    required this.onTap,
  }) : super(key: key);

  Map<String, dynamic> getEventModeStyle(String eventMode) {
    switch (eventMode.toLowerCase()) {
      case 'online':
        return {
          'colors': [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
          'icon': Icons.videocam_rounded,
          'bgColor': const Color(0xFFEFF6FF),
          'borderColor': const Color(0xFFBFDBFE),
        };
      case 'offline':
      case 'physical':
        return {
          'colors': [const Color(0xFF10B981), const Color(0xFF34D399)],
          'icon': Icons.location_on_rounded,
          'bgColor': const Color(0xFFECFDF5),
          'borderColor': const Color(0xFFA7F3D0),
        };
      case 'hybrid':
        return {
          'colors': [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
          'icon': Icons.hub_rounded,
          'bgColor': const Color(0xFFF5F3FF),
          'borderColor': const Color(0xFFC4B5FD),
        };
      case 'virtual':
        return {
          'colors': [const Color(0xFF6366F1), const Color(0xFF818CF8)],
          'icon': Icons.computer_rounded,
          'bgColor': const Color(0xFFEEF2FF),
          'borderColor': const Color(0xFFC7D2FE),
        };
      case 'webinar':
        return {
          'colors': [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
          'icon': Icons.cast_for_education_rounded,
          'bgColor': const Color(0xFFFFFBEB),
          'borderColor': const Color(0xFFFED7AA),
        };
      default:
        return {
          'colors': [const Color(0xFF6B7280), const Color(0xFF9CA3AF)],
          'icon': Icons.event_rounded,
          'bgColor': const Color(0xFFF9FAFB),
          'borderColor': const Color(0xFFD1D5DB),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventModeStyle = getEventModeStyle(event.eventMode);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFFAFBFC),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with date and event mode
                Row(
                  children: [
                    // Date badge - smaller
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black, const Color(0xFF374151)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        event.date,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Event Mode badge - positioned at right corner, more highlighted
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.4,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: eventModeStyle['colors'],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: eventModeStyle['colors'][0].withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 1,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              eventModeStyle['icon'],
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              event.eventMode.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                    color: Colors.black26,
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Booking status indicator - if exists
                if (event.bookingStatus != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: event.bookingStatus!
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: event.bookingStatus!
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            event.bookingStatus!
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            size: 12,
                            color: event.bookingStatus!
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            event.bookingStatus! ? 'Attending' : 'Not Attending',
                            style: TextStyle(
                              fontSize: 10,
                              color: event.bookingStatus!
                                  ? const Color(0xFF047857)
                                  : const Color(0xFFDC2626),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Event title - smaller font
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Event description - smaller and fewer lines
                Text(
                  event.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Time and location info - more compact
                Row(
                  children: [
                    if (event.time.isNotEmpty && event.time != 'Not specified') ...[
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  event.time,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF1E40AF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 12,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.location,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF047857),
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // "Tap for details" text at the bottom
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      "Tap for details",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ENHANCED Event Details Page - MORE COMPACT AND PROFESSIONAL
class EventDetailsPage extends StatefulWidget {
  final Event event;

  const EventDetailsPage({Key? key, required this.event}) : super(key: key);

  @override
  _EventDetailsPageState createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> with TickerProviderStateMixin {
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    ApiService.dispose();
    super.dispose();
  }

  Map<String, dynamic> getEventModeStyle(String eventMode) {
    switch (eventMode.toLowerCase()) {
      case 'online':
        return {
          'colors': [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
          'icon': Icons.videocam_rounded,
          'bgColor': const Color(0xFFEFF6FF),
          'borderColor': const Color(0xFFBFDBFE),
        };
      case 'offline':
      case 'physical':
        return {
          'colors': [const Color(0xFF10B981), const Color(0xFF34D399)],
          'icon': Icons.location_on_rounded,
          'bgColor': const Color(0xFFECFDF5),
          'borderColor': const Color(0xFFA7F3D0),
        };
      case 'hybrid':
        return {
          'colors': [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
          'icon': Icons.hub_rounded,
          'bgColor': const Color(0xFFF5F3FF),
          'borderColor': const Color(0xFFC4B5FD),
        };
      case 'virtual':
        return {
          'colors': [const Color(0xFF6366F1), const Color(0xFF818CF8)],
          'icon': Icons.computer_rounded,
          'bgColor': const Color(0xFFEEF2FF),
          'borderColor': const Color(0xFFC7D2FE),
        };
      case 'webinar':
        return {
          'colors': [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
          'icon': Icons.cast_for_education_rounded,
          'bgColor': const Color(0xFFFFFBEB),
          'borderColor': const Color(0xFFFED7AA),
        };
      default:
        return {
          'colors': [const Color(0xFF6B7280), const Color(0xFF9CA3AF)],
          'icon': Icons.event_rounded,
          'bgColor': const Color(0xFFF9FAFB),
          'borderColor': const Color(0xFFD1D5DB),
        };
    }
  }

  Future<void> saveResponse(bool attending) async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      print('SharedPreferences keys: $allKeys');
      for (var key in allKeys) {
        print('Key $key: ${prefs.get(key)} (Type: ${prefs.get(key).runtimeType})');
      }

      final memberIdString = prefs.getString('member_id');
      int mId = 0;
      if (memberIdString != null && memberIdString.isNotEmpty) {
        mId = int.tryParse(memberIdString) ?? 0;
        print('Retrieved member_id: $memberIdString, Parsed to int: $mId');
      }
      print('Member ID: $mId');

      if (mId == 0) {
        throw Exception('Member ID (member_id) not found in preferences. Please log in again.');
      }

      final success = await ApiService.saveEventResponse(
        mId: mId,
        evCalId: widget.event.evCalId,
        status: attending ? 1 : 2,
      );

      if (success) {
        setState(() {
          widget.event.bookingStatus = attending;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      attending ? Icons.check_circle_rounded : Icons.info_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          attending ? 'Successfully Registered!' : 'Response Saved!',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          attending
                              ? 'You\'re all set for this event'
                              : 'Your response has been recorded',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: attending
                ? const Color(0xFF10B981)
                : const Color(0xFF3B82F6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('Failed to save response. Please try again.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.error_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Something went wrong',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.toString().replaceAll('Exception: ', ''),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
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
    final eventModeStyle = getEventModeStyle(widget.event.eventMode);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Section - more compact
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date and Event Mode badges - more compact
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.black, const Color(0xFF374151)],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    widget.event.date,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),

                                Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: eventModeStyle['colors'],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: eventModeStyle['colors'][0].withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        eventModeStyle['icon'],
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          widget.event.eventMode.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Event title - smaller font
                            Text(
                              widget.event.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F2937),
                                height: 1.2,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Time and location info - more compact
                            Column(
                              children: [
                                if (widget.event.time.isNotEmpty && widget.event.time != 'Not specified') ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDBEAFE),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.access_time_rounded,
                                            size: 16,
                                            color: Color(0xFF3B82F6),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Time',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF3B82F6),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                widget.event.time,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF1E40AF),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFBBF7D0),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.location_on_rounded,
                                          size: 16,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Location',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF10B981),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              widget.event.location,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF047857),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Description Section - more compact
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F3FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.description_rounded,
                                  size: 16,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'About This Event',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.event.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // RSVP Section - more compact
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.how_to_reg_rounded,
                                  size: 16,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'RSVP Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Show current status or buttons
                          if (widget.event.bookingStatus != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: widget.event.bookingStatus!
                                      ? [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)]
                                      : [const Color(0xFFFEF2F2), const Color(0xFFFECACA)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.event.bookingStatus!
                                      ? const Color(0xFFA7F3D0)
                                      : const Color(0xFFFECACA),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: widget.event.bookingStatus!
                                          ? const Color(0xFFBBF7D0)
                                          : const Color(0xFFFECACA),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      widget.event.bookingStatus!
                                          ? Icons.check_circle_rounded
                                          : Icons.cancel_rounded,
                                      color: widget.event.bookingStatus!
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.event.bookingStatus! ? 'You\'re Attending!' : 'Not Attending',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: widget.event.bookingStatus!
                                                ? const Color(0xFF047857)
                                                : const Color(0xFFDC2626),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.event.bookingStatus!
                                              ? 'Your attendance has been confirmed'
                                              : 'You have declined to attend',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: widget.event.bookingStatus!
                                                ? const Color(0xFF065F46)
                                                : const Color(0xFFB91C1C),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Show RSVP buttons only if not already responded
                            const Text(
                              'Will you attend this event?',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Column(
                              children: [
                                // Yes button
                                Container(
                                  width: double.infinity,
                                  height: 48,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF34D399)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : () => saveResponse(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
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
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.check_circle_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Yes, I\'ll attend',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                // No button
                                Container(
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEF4444).withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : () => saveResponse(false),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
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
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.cancel_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'No, I can\'t attend',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
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