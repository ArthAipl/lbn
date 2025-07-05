import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

class BusinessDetailsPage extends StatefulWidget {
  const BusinessDetailsPage({Key? key}) : super(key: key);

  @override
  _BusinessDetailsPageState createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  String? userId;
  String? memBusiId;
  bool isLoading = true;
  String? errorMessage;
  final _businessFormKey = GlobalKey<FormState>();
  late TextEditingController _businessNameController;
  late TextEditingController _businessDescController;
  late TextEditingController _servicesController;
  late TextEditingController _productsController;
  late TextEditingController _weburlController;
  late TextEditingController _fblinkController;
  late TextEditingController _instalinkController;
  late TextEditingController _tellinkController;
  late TextEditingController _lilinkController;
  
  List<dynamic> businessCategories = [];
  String? selectedCategoryId;
  String? businessName;
  File? _logoImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController();
    _businessDescController = TextEditingController();
    _servicesController = TextEditingController();
    _productsController = TextEditingController();
    _weburlController = TextEditingController();
    _fblinkController = TextEditingController();
    _instalinkController = TextEditingController();
    _tellinkController = TextEditingController();
    _lilinkController = TextEditingController();
    initializeData();
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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (image != null) {
        setState(() {
          _logoImage = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      setState(() {
        errorMessage = 'Error selecting image: $e';
      });
    }
  }

  Future<void> initializeData() async {
    await fetchUserBasicData();
    await fetchBusinessCategories();
    await fetchBusinessData();
  }

  Future<void> fetchUserBasicData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString('user_id');
      
      setState(() {
        userId = storedUserId;
      });
      
      print('Retrieved user_id: $userId');
    } catch (e) {
      print('Error fetching user basic data: $e');
    }
  }

  Future<void> fetchBusinessCategories() async {
    try {
      print('Making API call to https://tagai.caxis.ca/public/api/busi-cates');
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/busi-cates'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Business Categories API response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(response.body);
        print('Business Categories API response data: $responseData');
        setState(() {
          businessCategories = responseData;
          if (businessCategories.isNotEmpty && selectedCategoryId == null) {
            selectedCategoryId = businessCategories[0]['B_Cat_Id'].toString();
          }
        });
      } else {
        setState(() {
          errorMessage = 'Failed to fetch business categories: ${response.statusCode}';
        });
        print('Error: Failed to fetch business categories, status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching business categories: $e';
        isLoading = false;
      });
      print('Exception caught while fetching business categories: $e');
    }
  }

  Future<void> fetchBusinessData() async {
    try {
      if (userId == null) {
        setState(() {
          errorMessage = 'User ID not available for fetching business data';
          isLoading = false;
        });
        print('Error: User ID not available for fetching business data');
        return;
      }

      print('Making API call to https://tagai.caxis.ca/public/api/memb-busi');
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/memb-busi'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Business API response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(response.body);
        print('Business API response data: $responseData');
        final business = responseData.firstWhere(
          (b) => b['M_ID'].toString() == userId,
          orElse: () => null,
        );

        if (business != null) {
          print('Found matching business: $business');
          setState(() {
            memBusiId = business['mem_busi_id']?.toString();
            businessName = business['Business_Name'] ?? 'N/A';
            selectedCategoryId = business['B_Cat_Id']?.toString();
            _businessNameController.text = businessName!;
            _businessDescController.text = business['busi_desc'] ?? '';
            _servicesController.text = business['services'] ?? '';
            _productsController.text = business['products'] ?? '';
            _weburlController.text = business['weburl'] ?? '';
            _fblinkController.text = business['fblink'] ?? '';
            _instalinkController.text = business['instalink'] ?? '';
            _tellinkController.text = business['tellink'] ?? '';
            _lilinkController.text = business['lilink'] ?? '';
            isLoading = false;
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('business_name', businessName!);
          if (memBusiId != null) {
            await prefs.setString('mem_busi_id', memBusiId!);
          }
          if (selectedCategoryId != null) {
            await prefs.setString('business_category_id', selectedCategoryId!);
          }
        } else {
          print('No matching business found for M_ID: $userId');
          setState(() {
            businessName = 'N/A';
            _businessNameController.text = businessName!;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to fetch business data: ${response.statusCode}';
          isLoading = false;
        });
        print('Error: Failed to fetch business data, status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching business data: $e';
        isLoading = false;
      });
      print('Exception caught while fetching business data: $e');
    }
  }

  Future<void> saveBusinessData() async {
    if (!_businessFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Create a multipart request
      var request = http.MultipartRequest(
        memBusiId != null ? 'PUT' : 'POST',
        Uri.parse('https://tagai.caxis.ca/public/api/memb-busi${memBusiId != null ? '/$memBusiId' : ''}'),
      );

      // Add text fields
      request.fields['Business_Name'] = _businessNameController.text;
      request.fields['B_Cat_Id'] = selectedCategoryId ?? '';
      request.fields['M_ID'] = userId ?? '';
      if (_businessDescController.text.isNotEmpty) {
        request.fields['busi_desc'] = _businessDescController.text;
      }
      if (_servicesController.text.isNotEmpty) {
        request.fields['services'] = _servicesController.text;
      }
      if (_productsController.text.isNotEmpty) {
        request.fields['products'] = _productsController.text;
      }
      if (_weburlController.text.isNotEmpty) {
        request.fields['weburl'] = _weburlController.text;
      }
      if (_fblinkController.text.isNotEmpty) {
        request.fields['fblink'] = _fblinkController.text;
      }
      if (_instalinkController.text.isNotEmpty) {
        request.fields['instalink'] = _instalinkController.text;
      }
      if (_tellinkController.text.isNotEmpty) {
        request.fields['tellink'] = _tellinkController.text;
      }
      if (_lilinkController.text.isNotEmpty) {
        request.fields['lilink'] = _lilinkController.text;
      }
      if (memBusiId != null) {
        request.fields['mem_busi_id'] = memBusiId!;
      }

      // Add logo image if selected
      if (_logoImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'logo',
          _logoImage!.path,
          filename: 'business_logo_${userId ?? 'unknown'}.jpg',
        ));
      }

      // Set headers
      request.headers['Accept'] = 'application/json';

      print('Sending business data to API: ${request.fields}');
      if (_logoImage != null) {
        print('Including logo image: ${_logoImage!.path}');
      }

      // Send the request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Business Save API response status code: ${response.statusCode}');
      print('Business Save API response body: $responseBody');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success
        await prefs.setString('business_name', _businessNameController.text);
        if (selectedCategoryId != null) {
          await prefs.setString('business_category_id', selectedCategoryId!);
        }

        // Try to get mem_busi_id from response if it's a new business
        if (memBusiId == null) {
          try {
            final responseData = jsonDecode(responseBody);
            if (responseData is Map && responseData.containsKey('mem_busi_id')) {
              memBusiId = responseData['mem_busi_id']?.toString();
              if (memBusiId != null) {
                await prefs.setString('mem_busi_id', memBusiId!);
              }
            }
          } catch (e) {
            print('Could not parse response for mem_busi_id: $e');
          }
        }

        setState(() {
          businessName = _businessNameController.text;
          isLoading = false;
          errorMessage = 'Business details updated successfully';
        });
        print('Business details updated successfully');
      } else if (response.statusCode == 422) {
        // Validation error
        try {
          final errorData = jsonDecode(responseBody);
          setState(() {
            errorMessage = 'Validation error: ${errorData['message'] ?? 'Please check your input'}';
            isLoading = false;
          });
        } catch (e) {
          setState(() {
            errorMessage = 'Validation error: Please check your input';
            isLoading = false;
          });
        }
      } else {
        // Other errors
        String errorMsg = 'Failed to update business details: ${response.statusCode}';
        try {
          final errorData = jsonDecode(responseBody);
          if (errorData is Map && errorData.containsKey('message')) {
            errorMsg += ' - ${errorData['message']}';
          }
        } catch (e) {
          // Could not parse error response
        }
        
        setState(() {
          errorMessage = errorMsg;
          isLoading = false;
        });
        print('Error: $errorMsg');
        print('Response body: $responseBody');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error saving business data: $e';
        isLoading = false;
      });
      print('Exception caught while saving business data: $e');
    }
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.black, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black54),
          prefixIcon: Icon(icon, color: Colors.black54),
          filled: true,


          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildLogoUploadSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Logo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: _logoImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(
                        _logoImage!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: Colors.black54,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap to select logo',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        value: selectedCategoryId,
        style: const TextStyle(color: Colors.black, fontSize: 16),
        decoration: InputDecoration(
          labelText: 'Business Category',
          labelStyle: const TextStyle(color: Colors.black54),
          prefixIcon: const Icon(Icons.business, color: Colors.black54),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        items: businessCategories.map((category) {
          return DropdownMenuItem<String>(
            value: category['B_Cat_Id'].toString(),
            child: Text(category['Category_Name'] ?? 'N/A'),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedCategoryId = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a business category';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSaveButton({required VoidCallback onPressed, required String text}) {
    return Container(
      width: double.infinity,
      height: 55,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (errorMessage == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: errorMessage!.contains('successfully')
            ? Colors.green[50]
            : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: errorMessage!.contains('successfully')
              ? Colors.green
              : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            errorMessage!.contains('successfully')
                ? Icons.check_circle
                : Icons.error,
            color: errorMessage!.contains('successfully')
                ? Colors.green
                : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage!,
              style: TextStyle(
                color: errorMessage!.contains('successfully')
                    ? Colors.green[800]
                    : Colors.red[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
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
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Business Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _businessFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildSectionHeader(
                        icon: Icons.business,
                        title: 'Business Information',
                        subtitle: 'Manage your business details',
                      ),
                      const SizedBox(height: 32),
                      _buildErrorMessage(),
                      _buildCustomTextField(
                        controller: _businessNameController,
                        label: 'Business Name',
                        icon: Icons.store_outlined,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a business name';
                          }
                          return null;
                        },
                      ),
                      _buildCustomDropdown(),
                      _buildCustomTextField(
                        controller: _businessDescController,
                        label: 'Business Description',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                      ),
                      _buildCustomTextField(
                        controller: _servicesController,
                        label: 'Services',
                        icon: Icons.room_service_outlined,
                        maxLines: 2,
                      ),
                      _buildCustomTextField(
                        controller: _productsController,
                        label: 'Products',
                        icon: Icons.inventory_outlined,
                        maxLines: 2,
                      ),
                      _buildCustomTextField(
                        controller: _weburlController,
                        label: 'Website URL',
                        icon: Icons.web_outlined,
                        keyboardType: TextInputType.url,
                      ),
                      _buildCustomTextField(
                        controller: _fblinkController,
                        label: 'Facebook Link',
                        icon: Icons.facebook_outlined,
                        keyboardType: TextInputType.url,
                      ),
                      _buildCustomTextField(
                        controller: _instalinkController,
                        label: 'Instagram Link',
                        icon: Icons.camera_alt_outlined,
                        keyboardType: TextInputType.url,
                      ),
                      _buildCustomTextField(
                        controller: _tellinkController,
                        label: 'Telegram Link',
                        icon: Icons.telegram_outlined,
                        keyboardType: TextInputType.url,
                      ),
                      _buildCustomTextField(
                        controller: _lilinkController,
                        label: 'LinkedIn Link',
                        icon: Icons.work_outline,
                        keyboardType: TextInputType.url,
                      ),
                      _buildLogoUploadSection(),
                      _buildSaveButton(
                        onPressed: saveBusinessData,
                        text: 'Save Business Details',
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}