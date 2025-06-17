import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Event Model with proper null handling
class Event {
  final int id;
  final String title;
  final String description;
  final String date;
  final String time;
  final String location;
  final String groupCode;
  final int evCalId;
  final String eventMode; // Event_Mode field with null safety

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
      // Fixed null handling for Event_Mode
      eventMode: json['Event_Mode']?.toString() ?? 'Standard',
    );
  }

  @override
  String toString() {
    return 'Event(id: $id, title: $title, groupCode: $groupCode, eventMode: $eventMode)';
  }
}

// API Service
class ApiService {
  static const String baseUrl = 'https://tagai.caxis.ca/public/api';

  static Future<void> initializePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final groupCode = prefs.getString('Group_code');
    print('initializePreferences: Group_code = $groupCode');

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
      await prefs.setString('Group_code', '572334'); // Fallback to known group code
      print('No Group_code found. Set default: 572334');
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
        print('Parsed JSON data: ${jsonData.length} items');
        final events = jsonData.map((json) => Event.fromJson(json)).toList();
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

  static Future<List<Event>> fetchFilteredEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupCode = prefs.getString('Group_code') ?? '';
      print('fetchFilteredEvents: Group_code = $groupCode');

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
      final response = await http.get(
        Uri.parse('$baseUrl/event-tracks?M_ID=$mId&status=1'),
        headers: {'Content-Type': 'application/json'},
      );

