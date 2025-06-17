import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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

  File? _selectedLogo;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchBusinessProfile();
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
        final data = json.decode(response.body);
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

  Future<void> _pickLogo() async {
    try {
      // Determine the correct permission based on platform and Android version
      Permission permission;
      if (Platform.isAndroid) {
        final androidSdkVersion = await _getAndroidSdkVersion();
        permission = androidSdkVersion >= 33 ? Permission.photos : Permission.storage;
        debugPrint('Selected permission for SDK $androidSdkVersion: $permission');
      } else {
        permission = Permission.photos;
      }

      // Check permission status
      var status = await permission.status;
      debugPrint('Initial Permission: $permission, Status: $status');

      if (status.isPermanentlyDenied) {
        _showErrorSnackBar(
            'Storage or Photos permission is permanently denied. Please enable it in app settings.');
        await openAppSettings();
        return;
      }

      if (!status.isGranted) {
        status = await permission.request();
        debugPrint('Requested Permission: $permission, Status: $status');
      }

      if (status.isGranted) {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 80,
        );

        if (image != null) {
          final file = File(image.path);
          if (await file.exists()) {
            setState(() {
              _selectedLogo = file;
            });
            debugPrint('Image selected: ${image.path}');
          } else {
            _showErrorSnackBar('Selected image file does not exist');
            debugPrint('File does not exist: ${image.path}');
          }
        } else {
          _showErrorSnackBar('No image selected');
          debugPrint('No image selected');
        }
      } else {
        _showErrorSnackBar(
            'Permission denied for ${permission == Permission.photos ? 'Photos' : 'Storage'}. Please grant permission in app settings.');
        debugPrint('Permission denied: $permission');
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
      debugPrint('Image picker error: $e');
    }
  }

  Future<int> _getAndroidSdkVersion() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      debugPrint('Android SDK Version: ${androidInfo.version.sdkInt}');
      return androidInfo.version.sdkInt;
    }
    return 0;
  }

  Future<void> _updateBusinessProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gId = prefs.getInt('G_ID') ?? 2;
      final mId = prefs.getInt('M_ID') ?? 1;
      final memBusiId = prefs.getString('mem_busi_id') ?? '2';

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

      // Add logo file if selected
      if (_selectedLogo != null && await _selectedLogo!.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('logo', _selectedLogo!.path),
        );
        debugPrint('Logo file added: ${_selectedLogo!.path}');
      } else if (_selectedLogo != null) {
        _showErrorSnackBar('Selected logo file does not exist');
        debugPrint('Logo file does not exist: ${_selectedLogo!.path}');
        return;
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        setState(() {
          _isEditing = false;
          _selectedLogo = null;
        });
        _showSuccessSnackBar('Business profile updated successfully!');
        await _fetchBusinessProfile();
        debugPrint('Update response: $responseBody');
      } else {
        throw Exception('Failed to update business profile: ${response.statusCode} - $responseBody');
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
          if (!_isLoading)
            IconButton(
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
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _populateControllers();
                  _selectedLogo = null;
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
                          if (_businessData['logo'] != null) ...[
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _businessData['logo'],
                                height: 60,
                                width: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('Image load error: $error');
                                  return Container(
                                    height: 60,
                                    width: 60,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.business),
                                  );
                                },
                              ),
                            ),
                          ],
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
                      _buildEditCard(
                        title: 'Logo',
                        icon: Icons.image,
                        child: Column(
                          children: [
                            if (_selectedLogo != null)
                              Image.file(
                                _selectedLogo!,
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                              ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _pickLogo,
                              icon: const Icon(Icons.upload),
                              label: const Text('Select Logo'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
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
                      icon: Icons.contact_mail,
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