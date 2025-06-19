import 'package:flutter/material.dart';
import 'package:lbn/adminscreen/eventsadmin.dart';
import 'package:lbn/adminscreen/grupmembers.dart';
import 'package:lbn/adminscreen/meetingsadmin.dart';
import 'package:lbn/adminscreen/membersrequests.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lbn/adminscreen/adminprofilepage.dart';
import 'package:lbn/screens/loginscreen.dart';
import 'package:flutter/services.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String userName = '';
  String userEmail = '';
  String groupCode = '';
  bool isLoading = true;
  int _selectedIndex = 0;
  bool _isDrawerOpen = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Sample data for charts
  final List<double> weeklyActivity = [5, 12, 8, 15, 7, 10, 13];
  final List<double> memberGrowth = [120, 132, 145, 160, 178, 195, 210];
  
  // Sample stats
  final Map<String, int> stats = {
    'Total Members': 210,
    'Pending Requests': 15,
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
        userName = prefs.getString('user_name') ?? '';
        userEmail = prefs.getString('user_email') ?? '';
        groupCode = prefs.getString('group_code') ?? '';
        isLoading = false;
      });

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

  void _navigateToFeature(String featureName) {
    _scaffoldKey.currentState?.closeDrawer();
    
    switch (featureName) {
      case 'Requests':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MemberApprovalScreen()),
        );
        break;
      case 'Members':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MembersPage()),
        );
        break;
      case 'Events':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EventsHomePage()),
        );
        break;
      case 'Meetings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MeetingsAdmin()), // Updated to navigate to MeetingAdmin
        );
        break;
      case 'Gallery':
        _showFeatureComingSoon('Gallery');
        break;
      case 'Attendance':
        _showFeatureComingSoon('Attendance');
        break;
      case 'Visitors':
        _showFeatureComingSoon('Visitors');
        break;
      case 'Profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
        );
        break;
      case 'Settings':
        _showFeatureComingSoon('Settings');
        break;
    }
  }

  void _showFeatureComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    switch (index) {
      case 0: // Dashboard
        break;
      case 1: // Members
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MembersPage()),
        );
        break;
      case 2: // Requests
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MemberApprovalScreen()),
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
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
              setState(() {
                _isDrawerOpen = true;
              });
            },
          ),
          title: const Text(
            'Business Network',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () {
                _showFeatureComingSoon('Notifications');
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        drawer: _buildEnhancedDrawer(),
        body: _buildDashboardContent(),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildEnhancedDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1E1E2C),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D3F),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF6C63FF), width: 2),
                      ),
                      child: const CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xFF3F3D56),
                        child: Icon(Icons.person, color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName.isNotEmpty ? userName : 'No user data',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Admin',
                              style: TextStyle(
                                color: const Color(0xFF6C63FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
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
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.person_rounded,
                  title: 'Profile',
                  isSelected: _selectedIndex == 0,
                  onTap: () => _navigateToFeature('Profile'),
                ),
                _buildDrawerItem(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  isSelected: _selectedIndex == 1,
                  onTap: () => _navigateToFeature('Settings'),
                ),
                const Divider(color: Color(0xFF3F3D56)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showLogoutDialog();
                    },
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Group Code: ',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                Text(
                  groupCode.isNotEmpty ? groupCode : 'N/A',
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF6C63FF) : Colors.white70,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: const Color(0xFF6C63FF).withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  Widget _buildDashboardContent() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName.isNotEmpty ? 'Welcome back, $userName!' : 'Welcome back!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E2C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Here\'s what\'s happening in your network',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            _buildStatsRow(),
            const SizedBox(height: 24),
            _buildFeaturesGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: stats.entries.map((entry) {
          IconData icon;
          Color color;
          
          switch (entry.key) {
            case 'Total Members':
              icon = Icons.people_rounded;
              color = const Color(0xFF6C63FF);
              break;
            case 'Pending Requests':
              icon = Icons.person_add_rounded;
              color = Colors.orange;
              break;
            case 'Events This Month':
              icon = Icons.event_rounded;
              color = Colors.green;
              break;
            case 'Active Projects':
              icon = Icons.work_rounded;
              color = Colors.blue;
              break;
            default:
              icon = Icons.info_rounded;
              color = Colors.grey;
          }
          
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    final features = [
      {'title': 'Requests', 'icon': Icons.person_add_rounded, 'color': Colors.blue},
      {'title': 'Members', 'icon': Icons.people_alt_rounded, 'color': const Color(0xFF6C63FF)},
      {'title': 'Events', 'icon': Icons.event_rounded, 'color': Colors.green},
      {'title': 'Meetings', 'icon': Icons.meeting_room_rounded, 'color': Colors.orange},
      {'title': 'Gallery', 'icon': Icons.photo_library_rounded, 'color': Colors.purple},
      {'title': 'Attendance', 'icon': Icons.check_circle_rounded, 'color': Colors.teal},
      {'title': 'Visitors', 'icon': Icons.person_add_alt_1_rounded, 'color': Colors.red},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Access',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1E2C),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: features.length,
          itemBuilder: (context, index) {
            final feature = features[index];
            return _buildFeatureCard(
              feature['title'] as String,
              feature['icon'] as IconData,
              feature['color'] as Color,
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _navigateToFeature(title),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E1E2C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavBarItem(0, Icons.dashboard_rounded, 'Home'),
              _buildNavBarItem(1, Icons.people_alt_rounded, 'Members'),
              _buildNavBarItem(2, Icons.person_add_rounded, 'Requests'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    
    return InkWell(
      onTap: () => _onNavItemTapped(index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF6C63FF) : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF6C63FF) : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
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
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}