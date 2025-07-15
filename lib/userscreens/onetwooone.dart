import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // For File operations

// Assuming lucide_icons is available, otherwise map to Material Icons
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One-To-One Meetings',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black, // App bar black
          foregroundColor: Colors.white, // Text and icon white
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const OneToOneMeetingScreen(),
    );
  }
}

// Data Models (Define these classes in a separate file like models/data_models.dart if your project grows)
class Member {
  final String mId;
  final String name;
  final String email;
  final String number;
  final String groupCode;
  final String status;

  Member({
    required this.mId,
    required this.name,
    required this.email,
    required this.number,
    required this.groupCode,
    required this.status,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      mId: json['M_ID'].toString(),
      name: json['Name'] ?? '',
      email: json['email'] ?? '',
      number: json['number'] ?? '',
      groupCode: json['Grop_code'] ?? '',
      status: json['status'] ?? '',
    );
  }
}

class Meeting {
  final String one2oneId;
  final String place;
  final String date;
  final String time;
  final String gId;
  final String fromMid;
  final String toMid;
  final String status;
  final Member? fromMember;
  final Member? toMember;
  final List<String> images; // Storing image paths/URLs as strings

  Meeting({
    required this.one2oneId,
    required this.place,
    required this.date,
    required this.time,
    required this.gId,
    required this.fromMid,
    required this.toMid,
    required this.status,
    this.fromMember,
    this.toMember,
    this.images = const [],
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      one2oneId: json['one2one_id'].toString(),
      place: json['Place'] ?? '',
      date: json['Date'] ?? '',
      time: json['Time'] ?? '',
      gId: json['G_ID'].toString(),
      fromMid: json['From_MID'].toString(),
      toMid: json['To_MID'].toString(),
      status: json['Status'].toString(),
      fromMember: json['from_member'] != null
          ? Member.fromJson(json['from_member'])
          : null,
      toMember: json['to_member'] != null
          ? Member.fromJson(json['to_member'])
          : null,
      images: (json['Image'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

// Custom Logo Loader (Mimics the original's visual style)
class CustomLogoLoader extends StatelessWidget {
  const CustomLogoLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Text animation (simplified for Flutter conversion)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.5, end: 1.0),
              duration: const Duration(milliseconds: 750),
              builder: (context, opacity, child) {
                return Opacity(
                  opacity: opacity,
                  child: Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
              // For continuous repeat, a StatefulWidget with AnimationController is needed.
              // This will animate once.
            ),
            const SizedBox(height: 16.0),
            SizedBox(
              width: 192.0, // Equivalent to w-48
              height: 6.0, // Equivalent to h-1.5
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Main Screen Widget
class OneToOneMeetingScreen extends StatefulWidget {
  const OneToOneMeetingScreen({super.key});

  @override
  State<OneToOneMeetingScreen> createState() => _OneToOneMeetingScreenState();
}

class _OneToOneMeetingScreenState extends State<OneToOneMeetingScreen>
    with SingleTickerProviderStateMixin {
  List<Member> _members = [];
  List<Meeting> _meetings = [];
  bool _isCompletionModalOpen = false;
  Meeting? _selectedMeetingForCompletion;
  List<File> _completionImages = []; // Stores File objects for local display
  bool _isLoading = false;

  // User data from SharedPreferences
  String? _fromMID;
  String? _gID;
  String? _groupCode;

  // Search term for members tab
  String _searchTerm = "";

  late TabController _tabController;
  int _previousTabIndex = 0; // To store the index of the last selected content tab

  // Define all tabs with their properties
  final List<Map<String, dynamic>> _tabsData = [
    {"id": "my_meetings", "label": "My Meetings", "icon": LucideIcons.calendar},
    {"id": "group_members", "label": "Group Members", "icon": LucideIcons.users},
    {"id": "scheduled", "label": "Scheduled Meeting", "icon": LucideIcons.clock},
    {"id": "history", "label": "History", "icon": LucideIcons.history},
    {"id": "new_meeting", "label": "New Meeting", "icon": LucideIcons.plus}, // New tab for the button
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabsData.length, vsync: this);
    _tabController.addListener(_handleTabSelection); // Add listener for tab changes
    _loadUserDataAndFetchData();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      final currentTabId = _tabsData[_tabController.index]["id"];
      if (currentTabId == "new_meeting") {
        // If "New Meeting" tab is selected, navigate to new screen and revert tab
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewMeetingScreen(
                members: _members,
                fromMID: _fromMID!,
                gID: _gID!,
                onMeetingSent: _fetchMeetings, // Callback to refresh meetings
              ),
            ),
          );
          // Revert to the previous tab after returning from NewMeetingScreen
          _tabController.animateTo(_previousTabIndex,
              duration: const Duration(milliseconds: 300), curve: Curves.ease);
        });
      } else {
        // For regular content tabs, update previousTabIndex
        _previousTabIndex = _tabController.index;
        // No need to update _activeTab or _rejectFilter here as they are managed internally now
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection); // Remove listener
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDataAndFetchData() async {
    setState(() {
      _isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    _fromMID = prefs.getString('M_ID');
    _gID = prefs.getString('G_ID');
    _groupCode = prefs.getString('Grop_code');

    if (_gID != null && _fromMID != null) {
      await Future.wait([_fetchMembers(), _fetchMeetings()]);
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchMembers() async {
    try {
      final response = await http.get(
        Uri.parse("https://tagai.caxis.ca/public/api/member"),
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status']) {
          final List<Member> fetchedMembers = (data['members'] as List)
              .map((json) => Member.fromJson(json))
              .where((member) =>
                  member.status == "1" &&
                  member.groupCode == _groupCode &&
                  member.mId != _fromMID)
              .toList();
          setState(() {
            _members = fetchedMembers;
          });
        }
      } else {
        throw Exception('Failed to load members: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching members: $e");
      setState(() {
        _members = [];
      });
    }
  }

  Future<void> _fetchMeetings() async {
    try {
      final response = await http.get(
        Uri.parse("https://tagai.caxis.ca/public/api/one2one"),
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Meeting> fetchedMeetings =
            data.map((json) => Meeting.fromJson(json)).toList();
        setState(() {
          _meetings = fetchedMeetings;
        });
      } else {
        throw Exception('Failed to load meetings: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching meetings: $e");
      setState(() {
        _meetings = [];
      });
    }
  }

  Future<void> _handleAcceptMeeting(String meetingId) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.put(
        Uri.parse("https://tagai.caxis.ca/public/api/one2one/$meetingId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"Status": "1"}),
      );
      if (response.statusCode == 200) {
        _fetchMeetings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Meeting accepted successfully!")),
        );
      } else {
        throw Exception("Failed to accept meeting");
      }
    } catch (e) {
      print("Error accepting meeting: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error accepting meeting: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRejectMeeting(String meetingId) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.put(
        Uri.parse("https://tagai.caxis.ca/public/api/one2one/$meetingId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"Status": "2"}),
      );
      if (response.statusCode == 200) {
        _fetchMeetings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Meeting rejected successfully!")),
        );
      } else {
        throw Exception("Failed to reject meeting");
      }
    } catch (e) {
      print("Error rejecting meeting: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error rejecting meeting: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openCompletionModal(Meeting meeting) {
    setState(() {
      _selectedMeetingForCompletion = meeting;
      _isCompletionModalOpen = true;
      _completionImages = [];
    });
  }

  Future<void> _handleCompletionImageUpload() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles != null) {
      setState(() {
        _completionImages.addAll(pickedFiles.map((xfile) => File(xfile.path)));
      });
    }
  }

  void _removeCompletionImage(int index) {
    setState(() {
      _completionImages.removeAt(index);
    });
  }

  Future<void> _handleCompleteMeeting(bool withImages) async {
    if (_selectedMeetingForCompletion == null) return;

    setState(() {
      _isLoading = true;
    });

    // In a real app, you would upload images to a server and get their URLs.
    // For this example, we'll just pass the local paths as strings.
    // The original React code also just stored local URLs.
    final List<String> imageUrls = withImages
        ? _completionImages.map((file) => file.path).toList()
        : [];

    final payload = {
      "Status": "3",
      "Image": imageUrls, // Sending local paths/URLs as strings
    };

    try {
      final response = await http.put(
        Uri.parse(
            "https://tagai.caxis.ca/public/api/one2one/${_selectedMeetingForCompletion!.one2oneId}"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        _fetchMeetings(); // Re-fetch to update status and images
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Meeting marked as completed successfully!")),
        );
        setState(() {
          _isCompletionModalOpen = false;
          _selectedMeetingForCompletion = null;
          _completionImages = [];
        });
      } else {
        throw Exception("Failed to complete meeting: ${response.body}");
      }
    } catch (e) {
      print("Error completing meeting: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to complete meeting: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Member> get _filteredMembers {
    return _members.where((member) {
      final lowerCaseSearchTerm = _searchTerm.toLowerCase();
      return member.name.toLowerCase().contains(lowerCaseSearchTerm) ||
          member.email.toLowerCase().contains(lowerCaseSearchTerm);
    }).toList();
  }

  List<Meeting> get _allMeetingsForUser {
    return _meetings.where((meeting) =>
        meeting.gId == _gID &&
        (meeting.fromMid == _fromMID || meeting.toMid == _fromMID)).toList();
  }

  List<Meeting> get _pendingRequestsForUser {
    return _meetings.where((meeting) =>
        meeting.toMid == _fromMID && meeting.status == "0").toList();
  }

  List<Meeting> get _sentRequestsForUser {
    return _meetings.where((meeting) =>
        meeting.fromMid == _fromMID &&
        (meeting.status == "0" || meeting.status == "1" || meeting.status == "2")).toList();
  }

  List<Meeting> get _scheduledMeetingsForUser {
    return _meetings.where((meeting) =>
        meeting.status == "1" &&
        (meeting.fromMid == _fromMID || meeting.toMid == _fromMID) &&
        !_isMeetingDatePassed(meeting)).toList(); // Only future scheduled meetings
  }

  List<Meeting> get _completedMeetingsForUser {
    return _meetings.where((meeting) =>
        meeting.status == "3" &&
        (meeting.fromMid == _fromMID || meeting.toMid == _fromMID)).toList();
  }

  List<Meeting> get _rejectedMeetingsForUser {
    return _meetings.where((meeting) =>
        meeting.status == "2" &&
        (meeting.fromMid == _fromMID || meeting.toMid == _fromMID)).toList();
  }

  bool _isMeetingDatePassed(Meeting meeting) {
    try {
      final meetingDateTime = DateTime.parse("${meeting.date}T${meeting.time}");
      return meetingDateTime.isBefore(DateTime.now());
    } catch (e) {
      print("Error parsing date/time for meeting: ${meeting.date}T${meeting.time} - $e");
      return false; // Or handle error appropriately
    }
  }

  // Helper to get the count for a specific tab ID
  int _getTabCount(String tabId) {
    switch (tabId) {
      case "my_meetings":
        return _allMeetingsForUser.length; // My Meetings shows all relevant meetings
      case "group_members":
        return _members.length;
      case "scheduled":
        return _scheduledMeetingsForUser.length;
      case "history":
        return _completedMeetingsForUser.length;
      default:
        return 0; // For "new_meeting" tab, count is 0
    }
  }

  // Helper to build the content of a regular tab (with count)
  Widget _buildTabContent(IconData icon, String label, int count, int tabIndex) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label),
          if (count > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _tabController.index == tabIndex
                      ? Colors.white.withOpacity(0.2) // Selected state
                      : Colors.grey[200], // Unselected state
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _tabController.index == tabIndex
                        ? Colors.white // Selected state
                        : Colors.grey[700], // Unselected state
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabsData.length, // Total number of tabs including "New Meeting"
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'One-To-One',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100.0), // Adjusted height for title/subtitle and TabBar
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'One-To-One',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      Text(
                        'Manage your professional meetings efficiently',
                        style: TextStyle(color: Colors.grey[300], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true, // Allows tabs to scroll if many
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[400],
                  indicator: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  tabs: _tabsData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final tabData = entry.value;
                    return _buildTabContent(
                      tabData["icon"],
                      tabData["label"],
                      _getTabCount(tabData["id"]),
                      index, // Pass current index to helper for indicator color
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _buildMyMeetingsTab(), // New consolidated tab
                _buildMembersTab(),
                _buildMeetingsTab(_scheduledMeetingsForUser, showActions: true),
                _buildMeetingsTab(_completedMeetingsForUser, isHistory: true),
                const Center(child: Text("")), // Placeholder for the "New Meeting" tab
              ],
            ),
            if (_isLoading) const CustomLogoLoader(),
            if (_isCompletionModalOpen) _buildCompletionModal(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMyMeetingsTab() {
    // Internal state for My Meetings tab's filter
    // This state is local to this widget's build method, managed by StatefulBuilder
    String myMeetingsFilter = "all"; // all, pending, accepted, rejected, completed

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setInnerState) {
        List<Meeting> filteredList;
        switch (myMeetingsFilter) {
          case "all":
            filteredList = _allMeetingsForUser;
            break;
          case "pending":
            filteredList = _pendingRequestsForUser;
            break;
          case "accepted":
            filteredList = _allMeetingsForUser.where((m) => m.status == "1").toList(); // All accepted, not just future
            break;
          case "rejected":
            filteredList = _rejectedMeetingsForUser;
            break;
          case "completed":
            filteredList = _completedMeetingsForUser;
            break;
          default:
            filteredList = _allMeetingsForUser;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Meetings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ToggleButtons(
                        isSelected: [
                          myMeetingsFilter == "all",
                          myMeetingsFilter == "pending",
                          myMeetingsFilter == "accepted",
                          myMeetingsFilter == "rejected",
                          myMeetingsFilter == "completed",
                        ],
                        onPressed: (int index) {
                          setInnerState(() {
                            myMeetingsFilter = [
                              "all",
                              "pending",
                              "accepted",
                              "rejected",
                              "completed"
                            ][index];
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: Colors.black,
                        color: Colors.grey[700],
                        borderColor: Colors.grey[300],
                        selectedBorderColor: Colors.black,
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text('All'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text('Pending'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text('Accepted'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text('Rejected'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text('Completed'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (filteredList.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1, // One column for better mobile layout
                    childAspectRatio: 3 / 2, // Adjust as needed
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 280, // Fixed height for cards
                  ),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final meeting = filteredList[index];
                    return MeetingCard(
                      meeting: meeting,
                      showActions: meeting.status == "0" || (meeting.status == "1" && _isMeetingDatePassed(meeting)),
                      isHistory: meeting.status == "3",
                      isMeetingDatePassed: _isMeetingDatePassed(meeting),
                      onAccept: _handleAcceptMeeting,
                      onReject: _handleRejectMeeting,
                      onComplete: _openCompletionModal,
                      showSentStatus: meeting.fromMid == _fromMID && meeting.status == "0",
                      fromMID: _fromMID!,
                    );
                  },
                )
              else
                _buildEmptyState(
                  LucideIcons.calendar,
                  'No meetings found for this filter',
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMeetingsTab(List<Meeting> meetings,
      {bool showActions = false, bool isHistory = false, bool showSentStatus = false}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meetings.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1, // One column for better mobile layout
                childAspectRatio: 3 / 2, // Adjust as needed
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 280, // Fixed height for cards
              ),
              itemCount: meetings.length,
              itemBuilder: (context, index) {
                final meeting = meetings[index];
                return MeetingCard(
                  meeting: meeting,
                  showActions: showActions,
                  isHistory: isHistory,
                  isMeetingDatePassed: _isMeetingDatePassed(meeting),
                  onAccept: _handleAcceptMeeting,
                  onReject: _handleRejectMeeting,
                  onComplete: _openCompletionModal,
                  showSentStatus: showSentStatus,
                  fromMID: _fromMID!,
                );
              },
            )
          else
            _buildEmptyState(
              LucideIcons.calendar,
              'No meetings found',
            ),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Group Members',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchTerm = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search members...',
                      prefixIcon: const Icon(LucideIcons.search, size: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_filteredMembers.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Two columns for members
                childAspectRatio: 1.5, // Adjust as needed
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 150, // Fixed height for member cards
              ),
              itemCount: _filteredMembers.length,
              itemBuilder: (context, index) {
                final member = _filteredMembers[index];
                return MemberCard(
                  member: member,
                  onTap: (selectedMember) {
                    // Navigate to NewMeetingScreen with pre-selected member
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewMeetingScreen(
                          members: _members,
                          fromMID: _fromMID!,
                          gID: _gID!,
                          preSelectedMember: selectedMember,
                          onMeetingSent: _fetchMeetings,
                        ),
                      ),
                    );
                  },
                );
              },
            )
          else
            _buildEmptyState(
              LucideIcons.users,
              'No members found',
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionModal(BuildContext context) {
    if (_selectedMeetingForCompletion == null) return const SizedBox.shrink();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
            maxWidth: 400, maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Complete Meeting',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () {
                    setState(() {
                      _isCompletionModalOpen = false;
                      _selectedMeetingForCompletion = null;
                      _completionImages = [];
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meeting Details',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey[700]),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                      LucideIcons.users,
                      _selectedMeetingForCompletion!.fromMid == _fromMID
                          ? _selectedMeetingForCompletion!.toMember?.name ?? 'N/A'
                          : _selectedMeetingForCompletion!.fromMember?.name ?? 'N/A'),
                  _buildDetailRow(
                      LucideIcons.mapPin, _selectedMeetingForCompletion!.place),
                  _buildDetailRow(
                      LucideIcons.calendar,
                      DateFormat('MMM d, yyyy').format(
                          DateTime.parse(_selectedMeetingForCompletion!.date))),
                  _buildDetailRow(
                      LucideIcons.clock, _selectedMeetingForCompletion!.time),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Meeting Photos (Optional)',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blueGrey[700]),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _handleCompletionImageUpload,
                  child: DottedBorderContainer(
                    child: Column(
                      children: [
                        Icon(LucideIcons.camera, size: 32, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'Click to upload meeting photos',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_completionImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Photos:',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.blueGrey[700]),
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: _completionImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _completionImages[index],
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () => _removeCompletionImage(index),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleCompleteMeeting(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(LucideIcons.checkCircle, size: 16),
                    label: const Text('Complete with Photos'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleCompleteMeeting(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Skip Photos'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// New Meeting Screen
class NewMeetingScreen extends StatefulWidget {
  final List<Member> members;
  final String fromMID;
  final String gID;
  final Member? preSelectedMember;
  final VoidCallback onMeetingSent; // Callback to refresh data on previous screen

  const NewMeetingScreen({
    super.key,
    required this.members,
    required this.fromMID,
    required this.gID,
    this.preSelectedMember,
    required this.onMeetingSent,
  });

  @override
  State<NewMeetingScreen> createState() => _NewMeetingScreenState();
}

class _NewMeetingScreenState extends State<NewMeetingScreen> {
  Member? _selectedMember;
  String _memberSearchTerm = "";
  bool _isLoading = false;

  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedMember = widget.preSelectedMember;
  }

  @override
  void dispose() {
    _placeController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  List<Member> get _filteredMembersForForm {
    return widget.members.where((member) {
      final lowerCaseSearchTerm = _memberSearchTerm.toLowerCase();
      return member.name.toLowerCase().contains(lowerCaseSearchTerm) ||
          member.email.toLowerCase().contains(lowerCaseSearchTerm);
    }).toList();
  }

  Future<void> _handleSubmitMeetingRequest() async {
    if (_selectedMember == null) return;

    setState(() {
      _isLoading = true;
    });

    final payload = {
      "Place": _placeController.text,
      "Date": _dateController.text,
      "Time": _timeController.text,
      "G_ID": widget.gID,
      "From_MID": widget.fromMID,
      "To_MID": _selectedMember!.mId,
      "Status": "0",
    };

    try {
      final response = await http.post(
        Uri.parse("https://tagai.caxis.ca/public/api/one2one"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Meeting request sent successfully!")),
        );
        widget.onMeetingSent(); // Call callback to refresh data
        Navigator.pop(context); // Go back to previous screen
      } else {
        throw Exception("Failed to send meeting request: ${response.body}");
      }
    } catch (e) {
      print("Error sending meeting request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send meeting request: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Meeting Request'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios), // iOS back icon
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_selectedMember == null)
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          onChanged: (value) {
                            setState(() {
                              _memberSearchTerm = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search group members...',
                            prefixIcon: const Icon(LucideIcons.search, size: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _filteredMembersForForm.length,
                            itemBuilder: (context, index) {
                              final member = _filteredMembersForForm[index];
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedMember = member;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[200]!),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            member.name.isNotEmpty
                                                ? member.name[0].toUpperCase()
                                                : '',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            member.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500, fontSize: 14),
                                          ),
                                          Text(
                                            member.email,
                                            style: TextStyle(
                                                color: Colors.grey[500], fontSize: 12),
                                          ),
                                        ],
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
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sending request to:',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                                Text(
                                  _selectedMember!.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500, color: Colors.black),
                                ),
                                Text(
                                  _selectedMember!.email,
                                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedMember = null;
                                      _memberSearchTerm = "";
                                    });
                                  },
                                  child: Text(
                                    'Change recipient',
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                        decoration: TextDecoration.underline),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _placeController,
                            label: 'Meeting Location',
                            hint: 'Enter meeting location',
                            icon: LucideIcons.mapPin,
                          ),
                          const SizedBox(height: 16),
                          _buildDateField(
                            controller: _dateController,
                            label: 'Meeting Date',
                            context: context,
                          ),
                          const SizedBox(height: 16),
                          _buildTimeField(
                            controller: _timeController,
                            label: 'Meeting Time',
                            context: context,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _handleSubmitMeetingRequest,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(LucideIcons.send, size: 16),
                              label: const Text('Send Meeting Request'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoading) const CustomLogoLoader(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 20) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blueGrey, width: 2),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'Select Date',
            prefixIcon: const Icon(LucideIcons.calendar, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blueGrey, width: 2),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          onTap: () async {
            DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2101),
            );
            if (pickedDate != null) {
              controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTimeField({
    required TextEditingController controller,
    required String label,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'Select Time',
            prefixIcon: const Icon(LucideIcons.clock, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blueGrey, width: 2),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          onTap: () async {
            TimeOfDay? pickedTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (pickedTime != null) {
              // Format TimeOfDay to a string like "HH:mm"
              final MaterialLocalizations localizations = MaterialLocalizations.of(context);
              controller.text = localizations.formatTimeOfDay(pickedTime, alwaysUse24HourFormat: true);
            }
          },
        ),
      ],
    );
  }
}

// Meeting Card Widget
class MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final bool showActions;
  final bool isHistory;
  final bool isMeetingDatePassed;
  final Function(String)? onAccept;
  final Function(String)? onReject;
  final Function(Meeting)? onComplete;
  final bool showSentStatus;
  final String fromMID;

  const MeetingCard({
    super.key,
    required this.meeting,
    this.showActions = false,
    this.isHistory = false,
    this.isMeetingDatePassed = false,
    this.onAccept,
    this.onReject,
    this.onComplete,
    this.showSentStatus = false,
    required this.fromMID,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case "0":
        return Colors.amber[50]!;
      case "1":
        return Colors.green[50]!; // Mapped from emerald
      case "2":
        return Colors.red[50]!;
      case "3":
        return Colors.blue[50]!;
      default:
        return Colors.grey[50]!;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case "0":
        return Colors.amber[700]!;
      case "1":
        return Colors.green[700]!; // Mapped from emerald
      case "2":
        return Colors.red[700]!;
      case "3":
        return Colors.blue[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case "0":
        return "Pending";
      case "1":
        return "Accepted";
      case "2":
        return "Rejected";
      case "3":
        return "Completed";
      default:
        return "Unknown";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFromMe = meeting.fromMid == fromMID;
    final partnerName = isFromMe ? meeting.toMember?.name : meeting.fromMember?.name;
    final partnerInitial = partnerName?.isNotEmpty == true ? partnerName![0].toUpperCase() : '';

    return Card(
      elevation: 2, // Added subtle shadow
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Slightly more rounded
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              partnerInitial,
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      partnerName ?? 'N/A',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(meeting.status),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(meeting.status).withOpacity(0.5)),
                  ),
                  child: Text(
                    _getStatusText(meeting.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getStatusTextColor(meeting.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(LucideIcons.mapPin, meeting.place),
            _buildInfoRow(
                LucideIcons.calendar,
                DateFormat('EEE, MMM d, yyyy')
                    .format(DateTime.parse(meeting.date))),
            _buildInfoRow(LucideIcons.clock, meeting.time),
            const SizedBox(height: 16),
            if (meeting.images.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.image, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Text(
                        'Meeting Photos',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...meeting.images.take(3).map((imgUrl) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                File(imgUrl), // Assuming imgUrl is a local file path
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                                ),
                              ),
                            ),
                          )),
                      if (meeting.images.length > 3)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Center(
                            child: Text(
                              '+${meeting.images.length - 3}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600]),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            if (showActions && meeting.status == "0" && meeting.toMid == fromMID)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onAccept?.call(meeting.one2oneId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: const Text('Accept', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onReject?.call(meeting.one2oneId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(LucideIcons.x, size: 16),
                      label: const Text('Decline', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            if (showActions && meeting.status == "1" && isMeetingDatePassed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onComplete?.call(meeting),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(LucideIcons.checkCircle, size: 16),
                  label: const Text('Mark as Completed', style: TextStyle(fontSize: 14)),
                ),
              ),
            if (showSentStatus && meeting.status == "0")
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Text(
                    'Awaiting Response',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.amber[700],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// Member Card Widget
class MemberCard extends StatelessWidget {
  final Member member;
  final Function(Member) onTap;

  const MemberCard({
    super.key,
    required this.member,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(member),
      child: Card(
        elevation: 2, // Added subtle shadow
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Slightly more rounded
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        member.name.isNotEmpty ? member.name[0].toUpperCase() : '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          member.email,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                member.number,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const Spacer(), // Pushes the button to the bottom
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton.icon(
                  onPressed: () => onTap(member),
                  icon: Icon(LucideIcons.userPlus, size: 16, color: Colors.blueGrey[600]),
                  label: Text(
                    'Send Request',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey[600]),
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

// Custom Dotted Border Container for image upload area
class DottedBorderContainer extends StatelessWidget {
  final Widget child;

  const DottedBorderContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey[300]!,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: child),
    );
  }
}
