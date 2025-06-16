import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Member {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String groupCode;
  final String address;
  final String joiningDate;
  final String status;

  Member({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.groupCode,
    required this.address,
    required this.joiningDate,
    required this.status,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['M_ID']?.toString() ?? '',
      name: json['Name'] ?? '',
      phone: json['number'] ?? '',
      email: json['email'] ?? '',
      groupCode: json['Grop_code'] ?? '',
      address: json['address'] ?? '',
      joiningDate: json['created_at'] ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class MemberDetailPage extends StatelessWidget {
  final Member member;

  const MemberDetailPage({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          member.name.isNotEmpty ? member.name : 'Member Details',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            child: Text(
                              member.name.isNotEmpty
                                  ? member.name[0].toUpperCase()
                                  : 'M',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.name.isNotEmpty
                                      ? member.name
                                      : 'Unknown Member',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: member.status == '1'
                                            ? Colors.green
                                            : Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      member.status == '1' ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: member.status == '1'
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      _buildDetailRow(
                          Icons.phone, 'Phone', member.phone.isNotEmpty ? member.phone : 'N/A'),
                      _buildDetailRow(
                          Icons.email, 'Email', member.email.isNotEmpty ? member.email : 'N/A'),
                      _buildDetailRow(Icons.group, 'Group Code', member.groupCode),
                      _buildDetailRow(Icons.location_on, 'Address',
                          member.address.isNotEmpty ? member.address : 'N/A'),
                      _buildDetailRow(Icons.date_range, 'Joining Date',
                          member.joiningDate.isNotEmpty ? member.joiningDate : 'N/A'),
                      _buildDetailRow(Icons.perm_identity, 'Member ID', member.id),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  List<Member> members = [];
  List<Member> filteredMembers = [];
  bool isLoading = true;
  String groupCode = '';
  String searchQuery = '';
  String userName = '';
  int totalMembersCount = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserDataAndFetchMembers();
  }

  Future<void> _loadUserDataAndFetchMembers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        groupCode = prefs.getString('group_code') ?? '';
        userName = prefs.getString('user_name') ?? '';
      });

      print('Loaded from SharedPreferences:');
      print('Group Code: $groupCode');
      print('User Name: $userName');

      if (groupCode.isEmpty) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar('No group code found. Please login again.');
        return;
      }

      await _fetchMembers();
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Error loading user information: $e');
    }
  }

  Future<void> _fetchMembers() async {
    try {
      setState(() {
        isLoading = true;
      });

      print('Fetching members from API...');
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/member'),
        headers: {'Content-Type': 'application/json'},
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['status'] == true && responseData['members'] != null) {
          List<dynamic> membersData = responseData['members'];
          
          List<Member> allMembers = membersData
              .map((memberJson) => Member.fromJson(memberJson))
              .toList();

          print('Group Code from SharedPreferences: $groupCode');
          print('Available Group Codes in API: ${allMembers.map((m) => m.groupCode).toSet().toList()}');

          List<Member> groupMembers = allMembers
              .where((member) => member.groupCode == groupCode)
              .toList();

          setState(() {
            members = groupMembers;
            filteredMembers = groupMembers;
            totalMembersCount = groupMembers.length;
            isLoading = false;
          });

          print('Total members in API: ${allMembers.length}');
          print('Members in group $groupCode: ${groupMembers.length}');

          _updateDashboardMemberCount(groupMembers.length);
        } else {
          setState(() {
            isLoading = false;
            totalMembersCount = 0;
          });
          _showErrorSnackBar('No members data found in API response');
        }
      } else {
        setState(() {
          isLoading = false;
          totalMembersCount = 0;
        });
        _showErrorSnackBar('Failed to fetch members. Status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        totalMembersCount = 0;
      });
      print('Error fetching members: $e');
      _showErrorSnackBar('Network error: $e');
    }
  }

  Future<void> _updateDashboardMemberCount(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('members_count', count);
      print('Updated members count in SharedPreferences: $count');
    } catch (e) {
      print('Error updating members count: $e');
    }
  }

  void _filterMembers(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredMembers = members;
      } else {
        filteredMembers = members
            .where((member) =>
                member.name.toLowerCase().contains(query.toLowerCase()) ||
                member.phone.contains(query) ||
                member.email.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Members',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchMembers,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _filterMembers,
                  decoration: InputDecoration(
                    hintText: 'Search members by name, phone, or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterMembers('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
                if (userName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Welcome, $userName',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${filteredMembers.length} of $totalMembersCount members',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (searchQuery.isNotEmpty)
                        Text(
                          'Filtered by: "$searchQuery"',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
                if (groupCode.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Group: $groupCode',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.black),
                        SizedBox(height: 16),
                        Text('Loading members...'),
                      ],
                    ),
                  )
                : filteredMembers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              searchQuery.isNotEmpty
                                  ? 'No members found for "$searchQuery"'
                                  : totalMembersCount == 0
                                      ? 'No members found in your group'
                                      : 'No members match your search',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              groupCode.isNotEmpty
                                  ? 'Group: $groupCode'
                                  : 'Check your group code or try refreshing',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _fetchMembers,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchMembers,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredMembers.length,
                          itemBuilder: (context, index) {
                            final member = filteredMembers[index];
                            return _buildMemberCard(member, index);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Member member, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MemberDetailPage(member: member),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Text(
                      member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name.isNotEmpty ? member.name : 'Unknown Member',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (member.phone.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            member.phone,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (member.email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              member.email,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: member.status == '1' ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          member.status == '1' ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            color: member.status == '1' ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

void main() {
  runApp(const MaterialApp(
    home: MembersPage(),
    debugShowCheckedModeBanner: false,
  ));
}