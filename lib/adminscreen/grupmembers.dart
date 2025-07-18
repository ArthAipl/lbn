import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemberDetailPage extends StatefulWidget {
  const MemberDetailPage({Key? key}) : super(key: key);

  @override
  _MemberDetailPageState createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> {
  List<dynamic> members = [];
  bool isLoading = true;
  String? groupId;
  final RefreshController _refreshController = RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    _loadGroupIdAndFetchMembers();
  }

  Future<void> _loadGroupIdAndFetchMembers() async {
    await _loadGroupId();
    await _fetchMembers();
  }

  Future<void> _loadGroupId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        groupId = prefs.getString('G_ID');
      });
      if (groupId == null || groupId!.isEmpty) {
        debugPrint('Error: G_ID not found or empty in SharedPreferences');
        setState(() {
          isLoading = false;
        });
      } else {
        debugPrint('Loaded G_ID from SharedPreferences: $groupId');
      }
    } catch (e) {
      debugPrint('Error loading SharedPreferences: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchMembers() async {
    if (groupId == null || groupId!.isEmpty) {
      debugPrint('Cannot fetch members: G_ID is null or empty');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Group ID not found')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      debugPrint('Fetching members from API for G_ID: $groupId');
      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/member'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('API Response: $data');
        // Handle both string "1" and boolean true for API status
        if (data['status'] == '1' || data['status'] == true) {
          if (data['members'] == null || data['members'].isEmpty) {
            debugPrint('Error: API returned no members or empty members list');
            setState(() {
              isLoading = false;
              members = [];
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No member data available')),
            );
            return;
          }
          setState(() {
            members = (data['members'] as List)
                .where((member) {
                  final memberGId = member['G_ID']?.toString();
                  final memberStatus = member['status']?.toString();
                  if (memberGId == null) {
                    debugPrint('Warning: Member with null G_ID found: $member');
                    return false;
                  }
                  if (memberStatus == null) {
                    debugPrint('Warning: Member with null status found: $member');
                    return false;
                  }
                  if (memberStatus != '1') {
                    debugPrint('Skipping member with status $memberStatus: $member');
                    return false;
                  }
                  return memberGId == groupId;
                })
                .toList();
            isLoading = false;
          });
          if (members.isEmpty) {
            debugPrint('Warning: No members found for G_ID: $groupId with status: 1');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No active members found for this group')),
            );
          } else {
            debugPrint('Found ${members.length} members for G_ID: $groupId with status: 1');
          }
        } else {
          debugPrint('Error: API returned status ${data['status']} with message: ${data['message'] ?? 'No message'}');
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load members: ${data['message'] ?? 'Unknown error'}')),
          );
        }
      } else {
        debugPrint('Error: HTTP ${response.statusCode} - ${response.reasonPhrase}');
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('HTTP Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Network or parsing error: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network or parsing error occurred')),
      );
    }
    _refreshController.refreshCompleted();
  }

  void _onRefresh() async {
    debugPrint('Pull-to-refresh triggered');
    await _fetchMembers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Group Members',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: PullToRefresh(
        controller: _refreshController,
        onRefresh: _onRefresh,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : members.isEmpty
                ? const Center(child: Text('No active members found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return Card(
                        elevation: 4.0,
                        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member['Name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              Text(
                                'Email: ${member['email'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 16.0),
                              ),
                              Text(
                                'Number: ${member['number'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 16.0),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}

class PullToRefresh extends StatelessWidget {
  final RefreshController controller;
  final VoidCallback onRefresh;
  final Widget child;

  const PullToRefresh({
    Key? key,
    required this.controller,
    required this.onRefresh,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SmartRefresher(
      controller: controller,
      onRefresh: onRefresh,
      child: child,
    );
  }
}