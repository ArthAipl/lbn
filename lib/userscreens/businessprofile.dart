import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

// Models
class BusinessModel {
  final int? memBusiId;
  final String businessName;
  final String? busiDesc;
  final String? services;
  final String? products;
  final String? weburl;
  final String? fblink;
  final String? instalink;
  final String? tellink;
  final String? lilink;
  final List<String> logo;
  final String bCatId;
  final String gId;
  final String mId;

  BusinessModel({
    this.memBusiId,
    required this.businessName,
    this.busiDesc,
    this.services,
    this.products,
    this.weburl,
    this.fblink,
    this.instalink,
    this.tellink,
    this.lilink,
    this.logo = const [],
    required this.bCatId,
    required this.gId,
    required this.mId,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      memBusiId: json['mem_busi_id'],
      businessName: json['Business_Name'] ?? '',
      busiDesc: json['busi_desc'],
      services: json['services'],
      products: json['products'],
      weburl: json['weburl'],
      fblink: json['fblink'],
      instalink: json['instalink'],
      tellink: json['tellink'],
      lilink: json['lilink'],
      logo: List<String>.from(json['logo'] ?? []),
      bCatId: json['B_Cat_Id']?.toString() ?? '',
      gId: json['G_ID']?.toString() ?? '',
      mId: json['M_ID']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Business_Name': businessName,
      'busi_desc': busiDesc,
      'services': services,
      'products': products,
      'weburl': weburl,
      'fblink': fblink,
      'instalink': instalink,
      'tellink': tellink,
      'lilink': lilink,
      'logo': logo,
      'B_Cat_Id': bCatId,
      'G_ID': gId,
      'M_ID': mId,
    };
  }
}

class CategoryModel {
  final int bCatId;
  final String categoryName;

  CategoryModel({
    required this.bCatId,
    required this.categoryName,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      bCatId: json['B_Cat_Id'],
      categoryName: json['Category_Name'],
    );
  }
}

// API Service
class ApiService {
  static const String baseUrl = 'https://tagai.caxis.ca/public/api';

  static Future<List<CategoryModel>> fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/busi-cates'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => CategoryModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error fetching categories: $error');
    }
  }

  static Future<List<BusinessModel>> fetchBusinesses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/memb-busi'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => BusinessModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load businesses: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error fetching businesses: $error');
    }
  }

  static Future<BusinessModel> createBusiness(BusinessModel business) async {
    try {
      final payload = business.toJson();
      debugPrint('Create Business Payload: ${json.encode(payload)}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/memb-busi'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(payload),
      );

      debugPrint('Create Business Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return BusinessModel.fromJson(data);
      } else {
        throw Exception('Failed to create business: ${response.statusCode} - ${response.body}');
      }
    } catch (error) {
      throw Exception('Error creating business: $error');
    }
  }

  static Future<BusinessModel> updateBusiness(int businessId, BusinessModel business) async {
    try {
      final payload = business.toJson();
      debugPrint('Update Business Payload: ${json.encode(payload)}');
      
      final response = await http.put(
        Uri.parse('$baseUrl/memb-busi/$businessId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(payload),
      );

      debugPrint('Update Business Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return BusinessModel.fromJson(data);
      } else {
        throw Exception('Failed to update business: ${response.statusCode} - ${response.body}');
      }
    } catch (error) {
      throw Exception('Error updating business: $error');
    }
  }
}