      print('fetchBookedEvents Response status: ${response.statusCode}');
      print('fetchBookedEvents Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        print('Parsed booked events JSON data: ${jsonData.length} items');

        // Fetch all events to match Ev_Cal_Id
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

      final response = await http.post(
        Uri.parse('$baseUrl/event-tracks'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      print('saveEventResponse Response status: ${response.statusCode}');
      print('saveEventResponse Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print('saveEventResponse Parsed response: $responseData');
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

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.event_available),
                title: const Text('Booked Events'),
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
            ],
          ),
        );
      },
    );
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
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showMenu,
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
      final userIdString = prefs.getString('user_id');
      final mId = int.tryParse(userIdString ?? '') ?? 0;

      if (mId == 0) {
        throw Exception('User ID (M_ID) not found in preferences. Please log in again.');
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
          'Booked Events',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                        'Error loading booked events',
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
                        onPressed: fetchBookedEvents,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : bookedEvents.isEmpty
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
                            'No booked events found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You haven\'t booked any events yet',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchBookedEvents,
                      color: Colors.black,
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

// FIXED Event Card Widget with proper overflow handling
class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const EventCard({
    Key? key,
    required this.event,
    required this.onTap,
  }) : super(key: key);

  // Helper method to get Event_Mode colors and icon
  Map<String, dynamic> getEventModeStyle(String eventMode) {
    switch (eventMode.toLowerCase()) {
      case 'online':
        return {
          'colors': [Colors.blue[600]!, Colors.blue[500]!],
          'icon': Icons.videocam_rounded,
          'bgColor': Colors.blue[50],
          'borderColor': Colors.blue[200],
        };
      case 'offline':
      case 'physical':
        return {
          'colors': [Colors.green[600]!, Colors.green[500]!],
          'icon': Icons.location_on_rounded,
          'bgColor': Colors.green[50],
          'borderColor': Colors.green[200],
        };
      case 'hybrid':
        return {
          'colors': [Colors.purple[600]!, Colors.purple[500]!],
          'icon': Icons.hub_rounded,
          'bgColor': Colors.purple[50],
          'borderColor': Colors.purple[200],
        };
      case 'virtual':
        return {
          'colors': [Colors.indigo[600]!, Colors.indigo[500]!],
          'icon': Icons.computer_rounded,
          'bgColor': Colors.indigo[50],
          'borderColor': Colors.indigo[200],
        };
      case 'webinar':
        return {
          'colors': [Colors.orange[600]!, Colors.orange[500]!],
          'icon': Icons.cast_for_education_rounded,
          'bgColor': Colors.orange[50],
          'borderColor': Colors.orange[200],
        };
      default:
        return {
          'colors': [Colors.grey[600]!, Colors.grey[500]!],
          'icon': Icons.event_rounded,
          'bgColor': Colors.grey[50],
          'borderColor': Colors.grey[200],
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventModeStyle = getEventModeStyle(event.eventMode);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey[50]!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with date, event mode, and arrow - FIXED OVERFLOW
                Row(
                  children: [
                    // Date badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black, Colors.grey[800]!],
                        ),
                        borderRadius: BorderRadius.circular(20),
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
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Event Mode badge - FIXED SIZE
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: eventModeStyle['colors'],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: eventModeStyle['colors'][0].withOpacity(0.3),
                              blurRadius: 6,
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
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                event.eventMode.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Event title
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                    height: 1.3,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Event description
                Text(
                  event.description,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 20),
                
                // Time and location info - FIXED OVERFLOW
                Row(
                  children: [
                    if (event.time.isNotEmpty && event.time != 'Not specified') ...[
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.blue[100]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Colors.blue[600],
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  event.time,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.green[100]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: Colors.green[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.location,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// FIXED Event Details Page with proper text wrapping
class EventDetailsPage extends StatefulWidget {
  final Event event;

  const EventDetailsPage({Key? key, required this.event}) : super(key: key);

  @override
  _EventDetailsPageState createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> with TickerProviderStateMixin {
  bool isLoading = false;
  bool? selectedResponse;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Helper method to get Event_Mode colors and icon
  Map<String, dynamic> getEventModeStyle(String eventMode) {
    switch (eventMode.toLowerCase()) {
      case 'online':
        return {
          'colors': [Colors.blue[600]!, Colors.blue[500]!],
          'icon': Icons.videocam_rounded,
          'bgColor': Colors.blue[50],
          'borderColor': Colors.blue[200],
        };
      case 'offline':
      case 'physical':
        return {
          'colors': [Colors.green[600]!, Colors.green[500]!],
          'icon': Icons.location_on_rounded,
          'bgColor': Colors.green[50],
          'borderColor': Colors.green[200],
        };
      case 'hybrid':
        return {
          'colors': [Colors.purple[600]!, Colors.purple[500]!],
          'icon': Icons.hub_rounded,
          'bgColor': Colors.purple[50],
          'borderColor': Colors.purple[200],
        };
      case 'virtual':
        return {
          'colors': [Colors.indigo[600]!, Colors.indigo[500]!],
          'icon': Icons.computer_rounded,
          'bgColor': Colors.indigo[50],
          'borderColor': Colors.indigo[200],
        };
      case 'webinar':
        return {
          'colors': [Colors.orange[600]!, Colors.orange[500]!],
          'icon': Icons.cast_for_education_rounded,
          'bgColor': Colors.orange[50],
          'borderColor': Colors.orange[200],
        };
      default:
        return {
          'colors': [Colors.grey[600]!, Colors.grey[500]!],
          'icon': Icons.event_rounded,
          'bgColor': Colors.grey[50],
          'borderColor': Colors.grey[200],
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

      final userIdString = prefs.getString('user_id');
      int mId = 0;
      if (userIdString != null && userIdString.isNotEmpty) {
        mId = int.tryParse(userIdString) ?? 0;
        print('Retrieved user_id: $userIdString, Parsed to int: $mId');
      }
      print('Member ID: $mId');

      if (mId == 0) {
        throw Exception('Member ID (user_id) not found in preferences. Please log in again.');
      }

      final success = await ApiService.saveEventResponse(
        mId: mId,
        evCalId: widget.event.evCalId,
        status: attending ? 1 : 2,
      );

      if (success) {
        setState(() {
          selectedResponse = attending;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  attending ? Icons.check_circle : Icons.info,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    attending
                        ? 'Successfully registered for the event!'
                        : 'Response saved successfully!',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: attending ? Colors.green[600] : Colors.blue[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        throw Exception('Failed to save response. Please try again.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error: ${e.toString()}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Section with Event_Mode highlighting - FIXED OVERFLOW
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.grey[50]!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date and Event Mode badges - FIXED OVERFLOW
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.black, Colors.grey[800]!],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.event.date,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          
                          // Event Mode badge - PROMINENTLY HIGHLIGHTED
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: eventModeStyle['colors'],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: eventModeStyle['colors'][0].withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  eventModeStyle['icon'],
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.event.eventMode.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Event title
                      Text(
                        widget.event.title,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey[900],
                          height: 1.2,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Time and location info
                      Column(
                        children: [
                          if (widget.event.time.isNotEmpty && widget.event.time != 'Not specified') ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue[100]!),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.access_time_rounded,
                                      size: 24,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Time',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          widget.event.time,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.blue[800],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.green[100]!),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    size: 24,
                                    color: Colors.green[700],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Location',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.event.location,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.green[800],
                                          fontWeight: FontWeight.w600,
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
              
              const SizedBox(height: 24),
              
              // Description Section
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.description_rounded,
                            size: 24,
                            color: Colors.purple[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.event.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // RSVP Section - FIXED TEXT OVERFLOW
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.how_to_reg_rounded,
                            size: 24,
                            color: Colors.orange[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Will you attend this event?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    if (selectedResponse != null)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: selectedResponse! 
                                ? [Colors.green[50]!, Colors.green[100]!]
                                : [Colors.red[50]!, Colors.red[100]!],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selectedResponse! ? Colors.green[200]! : Colors.red[200]!,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedResponse! ? Colors.green[200] : Colors.red[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                selectedResponse! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: selectedResponse! ? Colors.green[700] : Colors.red[700],
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedResponse! ? 'Attending' : 'Not Attending',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: selectedResponse! ? Colors.green[800] : Colors.red[800],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedResponse!
                                        ? 'You have confirmed your attendance'
                                        : 'You have declined this event',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: selectedResponse! ? Colors.green[600] : Colors.red[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    if (selectedResponse == null) ...[
                      Column(
                        children: [
                          // Yes button
                          Container(
                            width: double.infinity,
                            height: 56,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green[600]!, Colors.green[500]!],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isLoading ? null : () => saveResponse(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Yes, I\'ll attend',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
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
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.red[600]!, Colors.red[500]!],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isLoading ? null : () => saveResponse(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.cancel_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'No, I can\'t attend',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
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
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}