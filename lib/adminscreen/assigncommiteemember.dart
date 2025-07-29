import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For date formatting

// AssignCommitteeMemberPage (Main page with full-width cards)
class AssignCommitteeMemberPage extends StatefulWidget {
  const AssignCommitteeMemberPage({super.key});

  @override
  State<AssignCommitteeMemberPage> createState() => _AssignCommitteeMemberPageState();
}

class _AssignCommitteeMemberPageState extends State<AssignCommitteeMemberPage> {
  List<dynamic> _members = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    debugPrint('AssignCommitteeMemberPage: initState called, fetching members...');
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      debugPrint('Fetching members from API...');
      final prefs = await SharedPreferences.getInstance();
      final gId = prefs.getString('G_ID');
      if (gId == null) {
        setState(() {
          _errorMessage = 'Group ID not found. Please set a valid group.';
          _isLoading = false;
        });
        debugPrint('Error: $_errorMessage');
        return;
      }
      debugPrint('Retrieved G_ID from SharedPreferences: $gId');

      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/member'),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint('API Response Status Code: ${response.statusCode}');
      if (kDebugMode) {
        debugPrint('API Response Body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> members = data['members'] ?? [];
        debugPrint('Parsed API response data (members): $members');
        setState(() {
          _members = members.where((member) {
            final gIdValue = member['G_ID']?.toString() ?? member['group']?['G_ID']?.toString() ?? '';
            final statusValue = member['status'] ?? member['group']?['status'] ?? '';
            return gIdValue == gId && statusValue == '1';
          }).toList();
          _isLoading = false;
          debugPrint('Filtered members: $_members');
          debugPrint('Number of active members found: ${_members.length}');
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load members: ${response.statusCode}';
          _isLoading = false;
        });
        debugPrint('Error: $_errorMessage');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching members: $e';
        _isLoading = false;
      });
      debugPrint('Exception caught: $_errorMessage');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building AssignCommitteeMemberPage widget...');
    debugPrint('isLoading: $_isLoading, errorMessage: $_errorMessage, members count: ${_members.length}');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Assign Committee Members',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  )
                : _members.isEmpty
                    ? Center(
                        child: Text(
                          'No active members found for this group.',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 3.0,
                        ),
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          debugPrint('Building GridView item for member: ${member['Name'] ?? 'Unknown'}');
                          return GestureDetector(
                            onTap: () {
                              debugPrint('Tapped on member: ${member['Name'] ?? 'Unknown'}, M_ID: ${member['M_ID']}');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AssignRoleFormPage(
                                    mId: member['M_ID']?.toString() ?? '0',
                                  ),
                                ),
                              );
                            },
                            child: Transform.scale(
                              scale: 1.0,
                              child: Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: Colors.black12, width: 1),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.white, Colors.grey.shade50],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                member['Name'] ?? 'Unknown',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                member['email'] ?? 'N/A',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Tap to assign committee role',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              color: Colors.blueAccent,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

// AssignRoleFormPage (Form page for assigning or updating roles)
class AssignRoleFormPage extends StatefulWidget {
  final String mId;

  const AssignRoleFormPage({super.key, required this.mId});

  @override
  State<AssignRoleFormPage> createState() => _AssignRoleFormPageState();
}

class _AssignRoleFormPageState extends State<AssignRoleFormPage> {
  final _formKey = GlobalKey<FormState>();
  List<dynamic> _serviceAreas = [];
  String? _selectedMemDesiId;
  bool _isLoading = true;
  String _errorMessage = '';
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  bool _isUpdate = false;
  String? _roleId; // Store the role ID for updates

  @override
  void initState() {
    super.initState();
    _fetchServiceAreas();
    _checkExistingRole();
  }

