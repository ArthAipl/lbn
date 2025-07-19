import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// MemberDetailPage (now with dynamic G_ID input and professional design)
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
  final TextEditingController _groupIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroupIdAndFetchMembers();
  }

  Future<void> _loadGroupIdAndFetchMembers() async {
    await _loadGroupId();
    if (groupId != null && groupId!.isNotEmpty) {
      await _fetchMembers();
    } else {
      setState(() {
        isLoading = false; // Stop loading if G_ID is not found, wait for user input
      });
    }
  }

  Future<void> _loadGroupId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        groupId = prefs.getString('G_ID');
        if (groupId != null) {
          _groupIdController.text = groupId!; // Pre-fill if already saved
        }
      });
      if (groupId == null || groupId!.isEmpty) {
        debugPrint('Error: G_ID not found or empty in SharedPreferences. Prompting user.');
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

  Future<void> _saveGroupIdAndFetchMembers() async {
    final newGroupId = _groupIdController.text.trim();
    if (newGroupId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Group ID.')),
      );
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('G_ID', newGroupId);
      setState(() {
        groupId = newGroupId;
      });
      debugPrint('Saved new G_ID: $newGroupId');
      await _fetchMembers();
    } catch (e) {
      debugPrint('Error saving G_ID: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving Group ID.')),
      );
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
      backgroundColor: Colors.white, // Ensure white background
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Group Members'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (groupId == null || groupId!.isEmpty)
              ? _buildGroupIdInputScreen() // Show G_ID input if not set
              : members.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.users, size: 60, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No active members found for this group.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : SmartRefresher(
                      controller: _refreshController,
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final memberId = member['M_ID']?.toString();
                          return Card(
                            elevation: 2, // Lighter shadow for list items
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0), // Slightly less rounded for list cards
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12.0),
                              onTap: () {
                                if (memberId != null) {
                                  debugPrint('Tapped on member: ${member['Name']} with M_ID: $memberId');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BusinessProfilePage(memberId: memberId),
                                    ),
                                  );
                                } else {
                                  debugPrint('M_ID is null for member: ${member['Name']}');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Cannot view business profile: Member ID missing')),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0), // Adjusted padding
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24, // Slightly larger avatar
                                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                          child: Text(
                                            member['Name'] != null && member['Name'].isNotEmpty
                                                ? member['Name'][0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).colorScheme.primary),
                                          ),
                                        ),
                                        const SizedBox(width: 16.0),
                                        Expanded(
                                          child: Text(
                                            member['Name'] ?? 'Unknown',
                                            style: Theme.of(context).textTheme.titleLarge, // Use titleLarge for names
                                          ),
                                        ),
                                        const Icon(LucideIcons.chevronRight, size: 24.0, color: Colors.grey),
                                      ],
                                    ),
                                    const Divider(height: 24, thickness: 0.5, indent: 64, endIndent: 0), // Adjusted divider
                                    _buildMemberInfoRow(
                                      icon: LucideIcons.mail,
                                      label: 'Email',
                                      value: member['email'] ?? 'N/A',
                                    ),
                                    const SizedBox(height: 8.0), // Adjusted spacing
                                    _buildMemberInfoRow(
                                      icon: LucideIcons.phone,
                                      label: 'Number',
                                      value: member['number'] ?? 'N/A',
                                    ),
                                    const SizedBox(height: 16.0), // Adjusted spacing
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        'Tap to see business profile',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[500]),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildMemberInfoRow({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]), // Slightly larger icon
        const SizedBox(width: 12), // Adjusted spacing
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupIdInputScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.network, size: 80, color: Theme.of(context).colorScheme.primary), // Larger icon
                const SizedBox(height: 24),
                Text(
                  'Enter Group ID',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please provide your Group ID to view members. This will be saved for future use.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _groupIdController,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'Group ID',
                    hintText: 'e.g., 12345',
                    prefixIcon: Icon(LucideIcons.hash),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : _saveGroupIdAndFetchMembers,
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Load Members'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _groupIdController.dispose();
    super.dispose();
  }
}

// BusinessProfilePage (now with professional and modern design, using textboxes)
class BusinessProfilePage extends StatefulWidget {
  final String memberId;
  const BusinessProfilePage({Key? key, required this.memberId}) : super(key: key);

