import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lbn/adminscreen/meetingsadmin.dart';
import 'package:lbn/screens/loginscreen.dart';
import 'package:lbn/screens/settingslbn.dart';
import 'package:lbn/userscreens/businessprofile.dart';
import 'package:lbn/userscreens/circlemeetings.dart';
import 'package:lbn/userscreens/eventsmembers.dart';
import 'package:lbn/userscreens/meetingsuser.dart';
import 'package:lbn/userscreens/memberprofile.dart';
import 'package:lbn/userscreens/onetwooone.dart';
import 'package:lbn/userscreens/refrencessuser.dart';
import 'package:lbn/userscreens/usermembers.dart';
import 'package:lbn/userscreens/visitorsusers.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? memberName;
  bool isReceptionCommitteeMember = false;
  bool isAttendanceCommitteeMember = false;
  bool isTreasurerCommitteeMember = false;

  @override
  void initState() {
    super.initState();
    _fetchMemberName();
    _setLastDashboard();
    _checkCommitteeMemberStatus();
  }

  Future<void> _setLastDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_dashboard', 'user');
    } catch (e) {
      debugPrint('Error setting last dashboard: $e');
    }
  }

  Future<void> _fetchMemberName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? mId = prefs.getString('M_ID');

      if (mId == null || mId.isEmpty) {
        setState(() {
          memberName = 'User';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No M_ID found in SharedPreferences')),
        );
        return;
      }

      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/member'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedResponse = json.decode(response.body);

        if (decodedResponse.containsKey('members') && decodedResponse['members'] is List) {
          final List<dynamic> members = decodedResponse['members'];
          final member = members.firstWhere(
            (member) {
              if (member is Map<String, dynamic>) {
                return member['M_ID'].toString() == mId;
              }
              return false;
            },
            orElse: () => null,
          );

          if (member != null && member is Map<String, dynamic>) {
            setState(() {
              memberName = member['Name']?.toString() ?? 'User';
            });
          } else {
            setState(() {
              memberName = 'User';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Member not found in API response')),
            );
          }
        } else {
          setState(() {
            memberName = 'User';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid API response format: No members list')),
          );
        }
      } else {
        setState(() {
          memberName = 'User';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch member data: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() {
        memberName = 'User';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching member name: $e')),
      );
    }
  }

  // Updated _checkCommitteeMemberStatus to check ServiceAreas and c_m_status
  Future<void> _checkCommitteeMemberStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? mId = prefs.getString('M_ID');

      if (mId == null || mId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No M_ID found in SharedPreferences')),
        );
        return;
      }

      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/comm-memb'));

      if (response.statusCode == 200) {
        final List<dynamic> decodedResponse = json.decode(response.body);

        setState(() {
          // Reset flags
          isReceptionCommitteeMember = false;
          isAttendanceCommitteeMember = false;
          isTreasurerCommitteeMember = false;

          // Check for committee roles with c_m_status == "1"
          for (var member in decodedResponse) {
            if (member is Map<String, dynamic> &&
                member['M_ID'].toString() == mId &&
                member['c_m_status'] == '1') {
              final serviceArea = member['designation']?['ServiceAreas'] as String?;
              if (serviceArea == 'Reception') {
                isReceptionCommitteeMember = true;
              } else if (serviceArea == 'Attendance') {
                isAttendanceCommitteeMember = true;
              } else if (serviceArea == 'Treasurer') {
                isTreasurerCommitteeMember = true;
              }
            }
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch committee data: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking committee status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
      title: const Text(
        'Business Network',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8F9FA),
              Color(0xFFE9ECEF),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  _buildDrawerItem(
                    icon: Icons.person_outline,
                    title: 'Profile',
                    index: 0,
                    iconColor: const Color(0xFF667EEA),
                    isNavigationItem: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    index: 6,
                    iconColor: const Color(0xFF64748B),
                    isNavigationItem: true,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Divider(color: Color(0xFFDEE2E6)),
                  ),
                  _buildDrawerItem(
                    icon: Icons.logout_outlined,
                    title: 'Logout',
                    index: 7,
                    iconColor: const Color(0xFFDC3545),
                    isLogout: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
    required Color iconColor,
    bool isNavigationItem = false,
    bool isLogout = false,
  }) {
    bool isSelected = _selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (isLogout) {
              bool? confirm = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: Colors.white,
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC3545).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout_rounded, color: Color(0xFFDC3545), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Logout',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  content: const Text(
                    'Are you sure you want to log out?',
                    style: TextStyle(color: Colors.black54),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC3545),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error during logout: $e')),
                  );
                }
              }
            } else if (isNavigationItem) {
              Navigator.pop(context);
              if (title == 'Profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              } else if (title == 'Settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsLbn()),
                );
              }
            } else {
              setState(() {
                _selectedIndex = index;
              });
              Navigator.pop(context);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.black.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected ? Border.all(color: Colors.black.withOpacity(0.1)) : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? iconColor.withOpacity(0.2)
                        : iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return _buildDashboard();
  }

  Widget _buildDashboard() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF5A52E8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${memberName ?? 'Loading...'}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ready to network?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.3,
                ),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.6,
            ),
            delegate: SliverChildListDelegate([
              _buildFeatureCard(
                'Business Profile',
                'Business information',
                Icons.business_outlined,
                const Color(0xFF3B82F6),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BusinessProfileScreen()),
                  );
                },
              ),
              _buildFeatureCard(
                'Members',
                'Network members',
                Icons.people_outline,
                const Color(0xFF10B981),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MemberListPage()),
                  );
                },
              ),
              _buildFeatureCard(
                'Events',
                'Networking Events',
                Icons.event_outlined,
                const Color(0xFFF59E0B),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EventsPage()),
                  );
                },
              ),
              _buildFeatureCard(
                'Meetings',
                'Network Meetings',
                Icons.meeting_room_outlined,
                const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MeetingsPage()),
                  );
                },
              ),
              _buildFeatureCard(
                'One-to-One',
                'Personal connections',
                Icons.person_add_outlined,
                const Color(0xFFEF4444),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OneToOneMeetingScreen()),
                  );
                },
              ),
              _buildFeatureCard(
                'Circle Meeting',
                'Group discussions',
                Icons.group_outlined,
                const Color(0xFF06B6D4),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CircleMeetingsPage()),
                  );
                },
              ),
              _buildFeatureCard(
                'Visitors',
                'Manage guest access',
                Icons.person_pin_outlined,
                const Color(0xFFEC4899),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VisitorManagementScreen()),
                  );
                },
              ),
              _buildFeatureCard(
                'Reference',
                'Important resources',
                Icons.bookmark_outline,
                const Color(0xFF84CC16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ReferencesPage()),
                  );
                },
              ),
              if (isReceptionCommitteeMember)
                _buildFeatureCard(
                  'Reception',
                  'Committee tasks',
                  Icons.support_agent_outlined,
                  const Color(0xFF22D3EE),
                  onTap: () {
                    // Add navigation to Reception committee page if needed
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(builder: (context) => ReceptionCommitteePage()),
                    // );
                  },
                ),
              if (isAttendanceCommitteeMember)
                _buildFeatureCard(
                  'Attendance',
                  'Track attendance',
                  Icons.check_circle_outline,
                  const Color(0xFF4B5563),
                  onTap: () {
                    // Add navigation to Attendance committee page if needed
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(builder: (context) => AttendanceCommitteePage()),
                    // );
                  },
                ),
              if (isTreasurerCommitteeMember)
                _buildFeatureCard(
                  'Treasurer',
                  'Financial management',
                  Icons.account_balance_outlined,
                  const Color(0xFFD97706),
                  onTap: () {
                    // Add navigation to Treasurer committee page if needed
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(builder: (context) => TreasurerCommitteePage()),
                    // );
                  },
                ),
            ]),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.only(bottom: 20),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String title, String subtitle, IconData icon, Color iconColor, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          iconColor.withOpacity(0.1),
                          iconColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: iconColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}