  Future<void> _fetchServiceAreas() async {
    try {
      debugPrint('Fetching service areas from API...');
      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/comm-desi'),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint('Service Areas API Response Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> serviceAreas = jsonDecode(response.body);
        debugPrint('Parsed service areas: $serviceAreas');
        setState(() {
          _serviceAreas = serviceAreas;
          if (_serviceAreas.isNotEmpty && _selectedMemDesiId == null) {
            _selectedMemDesiId = _serviceAreas[0]['MemDesi_ID']?.toString();
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load service areas: ${response.statusCode}';
        });
        debugPrint('Error: $_errorMessage');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching service areas: $e';
      });
      debugPrint('Exception caught: $_errorMessage');
    }
  }

  Future<void> _checkExistingRole() async {
    try {
      debugPrint('Checking for existing role for M_ID: ${widget.mId}...');
      final prefs = await SharedPreferences.getInstance();
      final gId = prefs.getString('G_ID');
      if (gId == null) {
        setState(() {
          _errorMessage = 'Group ID not found. Please set a valid group.';
          _isLoading = false;
        });
        debugPrint('Error: $_errorMessage');
        return;
      }
      debugPrint('Retrieved G_ID from SharedPreferences: $gId');

      final response = await http.get(
        Uri.parse('https://tagai.caxis.ca/public/api/comm-memb?M_ID=${widget.mId}&G_ID=$gId'),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint('Check Role API Response Status Code: ${response.statusCode}');
      debugPrint('Check Role API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> roles = jsonDecode(response.body);
        debugPrint('Parsed roles: $roles');
        if (roles.isNotEmpty) {
          final role = roles[0]; // Assume first role is relevant
          setState(() {
            _isUpdate = true;
            _roleId = role['C_M_ID']?.toString(); // Store role ID (adjust field name if different)
            _fromDateController.text = role['From_Date'] ?? '';
            _toDateController.text = role['To_Date'] ?? '';
            _selectedMemDesiId = role['MemDesi_ID']?.toString();
          });
        }
      } else {
        debugPrint('No existing role found or API error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking existing role: $e';
      });
      debugPrint('Exception caught: $_errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Validate To_Date is after From_Date
      final fromDate = DateFormat('yyyy-MM-dd').parse(_fromDateController.text);
      final toDate = DateFormat('yyyy-MM-dd').parse(_toDateController.text);
      if (toDate.isBefore(fromDate)) {
        setState(() {
          _errorMessage = 'To Date must be after From Date';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        final prefs = await SharedPreferences.getInstance();
        final gId = prefs.getString('G_ID');
        if (gId == null) {
          setState(() {
            _errorMessage = 'Group ID not found. Please set a valid group.';
            _isLoading = false;
          });
          debugPrint('Error: $_errorMessage');
          return;
        }
        debugPrint('Retrieved G_ID from SharedPreferences: $gId');

        final payload = {
          'From_Date': _fromDateController.text,
          'To_Date': _toDateController.text,
          'G_ID': int.parse(gId),
          'M_ID': int.parse(widget.mId),
          'MemDesi_ID': int.parse(_selectedMemDesiId ?? '0'),
          if (_isUpdate && _roleId != null) 'C_M_ID': _roleId, // Include role ID for updates
        };
        debugPrint('Submitting payload: $payload');

        http.Response response;
        String requestUrl;

        if (_isUpdate && _roleId != null) {
          requestUrl = 'https://tagai.caxis.ca/public/api/comm-memb/$_roleId';
          debugPrint('Sending PUT request to: $requestUrl');
          response = await http.put(
            Uri.parse(requestUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );
        } else {
          requestUrl = 'https://tagai.caxis.ca/public/api/comm-memb';
          debugPrint('Sending POST request to: $requestUrl');
          response = await http.post(
            Uri.parse(requestUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );
        }

        debugPrint('Submit API Response Status Code: ${response.statusCode}');
        debugPrint('Submit API Response Body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isUpdate ? 'Role updated successfully!' : 'Role assigned successfully!',
                style: GoogleFonts.poppins(),
              ),
            ),
          );
          Navigator.pop(context);
        } else {
          final errorBody = response.body.isNotEmpty ? jsonDecode(response.body) : {};
          setState(() {
            _errorMessage = 'Failed to ${_isUpdate ? 'update' : 'assign'} role: ${response.statusCode}. '
                '${errorBody['message'] ?? 'No additional details provided.'}';
          });
          debugPrint('Error: $_errorMessage');
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error ${_isUpdate ? 'updating' : 'submitting'} form: $e';
        });
        debugPrint('Exception caught: $_errorMessage');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isUpdate ? 'Update Committee Role' : 'Assign Committee Role',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        TextFormField(
                          controller: _fromDateController,
                          decoration: InputDecoration(
                            labelText: 'From Date (YYYY-MM-DD)',
                            labelStyle: GoogleFonts.poppins(),
                            border: const OutlineInputBorder(),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context, _fromDateController),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a start date';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _toDateController,
                          decoration: InputDecoration(
                            labelText: 'To Date (YYYY-MM-DD)',
                            labelStyle: GoogleFonts.poppins(),
                            border: const OutlineInputBorder(),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context, _toDateController),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select an end date';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedMemDesiId,
                          decoration: InputDecoration(
                            labelText: 'Service Area',
                            labelStyle: GoogleFonts.poppins(),
                            border: const OutlineInputBorder(),
                          ),
                          items: _serviceAreas.map<DropdownMenuItem<String>>((area) {
                            return DropdownMenuItem<String>(
                              value: area['MemDesi_ID']?.toString(),
                              child: Text(
                                area['ServiceAreas'] ?? 'Unknown',
                                style: GoogleFonts.poppins(),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedMemDesiId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a service area';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            _isLoading ? 'Submitting...' : (_isUpdate ? 'Update Role' : 'Assign Role'),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}