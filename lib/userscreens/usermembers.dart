import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Member model
class Member {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String groupCode;
  final int status;
  final String address;
  final String createdAt;
  final String gId;
  final String roleId;

  Member({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.groupCode,
    required this.status,
    required this.address,
    required this.createdAt,
    required this.gId,
    required this.roleId,
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
      groupCode: json['Grop_code']?.toString() ?? '',
      status: parsedStatus,
      address: json['address']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      gId: json['G_ID']?.toString() ?? '',
      roleId: json['role_id']?.toString() ?? '',
    );
  }
}

// Function to save user data to SharedPreferences
Future<void> saveUserData(Map<String, dynamic> userData) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('M_ID', userData['M_ID']?.toString() ?? '');
    await prefs.setString('Name', userData['Name']?.toString() ?? '');
    await prefs.setString('email', userData['email']?.toString() ?? '');
    await prefs.setString('number', userData['number']?.toString() ?? '');
    await prefs.setString('Grop_code', userData['Grop_code']?.toString() ?? '');
    await prefs.setString('G_ID', userData['G_ID']?.toString() ?? '');
    await prefs.setString('role_id', userData['role_id']?.toString() ?? '');
    print('DEBUG: Saved user data to SharedPreferences');
  } catch (e) {
    print('DEBUG ERROR: Error saving user data to SharedPreferences: $e');
  }
}

// Member List Page
class MemberListPage extends StatefulWidget {
  const MemberListPage({super.key});

  @override
  State<MemberListPage> createState() => _MemberListPageState();
}

class _MemberListPageState extends State<MemberListPage> {
  List<Member> members = [];
  List<Member> filteredMembers = [];
  bool isLoading = true;
  String? errorMessage;
  String? groupCode;
  String? gId;
  String? roleId;
  final TextEditingController _searchController = TextEditingController();
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadGroupCodeAndFetchMembers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      if (_searchController.text.isEmpty) {
        filteredMembers = members;
      } else {
        filteredMembers = members
            .where((member) =>
                member.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                member.email.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                member.phone.contains(_searchController.text))
            .toList();
      }
    });
  }

  Future<void> _loadGroupCodeAndFetchMembers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      print('DEBUG: Loading user data from SharedPreferences');
      // Load data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final storedGroupCode = prefs.getString('Grop_code');
      final storedGId = prefs.getString('G_ID');
      final storedRoleId = prefs.getString('role_id');
      final storedMId = prefs.getString('M_ID');
      final storedName = prefs.getString('Name');

      print('DEBUG: Retrieved Grop_code: $storedGroupCode, M_ID: $storedMId, Name: $storedName, G_ID: $storedGId, role_id: $storedRoleId');

      if (storedGroupCode == null || storedGroupCode.trim().isEmpty) {
        print('DEBUG ERROR: Group ID not found in SharedPreferences');
        setState(() {
          isLoading = false;
          errorMessage = 'Group ID not found. Please login again.';
        });
        return;
      }

      setState(() {
        groupCode = storedGroupCode.trim();
        gId = storedGId;
        roleId = storedRoleId;
      });

      // Fetch members
      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/member'));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('DEBUG: API Response: $jsonData');

        List<dynamic> data;

        // Handle JSON structure
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('members')) {
          data = jsonData['members'] is List

 ? jsonData['members'] : [];
        } else {
          setState(() {
            isLoading = false;
            errorMessage = 'Unexpected JSON structure: No members list found';
          });
          return;
        }

        // Parse members
        try {
          final membersList = data
              .map((json) => Member.fromJson(json as Map<String, dynamic>))
              .where((member) => member.groupCode == groupCode && member.status == 1)
              .toList();

          setState(() {
            members = membersList;
            filteredMembers = membersList;
            isLoading = false;
            errorMessage = null;
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

  void _toggleSearch() {
    setState(() {
      isSearching = !isSearching;
      if (!isSearching) {
        _searchController.clear();
        filteredMembers = members;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          if (isSearching)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search members by name, email, or phone...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

          // Main Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadGroupCodeAndFetchMembers,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
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
                              Text(
                                errorMessage!,
                                style: const TextStyle(fontSize: 16, color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadGroupCodeAndFetchMembers,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : filteredMembers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _searchController.text.isNotEmpty
                                        ? Icons.search_off
                                        : Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchController.text.isNotEmpty
                                        ? 'No members found matching "${_searchController.text}"'
                                        : 'No active members found for this group',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredMembers.length,
                              itemBuilder: (context, index) {
                                final member = filteredMembers[index];
                                return _buildMemberCard(member);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Member member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MemberDetailsPage(),
                settings: RouteSettings(arguments: member),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: Text(
                      member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Member Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.phone,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
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

// Member Details Page
class MemberDetailsPage extends StatelessWidget {
  const MemberDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Member member = ModalRoute.of(context)!.settings.arguments as Member;

    return Scaffold(
      appBar: AppBar(
        title: Text(member.name),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Header Card
            Card(
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black,
                      Colors.grey[800]!,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Center(
                        child: Text(
                          member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    Text(
                      member.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Group Code Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Group: ${member.groupCode}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Contact Information Card
            Card(
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildDetailItem(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: member.email,
                      iconColor: Colors.red,
                    ),

                    const SizedBox(height: 16),

                    _buildDetailItem(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: member.phone,
                      iconColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Additional Information Card
            Card(
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Member Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildDetailItem(
                      icon: Icons.badge_outlined,
                      label: 'Member ID',
                      value: member.id.toString(),
                      iconColor: Colors.blue,
                    ),

                    const SizedBox(height: 16),

                    _buildDetailItem(
                      icon: Icons.group_outlined,
                      label: 'Group ID',
                      value: member.gId,
                      iconColor: Colors.purple,
                    ),

                    const SizedBox(height: 16),

                    _buildDetailItem(
                      icon: Icons.person_outline,
                      label: 'Role ID',
                      value: member.roleId,
                      iconColor: Colors.teal,
                    ),

                    const SizedBox(height: 16),

                    _buildDetailItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'Joined Date',
                      value: _formatDate(member.createdAt),
                      iconColor: Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
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
                value.isEmpty ? 'N/A' : value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString.isEmpty ? 'N/A' : dateString;
    }
  }
}