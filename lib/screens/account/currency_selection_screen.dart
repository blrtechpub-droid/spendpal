import 'package:flutter/material.dart';
import 'package:spendpal/services/currency_service.dart';
import 'package:spendpal/theme/app_theme.dart';

class CurrencySelectionScreen extends StatefulWidget {
  const CurrencySelectionScreen({super.key});

  @override
  State<CurrencySelectionScreen> createState() => _CurrencySelectionScreenState();
}

class _CurrencySelectionScreenState extends State<CurrencySelectionScreen> {
  Currency? _selectedCurrency;
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentCurrency();
  }

  Future<void> _loadCurrentCurrency() async {
    final current = await CurrencyService.getSelectedCurrency();
    setState(() {
      _selectedCurrency = current;
      _isLoading = false;
    });
  }

  Future<void> _selectCurrency(Currency currency) async {
    setState(() {
      _selectedCurrency = currency;
    });

    await CurrencyService.setSelectedCurrency(currency);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Currency changed to ${currency.code} (${currency.symbol})'),
          backgroundColor: AppTheme.tealAccent,
          duration: const Duration(seconds: 2),
        ),
      );

      // Pop back to account screen
      Navigator.pop(context, currency);
    }
  }

  List<Currency> get _filteredCurrencies {
    if (_searchQuery.isEmpty) {
      return CurrencyService.popularCurrencies;
    }

    final query = _searchQuery.toLowerCase();
    return CurrencyService.popularCurrencies.where((currency) {
      return currency.code.toLowerCase().contains(query) ||
          currency.name.toLowerCase().contains(query) ||
          currency.symbol.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Currency',
          style: TextStyle(color: AppTheme.primaryText),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.tealAccent),
            )
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    style: const TextStyle(color: AppTheme.primaryText),
                    decoration: AppTheme.inputDecoration(
                      labelText: 'Search currency',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.secondaryText),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),

                // Currency List
                Expanded(
                  child: _filteredCurrencies.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: AppTheme.secondaryText,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No currencies found',
                                style: TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredCurrencies.length,
                          itemBuilder: (context, index) {
                            final currency = _filteredCurrencies[index];
                            final isSelected = _selectedCurrency?.code == currency.code;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.tealAccent.withValues(alpha: 0.2)
                                      : AppTheme.cardBackground,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    currency.symbol,
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: isSelected
                                          ? AppTheme.tealAccent
                                          : AppTheme.primaryText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                currency.name,
                                style: TextStyle(
                                  color: AppTheme.primaryText,
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                '${currency.code} • ${currency.symbol}',
                                style: TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: AppTheme.tealAccent,
                                      size: 24,
                                    )
                                  : null,
                              onTap: () => _selectCurrency(currency),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
