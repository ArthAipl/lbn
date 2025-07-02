import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BusinessDetailsPage extends StatefulWidget {
  const BusinessDetailsPage({Key? key}) : super(key: key);

  @override
  _BusinessDetailsPageState createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  String? userId;
  String? groupId;
  String? memBusiId;
  bool isLoading = true;
  String? errorMessage;
  final _businessFormKey = GlobalKey<FormState>();

  late TextEditingController _businessNameController;

  List<dynamic> businessCategories = [];
  String? selectedCategoryId;
  String? businessName;

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController();
    initializeData();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    super.dispose();
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
      final storedGroupId = prefs.getString('group_id');
      
      setState(() {
        userId = storedUserId;
        groupId = storedGroupId;
      });
      
      print('Retrieved user_id: $userId, group_id: $groupId');
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

    if (groupId == null) {
      setState(() {
        errorMessage = 'Group ID is not available. Please try again later.';
        isLoading = false;
      });
      print('Error: Group ID is null');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final businessData = {
        'mem_busi_id': memBusiId ?? userId,
        'Business_Name': _businessNameController.text,
        'B_Cat_Id': selectedCategoryId,
        'G_ID': groupId,
        'M_ID': userId,
      };

      print('Sending business data to API: $businessData');

      // Use PUT request for updating business data
      final response = await http.put(
        Uri.parse('https://tagai.caxis.ca/public/api/memb-busi/${memBusiId ?? userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(businessData),
      );

      print('Business Save API response status code: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        await prefs.setString('business_name', _businessNameController.text);
        await prefs.setString('business_category_id', selectedCategoryId!);

        if (memBusiId == null) {
          final responseData = jsonDecode(response.body);
          memBusiId = responseData['mem_busi_id']?.toString();
          if (memBusiId != null) {
            await prefs.setString('mem_busi_id', memBusiId!);
          }
        }

        setState(() {
          businessName = _businessNameController.text;
          isLoading = false;
          errorMessage = 'Business details updated successfully';
        });
        print('Business details updated successfully');
      } else {
        setState(() {
          errorMessage = 'Failed to update business details: ${response.statusCode}';
          isLoading = false;
        });
        print('Error: Failed to update business details, status code: ${response.statusCode}');
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
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