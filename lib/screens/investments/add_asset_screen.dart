import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/models/investment_asset.dart';

class AddAssetScreen extends StatefulWidget {
  final InvestmentAsset? asset;
  final bool isEdit;

  const AddAssetScreen({
    super.key,
    this.asset,
    this.isEdit = false,
  });

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _symbolController = TextEditingController();
  final _schemeCodeController = TextEditingController();
  final _platformController = TextEditingController();

  // FD/RD/PPF/EPF/NPS fields
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _tenureController = TextEditingController();

  // Gold fields
  final _weightController = TextEditingController();

  String _selectedAssetType = 'equity';
  String? _selectedGoldForm;
  String? _selectedPurity;
  String? _selectedBank;
  String? _selectedPlatform;
  String? _selectedInterestPreset;
  String? _selectedTenurePreset;
  DateTime? _selectedMaturityDate;
  bool _isLoading = false;
  bool _showCustomBank = false;
  bool _showCustomPlatform = false;
  bool _showCustomInterest = false;
  bool _showCustomTenure = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.asset != null) {
      _nameController.text = widget.asset!.name;
      _symbolController.text = widget.asset!.symbol ?? '';
      _schemeCodeController.text = widget.asset!.schemeCode ?? '';
      _platformController.text = widget.asset!.platform ?? '';
      _bankNameController.text = widget.asset!.bankName ?? '';
      _accountNumberController.text = widget.asset!.accountNumber ?? '';
      _interestRateController.text = widget.asset!.interestRate?.toString() ?? '';
      _tenureController.text = widget.asset!.tenureMonths?.toString() ?? '';
      _weightController.text = widget.asset!.weightGrams?.toString() ?? '';
      _selectedAssetType = widget.asset!.assetType;
      _selectedGoldForm = widget.asset!.goldForm;
      _selectedPurity = widget.asset!.purity;
      _selectedMaturityDate = widget.asset!.maturityDate;
    }
  }

  final List<Map<String, String>> _assetTypes = [
    {'value': 'equity', 'label': 'Equity (Stock)'},
    {'value': 'mutual_fund', 'label': 'Mutual Fund'},
    {'value': 'etf', 'label': 'ETF'},
    {'value': 'fd', 'label': 'Fixed Deposit'},
    {'value': 'rd', 'label': 'Recurring Deposit'},
    {'value': 'ppf', 'label': 'PPF'},
    {'value': 'epf', 'label': 'EPF'},
    {'value': 'nps', 'label': 'NPS'},
    {'value': 'gold', 'label': 'Gold'},
  ];

  final List<String> _commonBanks = [
    'State Bank of India (SBI)',
    'HDFC Bank',
    'ICICI Bank',
    'Axis Bank',
    'Kotak Mahindra Bank',
    'Punjab National Bank (PNB)',
    'Bank of Baroda',
    'Canara Bank',
    'Union Bank of India',
    'Bank of India',
    'Indian Bank',
    'Central Bank of India',
    'IDFC First Bank',
    'YES Bank',
    'IndusInd Bank',
    'Other',
  ];

  final List<String> _commonPlatforms = [
    'Zerodha',
    'Groww',
    'Upstox',
    'Angel One',
    '5Paisa',
    'ICICI Direct',
    'HDFC Securities',
    'Kotak Securities',
    'Axis Direct',
    'Paytm Money',
    'ET Money',
    'Coin by Zerodha',
    'Other',
  ];

  final List<String> _interestRatePresets = [
    '6.0%',
    '6.5%',
    '7.0%',
    '7.5%',
    '8.0%',
    '8.5%',
    '9.0%',
    'Custom',
  ];

  final List<String> _tenurePresets = [
    '6 months',
    '12 months (1 year)',
    '24 months (2 years)',
    '36 months (3 years)',
    '60 months (5 years)',
    '120 months (10 years)',
    'Custom',
  ];

  final List<String> _popularStocks = [
    'Reliance Industries',
    'Tata Consultancy Services (TCS)',
    'HDFC Bank',
    'Infosys',
    'ICICI Bank',
    'Hindustan Unilever',
    'State Bank of India (SBI)',
    'Bharti Airtel',
    'ITC',
    'Kotak Mahindra Bank',
    'Larsen & Toubro (L&T)',
    'Axis Bank',
    'Bajaj Finance',
    'Asian Paints',
    'Maruti Suzuki',
    'Titan Company',
    'Wipro',
    'Tech Mahindra',
    'UltraTech Cement',
    'Nestle India',
    'HCL Technologies',
    'Sun Pharma',
    'Adani Enterprises',
    'Power Grid Corporation',
    'NTPC',
  ];

  final List<String> _popularMutualFunds = [
    'SBI Bluechip Fund',
    'HDFC Top 100 Fund',
    'Axis Bluechip Fund',
    'ICICI Prudential Bluechip Fund',
    'Mirae Asset Large Cap Fund',
    'Parag Parikh Flexi Cap Fund',
    'Axis Midcap Fund',
    'Kotak Emerging Equity Fund',
    'SBI Small Cap Fund',
    'Axis Small Cap Fund',
    'HDFC Balanced Advantage Fund',
    'ICICI Prudential Equity & Debt Fund',
    'SBI Equity Hybrid Fund',
    'UTI Nifty Index Fund',
    'HDFC Index Fund - Nifty 50',
  ];

  final List<String> _popularETFs = [
    'Nippon India ETF Nifty BeES',
    'HDFC Nifty 50 ETF',
    'SBI ETF Nifty 50',
    'ICICI Prudential Nifty ETF',
    'Nippon India ETF Bank BeES',
    'Kotak Nifty Bank ETF',
    'Nippon India ETF Gold BeES',
    'SBI Gold ETF',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _symbolController.dispose();
    _schemeCodeController.dispose();
    _platformController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _interestRateController.dispose();
    _tenureController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login first'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final assetId = widget.isEdit && widget.asset != null
          ? widget.asset!.assetId
          : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('investmentAssets')
              .doc()
              .id;

      final asset = InvestmentAsset(
        assetId: assetId,
        userId: user.uid,
        assetType: _selectedAssetType,
        name: _nameController.text.trim(),
        symbol: _symbolController.text.trim().isEmpty
            ? null
            : _symbolController.text.trim(),
        schemeCode: _schemeCodeController.text.trim().isEmpty
            ? null
            : _schemeCodeController.text.trim(),
        platform: _platformController.text.trim().isEmpty
            ? null
            : _platformController.text.trim(),
        bankName: _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim().isEmpty
            ? null
            : _accountNumberController.text.trim(),
        interestRate: _interestRateController.text.trim().isEmpty
            ? null
            : double.tryParse(_interestRateController.text.trim()),
        maturityDate: _selectedMaturityDate,
        tenureMonths: _tenureController.text.trim().isEmpty
            ? null
            : int.tryParse(_tenureController.text.trim()),
        goldForm: _selectedGoldForm,
        weightGrams: _weightController.text.trim().isEmpty
            ? null
            : double.tryParse(_weightController.text.trim()),
        purity: _selectedPurity,
        createdAt: widget.isEdit && widget.asset != null
            ? widget.asset!.createdAt
            : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('investmentAssets')
          .doc(assetId)
          .set(asset.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEdit ? 'Asset updated successfully' : 'Asset created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${widget.isEdit ? 'updating' : 'creating'} asset: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Asset' : 'Add New Asset'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Asset Type
            DropdownButtonFormField<String>(
              initialValue: _selectedAssetType,
              decoration: const InputDecoration(
                labelText: 'Asset Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _assetTypes.map((type) {
                return DropdownMenuItem(
                  value: type['value'],
                  child: Text(type['label']!),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedAssetType = value!;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select asset type';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Asset Name with Autocomplete
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }

                List<String> suggestions = [];
                if (_selectedAssetType == 'equity') {
                  suggestions = _popularStocks;
                } else if (_selectedAssetType == 'mutual_fund') {
                  suggestions = _popularMutualFunds;
                } else if (_selectedAssetType == 'etf') {
                  suggestions = _popularETFs;
                }

                return suggestions.where((String option) {
                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                _nameController.text = selection;
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // Sync with our controller
                if (_nameController.text.isNotEmpty && controller.text.isEmpty) {
                  controller.text = _nameController.text;
                }
                controller.addListener(() {
                  _nameController.text = controller.text;
                });

                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Asset Name',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.label),
                    hintText: _selectedAssetType == 'equity'
                        ? 'e.g., Reliance Industries'
                        : _selectedAssetType == 'mutual_fund'
                        ? 'e.g., SBI Bluechip Fund'
                        : _selectedAssetType == 'etf'
                        ? 'e.g., Nifty BeES'
                        : _selectedAssetType == 'fd' || _selectedAssetType == 'rd'
                        ? 'e.g., HDFC FD 2024'
                        : _selectedAssetType == 'gold'
                        ? 'e.g., Physical Gold 24K'
                        : 'e.g., My PPF Account',
                    helperText: _selectedAssetType == 'equity'
                        ? 'Type to see popular stocks'
                        : _selectedAssetType == 'mutual_fund'
                        ? 'Type to see popular funds'
                        : _selectedAssetType == 'etf'
                        ? 'Type to see popular ETFs'
                        : null,
                    helperMaxLines: 2,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter asset name';
                    }
                    return null;
                  },
                  onFieldSubmitted: (value) => onFieldSubmitted(),
                );
              },
            ),

            const SizedBox(height: 16),

            // Symbol (for stocks/ETF)
            if (_selectedAssetType == 'equity' || _selectedAssetType == 'etf')
              TextFormField(
                controller: _symbolController,
                decoration: const InputDecoration(
                  labelText: 'Symbol (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                  hintText: 'e.g., RELIANCE, NIFTYBEES',
                ),
              ),

            if (_selectedAssetType == 'equity' || _selectedAssetType == 'etf')
              const SizedBox(height: 16),

            // Scheme Code (for mutual funds)
            if (_selectedAssetType == 'mutual_fund')
              TextFormField(
                controller: _schemeCodeController,
                decoration: const InputDecoration(
                  labelText: 'Scheme Code (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.code),
                  hintText: 'e.g., 119551',
                ),
              ),

            if (_selectedAssetType == 'mutual_fund')
              const SizedBox(height: 16),

            // Platform (for stocks/mutual funds/ETF)
            if (_selectedAssetType == 'equity' || _selectedAssetType == 'mutual_fund' || _selectedAssetType == 'etf') ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedPlatform,
                decoration: const InputDecoration(
                  labelText: 'Platform (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                items: _commonPlatforms.map((platform) {
                  return DropdownMenuItem(value: platform, child: Text(platform));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlatform = value;
                    _showCustomPlatform = value == 'Other';
                    if (value != 'Other') {
                      _platformController.text = value ?? '';
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              if (_showCustomPlatform) ...[
                TextFormField(
                  controller: _platformController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Platform Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                    hintText: 'e.g., Your Platform',
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Bank Name (for FD/RD/PPF/EPF/NPS)
            if (_selectedAssetType == 'fd' || _selectedAssetType == 'rd' || _selectedAssetType == 'ppf' || _selectedAssetType == 'epf' || _selectedAssetType == 'nps') ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedBank,
                decoration: const InputDecoration(
                  labelText: 'Bank/Institution Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance),
                ),
                items: _commonBanks.map((bank) {
                  return DropdownMenuItem(value: bank, child: Text(bank));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBank = value;
                    _showCustomBank = value == 'Other';
                    if (value != 'Other') {
                      _bankNameController.text = value ?? '';
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select bank/institution';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              if (_showCustomBank) ...[
                TextFormField(
                  controller: _bankNameController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Bank Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                    hintText: 'e.g., Your Bank Name',
                  ),
                  validator: (value) {
                    if (_showCustomBank && (value == null || value.trim().isEmpty)) {
                      return 'Please enter bank name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Account Number (for FD/RD/PPF/EPF/NPS)
            if (_selectedAssetType == 'fd' || _selectedAssetType == 'rd' || _selectedAssetType == 'ppf' || _selectedAssetType == 'epf' || _selectedAssetType == 'nps') ...[
              TextFormField(
                controller: _accountNumberController,
                decoration: const InputDecoration(
                  labelText: 'Account Number (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number),
                  hintText: 'e.g., XXXX1234',
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Interest Rate (for FD/RD)
            if (_selectedAssetType == 'fd' || _selectedAssetType == 'rd') ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedInterestPreset,
                decoration: const InputDecoration(
                  labelText: 'Interest Rate (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.percent),
                ),
                items: _interestRatePresets.map((rate) {
                  return DropdownMenuItem(value: rate, child: Text(rate));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedInterestPreset = value;
                    _showCustomInterest = value == 'Custom';
                    if (value != 'Custom' && value != null) {
                      _interestRateController.text = value.replaceAll('%', '');
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              if (_showCustomInterest) ...[
                TextFormField(
                  controller: _interestRateController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Interest Rate %',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                    hintText: 'e.g., 7.5',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Tenure (for FD/RD)
            if (_selectedAssetType == 'fd' || _selectedAssetType == 'rd') ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedTenurePreset,
                decoration: const InputDecoration(
                  labelText: 'Tenure (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                items: _tenurePresets.map((tenure) {
                  return DropdownMenuItem(value: tenure, child: Text(tenure));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTenurePreset = value;
                    _showCustomTenure = value == 'Custom';
                    if (value != 'Custom' && value != null) {
                      // Extract number from "12 months (1 year)"
                      final match = RegExp(r'(\d+)').firstMatch(value);
                      if (match != null) {
                        _tenureController.text = match.group(1)!;
                      }
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              if (_showCustomTenure) ...[
                TextFormField(
                  controller: _tenureController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Tenure (months)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                    hintText: 'e.g., 12, 36, 60',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Maturity Date (for FD/RD)
            if (_selectedAssetType == 'fd' || _selectedAssetType == 'rd') ...[
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedMaturityDate ?? DateTime.now().add(Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 3650)),
                  );
                  if (date != null) {
                    setState(() => _selectedMaturityDate = date);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Maturity Date (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event),
                  ),
                  child: Text(
                    _selectedMaturityDate != null
                        ? '${_selectedMaturityDate!.day}/${_selectedMaturityDate!.month}/${_selectedMaturityDate!.year}'
                        : 'Select maturity date',
                    style: TextStyle(
                      color: _selectedMaturityDate != null ? null : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Gold Form (for gold)
            if (_selectedAssetType == 'gold') ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedGoldForm,
                decoration: const InputDecoration(
                  labelText: 'Gold Form',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.diamond),
                ),
                items: [
                  {'value': 'physical', 'label': 'Physical Gold'},
                  {'value': 'digital', 'label': 'Digital Gold'},
                  {'value': 'etf', 'label': 'Gold ETF'},
                ].map((form) {
                  return DropdownMenuItem(
                    value: form['value'],
                    child: Text(form['label']!),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedGoldForm = value),
              ),
              const SizedBox(height: 16),
            ],

            // Weight (for physical/digital gold)
            if (_selectedAssetType == 'gold' && (_selectedGoldForm == 'physical' || _selectedGoldForm == 'digital')) ...[
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Weight (grams) (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale),
                  hintText: 'e.g., 10, 50, 100',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
            ],

            // Purity (for physical gold)
            if (_selectedAssetType == 'gold' && _selectedGoldForm == 'physical') ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedPurity,
                decoration: const InputDecoration(
                  labelText: 'Purity (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.stars),
                ),
                items: ['24K', '22K', '18K', '14K'].map((purity) {
                  return DropdownMenuItem(
                    value: purity,
                    child: Text(purity),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedPurity = value),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 8),

            // Info Card
            Card(
              color: Colors.blue.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Note',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create an asset first, then add transactions (Buy/Sell) to track your investments.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveAsset,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.isEdit ? 'Update Asset' : 'Create Asset',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
