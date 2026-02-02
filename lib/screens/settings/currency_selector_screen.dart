import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../../services/currency_service.dart';

/// Currency Selector Screen
///
/// Allows users to select their preferred currency
/// Changes apply immediately across the entire app
class CurrencySelectorScreen extends StatefulWidget {
  const CurrencySelectorScreen({super.key});

  @override
  State<CurrencySelectorScreen> createState() => _CurrencySelectorScreenState();
}

class _CurrencySelectorScreenState extends State<CurrencySelectorScreen> {
  String? _selectedCode;

  @override
  void initState() {
    super.initState();
    _selectedCode = context.read<CurrencyProvider>().currencyCode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Select Currency'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Info card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Changes apply immediately to all amounts in the app',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Currency list
          ...CurrencyService.popularCurrencies.map((currency) {
            final isSelected = currency.code == _selectedCode;

            return ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.dividerColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    currency.symbol,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ),
              title: Text(
                currency.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              subtitle: Text(
                '${currency.code} • ${currency.symbol}1,234.56',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                    )
                  : null,
              onTap: () async {
                // Capture context before async gap
                final messenger = ScaffoldMessenger.of(context);

                setState(() {
                  _selectedCode = currency.code;
                });

                // Update currency provider
                await currencyProvider.setCurrency(currency);

                // Show confirmation
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Currency changed to ${currency.name}'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            );
          }),

          const SizedBox(height: 16),

          // Example amounts
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildPreviewRow(
                        context,
                        'Small amount',
                        currencyProvider.formatAmount(123.45),
                      ),
                      const Divider(height: 24),
                      _buildPreviewRow(
                        context,
                        'Medium amount',
                        currencyProvider.formatAmount(12345.67),
                      ),
                      const Divider(height: 24),
                      _buildPreviewRow(
                        context,
                        'Large amount',
                        currencyProvider.formatAmount(1234567.89),
                      ),
                      const Divider(height: 24),
                      _buildPreviewRow(
                        context,
                        'Compact format',
                        currencyProvider.formatCompact(1234567.89),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }
}