  @override
  _BusinessProfilePageState createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  Map<String, dynamic>? businessProfile;
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchBusinessProfile();
  }

  Future<void> _fetchBusinessProfile() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });
    try {
      debugPrint('Fetching business profile for M_ID: ${widget.memberId}');
      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/memb-busi'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('Business API Response: $data');
        final profile = data.firstWhere(
          (item) => item['M_ID']?.toString() == widget.memberId,
          orElse: () => null,
        );
        if (profile != null) {
          setState(() {
            businessProfile = profile;
            isLoading = false;
          });
          debugPrint('Found business profile for M_ID: ${widget.memberId}');
        } else {
          debugPrint('No business profile found for M_ID: ${widget.memberId}');
          setState(() {
            isLoading = false;
            hasError = true; // Indicate no profile found
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No business profile found for this member.')),
          );
        }
      } else {
        debugPrint('Error: HTTP ${response.statusCode} - ${response.reasonPhrase}');
        setState(() {
          isLoading = false;
          hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('HTTP Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Network or parsing error: $e');
      setState(() {
        isLoading = false;
        hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network or parsing error occurred')),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $url')),
      );
    }
  }

  // Widget to build a display field using TextFormField for a "textbox" look
  Widget _buildDisplayField(String label, String? value, {IconData? icon, VoidCallback? onTap}) {
    final displayValue = value != null && value.isNotEmpty ? value : 'Not Provided';
    final isLink = onTap != null && value != null && value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: isLink ? onTap : null,
            child: TextFormField(
              readOnly: true,
              initialValue: displayValue,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isLink ? Colors.blueAccent[700] : Colors.black87,
                    decoration: isLink ? TextDecoration.underline : TextDecoration.none,
                  ),
              decoration: InputDecoration(
                prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600], size: 20) : null,
              ),
              maxLines: null, // Allow multiple lines for description
            ),
          ),
        ],
      ),
    );
  }

  // Widget to build a social icon button
  Widget _buildSocialIconButton(IconData icon, Color color, String url, String tooltip) {
    if (url.isEmpty) return const SizedBox.shrink();
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(24.0),
        onTap: () => _launchUrl(url),
        child: Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 1.0),
          ),
          child: Icon(icon, size: 26, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Ensure white background
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Business Profile'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.alertCircle, size: 60, color: Colors.redAccent[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load business profile or no profile found.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Business Logo Section
                      if (businessProfile!['logo'] != null && businessProfile!['logo'].isNotEmpty)
                        Column(
                          children: [
                            Text(
                              'Business Logo',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.black54),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 24.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.2),
                                        spreadRadius: 2,
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18.0),
                                    child: Image.network(
                                      businessProfile!['logo'][0],
                                      height: 120,
                                      width: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Icon(LucideIcons.imageOff, size: 80, color: Colors.grey[400]),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      // Business Name
                      Center(
                        child: Text(
                          businessProfile!['Business_Name'] ?? 'Business Name Not Provided',
                          style: Theme.of(context).textTheme.headlineLarge, // Adjusted font size for "huge"
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      // Business Details Card
                      Card(
                        elevation: 2, // Softer shadow for content card
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDisplayField(
                                'Description',
                                businessProfile!['busi_desc'],
                                icon: LucideIcons.info,
                              ),
                              _buildDisplayField(
                                'Services',
                                businessProfile!['services'],
                                icon: LucideIcons.briefcase,
                              ),
                              _buildDisplayField(
                                'Products',
                                businessProfile!['products'],
                                icon: LucideIcons.package,
                              ),
                              _buildDisplayField(
                                'Website URL',
                                businessProfile!['weburl'],
                                icon: LucideIcons.globe,
                                onTap: () => _launchUrl(businessProfile!['weburl'] ?? ''),
                              ),
                              const SizedBox(height: 16.0),
                              Text(
                                'Social Links',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12.0),
                              Wrap(
                                spacing: 12.0,
                                runSpacing: 10.0,
                                children: [
                                  _buildSocialIconButton(LucideIcons.facebook, Colors.blue[700]!,
                                      businessProfile!['fblink'] ?? '', 'Facebook'),
                                  _buildSocialIconButton(LucideIcons.instagram, Colors.purple[700]!,
                                      businessProfile!['instalink'] ?? '', 'Instagram'),
                                  _buildSocialIconButton(LucideIcons.send, Colors.lightBlue[700]!,
                                      businessProfile!['tellink'] ?? '', 'Telegram'),
                                  _buildSocialIconButton(LucideIcons.linkedin, Colors.blue[900]!,
                                      businessProfile!['lilink'] ?? '', 'LinkedIn'),
                                ],
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
}
