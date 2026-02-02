# Currency Migration Guide

This guide shows how to update screens from hardcoded ₹ symbols to use the dynamic Currency system.

## What's Been Implemented

✅ **CurrencyProvider** - State management for currency across the app
✅ **Currency Helper Utils** - Easy-to-use functions and widgets
✅ **Currency Selector Screen** - User can select from 20 currencies
✅ **Account Screen Integration** - Currency option added to settings
✅ **Main.dart Integration** - Provider added to app root

## Files to Update (237 occurrences across 62 files)

### Helper Functions Available

```dart
// 1. Context Extension (Easiest)
context.currencySymbol  // Returns current symbol (₹, $, €, etc.)
context.formatCurrency(1000.50)  // Returns "₹1,000.50" or "$1,000.50"
context.formatCurrencyCompact(150000)  // Returns "₹1.5L" or "$150K"

// 2. Utility Functions
CurrencyUtils.formatAmount(context, 1000.50)  // Returns formatted amount
CurrencyUtils.formatCompact(context, 150000)  // Returns compact format
CurrencyUtils.getSymbol(context)  // Returns symbol only

// 3. Widgets (Auto-updates when currency changes)
CurrencyText(1000.50)  // Displays formatted amount
CurrencyText(1000.50, compact: true)  // Displays compact amount
CurrencySymbol()  // Displays symbol only
```

## Migration Pattern

### Before (Hardcoded):
```dart
Text('₹${amount.toStringAsFixed(2)}')
```

### After (Dynamic):
```dart
// Option 1: Using context extension (Recommended)
Text(context.formatCurrency(amount))

// Option 2: Using CurrencyText widget
CurrencyText(amount)

// Option 3: Using utility function
Text(CurrencyUtils.formatAmount(context, amount))
```

## Example Screen Updates

### Example 1: Simple Amount Display

**Before:**
```dart
Text(
  '₹${expense.amount.toStringAsFixed(2)}',
  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
)
```

**After:**
```dart
CurrencyText(
  expense.amount,
  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
)
```

### Example 2: Amount with Custom Formatting

**Before:**
```dart
final formattedAmount = '₹${amount.toStringAsFixed(2)}';
Text('Total: $formattedAmount')
```

**After:**
```dart
Text('Total: ${context.formatCurrency(amount)}')
```

### Example 3: Compact Display

**Before:**
```dart
// Custom compact logic
String _formatCompact(double amount) {
  if (amount >= 100000) {
    return '₹${(amount / 100000).toStringAsFixed(1)}L';
  }
  return '₹${amount.toStringAsFixed(0)}';
}
```

**After:**
```dart
// Just use the helper
Text(context.formatCurrencyCompact(amount))
// OR
CurrencyText(amount, compact: true)
```

### Example 4: Symbol Only

**Before:**
```dart
Text('₹')
```

**After:**
```dart
CurrencySymbol()
// OR
Text(context.currencySymbol)
```

### Example 5: Input Field Prefix

**Before:**
```dart
TextField(
  decoration: InputDecoration(
    prefixText: '₹',
    labelText: 'Amount',
  ),
)
```

**After:**
```dart
// Use Consumer to update when currency changes
Consumer<CurrencyProvider>(
  builder: (context, currency, _) {
    return TextField(
      decoration: InputDecoration(
        prefixText: currency.currencySymbol,
        labelText: 'Amount',
      ),
    );
  },
)
```

## Priority Files to Update

### High Priority (Most Visible)
1. **money_tracker_screen.dart** (27 occurrences) - Main balance display
2. **groups_screen.dart** (7 occurrences) - Group expense displays
3. **friends_screen.dart** & **friend_home_screen.dart** (10 occurrences) - Friend balances
4. **expense_screen.dart** & **expense_detail_screen.dart** (10 occurrences) - Expense forms

### Medium Priority
5. **analytics_screen.dart** (6 occurrences) - Charts and graphs
6. **investments_screen.dart** & **asset_detail_screen.dart** (14 occurrences) - Investment displays
7. **budget_screen.dart** (5 occurrences) - Budget displays
8. **processing_stats_screen.dart** & **sms_processing_stats_screen.dart** (6 occurrences) - Cost statistics

### Low Priority (Services & Models)
9. Services and models that store currency data
10. Email/SMS parsers for currency detection

## Step-by-Step Migration Process

### 1. Import the utilities (if needed)
```dart
import 'package:spendpal/utils/currency_utils.dart';
import 'package:provider/provider.dart';
import 'package:spendpal/providers/currency_provider.dart';
```

### 2. Find all ₹ symbols
Search for: `₹` in the file

### 3. Replace based on context

**For simple displays:**
- Replace `Text('₹$amount')` with `CurrencyText(amount)`

**For formatted strings:**
- Replace `'₹${amount.toStringAsFixed(2)}'` with `context.formatCurrency(amount)`

**For compact displays:**
- Replace custom logic with `context.formatCurrencyCompact(amount)` or `CurrencyText(amount, compact: true)`

**For symbol only:**
- Replace `'₹'` with `context.currencySymbol` or `CurrencySymbol()`

### 4. Test the screen
- Change currency in Account → Settings → Currency
- Verify all amounts update correctly
- Check both light and dark themes

## Testing Checklist

- [ ] Build succeeds without errors
- [ ] Currency selector opens from Account screen
- [ ] Can select different currencies
- [ ] All amounts update when currency changes
- [ ] Number formatting is correct (commas, decimals)
- [ ] Compact format uses correct units (L/Cr for INR, K/M for others)
- [ ] Dark mode works correctly
- [ ] No hardcoded ₹ symbols remain

## Common Pitfalls

### ❌ Don't do this:
```dart
// Hardcoded currency in string templates
final total = 'Total: ₹${amount}';

// Using toStringAsFixed directly without formatting
Text('₹${amount.toStringAsFixed(2)}')

// Not handling currency in services
await db.insert({'amount': '₹${amount}'});  // Don't store symbols in DB!
```

### ✅ Do this instead:
```dart
// Use helper functions
final total = 'Total: ${context.formatCurrency(amount)}';

// Use widgets
CurrencyText(amount)

// Store numbers only in DB
await db.insert({'amount': amount});  // Store numeric value only
```

## Number Formatting Differences

### Indian Rupee (INR)
- Uses lakhs and crores: `₹1,00,000` (1 lakh), `₹1,00,00,000` (1 crore)
- Compact: `₹1.5L` (1.5 lakhs), `₹3.2Cr` (3.2 crores)

### Western Currencies (USD, EUR, GBP, etc.)
- Uses thousands and millions: `$100,000`, `$1,000,000`
- Compact: `$150K` (150 thousand), `$3.5M` (3.5 million)

The `CurrencyProvider` automatically handles these differences based on the selected currency!

## Summary

1. ✅ Infrastructure is ready (Provider, Utils, Widgets)
2. ✅ Currency selector is working
3. 🔨 237 occurrences need updating across 62 files
4. 📝 Use the helper functions/widgets provided
5. 🎯 Start with high-priority visible screens
6. ✅ Test after each screen update

The helper functions make migration simple - most replacements are one-liners!
