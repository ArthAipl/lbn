import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BusinessPage extends StatefulWidget {
  const BusinessPage({super.key});

  @override
  State<BusinessPage> createState() => _BusinessPageState();
}

class _BusinessPageState extends State<BusinessPage> {
  bool _isLoading = true;
  bool _isEditing = false;
  Map<String, dynamic> _businessData = {};

  // Controllers for editing
  final _businessNameController = TextEditingController();
  final _descController = TextEditingController();
  final _servicesController = TextEditingController();
  final _productsController = TextEditingController();
  final _weburlController = TextEditingController();
  final _fblinkController = TextEditingController();
  final _instalinkController = TextEditingController();
  final _tellinkController = TextEditingController();
  final _lilinkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _debugSharedPreferences();
    _fetchBusinessProfile();
  }

  Future<void> _debugSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    debugPrint('SharedPreferences - mem_busi_id: ${prefs.getString('mem_busi_id')}');
    debugPrint('SharedPreferences - G_ID: ${prefs.getInt('G_ID')}');
    debugPrint('SharedPreferences - M_ID: ${prefs.getInt('M_ID')}');
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _descController.dispose();
    _servicesController.dispose();
    _productsController.dispose();
    _weburlController.dispose();
    _fblinkController.dispose();
    _instalinkController.dispose();
    _tellinkController.dispose();
    _lilinkController.dispose();
    super.dispose();
  }

  Future<void> _fetchBusinessProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gId = prefs.getInt('G_ID') ?? 2;
      final mId = prefs.getInt('M_ID') ?? 1;

      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/busi-profiles?G_ID=$gId&M_ID=$mId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;
        debugPrint('GET API Response: $responseBody');
        final data = json.decode(responseBody);
        if (data['mem_busi_id'] != null) {
          await prefs.setString('mem_busi_id', data['mem_busi_id'].toString());
          debugPrint('Stored mem_busi_id from API: ${data['mem_busi_id']}');
        } else {
          debugPrint('Warning: mem_busi_id not found in API response');
        }
        setState(() {
          _businessData = data;
          _populateControllers();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load business profile: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error fetching business profile: $e');
      debugPrint('Fetch error: $e');
    }
  }

  void _populateControllers() {
    _businessNameController.text = _businessData['business_name'] ?? '';
    _descController.text = _businessData['busi_desc'] ?? '';
    _servicesController.text = _businessData['services'] ?? '';
    _productsController.text = _businessData['products'] ?? '';
    _weburlController.text = _businessData['weburl'] ?? '';
    _fblinkController.text = _businessData['fblink'] ?? '';
    _instalinkController.text = _businessData['instalink'] ?? '';
    _tellinkController.text = _businessData['tellink'] ?? '';
    _lilinkController.text = _businessData['lilink'] ?? '';
  }

  Future<void> _updateBusinessProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gId = prefs.getInt('G_ID') ?? 2;
      final mId = prefs.getInt('M_ID') ?? 1;
      final memBusiId = prefs.getString('mem_busi_id');

      if (memBusiId == null) {
        _showErrorSnackBar('Member business ID is missing. Please set it first.');
        debugPrint('Error: mem_busi_id is null');
        return;
      }

      debugPrint('Sending mem_busi_id: $memBusiId');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://tagai.caxis.ca/public/api/busi-profiles'),
      );

      // Add form fields
      request.fields.addAll({
        'business_name': _businessNameController.text,
        'busi_desc': _descController.text,
        'services': _servicesController.text,
        'products': _productsController.text,
        'weburl': _weburlController.text,
        'fblink': _fblinkController.text,
        'instalink': _instalinkController.text,
        'tellink': _tellinkController.text,
        'lilink': _lilinkController.text,
        'mem_busi_id': memBusiId,
        'G_ID': gId.toString(),
        'M_ID': mId.toString(),
      });

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      debugPrint('POST API Response: $responseBody');

      if (response.statusCode == 200) {
        setState(() {
          _isEditing = false;
        });
        _showSuccessSnackBar('Business profile updated successfully!');
        await _fetchBusinessProfile();
      } else {
        final errorData = json.decode(responseBody);
        final errorMessage = errorData['error'] ?? 'Unknown error';
        throw Exception('Failed to update business profile: ${response.statusCode} - $errorMessage');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating business profile: $e');
      debugPrint('Update error: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Business Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          FutureBuilder<String?>(
            future: SharedPreferences.getInstance()
                .then((prefs) => prefs.getString('mem_busi_id')),
            builder: (context, snapshot) {
              if (!_isLoading && snapshot.hasData && snapshot.data != null) {
                return IconButton(
                  icon: Icon(
                    _isEditing ? Icons.save : Icons.edit,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (_isEditing) {
                      _updateBusinessProfile();
                    } else {
                      setState(() {
                        _isEditing = true;
                      });
                    }
                  },
                );
              }
              return const SizedBox.shrink(); // Hide button if mem_busi_id is null
            },
          ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _populateControllers();
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.black, Colors.grey],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Business',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _businessData['business_name'] ?? 'Business Name',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isEditing) ...[
                      _buildEditCard(
                        title: 'Business Name',
                        icon: Icons.business,
                        child: TextFormField(
                          controller: _businessNameController,
                          decoration: const InputDecoration(
                            labelText: 'Business Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildInfoCard(
                      title: 'Business Description',
                      icon: Icons.description,
                      children: [
                        _isEditing
                            ? TextFormField(
                                controller: _descController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: 'Enter business description',
                                  border: OutlineInputBorder(),
                                ),
                              )
                            : Text(
                                _businessData['busi_desc'] ?? 'No description available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[800],
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      title: 'Services & Products',
                      icon: Icons.business_center,
                      children: [
                        if (_isEditing) ...[
                          TextFormField(
                            controller: _servicesController,
                            decoration: const InputDecoration(
                              labelText: 'Services',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _productsController,
                            decoration: const InputDecoration(
                              labelText: 'Products',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ] else ...[
                          _buildInfoRow('Services', _businessData['services'] ?? 'Not specified'),
                          _buildInfoRow('Products', _businessData['products'] ?? 'Not specified'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      title: 'Contact Information',
                      icon: Icons

.contact_mail,
                      children: [
                        if (_isEditing) ...[
                          TextFormField(
                            controller: _weburlController,
                            decoration: const InputDecoration(
                              labelText: 'Website URL',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ] else ...[
                          _buildInfoRow('Website', _businessData['weburl'] ?? 'Not provided'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      title: 'Social Media Links',
                      icon: Icons.share,
                      children: [
                        if (_isEditing) ...[
                          TextFormField(
                            controller: _fblinkController,
                            decoration: const InputDecoration(
                              labelText: 'Facebook',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _instalinkController,
                            decoration: const InputDecoration(
                              labelText: 'Instagram',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _tellinkController,
                            decoration: const InputDecoration(
                              labelText: 'Telegram',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _lilinkController,
                            decoration: const InputDecoration(
                              labelText: 'LinkedIn',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ] else ...[
                          _buildInfoRow('Facebook', _businessData['fblink'] ?? 'Not provided'),
                          _buildInfoRow('Instagram', _businessData['instalink'] ?? 'Not provided'),
                          _buildInfoRow('Telegram', _businessData['tellink'] ?? 'Not provided'),
                          _buildInfoRow('LinkedIn', _businessData['lilink'] ?? 'Not provided'),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildEditCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}