import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';

// App Theme
class AppTheme {
  static const Color primaryColor = Colors.black;
  static const Color secondaryColor = Color(0xFF64748B);
  static const Color accentColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color surfaceColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    ),
  );
}

// Member model
class Member {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String gropCode;
  final int status;
  final String address;
  final String createdAt;

  Member({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.gropCode,
    required this.status,
    required this.address,
    required this.createdAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    final idValue = json['M_ID'];
    if (idValue == null || idValue.toString().isEmpty) {
      throw FormatException('Invalid or missing M_ID: $idValue');
    }
    final parsedId = int.tryParse(idValue.toString());
    if (parsedId == null) {
      throw FormatException('Invalid M_ID format: ${idValue.toString()}');
    }

    final statusValue = json['status'];
    final parsedStatus = int.tryParse(statusValue?.toString() ?? '0') ?? 0;

    return Member(
      id: parsedId,
      name: json['Name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['number']?.toString() ?? '',
      gropCode: json['Grop_code']?.toString() ?? '',
      status: parsedStatus,
      address: json['address']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

// MeetingRequest model
class MeetingRequest {
  final int id;
  final String place;
  final String date;
  final String time;
  final String status;
  final String gropCode;
  final String gId;
  final Member fromMember;
  final Member toMember;
  final String toMID;
  final String fromMID;
  final List<String> image;

  MeetingRequest({
    required this.id,
    required this.place,
    required this.date,
    required this.time,
    required this.status,
    required this.gropCode,
    required this.gId,
    required this.fromMember,
    required this.toMember,
    required this.toMID,
    required this.fromMID,
    required this.image,
  });

  factory MeetingRequest.fromJson(Map<String, dynamic> json) {
    final idValue = json['one2one_id']?.toString();
    if (idValue == null || idValue.isEmpty) {
      throw FormatException('Invalid or missing one2one_id: $idValue');
    }
    final parsedId = int.tryParse(idValue);
    if (parsedId == null) {
      throw FormatException('Invalid one2one_id format: $idValue');
    }

    if (json['from_member'] == null || json['to_member'] == null) {
      throw FormatException('Missing from_member or to_member in JSON');
    }

    final toMID = json['To_MID']?.toString() ?? '';
    final fromMID = json['From_MID']?.toString() ?? '';
    List<String> images = [];
    if (json['Image'] != null) {
      if (json['Image'] is List) {
        images = List<String>.from(json['Image'].map((item) => item.toString()));
      } else if (json['Image'] is String) {
        images = [json['Image'].toString()];
      }
    }

    try {
      return MeetingRequest(
        id: parsedId,
        place: json['Place']?.toString() ?? '',
        date: json['Date']?.toString() ?? '',
        time: json['Time']?.toString() ?? '',
        status: json['Status']?.toString() ?? '',
        gropCode: json['Grop_code']?.toString() ?? '',
        gId: json['G_ID']?.toString() ?? '',
        fromMember: Member.fromJson(json['from_member'] as Map<String, dynamic>),
        toMember: Member.fromJson(json['to_member'] as Map<String, dynamic>),
        toMID: toMID,
        fromMID: fromMID,
        image: images,
      );
    } catch (e) {
      throw FormatException('Error parsing MeetingRequest: $e');
    }
  }
}

// Custom App Bar Widget
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.black,
      elevation: 2,
      leading: showBackButton
          ? leading ??
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: onBackPressed ?? () => Navigator.pop(context),
              )
          : leading,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Loading Widget
class LoadingWidget extends StatelessWidget {
  final String message;

  const LoadingWidget({super.key, this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Error Widget
class ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Empty State Widget
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                icon,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// OneToOnePage - Team Members Page
class OneToOnePage extends StatefulWidget {
  const OneToOnePage({super.key});

  @override
  State<OneToOnePage> createState() => _OneToOnePageState();
}

class _OneToOnePageState extends State<OneToOnePage> {
  List<Member> members = [];
  List<Member> filteredMembers = [];
  bool isLoading = true;
  String? errorMessage;
  String? gropCode;
  String? loggedInUserEmail;
  String? loggedInUserMID;
  String? loggedInGID;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadGropCodeAndMembers();
  }

  Future<void> _debugSharedPreferences(String context) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    debugPrint('SharedPreferences ($context):');
    if (keys.isEmpty) {
      debugPrint('  No keys found in SharedPreferences');
    } else {
      for (var key in keys) {
        debugPrint('  $key: ${prefs.get(key)}');
      }
    }
  }

  Future<void> _loadGropCodeAndMembers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await _debugSharedPreferences('OneToOnePage');

      final storedGropCode = prefs.getString('Grop_code') ?? prefs.getString('group_code');
      final storedEmail = prefs.getString('user_email');
      final storedGID = prefs.getString('user_id');

      debugPrint('Stored Grop_code: $storedGropCode, user_email: $storedEmail, G_ID: $storedGID');

      if (storedGropCode == null || storedGropCode.trim().isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'No group code found. Please try again later.';
        });
        return;
      }

      if (storedGID == null || storedGID.trim().isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'No group ID found. Please try again later.';
        });
        return;
      }

      setState(() {
        gropCode = storedGropCode.trim();
        loggedInUserEmail = storedEmail;
        loggedInGID = storedGID.trim();
      });

      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/member'));
      debugPrint('Member API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint('Member API Response: $jsonData');

        List<dynamic> data;
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('members')) {
          data = jsonData['members'] is List ? jsonData['members'] : [];
        } else {
          setState(() {
            isLoading = false;
            errorMessage = 'Unexpected JSON structure: No members list found';
          });
          return;
        }

        try {
          final membersList = data
              .map((json) => Member.fromJson(json as Map<String, dynamic>))
              .where((member) =>
                  member.gropCode == gropCode &&
                  member.status == 1 &&
                  member.email != loggedInUserEmail)
              .toList();

          final userMember = data
              .map((json) => Member.fromJson(json as Map<String, dynamic>))
              .firstWhere(
                (member) => member.email == loggedInUserEmail && member.gropCode == gropCode,
                orElse: () => Member(
                  id: 0,
                  name: '',
                  email: '',
                  phone: '',
                  gropCode: '',
                  status: 0,
                  address: '',
                  createdAt: '',
                ),
              );

          setState(() {
            members = membersList;
            filteredMembers = membersList;
            loggedInUserMID = userMember.id != 0 ? userMember.id.toString() : null;
            isLoading = false;
            errorMessage = loggedInUserMID == null ? 'Could not find user ID. Please try again later.' : null;
          });
        } catch (e) {
          setState(() {
            isLoading = false;
            errorMessage = 'Error parsing members: $e';
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load members: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching members: $e';
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0 && loggedInUserMID != null && loggedInGID != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleMeetingsPage(
            loggedInUserMID: loggedInUserMID,
            loggedInGID: loggedInGID,
          ),
        ),
      );
    } else if (index == 1 && loggedInUserMID != null && loggedInGID != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryPage(
            loggedInUserMID: loggedInUserMID,
            loggedInGID: loggedInGID,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: CustomAppBar(
  title: 'One-2-One Meeting',
  showBackButton: true, // Enable back button
  leading: IconButton(
    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
    onPressed: () {
      Navigator.pop(context);
    },
  ),
  actions: [
    Container(
      margin: const EdgeInsets.only(right: 8),
    
      child: IconButton(
        icon: const Icon(Icons.notifications_outlined, color: Colors.white),
        onPressed: () {
          if (loggedInUserMID != null && loggedInGID != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RequestsPage(
                  loggedInUserMID: loggedInUserMID,
                  loggedInGID: loggedInGID,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User information missing. Please try again later.'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        },
      ),
    ),
  ],
),
      body: RefreshIndicator(
        onRefresh: _loadGropCodeAndMembers,
        color: Colors.black,
        child: isLoading
            ? const LoadingWidget(message: 'Loading team members...')
            : errorMessage != null
                ? ErrorWidget(
                    message: errorMessage!,
                    onRetry: _loadGropCodeAndMembers,
                  )
                : filteredMembers.isEmpty
                    ? const EmptyStateWidget(
                        title: 'No Team Members',
                        message: 'No active members found for this group',
                        icon: Icons.people_outline,
                      )
                    : Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.people, color: Colors.black, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  '${filteredMembers.length} Active Members',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.85, // Fixed aspect ratio to prevent overflow
                              ),
                              itemCount: filteredMembers.length,
                              itemBuilder: (context, index) {
                                final member = filteredMembers[index];
                                return _buildMemberCard(member);
                              },
                            ),
                          ),
                        ],
                      ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule_outlined),
              activeIcon: Icon(Icons.schedule),
              label: 'Meetings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey[600],
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildMemberCard(Member member) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (loggedInUserMID != null && loggedInGID != null) {
            debugPrint('Navigating to Arrange Meeting with member: ${member.name} (ID: ${member.id})');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArrangeMeetingPage(
                  member: member,
                  fromMID: loggedInUserMID,
                  gId: loggedInGID,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User information missing. Please try again later.'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12), // Reduced padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48, // Reduced size
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20, // Reduced font size
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8), // Reduced spacing
              Text(
                member.name,
                style: const TextStyle(
                  fontSize: 14, // Reduced font size
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                member.email,
                style: TextStyle(
                  fontSize: 10, // Reduced font size
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                member.phone,
                style: TextStyle(
                  fontSize: 10, // Reduced font size
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8), // Reduced spacing
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (loggedInUserMID != null && loggedInGID != null) {
                      debugPrint('Arrange meeting button pressed for ${member.name} (ID: ${member.id})');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ArrangeMeetingPage(
                            member: member,
                            fromMID: loggedInUserMID,
                            gId: loggedInGID,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User information missing. Please try again later.'),
                          backgroundColor: AppTheme.errorColor,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 6), // Reduced padding
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Arrange Meeting',
                    style: TextStyle(
                      fontSize: 10, // Reduced font size
                      fontWeight: FontWeight.w600,
                    ),
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

// NEW: History Page - Shows meetings with Status "3"
class HistoryPage extends StatefulWidget {
  final String? loggedInUserMID;
  final String? loggedInGID;

  const HistoryPage({super.key, this.loggedInUserMID, this.loggedInGID});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<MeetingRequest> historyMeetings = [];
  bool isLoading = true;
  String? errorMessage;
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _loadHistoryMeetings();
  }

  Future<void> _loadHistoryMeetings() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      String? mId = widget.loggedInUserMID;
      String? gId = widget.loggedInGID;
      
      if (mId == null || gId == null) {
        final storedGID = prefs.getString('user_id');
        final storedEmail = prefs.getString('user_email');
        if (storedGID == null || storedGID.trim().isEmpty) {
          setState(() {
            isLoading = false;
            errorMessage = 'No group ID found. Please try again later.';
          });
          return;
        }
        
        final memberResponse = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/member'));
        if (memberResponse.statusCode == 200) {
          final memberData = json.decode(memberResponse.body);
          List<dynamic> members = memberData is Map<String, dynamic> && memberData.containsKey('members')
              ? memberData['members']
              : [];
          final userMember = members
              .map((json) => Member.fromJson(json as Map<String, dynamic>))
              .firstWhere(
                (member) => member.email == storedEmail,
                orElse: () => Member(
                  id: 0,
                  name: '',
                  email: '',
                  phone: '',
                  gropCode: '',
                  status: 0,
                  address: '',
                  createdAt: '',
                ),
              );
          mId = userMember.id != 0 ? userMember.id.toString() : null;
          gId = storedGID.trim();
        } else {
          setState(() {
            isLoading = false;
            errorMessage = 'Failed to fetch user information: HTTP ${memberResponse.statusCode}';
          });
          return;
        }
      }

      if (mId == null || mId.trim().isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'No user ID found. Please try again later.';
        });
        return;
      }

      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/one2one'));
      debugPrint('History API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint('History API Response: $jsonData');

        List<dynamic> data;
        if (jsonData is List) {
          data = jsonData;
        } else if (jsonData is Map<String, dynamic> && jsonData.containsKey('requests')) {
          data = jsonData['requests'] is List ? jsonData['requests'] : [];
        } else {
          data = [];
        }

        try {
          final historyList = data
              .map((json) {
                try {
                  return MeetingRequest.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('Error parsing individual history meeting: $e');
                  return null;
                }
              })
              .where((meeting) => meeting != null)
              .cast<MeetingRequest>()
              .where((meeting) => 
                  meeting.status == '3' && 
                  (meeting.fromMID == mId || meeting.toMID == mId))
              .toList();

          setState(() {
            historyMeetings = historyList;
            isLoading = false;
            errorMessage = null;
          });
        } catch (e) {
          setState(() {
            isLoading = false;
            errorMessage = 'Error processing history meetings: $e';
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load history meetings: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching history meetings: $e';
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0 && widget.loggedInUserMID != null && widget.loggedInGID != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleMeetingsPage(
            loggedInUserMID: widget.loggedInUserMID,
            loggedInGID: widget.loggedInGID,
          ),
        ),
      );
    } else if (index == 1) {
      // Already on history page
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: CustomAppBar(
        title: 'Meeting History',
        onBackPressed: () {
          // Navigate back to Team Members page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OneToOnePage()),
          );
        },
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${historyMeetings.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistoryMeetings,
        color: Colors.black,
        child: isLoading
            ? const LoadingWidget(message: 'Loading meeting history...')
            : errorMessage != null
                ? ErrorWidget(
                    message: errorMessage!,
                    onRetry: _loadHistoryMeetings,
                  )
                : historyMeetings.isEmpty
                    ? const EmptyStateWidget(
                        title: 'No Meeting History',
                        message: 'You have no completed meetings yet',
                        icon: Icons.history,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: historyMeetings.length,
                        itemBuilder: (context, index) {
                          final meeting = historyMeetings[index];
                          return _buildHistoryCard(meeting);
                        },
                      ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule_outlined),
              activeIcon: Icon(Icons.schedule),
              label: 'Meetings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey[600],
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildHistoryCard(MeetingRequest meeting) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Completed Meeting',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'With ${meeting.toMember.name}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'COMPLETED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.person_outline, 'From', '${meeting.fromMember.name} (${meeting.fromMember.email})'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.location_on_outlined, 'Place', meeting.place),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.calendar_today_outlined, 'Date', meeting.date),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.access_time_outlined, 'Time', meeting.time),
                  ],
                ),
              ),
              if (meeting.image.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Meeting Images',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: meeting.image.length,
                    itemBuilder: (context, index) {
                      final imageUrl = meeting.image[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildImageWidget(imageUrl),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
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

  Widget _buildImageWidget(String imageUrl) {
    if (imageUrl.startsWith('data:image') || RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(imageUrl)) {
      try {
        final decodedImage = base64Decode(
          imageUrl.startsWith('data:image')
              ? imageUrl.split(',')[1]
              : imageUrl,
        );
        return Image.memory(
          decodedImage,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 100,
            height: 100,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
        return Container(
          width: 100,
          height: 100,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
      }
    } else {
      return Image.network(
        imageUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 100,
            height: 100,
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.black,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          width: 100,
          height: 100,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    }
  }
}

// RequestsPage
class RequestsPage extends StatefulWidget {
  final String? loggedInUserMID;
  final String? loggedInGID;

  const RequestsPage({super.key, this.loggedInUserMID, this.loggedInGID});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  List<MeetingRequest> requests = [];
  bool isLoading = true;
  String? errorMessage;
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _debugSharedPreferences(String context) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    debugPrint('SharedPreferences ($context):');
    if (keys.isEmpty) {
      debugPrint('  No keys found in SharedPreferences');
    } else {
      for (var key in keys) {
        debugPrint('  $key: ${prefs.get(key)}');
      }
    }
  }

  Future<void> _loadRequests() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await _debugSharedPreferences('RequestsPage');

      String? mId = widget.loggedInUserMID;
      String? gId = widget.loggedInGID;
      if (mId == null || gId == null) {
        final storedGID = prefs.getString('user_id');
        final storedEmail = prefs.getString('user_email');
        if (storedGID == null || storedGID.trim().isEmpty) {
          setState(() {
            isLoading = false;
            errorMessage = 'No group ID found. Please try again later.';
          });
          return;
        }
        final memberResponse = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/member'));
        if (memberResponse.statusCode == 200) {
          final memberData = json.decode(memberResponse.body);
          List<dynamic> members = memberData is Map<String, dynamic> && memberData.containsKey('members')
              ? memberData['members']
              : [];
          final userMember = members
              .map((json) => Member.fromJson(json as Map<String, dynamic>))
              .firstWhere(
                (member) => member.email == storedEmail,
                orElse: () => Member(
                  id: 0,
                  name: '',
                  email: '',
                  phone: '',
                  gropCode: '',
                  status: 0,
                  address: '',
                  createdAt: '',
                ),
              );
          mId = userMember.id != 0 ? userMember.id.toString() : null;
          gId = storedGID.trim();
        } else {
          setState(() {
            isLoading = false;
            errorMessage = 'Failed to fetch user information: HTTP ${memberResponse.statusCode}';
          });
          return;
        }
      }

      if (mId == null || mId.trim().isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'No user ID found. Please try again later.';
        });
        return;
      }

      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/one2one'));
      debugPrint('Requests API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint('Requests API Response: $jsonData');

        List<dynamic> data;
        if (jsonData is List) {
          data = jsonData;
        } else if (jsonData is Map<String, dynamic> && jsonData.containsKey('requests')) {
          data = jsonData['requests'] is List ? jsonData['requests'] : [];
        } else {
          data = [];
        }

        try {
          final requestsList = data
              .map((json) {
                try {
                  return MeetingRequest.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('Error parsing individual request: $e');
                  return null;
                }
              })
              .where((request) => request != null)
              .cast<MeetingRequest>()
              .where((request) => request.toMID == mId && request.status == '0')
              .toList();

          setState(() {
            requests = requestsList;
            isLoading = false;
            errorMessage = null;
          });
        } catch (e) {
          setState(() {
            isLoading = false;
            errorMessage = 'Error processing requests: $e';
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load requests: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching requests: $e';
      });
    }
  }

  Future<void> _updateRequestStatus(int requestId, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gropCode = prefs.getString('Grop_code') ?? prefs.getString('group_code');
      final gId = widget.loggedInGID ?? prefs.getString('user_id');

      if (gropCode == null || gId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing group information. Please try again later.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      final payload = {
        'Status': status,
        'Grop_code': gropCode.trim(),
        'G_ID': gId.trim(),
      };

      final response = await http.put(
        Uri.parse('https://tagai.caxis.ca/public/api/one2one/$requestId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint('Update Request Status API Response Status: ${response.statusCode}');
      debugPrint('Update Request Status API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == '1' ? 'Request accepted successfully' : 'Request rejected'),
            backgroundColor: status == '1' ? AppTheme.accentColor : AppTheme.errorColor,
          ),
        );
        _loadRequests();
      } else {
        String errorMsg = 'Failed to update request status: HTTP ${response.statusCode}';
        try {
          final responseData = json.decode(response.body);
          if (responseData is Map<String, dynamic> && responseData['message'] != null) {
            errorMsg = responseData['message'].toString();
            if (responseData['data'] != null) {
              errorMsg += '\nDetails: ${jsonEncode(responseData['data'])}';
            }
          }
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating request: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0 && widget.loggedInUserMID != null && widget.loggedInGID != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleMeetingsPage(
            loggedInUserMID: widget.loggedInUserMID,
            loggedInGID: widget.loggedInGID,
          ),
        ),
      );
    } else if (index == 1 && widget.loggedInUserMID != null && widget.loggedInGID != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryPage(
            loggedInUserMID: widget.loggedInUserMID,
            loggedInGID: widget.loggedInGID,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: CustomAppBar(
        title: 'Meeting Requests',
        onBackPressed: () {
          // Navigate back to Team Members page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OneToOnePage()),
          );
        },
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${requests.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        color: Colors.black,
        child: isLoading
            ? const LoadingWidget(message: 'Loading meeting requests...')
            : errorMessage != null
                ? ErrorWidget(
                    message: errorMessage!,
                    onRetry: _loadRequests,
                  )
                : requests.isEmpty
                    ? const EmptyStateWidget(
                        title: 'No Pending Requests',
                        message: 'You have no pending meeting requests at the moment',
                        icon: Icons.notifications_none,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final request = requests[index];
                          return _buildRequestCard(request);
                        },
                      ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule_outlined),
              activeIcon: Icon(Icons.schedule),
              label: 'Meetings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey[600],
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildRequestCard(MeetingRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        request.fromMember.name.isNotEmpty 
                            ? request.fromMember.name[0].toUpperCase() 
                            : 'M',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meeting Request',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'From ${request.fromMember.name}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'PENDING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.person_outline, 'To', '${request.toMember.name} (${request.toMember.email})'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.location_on_outlined, 'Place', request.place),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.calendar_today_outlined, 'Date', request.date),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.access_time_outlined, 'Time', request.time),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateRequestStatus(request.id, '2'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateRequestStatus(request.id, '1'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
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

// ArrangeMeetingPage
class ArrangeMeetingPage extends StatefulWidget {
  final Member member;
  final String? fromMID;
  final String? gId;

  const ArrangeMeetingPage({super.key, required this.member, this.fromMID, this.gId});

  @override
  State<ArrangeMeetingPage> createState() => _ArrangeMeetingPageState();
}

class _ArrangeMeetingPageState extends State<ArrangeMeetingPage> {
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  bool isSubmitting = false;
  String? errorMessage;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _debugSharedPreferences('ArrangeMeetingPage');
  }

  @override
  void dispose() {
    _placeController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _debugSharedPreferences(String context) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    debugPrint('SharedPreferences ($context):');
    if (keys.isEmpty) {
      debugPrint('  No keys found in SharedPreferences');
    } else {
      for (var key in keys) {
        debugPrint('  $key: ${prefs.get(key)}');
      }
    }
  }

  Future<void> _submitMeeting() async {
    if (_placeController.text.trim().isEmpty ||
        _dateController.text.trim().isEmpty ||
        _timeController.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please fill in all fields';
      });
      return;
    }

    // Validate date format (YYYY-MM-DD)
    final dateRegExp = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dateRegExp.hasMatch(_dateController.text.trim())) {
      setState(() {
        errorMessage = 'Invalid date format. Use YYYY-MM-DD';
      });
      return;
    }

    // Validate time format (HH:MM)
    final timeRegExp = RegExp(r'^\d{2}:\d{2}$');
    if (!timeRegExp.hasMatch(_timeController.text.trim())) {
      setState(() {
        errorMessage = 'Invalid time format. Use HH:MM';
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final gropCode = prefs.getString('Grop_code') ?? prefs.getString('group_code');
      String? fromMID = widget.fromMID;
      String? gId = widget.gId;
      if (fromMID == null || gId == null) {
        final storedGID = prefs.getString('user_id');
        final storedEmail = prefs.getString('user_email');
        if (storedGID == null || storedGID.trim().isEmpty) {
          setState(() {
            isSubmitting = false;
            errorMessage = 'No group ID found. Please try again later.';
          });
          return;
        }
        final memberResponse = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/member'));
        if (memberResponse.statusCode == 200) {
          final memberData = json.decode(memberResponse.body);
          List<dynamic> members = memberData is Map<String, dynamic> && memberData.containsKey('members')
              ? memberData['members']
              : [];
          final userMember = members
              .map((json) => Member.fromJson(json as Map<String, dynamic>))
              .firstWhere(
                (member) => member.email == storedEmail,
                orElse: () => Member(
                  id: 0,
                  name: '',
                  email: '',
                  phone: '',
                  gropCode: '',
                  status: 0,
                  address: '',
                  createdAt: '',
                ),
              );
          fromMID = userMember.id != 0 ? userMember.id.toString() : null;
          gId = storedGID.trim();
        } else {
          setState(() {
            isSubmitting = false;
            errorMessage = 'Failed to fetch user information: HTTP ${memberResponse.statusCode}';
          });
          return;
        }
      }

      if (fromMID == null || fromMID.trim().isEmpty) {
        setState(() {
          isSubmitting = false;
          errorMessage = 'No user ID found.';
        });
        return;
      }

      if (gropCode == null || gropCode.trim().isEmpty) {
        setState(() {
          isSubmitting = false;
          errorMessage = 'No group code found.';
        });
        return;
      }

      if (gId == null || gId.trim().isEmpty) {
        setState(() {
          isSubmitting = false;
          errorMessage = 'No group ID found.';
        });
        return;
      }

      final payload = {
        'Place': _placeController.text.trim(),
        'Date': _dateController.text.trim(),
        'Time': _timeController.text.trim(),
        'Status': '0',
        'Grop_code': gropCode,
        'G_ID': gId,
        'From_MID': fromMID,
        'To_MID': widget.member.id.toString(),
      };

      debugPrint('Submitting meeting with payload: ${jsonEncode(payload)}');

      final response = await http.post(
        Uri.parse('https://tagai.caxis.ca/public/api/one2one'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint('One2one API Response Status: ${response.statusCode}');
      debugPrint('One2one API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting arranged successfully'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
        Navigator.pop(context);
      } else {
        String errorMsg = 'Failed to arrange meeting: HTTP ${response.statusCode}';
        try {
          final responseData = json.decode(response.body);
          if (responseData is Map<String, dynamic> && responseData['message'] != null) {
            errorMsg = responseData['message'].toString();
            if (responseData['data'] != null) {
              errorMsg += '\nDetails: ${jsonEncode(responseData['data'])}';
            }
          }
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }
        setState(() {
          isSubmitting = false;
          errorMessage = errorMsg;
        });
      }
    } catch (e) {
      setState(() {
        isSubmitting = false;
        errorMessage = 'Error submitting meeting: $e';
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _timeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0 && widget.fromMID != null && widget.gId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleMeetingsPage(
            loggedInUserMID: widget.fromMID,
            loggedInGID: widget.gId,
          ),
        ),
      );
    } else if (index == 1 && widget.fromMID != null && widget.gId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryPage(
            loggedInUserMID: widget.fromMID,
            loggedInGID: widget.gId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: CustomAppBar(
        title: 'Arrange Meeting',
        onBackPressed: () {
          // Navigate back to Team Members page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OneToOnePage()),
          );
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member Info Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.member.name.isNotEmpty ? widget.member.name[0].toUpperCase() : 'M',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meeting with',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            widget.member.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.member.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            widget.member.phone,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Form Section
            Text(
              'Meeting Details',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            // Place Field
            TextField(
              controller: _placeController,
              decoration: const InputDecoration(
                labelText: 'Meeting Place',
                hintText: 'Enter meeting location',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 16),
            
            // Date Field
            TextField(
              controller: _dateController,
              readOnly: true,
              onTap: _selectDate,
              decoration: const InputDecoration(
                labelText: 'Meeting Date',
                hintText: 'Select date',
                prefixIcon: Icon(Icons.calendar_today_outlined),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
            ),
            const SizedBox(height: 16),
            
            // Time Field
            TextField(
              controller: _timeController,
              readOnly: true,
              onTap: _selectTime,
              decoration: const InputDecoration(
                labelText: 'Meeting Time',
                hintText: 'Select time',
                prefixIcon: Icon(Icons.access_time_outlined),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
            ),
            
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: AppTheme.errorColor, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submitMeeting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Send Meeting Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule_outlined),
              activeIcon: Icon(Icons.schedule),
              label: 'Meetings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey[600],
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}

// ScheduleMeetingsPage with Fixed Navigation
class ScheduleMeetingsPage extends StatefulWidget {
  final String? loggedInUserMID;
  final String? loggedInGID;

  const ScheduleMeetingsPage({super.key, this.loggedInUserMID, this.loggedInGID});

  @override
  State<ScheduleMeetingsPage> createState() => _ScheduleMeetingsPageState();
}

class _ScheduleMeetingsPageState extends State<ScheduleMeetingsPage> {
  List<MeetingRequest> meetings = [];
  bool isLoading = true;
  String? errorMessage;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _debugSharedPreferences(String context) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    debugPrint('SharedPreferences ($context):');
    if (keys.isEmpty) {
      debugPrint('  No keys found.');
    } else {
      for (var key in keys) {
        debugPrint('  $key: ${prefs.get(key)}');
      }
    }
  }

  Future<void> _loadMeetings() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await _debugSharedPreferences('ScheduleMeetings');

      String? mId = widget.loggedInUserMID;
      String? gId = widget.loggedInGID;
      if (mId == null || gId == null) {
        final storedGID = prefs.getString('user_id');
        final storedEmail = prefs.getString('user_email');
        if (storedGID == null || storedGID.trim().isEmpty) {
          setState(() {
            isLoading = false;
            errorMessage = 'No group ID found.';
          });
          return;
        }
        final memberResponse = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/member'));
        if (memberResponse.statusCode == 200) {
          final memberData = json.decode(memberResponse.body);
          List<dynamic> members = memberData is Map<String, dynamic> && memberData.containsKey('members')
              ? memberData['members']
              : [];
          final userMember = members
              .map((json) => Member.fromJson(json as Map<String, dynamic>))
              .firstWhere(
                (member) => member.email == storedEmail,
                orElse: () => Member(
                  id: 0,
                  name: '',
                  email: '',
                  phone: '',
                  gropCode: '',
                  status: 0,
                  address: '',
                  createdAt: '',
                ),
              );
          mId = userMember.id != 0 ? userMember.id.toString() : null;
          gId = storedGID;
        } else {
          setState(() {
            isLoading = false;
            errorMessage = 'Failed to fetch user information: HTTP ${memberResponse.statusCode}';
          });
          return;
        }
      }

      if (mId == null || mId.trim().isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'No user ID found.';
        });
        return;
      }

      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/one2one'));
      debugPrint('Meetings API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint('Meeting API Response: ${jsonData}');

        List<dynamic> data;
        if (jsonData is List) {
          data = jsonData;
        } else if (jsonData is Map<String, dynamic> && jsonData.containsKey('requests')) {
          data = jsonData['requests'] as List;
        } else {
          data = [];
        }

        try {
          final meetingsList = data
              .map((json) {
                try {
                  return MeetingRequest.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('Error parsing json data: $e');
                  return null;
                }
              })
              .where((meeting) => meeting != null)
              .cast<MeetingRequest>()
              .where((meeting) =>
                  (meeting.toMID == mId || meeting.fromMember.id.toString() == mId) && meeting.status == '1')
              .toList();

          setState(() {
            meetings = meetingsList;
            isLoading = false;
            errorMessage = null;
          });
        } catch (e) {
          setState(() {
            isLoading = false;
            errorMessage = 'Error processing meetings: $e';
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load meetings: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching meetings: $e';
      });
    }
  }

  // Fixed completion method - now uses status "3"
  Future<void> _completeMeeting(int meetingId) async {
    try {
      debugPrint('=== COMPLETING MEETING WITH STATUS 3 ===');
      debugPrint('Meeting ID: $meetingId');
      
      final prefs = await SharedPreferences.getInstance();
      final gropCode = prefs.getString('Grop_code') ?? prefs.getString('group_code');
      final gId = widget.loggedInGID ?? prefs.getString('user_id');

      if (gropCode == null || gId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing group information.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      // Use status "3" as requested
      final payload = {
        'Status': '3',
        'Grop_code': gropCode.trim(),
        'G_ID': gId.trim(),
      };

      debugPrint('Completion payload: ${jsonEncode(payload)}');

      final response = await http.put(
        Uri.parse('https://tagai.caxis.ca/public/api/one2one/$meetingId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint('Completion Response Status: ${response.statusCode}');
      debugPrint('Completion Response Body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting completed successfully'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
        _loadMeetings();
      } else {
        String errorMsg = 'Failed to complete meeting: HTTP ${response.statusCode}';
        try {
          final responseData = json.decode(response.body);
          if (responseData is Map<String, dynamic> && responseData['message'] != null) {
            errorMsg = responseData['message'].toString();
          }
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in _completeMeeting: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing meeting: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  // Fixed image upload method
  Future<void> _uploadMeetingImage(int meetingId) async {
    try {
      final imagePicker = ImagePicker();
      final XFile? image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No image selected'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final gropCode = prefs.getString('Grop_code') ?? prefs.getString('group_code');
      final gId = widget.loggedInGID ?? prefs.getString('user_id');

      if (gropCode == null || gId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing group information.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.black),
              SizedBox(width: 16),
              Text('Uploading image...'),
            ],
          ),
        ),
      );

      try {
        // Create multipart request
        var request = http.MultipartRequest(
          'PUT',
          Uri.parse('https://tagai.caxis.ca/public/api/one2one/$meetingId'),
        );

        // Add form fields
        request.fields['Grop_code'] = gropCode.trim();
        request.fields['G_ID'] = gId.trim();

        // Add image file with proper field name
        var multipartFile = await http.MultipartFile.fromPath(
          'Image', // Capital I as per API expectation
          image.path,
          filename: 'meeting_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        request.files.add(multipartFile);

        debugPrint('=== IMAGE UPLOAD REQUEST ===');
        debugPrint('URL: https://tagai.caxis.ca/public/api/one2one/$meetingId');
        debugPrint('Fields: ${request.fields}');
        debugPrint('File field name: Image');
        debugPrint('File path: ${image.path}');

        // Send request
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        Navigator.pop(context); // Close loading dialog

        debugPrint('Upload Response Status: ${response.statusCode}');
        debugPrint('Upload Response Body: ${response.body}');

        if (response.statusCode == 200) {
          try {
            final responseData = json.decode(response.body);
            debugPrint('Parsed response data: $responseData');
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image uploaded successfully'),
                backgroundColor: AppTheme.accentColor,
              ),
            );
            _loadMeetings(); // Refresh to show updated images
          } catch (e) {
            debugPrint('Error parsing upload response: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image uploaded but response parsing failed'),
                backgroundColor: AppTheme.warningColor,
              ),
            );
            _loadMeetings(); // Still refresh in case upload worked
          }
        } else {
          // Try alternative field name if first attempt fails
          debugPrint('First upload attempt failed, trying with lowercase field name...');
          
          var request2 = http.MultipartRequest(
            'PUT',
            Uri.parse('https://tagai.caxis.ca/public/api/one2one/$meetingId'),
          );

          request2.fields['Grop_code'] = gropCode.trim();
          request2.fields['G_ID'] = gId.trim();

          var multipartFile2 = await http.MultipartFile.fromPath(
            'image', // lowercase
            image.path,
            filename: 'meeting_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          request2.files.add(multipartFile2);

          var streamedResponse2 = await request2.send();
          var response2 = await http.Response.fromStream(streamedResponse2);

          debugPrint('Second upload attempt - Status: ${response2.statusCode}');
          debugPrint('Second upload attempt - Body: ${response2.body}');

          if (response2.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image uploaded successfully'),
                backgroundColor: AppTheme.accentColor,
              ),
            );
            _loadMeetings();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload image: HTTP ${response2.statusCode}'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      } catch (e) {
        Navigator.pop(context); // Close loading dialog if still open
        throw e;
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      // Already on meetings page
    } else if (index == 1 && widget.loggedInUserMID != null && widget.loggedInGID != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryPage(
            loggedInUserMID: widget.loggedInUserMID,
            loggedInGID: widget.loggedInGID,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: CustomAppBar(
        title: 'Scheduled Meetings',
        onBackPressed: () {
          // Navigate back to Team Members page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OneToOnePage()),
          );
        },
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${meetings.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMeetings,
        color: Colors.black,
        child: isLoading
            ? const LoadingWidget(message: 'Loading scheduled meetings...')
            : errorMessage != null
                ? ErrorWidget(
                    message: errorMessage!,
                    onRetry: _loadMeetings,
                  )
                : meetings.isEmpty
                    ? const EmptyStateWidget(
                        title: 'No Scheduled Meetings',
                        message: 'You have no scheduled meetings at the moment',
                        icon: Icons.event_busy,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: meetings.length,
                        itemBuilder: (context, index) {
                          final meeting = meetings[index];
                          return _buildMeetingCard(meeting);
                        },
                      ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule_outlined),
              activeIcon: Icon(Icons.schedule),
              label: 'Meetings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey[600],
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildMeetingCard(MeetingRequest meeting) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        meeting.toMember.name.isNotEmpty 
                            ? meeting.toMember.name[0].toUpperCase() 
                            : 'M',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meeting with',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          meeting.toMember.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Meeting Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.person_outline, 'From', '${meeting.fromMember.name} (${meeting.fromMember.email})'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.location_on_outlined, 'Place', meeting.place),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.calendar_today_outlined, 'Date', meeting.date),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.access_time_outlined, 'Time', meeting.time),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Images Section
              Text(
                'Meeting Images',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              
              meeting.image.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.image_outlined, color: Colors.grey[400], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'No images uploaded yet',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: meeting.image.length,
                        itemBuilder: (context, index) {
                          final imageUrl = meeting.image[index];
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildImageWidget(imageUrl),
                            ),
                          );
                        },
                      ),
                    ),
              
              const SizedBox(height: 20),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _uploadMeetingImage(meeting.id),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Upload Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _completeMeeting(meeting.id),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
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

  Widget _buildImageWidget(String imageUrl) {
    // Check if the image is a base64 string or a URL
    if (imageUrl.startsWith('data:image') || RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(imageUrl)) {
      try {
        final decodedImage = base64Decode(
          imageUrl.startsWith('data:image')
              ? imageUrl.split(',')[1]
              : imageUrl,
        );
        return Image.memory(
          decodedImage,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 100,
            height: 100,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
        return Container(
          width: 100,
          height: 100,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
      }
    } else {
      // Assume it's a URL
      return Image.network(
        imageUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 100,
            height: 100,
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.black,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          width: 100,
          height: 100,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    }
  }
}