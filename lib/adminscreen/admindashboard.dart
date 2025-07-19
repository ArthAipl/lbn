import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lbn/adminscreen/admincircle.dart';
import 'package:lbn/adminscreen/adminonetoone.dart';
import 'package:lbn/adminscreen/adminvisitors.dart';
import 'package:lbn/adminscreen/eventsadmin.dart';
import 'package:lbn/adminscreen/grupmembers.dart';
import 'package:lbn/adminscreen/meetingsadmin.dart';
import 'package:lbn/adminscreen/membersrequests.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lbn/adminscreen/adminprofilepage.dart';
import 'package:lbn/screens/loginscreen.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

// Model for Group data to ensure type safety
class Group {
  final String gId;
  final String groupName;
  Group({required this.gId, required this.groupName});

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      gId: json['G_ID'].toString(),
      groupName: json['group_name'] ?? '',
    );
  }
}

// Enum for feature navigation to prevent dynamic type issues
enum Feature {
  requests,
  members,
  events,
  meetings,
  oneToOne,
  circleMeeting,
  committeeMembers,
  profile,
  visitors, // Added new feature
  references // Added new feature
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String userName = '';
  String userEmail = '';
  String groupCode = '';
  String groupName = '';
  String gId = '';
  bool isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Sample stats (consider fetching from API if dynamic)
  final Map<String, int> stats = {
    'Events This Month': 8,
    'Active Projects': 12,
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        userName = prefs.getString('Name') ?? '';
        userEmail = prefs.getString('email') ?? '';
        groupCode = prefs.getString('Group_code') ?? '';
        gId = prefs.getString('G_ID') ?? '';
        isLoading = false;
      });
      if (gId.isNotEmpty) {
        await _fetchGroupName();
      }
      if (userName.isEmpty && userEmail.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No user data found. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchGroupName() async {
    try {
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/group-master'),
      );
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is List) {
          final groups = jsonData.map((json) => Group.fromJson(json)).toList();
          // Changed to nullable Group? to handle case where no group is found
          final Group? group = groups.isNotEmpty
              ? groups.firstWhere(
                  (g) => g.gId == gId,
                  orElse: () => Group(gId: gId, groupName: ''), // Return a default Group
                )
              : null;
          if (group != null && mounted) {
            setState(() {
              groupName = group.groupName;
            });
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Group not found'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          // Handle case where jsonData is not a List
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to fetch group name'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching group name: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Error clearing preferences: $e');
    }
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _navigateToFeature(Feature feature) {
    _scaffoldKey.currentState?.closeDrawer();
    switch (feature) {
      case Feature.requests:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MemberApprovalScreen()),
        );
        break;
      case Feature.members:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MemberDetailPage()),
        );
        break;
      case Feature.events:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EventsAdminPage()),
        );
        break;
      case Feature.meetings:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MeetingAdminPage()),
        );
        break;
      case Feature.oneToOne:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OneToOneAdmin()),
        );
        break;
      case Feature.circleMeeting:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CircleAdmin()),
        );
        break;
      case Feature.committeeMembers:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Committee Members feature coming soon!'),
            backgroundColor: Colors.blue,
          ),
        );
        break;
      case Feature.profile:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminProfilePage()),
        );
        break;
      case Feature.visitors: // Handle new feature
         Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VisitorsAdmin()),
        );
        break;
      case Feature.references: // Handle new feature
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('References feature coming soon!'),
            backgroundColor: Colors.blue,
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E1E2C),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF1E1E2C),
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 24),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          title: const Text(
            'Business Network',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
        ),
        drawer: _buildProfessionalDrawer(),
        body: _buildDashboardContent(),
      ),
    );
  }

  Widget _buildProfessionalDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                _buildDrawerMenuItem(
                  icon: Icons.person_outline,
                  title: 'My Profile',
                  onTap: () => _navigateToFeature(Feature.profile),
                ),
                // You can add more menu items here if needed
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showLogoutDialog();
                  },
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.black,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.black54,
          size: 16,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF5A52E8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName.isNotEmpty
                              ? 'Welcome back, $userName! ${groupName.isNotEmpty ? '($groupName)' : ''}'
                              : 'Welcome back! ${groupName.isNotEmpty ? '($groupName)' : ''}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Here\'s what\'s happening in your network today',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.dashboard,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E2C),
              ),
            ),
            const SizedBox(height: 12),
            _buildFeaturesGrid(),
            const SizedBox(height: 16),
            const Text(
              'Committee Members',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E2C),
              ),
            ),
            const SizedBox(height: 12),
            _buildCommitteeMembersGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    final features = [
      {'title': 'Requests', 'icon': Icons.person_add_rounded, 'color': Colors.blue, 'feature': Feature.requests},
      {'title': 'Members', 'icon': Icons.people_alt_rounded, 'color': const Color(0xFF6C63FF), 'feature': Feature.members},
      {'title': 'Events', 'icon': Icons.event_rounded, 'color': Colors.green, 'feature': Feature.events},
      {'title': 'Meetings', 'icon': Icons.meeting_room_rounded, 'color': Colors.orange, 'feature': Feature.meetings},
      {'title': 'One 2 One', 'icon': Icons.person_pin_rounded, 'color': Colors.purple, 'feature': Feature.oneToOne},
      {'title': 'Circle Meeting Registration', 'icon': Icons.event_available_rounded, 'color': Colors.teal, 'feature': Feature.circleMeeting},
      // New additions
      {'title': 'Visitors', 'icon': Icons.visibility_rounded, 'color': Colors.red, 'feature': Feature.visitors},
      {'title': 'References', 'icon': Icons.link_rounded, 'color': Colors.pink, 'feature': Feature.references},
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return _buildFeatureCard(
          feature['title'] as String,
          feature['icon'] as IconData,
          feature['color'] as Color,
          feature['feature'] as Feature,
        );
      },
    );
  }

  Widget _buildCommitteeMembersGrid() {
    final committeeMembers = [
      {'title': 'Secretary', 'icon': Icons.description_rounded, 'color': Colors.orange, 'feature': Feature.committeeMembers},
      {'title': 'Treasurer', 'icon': Icons.settings, 'color': Colors.purple, 'feature': Feature.committeeMembers},
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: committeeMembers.length,
      itemBuilder: (context, index) {
        final member = committeeMembers[index];
        return _buildFeatureCard(
          member['title'] as String,
          member['icon'] as IconData,
          member['color'] as Color,
          member['feature'] as Feature,
        );
      },
    );
  }

  Widget _buildFeatureCard(String title, IconData icon, Color color, Feature feature) {
    return GestureDetector(
      onTap: () => _navigateToFeature(feature),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E1E2C),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E2C),
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Color(0xFF1E1E2C)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}