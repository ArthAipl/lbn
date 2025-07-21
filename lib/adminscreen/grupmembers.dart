import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// MemberDetailPage
class MemberDetailPage extends StatefulWidget {
  const MemberDetailPage({Key? key}) : super(key: key);

  @override
  _MemberDetailPageState createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> with SingleTickerProviderStateMixin {
  List<dynamic> members = [];
  bool isLoading = true;
  String? groupId;
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  final TextEditingController _groupIdController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _animationController.forward();
    _loadGroupIdAndFetchMembers();
  }

  Future<void> _loadGroupIdAndFetchMembers() async {
    await _loadGroupId();
    if (groupId != null && groupId!.isNotEmpty) {
      await _fetchMembers();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadGroupId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        groupId = prefs.getString('G_ID');
        if (groupId != null) {
          _groupIdController.text = groupId!;
        }
      });
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
        const SnackBar(content: Text('Please enter a Group ID')),
      );
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('G_ID', newGroupId);
      setState(() {
        groupId = newGroupId;
      });
      await _fetchMembers();
    } catch (e) {
      debugPrint('Error saving G_ID: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving Group ID')),
      );
    }
  }

  Future<void> _fetchMembers() async {
    if (groupId == null || groupId!.isEmpty) {
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
      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/member'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == '1' || data['status'] == true) {
          if (data['members'] == null || data['members'].isEmpty) {
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
                  return memberGId == groupId && memberStatus == '1';
                })
                .toList();
            isLoading = false;
          });
          if (members.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No active members found for this group')),
            );
          }
        } else {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load members: ${data['message'] ?? 'Unknown error'}')),
          );
        }
      } else {
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
    await _fetchMembers();
    _animationController.forward(from: 0);
  }

  void _showGroupIdDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter Group ID', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _groupIdController,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: 'Group ID',
            hintText: 'e.g., 12345',
            prefixIcon: const Icon(LucideIcons.hash, color: Colors.black54),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveGroupIdAndFetchMembers();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Group Members',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(
              child: SizedBox(
                height: 50,
                width: 50,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              ),
            )
          : (groupId == null || groupId!.isEmpty)
              ? _buildGroupIdInputScreen()
              : members.isEmpty
                  ? Center(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.users, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No active members found for this group.',
                              style: TextStyle(color: Colors.grey[600], fontSize: 18),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _showGroupIdDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text('Change Group ID', style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SmartRefresher(
                      controller: _refreshController,
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final memberId = member['M_ID']?.toString();
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut),
                              ),
                            ),
                            child: _buildMemberCard(member, memberId),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildMemberCard(dynamic member, String? memberId) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.black12,
            child: Text(
              member['Name']?.isNotEmpty == true ? member['Name'][0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            member['Name'] ?? 'Unknown',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('Email: ${member['email'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text('Number: ${member['number'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
          trailing: const Icon(LucideIcons.chevronRight, color: Colors.black54),
          onTap: () {
            if (memberId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BusinessProfilePage(memberId: memberId),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cannot view business profile: Member ID missing')),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildGroupIdInputScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.network, size: 80, color: Colors.black),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter Group ID',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please provide your Group ID to view members.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _groupIdController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Group ID',
                      hintText: 'e.g., 12345',
                      prefixIcon: const Icon(LucideIcons.hash, color: Colors.black54),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _saveGroupIdAndFetchMembers,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Load Members', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshController.dispose();
    _groupIdController.dispose();
    super.dispose();
  }
}

// BusinessProfilePage with Pull-to-Refresh and Removed Visit Website Button
class BusinessProfilePage extends StatefulWidget {
  final String memberId;

  const BusinessProfilePage({Key? key, required this.memberId}) : super(key: key);

  @override
  _BusinessProfilePageState createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? businessProfile;
  bool isLoading = true;
  bool hasError = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final RefreshController _refreshController = RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _fetchBusinessProfile();
  }

  Future<void> _fetchBusinessProfile() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });
    try {
      final response = await http.get(Uri.parse('https://tagai.caxis.ca/public/api/memb-busi'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final profile = data.firstWhere(
          (item) => item['M_ID']?.toString() == widget.memberId,
          orElse: () => null,
        );
        if (profile != null) {
          setState(() {
            businessProfile = profile;
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
            hasError = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No business profile found for this member')),
          );
        }
      } else {
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
    _refreshController.refreshCompleted();
    _animationController.forward(from: 0);
  }

  void _onRefresh() async {
    await _fetchBusinessProfile();
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $url')),
      );
    }
  }

  Widget _buildDisplayField(String label, String? value, {IconData? icon, VoidCallback? onTap}) {
    final displayValue = value != null && value.isNotEmpty ? value : 'Not Provided';
    final isLink = onTap != null && value != null && value.isNotEmpty;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: isLink ? onTap : null,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (icon != null) Icon(icon, color: Colors.black54, size: 22),
                    if (icon != null) const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayValue,
                        style: TextStyle(
                          color: isLink ? Colors.blue[600] : Colors.black87,
                          fontSize: 16,
                          decoration: isLink ? TextDecoration.underline : TextDecoration.none,
                        ),
                      ),
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

  Widget _buildSocialIconButton(IconData icon, Color color, String url, String tooltip) {
    if (url.isEmpty) return const SizedBox.shrink();
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: () => _launchUrl(url),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: color.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 28, color: color),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Business Profile',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: Colors.black,
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.6),
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'About'),
                  Tab(text: 'Connect'),
                ],
              ),
            ),
          ),
        ),
        body: isLoading
            ? const Center(
                child: SizedBox(
                  height: 60,
                  width: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                ),
              )
            : hasError
                ? Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.alertTriangle, size: 100, color: Colors.red[400]),
                          const SizedBox(height: 20),
                          Text(
                            'Unable to load business profile.',
                            style: TextStyle(color: Colors.grey[700], fontSize: 20, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Please try again later or check the member ID.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _fetchBusinessProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Retry', style: TextStyle(fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                  )
                : SmartRefresher(
                    controller: _refreshController,
                    onRefresh: _onRefresh,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Hero Section (Visit Website Button Removed)
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipOval(
                                    child: businessProfile!['logo'] != null && businessProfile!['logo'].isNotEmpty
                                        ? Image.network(
                                            businessProfile!['logo'][0],
                                            height: 100,
                                            width: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              height: 100,
                                              width: 100,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.grey[200],
                                              ),
                                              child: Icon(LucideIcons.imageOff, size: 50, color: Colors.grey[400]),
                                            ),
                                          )
                                        : Container(
                                            height: 100,
                                            width: 100,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.grey[200],
                                            ),
                                            child: Icon(LucideIcons.imageOff, size: 50, color: Colors.grey[400]),
                                          ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    businessProfile!['Business_Name'] ?? 'Business Name Not Provided',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Tabbed Content
                          Container(
                            height: MediaQuery.of(context).size.height - kToolbarHeight - 48 - MediaQuery.of(context).padding.top,
                            child: TabBarView(
                              children: [
                                // About Tab
                                SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: Card(
                                      elevation: 3,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 6,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Business Details',
                                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                                            ),
                                            const SizedBox(height: 20),
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
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Connect Tab
                                SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: Card(
                                      elevation: 3,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 6,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Connect with Us',
                                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                                            ),
                                            const SizedBox(height: 20),
                                            _buildDisplayField(
                                              'Website URL',
                                              businessProfile!['weburl'],
                                              icon: LucideIcons.globe,
                                              onTap: () => _launchUrl(businessProfile!['weburl'] ?? ''),
                                            ),
                                            const SizedBox(height: 20),
                                            const Text(
                                              'Social Links',
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                                            ),
                                            const SizedBox(height: 16),
                                            Wrap(
                                              spacing: 16,
                                              runSpacing: 16,
                                              children: [
                                                _buildSocialIconButton(
                                                  LucideIcons.facebook,
                                                  Colors.blue,
                                                  businessProfile!['fblink'] ?? '',
                                                  'Facebook',
                                                ),
                                                _buildSocialIconButton(
                                                  LucideIcons.instagram,
                                                  Colors.pinkAccent,
                                                  businessProfile!['instalink'] ?? '',
                                                  'Instagram',
                                                ),
                                                _buildSocialIconButton(
                                                  LucideIcons.send,
                                                  Colors.cyan,
                                                  businessProfile!['tellink'] ?? '',
                                                  'Telegram',
                                                ),
                                                _buildSocialIconButton(
                                                  LucideIcons.linkedin,
                                                  Colors.blueAccent,
                                                  businessProfile!['lilink'] ?? '',
                                                  'LinkedIn',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
    _animationController.dispose();
    _refreshController.dispose();
    super.dispose();
  }
}