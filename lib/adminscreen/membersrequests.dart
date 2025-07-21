import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class MemberApprovalScreen extends StatefulWidget {
  const MemberApprovalScreen({Key? key}) : super(key: key);

  @override
  State<MemberApprovalScreen> createState() => _MemberApprovalScreenState();
}

class _MemberApprovalScreenState extends State<MemberApprovalScreen> {
  List<Member> members = [];
  bool isLoading = true;
  bool _isUpdatingStatus = false;
  String? groupCode;
  String errorMessage = '';
  int currentStatusFilter = 0; // 0 = pending, 1 = approved, 2 = rejected, -1 = all
  String currentStatusText = 'Pending Requests';

  @override
  void initState() {
    super.initState();
    _loadGroupCodeAndMembers();
  }

  Future<void> _loadGroupCodeAndMembers() async {
    try {
      debugPrint('Loading group code and members...');
      final prefs = await SharedPreferences.getInstance();
      groupCode = prefs.getString('Grop_code');
      debugPrint('Retrieved group code from SharedPreferences: $groupCode');

      if (groupCode == null || groupCode!.isEmpty) {
        debugPrint('No group code found in SharedPreferences');
        setState(() {
          errorMessage = 'Group code not found. Please log in again.';
          isLoading = false;
        });
        // Redirect to login screen
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      debugPrint('Using group code: $groupCode');
      await _fetchMembers();
    } catch (e) {
      debugPrint('Error in _loadGroupCodeAndMembers: ${e.toString()}');
      setState(() {
        errorMessage = 'Error loading data. Please try again.';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchMembers() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      debugPrint('Fetching members for group code: $groupCode');
      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/member'));

      if (response.statusCode == 200) {
        debugPrint('Raw API Response: ${response.body}');
        final decoded = json.decode(response.body);

        if (decoded is! Map<String, dynamic> || !decoded.containsKey('members')) {
          throw Exception('Unexpected response format: missing or invalid members array');
        }

        final List<dynamic> data = decoded['members'];
        debugPrint('Total members received: ${data.length}');

        final filteredMembers = data
            .map((item) => Member.fromJson(item as Map<String, dynamic>))
            .where((member) {
              final matchesGroup = member.groupCode == groupCode;
              final matchesStatus = currentStatusFilter == -1 || member.status == currentStatusFilter;
              return matchesGroup && matchesStatus;
            })
            .toList();

        debugPrint('Found ${filteredMembers.length} members with group code $groupCode and filtered status');
        setState(() {
          members = filteredMembers;
          isLoading = false;
        });
      } else {
        debugPrint('Failed to load members. Status code: ${response.statusCode}');
        setState(() {
          errorMessage = 'Failed to load members. Please try again.';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _fetchMembers: ${e.toString()}');
      setState(() {
        errorMessage = 'Error fetching members. Please try again.';
        isLoading = false;
      });
    }
  }

  Future<void> _updateMemberStatus(Member member, int newStatus) async {
    if (_isUpdatingStatus) return;
    try {
      debugPrint('Updating member ${member.id} status to $newStatus');
      setState(() => _isUpdatingStatus = true);
      final response = await http.put(
        Uri.parse('https://tagai.caxis.ca/public/api/member/${member.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': newStatus.toString()}),
      );

      if (response.statusCode == 200) {
        debugPrint('Member ${member.id} status updated successfully');
        await _fetchMembers();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 1 ? 'Member approved successfully' : 'Member rejected successfully',
            ),
            backgroundColor: newStatus == 1 ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          ),
        );
      } else {
        debugPrint('Failed to update member status. Status code: ${response.statusCode}');
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update member. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating member status: ${e.toString()}');
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      );
    } finally {
      setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('M_ID');
      await prefs.remove('Name');
      await prefs.remove('email');
      await prefs.remove('number');
      await prefs.remove('Grop_code');
      await prefs.remove('G_ID');
      await prefs.remove('role_id');
      await prefs.remove('group_name');
      await prefs.remove('short_group_name');
      debugPrint('SharedPreferences cleared successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Logged out successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      debugPrint('Error clearing SharedPreferences: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error logging out. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      );
    }
  }

  void _changeStatusFilter(int status) {
    setState(() {
      currentStatusFilter = status;
      switch (status) {
        case -1:
          currentStatusText = 'All Members';
          break;
        case 0:
          currentStatusText = 'Pending Requests';
          break;
        case 1:
          currentStatusText = 'Approved Members';
          break;
        case 2:
          currentStatusText = 'Rejected Members';
          break;
      }
    });
    _fetchMembers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          currentStatusText,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == -2) {
                _logout();
              } else {
                _changeStatusFilter(value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: -1,
                child: Text('Show All Members'),
              ),
              const PopupMenuItem(
                value: 0,
                child: Text('Show Pending Requests'),
              ),
              const PopupMenuItem(
                value: 1,
                child: Text('Show Approved Members'),
              ),
              const PopupMenuItem(
                value: 2,
                child: Text('Show Rejected Members'),
              ),
              const PopupMenuItem(
                value: -2,
                child: Text('Logout'),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.black,
              ),
            )
          : errorMessage.isNotEmpty
              ? _buildErrorView()
              : _buildMembersList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[400],
              size: 70,
            ),
            const SizedBox(height: 24),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = '';
                });
                _loadGroupCodeAndMembers();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    if (members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              currentStatusFilter == 0 ? Icons.person_search : Icons.people_outline,
              size: 70,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              currentStatusFilter == 0
                  ? 'No pending members to approve'
                  : currentStatusFilter == 1
                      ? 'No approved members found'
                      : currentStatusFilter == 2
                          ? 'No rejected members found'
                          : 'No members found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMembers,
      color: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: members.length,
        itemBuilder: (context, index) {
          final member = members[index];
          return MemberCard(
            member: member,
            onApprove: currentStatusFilter == 0 && !_isUpdatingStatus
                ? () => _updateMemberStatus(member, 1)
                : null,
            onReject: currentStatusFilter == 0 && !_isUpdatingStatus
                ? () => _updateMemberStatus(member, 2)
                : null,
            showActions: currentStatusFilter == 0,
          );
        },
      ),
    );
  }
}