// Image Helper
class ImageHelper {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (error) {
      debugPrint('Error picking image: $error');
      return null;
    }
  }

  static Future<File?> pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (error) {
      debugPrint('Error taking photo: $error');
      return null;
    }
  }

  static String _getMimeType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // Default fallback
    }
  }

  static bool _isValidBase64(String base64String) {
    try {
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',').last;
      }
      base64Decode(cleanBase64);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String> convertImageToBase64(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('Image size too large. Please select an image smaller than 5MB.');
      }

      Uint8List imageBytes = await imageFile.readAsBytes();
      String base64String = base64Encode(imageBytes);
      String mimeType = _getMimeType(imageFile.path);
      String dataUrl = 'data:$mimeType;base64,$base64String';
      
      debugPrint('Image converted to base64 with MIME type: $mimeType');
      debugPrint('Data URL length: ${dataUrl.length}');
      
      if (!_isValidBase64(dataUrl)) {
        throw Exception('Invalid base64 format generated');
      }
      
      return dataUrl;
    } catch (error) {
      debugPrint('Error converting image to base64: $error');
      throw Exception('Failed to convert image: $error');
    }
  }

  static String _extractBase64FromDataUrl(String dataUrl) {
    if (dataUrl.contains(',')) {
      return dataUrl.split(',').last;
    }
    return dataUrl;
  }

  static Widget buildImageWidget({
    File? imageFile,
    String? base64String,
    String? imageUrl,
    double width = 100,
    double height = 100,
    double borderRadius = 50,
    IconData fallbackIcon = Icons.business_center,
    double fallbackIconSize = 40,
  }) {
    Widget imageWidget;

    if (imageFile != null) {
      imageWidget = Image.file(
        imageFile,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    } else if (base64String != null && base64String.isNotEmpty) {
      try {
        if (base64String.startsWith('http')) {
          imageWidget = Image.network(
            base64String,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading network image: $error');
              return Icon(
                fallbackIcon,
                size: fallbackIconSize,
                color: Colors.grey[600],
              );
            },
          );
        } else {
          String cleanBase64 = base64String;
          if (base64String.startsWith('data:')) {
            cleanBase64 = _extractBase64FromDataUrl(base64String);
          }
          
          final bytes = base64Decode(cleanBase64);
          imageWidget = Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading base64 image: $error');
              return Icon(
                fallbackIcon,
                size: fallbackIconSize,
                color: Colors.grey[600],
              );
            },
          );
        }
      } catch (e) {
        debugPrint('Error processing image: $e');
        imageWidget = Icon(
          fallbackIcon,
          size: fallbackIconSize,
          color: Colors.grey[600],
        );
      }
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      imageWidget = Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading image URL: $error');
          return Icon(
            fallbackIcon,
            size: fallbackIconSize,
            color: Colors.grey[600],
          );
        },
      );
    } else {
      imageWidget = Icon(
        fallbackIcon,
        size: fallbackIconSize,
        color: Colors.grey[600],
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageWidget,
      ),
    );
  }

  static void showImagePickerBottomSheet(
    BuildContext context, {
    required VoidCallback onGalleryTap,
    required VoidCallback onCameraTap,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onGalleryTap();
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Icon(
                            Icons.photo_library,
                            size: 30,
                            color: Colors.blue[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gallery',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onCameraTap();
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 30,
                            color: Colors.green[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Camera',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

// Main Screen
class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  _BusinessProfileScreenState createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  bool _loading = false;
  String _currentStep = "checking";
  BusinessModel? _businessData;
  List<CategoryModel> _categories = [];

  // Form controllers
  final _businessNameController = TextEditingController();
  final _businessDescController = TextEditingController();
  final _servicesController = TextEditingController();
  final _productsController = TextEditingController();
  final _weburlController = TextEditingController();
  final _fblinkController = TextEditingController();
  final _instalinkController = TextEditingController();
  final _tellinkController = TextEditingController();
  final _lilinkController = TextEditingController();

  String _selectedCategoryId = "";
  File? _logoFile;
  String? _currentLogoUrl;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessDescController.dispose();
    _servicesController.dispose();
    _productsController.dispose();
    _weburlController.dispose();
    _fblinkController.dispose();
    _instalinkController.dispose();
    _tellinkController.dispose();
    _lilinkController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _fetchCategories();
    await _checkBusinessExists();
  }

  Future<Map<String, dynamic>?> _getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'email': prefs.getString('email'),
        'role_id': prefs.getString('role_id'),
        'Grop_code': prefs.getString('Grop_code'),
        'M_ID': prefs.getString('M_ID'),
        'Name': prefs.getString('Name'),
        'number': prefs.getString('number'),
             
        'G_ID': prefs.getString('G_ID'),
      };
    } catch (error) {
      debugPrint('Error getting user data: $error');
      return null;
    }
  }

  void _showNotification(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _fetchCategories() async {
    try {
      final categories = await ApiService.fetchCategories();
      setState(() {
        _categories = categories;
      });
    } catch (error) {
      debugPrint('Error fetching categories: $error');
      _showNotification('Error loading categories', isError: true);
    }
  }

  Future<void> _checkBusinessExists() async {
    final userData = await _getUserData();
    if (userData?['M_ID'] == null) {
      _showNotification('User not found', isError: true);
      return;
    }

    try {
      final businesses = await ApiService.fetchBusinesses();
      final userBusiness = businesses.firstWhere(
        (business) => business.mId == userData!['M_ID'],
        orElse: () => throw Exception('No business found'),
      );

      if (userBusiness.logo.isNotEmpty) {
        _currentLogoUrl = userBusiness.logo.first;
      }

      _populateFormFields(userBusiness);
      setState(() {
        _businessData = userBusiness;
        _currentStep = "profile";
      });
    } catch (error) {
      debugPrint('No business found for user, showing create form');
      setState(() => _currentStep = "create-business");
    }
  }

  void _populateFormFields(BusinessModel business) {
    _businessNameController.text = business.businessName;
    _selectedCategoryId = business.bCatId;
    _businessDescController.text = business.busiDesc ?? '';
    _servicesController.text = business.services ?? '';
    _productsController.text = business.products ?? '';
    _weburlController.text = business.weburl ?? '';
    _fblinkController.text = business.fblink ?? '';
    _instalinkController.text = business.instalink ?? '';
    _tellinkController.text = business.tellink ?? '';
    _lilinkController.text = business.lilink ?? '';
  }

  Future<void> _pickImage() async {
    ImageHelper.showImagePickerBottomSheet(
      context,
      onGalleryTap: () async {
        try {
          final file = await ImageHelper.pickImageFromGallery();
          if (file != null) {
            setState(() {
              _logoFile = file;
            });
            _showNotification('Image selected successfully!');
          }
        } catch (error) {
          _showNotification('Error selecting image: $error', isError: true);
        }
      },
      onCameraTap: () async {
        try {
          final file = await ImageHelper.pickImageFromCamera();
          if (file != null) {
            setState(() {
              _logoFile = file;
            });
            _showNotification('Photo taken successfully!');
          }
        } catch (error) {
          _showNotification('Error taking photo: $error', isError: true);
        }
      },
    );
  }

  Future<void> _createBusiness() async {
    if (_businessNameController.text.isEmpty || _selectedCategoryId.isEmpty) {
      _showNotification('Please fill all required fields', isError: true);
      return;
    }

    final userData = await _getUserData();
    if (userData?['M_ID'] == null) {
      _showNotification('User not found', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      List<String> logoArray = [];
      
      if (_logoFile != null) {
        try {
          final base64String = await ImageHelper.convertImageToBase64(_logoFile!);
          logoArray.add(base64String);
          debugPrint('Logo converted for business creation');
        } catch (error) {
          debugPrint('Error converting logo: $error');
          _showNotification('Error processing image: $error', isError: true);
          return;
        }
      }

      final business = BusinessModel(
        businessName: _businessNameController.text,
        bCatId: _selectedCategoryId,
        gId: userData!['Grop_code'] ?? '',
        mId: userData['M_ID'] ?? '',
        logo: logoArray,
      );

      await ApiService.createBusiness(business);
      _showNotification('Business created successfully!');
      await _checkBusinessExists();
    } catch (error) {
      debugPrint('Error creating business: $error');
      String errorMessage = 'Error creating business';
      if (error.toString().contains('Invalid Base64')) {
        errorMessage = 'Invalid image format. Please try a different image.';
      }
      _showNotification(errorMessage, isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateBusiness() async {
    if (_businessData?.memBusiId == null) {
      _showNotification('Business ID not found', isError: true);
      return;
    }

    final userData = await _getUserData();
    if (userData?['M_ID'] == null) {
      _showNotification('User not found', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      List<String> logoArray = [];
      
      if (_logoFile != null) {
        try {
          final base64String = await ImageHelper.convertImageToBase64(_logoFile!);
          logoArray.add(base64String);
          debugPrint('New logo converted for business update');
        } catch (error) {
          debugPrint('Error converting new logo: $error');
          _showNotification('Error processing image: $error', isError: true);
          return;
        }
      } else if (_currentLogoUrl != null && _currentLogoUrl!.isNotEmpty) {
        logoArray.add(_currentLogoUrl!);
        debugPrint('Keeping existing logo for business update');
      }

      final updatedBusiness = BusinessModel(
        memBusiId: _businessData!.memBusiId,
        businessName: _businessNameController.text,
        bCatId: _selectedCategoryId,
        busiDesc: _businessDescController.text.isEmpty ? null : _businessDescController.text,
        services: _servicesController.text.isEmpty ? null : _servicesController.text,
        products: _productsController.text.isEmpty ? null : _productsController.text,
        weburl: _weburlController.text.isEmpty ? null : _weburlController.text,
        fblink: _fblinkController.text.isEmpty ? null : _fblinkController.text,
        instalink: _instalinkController.text.isEmpty ? null : _instalinkController.text,
        tellink: _tellinkController.text.isEmpty ? null : _tellinkController.text,
        lilink: _lilinkController.text.isEmpty ? null : _lilinkController.text,
        gId: userData!['Grop_code'] ?? '',
        mId: userData['M_ID'] ?? '',
        logo: logoArray,
      );

      await ApiService.updateBusiness(_businessData!.memBusiId!, updatedBusiness);
      _showNotification('Profile updated successfully!');
      
      setState(() {
        _logoFile = null;
      });
      
      await _checkBusinessExists();
    } catch (error) {
      debugPrint('Error updating business: $error');
      String errorMessage = 'Error updating profile';
      if (error.toString().contains('Invalid Base64')) {
        errorMessage = 'Invalid image format. Please try a different image.';
      } else if (error.toString().contains('too large')) {
        errorMessage = 'Image size too large. Please select a smaller image.';
      }
      _showNotification(errorMessage, isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildCreateBusinessForm() {
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
          'Create Business',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Text(
              'Create Your Business',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Let\'s set up your business profile',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  _buildStyledTextField(
                    controller: _businessNameController,
                    label: 'Business Name',
                    hint: 'Enter your business name',
                    icon: Icons.business,
                    isRequired: true,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategoryId.isEmpty ? null : _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Business Category *',
                        prefixIcon: Icon(Icons.category, color: Colors.black),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      items: _categories.map<DropdownMenuItem<String>>((category) {
                        return DropdownMenuItem<String>(
                          value: category.bCatId.toString(),
                          child: Text(category.categoryName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value ?? '';
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickImage,
                    child: ImageHelper.buildImageWidget(
                      imageFile: _logoFile,
                      width: 120,
                      height: 120,
                      borderRadius: 60,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tap to add logo',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _createBusiness,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Text('Creating...', style: TextStyle(fontSize: 16)),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.rocket_launch, size: 24),
                                SizedBox(width: 12),
                                Text('Create Business', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePage() {
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
          'Business Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _pickImage,
            icon: const Icon(
              Icons.camera_alt,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        ImageHelper.buildImageWidget(
                          imageFile: _logoFile,
                          base64String: _currentLogoUrl,
                          width: 100,
                          height: 100,
                          borderRadius: 50,
                        ),
                        if (_logoFile != null)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _logoFile != null ? 'New image selected' : 'Tap to change logo',
                    style: TextStyle(
                      color: _logoFile != null ? Colors.green[600] : Colors.grey[600],
                      fontSize: 12,
                      fontWeight: _logoFile != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Business Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildEditableField(
                      controller: _businessNameController,
                      label: 'Business Name',
                      icon: Icons.business,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategoryId.isEmpty ? null : _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Business Category',
                          prefixIcon: Icon(Icons.category, color: Colors.black, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        items: _categories.map<DropdownMenuItem<String>>((category) {
                          return DropdownMenuItem<String>(
                            value: category.bCatId.toString(),
                            child: Text(category.categoryName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategoryId = value ?? '';
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildEditableField(
                      controller: _businessDescController,
                      label: 'Business Description',
                      icon: Icons.description,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEditableField(
                            controller: _servicesController,
                            label: 'Services',
                            icon: Icons.build,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildEditableField(
                            controller: _productsController,
                            label: 'Products',
                            icon: Icons.inventory,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildEditableField(
                      controller: _weburlController,
                      label: 'Website URL',
                      icon: Icons.language,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEditableField(
                            controller: _fblinkController,
                            label: 'Facebook',
                            icon: Icons.facebook,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildEditableField(
                            controller: _instalinkController,
                            label: 'Instagram',
                            icon: Icons.camera_alt,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEditableField(
                            controller: _tellinkController,
                            label: 'Telegram',
                            icon: Icons.telegram,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildEditableField(
                            controller: _lilinkController,
                            label: 'LinkedIn',
                            icon: Icons.business,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _updateBusiness,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.save, size: 20),
                                  SizedBox(width: 8),
                                  Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_hasAnyLinks()) ...[
              const SizedBox(height: 20),
              _buildSocialLinksCard(),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label + (isRequired ? ' *' : ''),
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.black),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: Colors.black,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  bool _hasAnyLinks() {
    return _fblinkController.text.isNotEmpty ||
           _instalinkController.text.isNotEmpty ||
           _lilinkController.text.isNotEmpty ||
           _weburlController.text.isNotEmpty;
  }

  Widget _buildSocialLinksCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Social Links',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                if (_fblinkController.text.isNotEmpty)
                  _buildSocialIcon(Icons.facebook, Colors.blue, _fblinkController.text, 'Facebook'),
                if (_instalinkController.text.isNotEmpty)
                  _buildSocialIcon(Icons.camera_alt, Colors.pink, _instalinkController.text, 'Instagram'),
                if (_lilinkController.text.isNotEmpty)
                  _buildSocialIcon(Icons.business, Colors.blue[800]!, _lilinkController.text, 'LinkedIn'),
                if (_weburlController.text.isNotEmpty)
                  _buildSocialIcon(Icons.language, Colors.black, _weburlController.text, 'Website'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color, String url, String platform) {
    return GestureDetector(
      onTap: () {
        debugPrint('Opening $platform: $url');
        _showNotification('Opening $platform...');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              platform,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == "checking") {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
              SizedBox(height: 20),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_currentStep == "create-business") {
      return _buildCreateBusinessForm();
    }
    
    return _buildProfilePage();
  }
}