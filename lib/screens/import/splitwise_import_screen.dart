import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:spendpal/models/splitwise_expense_model.dart';
import 'package:spendpal/services/splitwise_import_service.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:intl/intl.dart';

class SplitwiseImportScreen extends StatefulWidget {
  const SplitwiseImportScreen({super.key});

  @override
  State<SplitwiseImportScreen> createState() => _SplitwiseImportScreenState();
}

class _SplitwiseImportScreenState extends State<SplitwiseImportScreen> {
  final SplitwiseImportService _importService = SplitwiseImportService();

  // Import flow steps
  int _currentStep = 0;

  // Step 1: File selection
  File? _selectedFile;
  bool _isParsingFile = false;

  // Step 2: Parsed data & friend selection
  SplitwiseImportData? _importData;
  final Set<String> _selectedUsers = {};

  // Step 3: User mapping
  Map<String, String> _userMapping = {}; // Splitwise name -> SpendPal UID
  Map<String, String> _spendPalFriends = {}; // UID -> Name

  // Step 4: Preview & import
  List<SplitwiseExpense> _expensesToImport = [];
  bool _isImporting = false;
  int _importedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final friends = await _importService.getUserFriends();
    setState(() {
      _spendPalFriends = friends;
    });
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _selectedFile = File(result.files.first.path!);
        _isParsingFile = true;
      });

      // Parse CSV
      final importData = await _importService.parseCSV(_selectedFile!);

      setState(() {
        _importData = importData;
        _isParsingFile = false;
        _currentStep = 1; // Move to friend selection
      });
    } catch (e) {
      setState(() => _isParsingFile = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error parsing file: $e')),
      );
    }
  }

  void _toggleUserSelection(String userName) {
    setState(() {
      if (_selectedUsers.contains(userName)) {
        _selectedUsers.remove(userName);
      } else {
        _selectedUsers.add(userName);
      }
    });
  }

  void _proceedToUserMapping() {
    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one friend')),
      );
      return;
    }

    // Auto-map users if names match
    for (final splitwiseName in _selectedUsers) {
      for (final entry in _spendPalFriends.entries) {
        if (entry.value.toLowerCase() == splitwiseName.toLowerCase()) {
          _userMapping[splitwiseName] = entry.key;
          break;
        }
      }
    }

    setState(() {
      _currentStep = 2; // Move to user mapping
    });
  }

  void _proceedToPreview() {
    // Check if all selected users are mapped
    final unmapped = _selectedUsers.where((name) => !_userMapping.containsKey(name)).toList();
    if (unmapped.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please map: ${unmapped.join(", ")}')),
      );
      return;
    }

    // Filter expenses for selected users
    final expenses = _importData!.getExpensesForUsers(_selectedUsers);

    setState(() {
      _expensesToImport = expenses;
      _currentStep = 3; // Move to preview
    });
  }

  Future<void> _performImport() async {
    setState(() => _isImporting = true);

    try {
      final count = await _importService.importExpenses(_expensesToImport, _userMapping);

      setState(() {
        _importedCount = count;
        _isImporting = false;
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Complete'),
          content: Text('Successfully imported $count expenses'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to account screen
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isImporting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Import from Splitwise'),
      ),
      body: _buildStep(theme),
    );
  }

  Widget _buildStep(ThemeData theme) {
    switch (_currentStep) {
      case 0:
        return _buildFileSelectionStep(theme);
      case 1:
        return _buildFriendSelectionStep(theme);
      case 2:
        return _buildUserMappingStep(theme);
      case 3:
        return _buildPreviewStep(theme);
      default:
        return const SizedBox();
    }
  }

  Widget _buildFileSelectionStep(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.upload_file,
              size: 80,
              color: AppTheme.tealAccent,
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Splitwise CSV Export',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Export your Splitwise data as CSV and select it here',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_isParsingFile)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.file_open),
                label: const Text('Choose CSV File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendSelectionStep(ThemeData theme) {
    final users = _importData?.allUsers.toList() ?? [];
    users.sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Friends to Import',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose which friends\' expenses you want to import',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userName = users[index];
              final expenseCount = _importData!.getExpenseCountForUser(userName);
              final isSelected = _selectedUsers.contains(userName);

              return CheckboxListTile(
                title: Text(userName),
                subtitle: Text('$expenseCount expenses'),
                value: isSelected,
                activeColor: AppTheme.tealAccent,
                onChanged: (_) => _toggleUserSelection(userName),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _selectedUsers.isEmpty ? null : _proceedToUserMapping,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.tealAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text('Next (${_selectedUsers.length} selected)'),
          ),
        ),
      ],
    );
  }

  Widget _buildUserMappingStep(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Map Users',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Match Splitwise users to your SpendPal friends',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _selectedUsers.length,
            itemBuilder: (context, index) {
              final splitwiseName = _selectedUsers.elementAt(index);
              final mappedUid = _userMapping[splitwiseName];

              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(splitwiseName),
                subtitle: mappedUid != null
                    ? Text('→ ${_spendPalFriends[mappedUid]}')
                    : const Text('Not mapped', style: TextStyle(color: Colors.red)),
                trailing: DropdownButton<String>(
                  value: mappedUid,
                  hint: const Text('Select friend'),
                  items: _spendPalFriends.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (uid) {
                    if (uid != null) {
                      setState(() {
                        _userMapping[splitwiseName] = uid;
                      });
                    }
                  },
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _proceedToPreview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Preview Expenses'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _currentStep = 1),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewStep(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Preview Import',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${_expensesToImport.length} expenses will be imported',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _expensesToImport.length,
            itemBuilder: (context, index) {
              final expense = _expensesToImport[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.tealAccent,
                  child: Text(
                    expense.currency,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
                title: Text(expense.description),
                subtitle: Text(
                  '${expense.date} • ${expense.category}\n'
                  'Paid by: ${expense.paidBy}',
                ),
                trailing: Text(
                  '${expense.currency} ${expense.cost.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                isThreeLine: true,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _isImporting ? null : _performImport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isImporting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Import Expenses'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isImporting ? null : () => setState(() => _currentStep = 2),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