class MemberCard extends StatelessWidget {
  final Member member;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool showActions;

  const MemberCard({
    Key? key,
    required this.member,
    this.onApprove,
    this.onReject,
    required this.showActions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            member.mobile,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(),
              ],
            ),
            if (showActions) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.grey[200],
      child: Text(
        member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
          fontSize: 22,
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color badgeColor;
    String statusText;
    IconData statusIcon;

    switch (member.status) {
      case 0:
        badgeColor = Colors.amber;
        statusText = 'Pending';
        statusIcon = Icons.hourglass_empty;
        break;
      case 1:
        badgeColor = Colors.green;
        statusText = 'Approved';
        statusIcon = Icons.check_circle;
        break;
      case 2:
        badgeColor = Colors.red;
        statusText = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      default:
        badgeColor = Colors.grey;
        statusText = 'Unknown';
        statusIcon = Icons.question_mark;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onReject,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red[700],
              elevation: 0,
              side: BorderSide(color: Colors.red[300]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onApprove,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class Member {
  final int id;
  final String name;
  final String mobile;
  final String groupCode;
  final int status;

  Member({
    required this.id,
    required this.name,
    required this.mobile,
    required this.groupCode,
    required this.status,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: _parseInt(json['M_ID']) ?? 0,
      name: json['Name']?.toString() ?? '',
      mobile: json['number']?.toString() ?? '',
      groupCode: json['Grop_code']?.toString() ?? '',
      status: _parseInt(json['status']) ?? 0,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is bool) return value ? 1 : 0;
    return null;
  }
}

Future<void> saveUserPreferences({
  required String? mId,
  required String name,
  required String email,
  required String number,
  required String groupCode,
  required String gId,
  required String roleId,
  Map<String, dynamic>? userData,
}) async {
  try {
    if (groupCode.isEmpty) {
      throw Exception('Group code cannot be empty');
    }
    final prefs = await SharedPreferences.getInstance();
    if (roleId == '3') {
      await prefs.setString('M_ID', mId ?? '');
    }
    await prefs.setString('Name', name);
    await prefs.setString('email', email);
    await prefs.setString('number', number);
    await prefs.setString('Grop_code', groupCode);
    await prefs.setString('G_ID', gId);
    await prefs.setString('role_id', roleId);
    if (roleId == '2') {
      await prefs.setString('group_name', userData?['group_name']?.toString() ?? '');
      await prefs.setString('short_group_name', userData?['short_group_name']?.toString() ?? '');
    }
    debugPrint('User preferences saved successfully: Grop_code=$groupCode');
  } catch (e) {
    debugPrint('Error saving SharedPreferences: ${e.toString()}');
    throw Exception('Failed to save user preferences: ${e.toString()}');
  }
}