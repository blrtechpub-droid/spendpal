import 'package:cloud_firestore/cloud_firestore.dart';
import 'investment_transaction_service.dart';
import 'package:spendpal/models/investment_asset.dart';

/// Service for parsing SMS messages to detect investment transactions
/// Supports Mutual Funds, Stocks, ETFs, Dividends, SIP, etc.
class InvestmentSmsParserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final InvestmentTransactionService _txnService = InvestmentTransactionService();

  /// Patterns for investment-related SMS from Indian AMCs, brokers, and RTA
  static final Map<String, List<RegExp>> investmentPatterns = {
    'mf_purchase': [
      // Pattern: purchased 10.5 units of Fund Name at NAV Rs.45.23 Amount: Rs.475
      RegExp(
        r'purchased?\s+(\d+(?:\.\d+)?)\s+units?\s+of\s+([A-Za-z\s\-]+?)(?:\(([A-Z0-9]+)\))?\s+at\s+(?:NAV|nav)\s+(?:Rs\.?|INR)\s*(\d+(?:\.\d+)?).{0,50}(?:amount|amt)[\s:]+(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
        caseSensitive: false,
      ),
      // Pattern: Units allotted: 10.5 in Fund Name Folio: 123 NAV: Rs.45.23
      RegExp(
        r'units?\s+allotted[\s:]+(\d+(?:\.\d+)?)\s+(?:in|of)\s+([A-Za-z\s\-]+).*?(?:NAV|nav)[\s:]+(?:Rs\.?|INR)\s*(\d+(?:\.\d+)?)',
        caseSensitive: false,
      ),
    ],
    'sip': [
      // Pattern: SIP of Rs.5000 executed for Fund Name Units: 110.45 NAV: Rs.45.28
      RegExp(
        r'(?:SIP|sip)\s+(?:of\s+)?(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+(?:executed|processed|invested)\s+(?:for|in)\s+([A-Za-z\s\-]+).{0,50}units?[\s:]+(\d+(?:\.\d+)?).{0,30}(?:NAV|nav)[\s:]+(?:Rs\.?|INR)\s*(\d+(?:\.\d+)?)',
        caseSensitive: false,
      ),
      // Pattern: Your SIP investment of Rs.5000 in Fund Name is successful
      RegExp(
        r'(?:your\s+)?(?:SIP|sip)\s+(?:investment|instalment)\s+of\s+(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+(?:in|for)\s+([A-Za-z\s\-]+)\s+(?:is\s+)?(?:successful|completed|executed)',
        caseSensitive: false,
      ),
    ],
    'mf_redemption': [
      // Pattern: redeemed 10.5 units of Fund Name at NAV Rs.45.23 Amount: Rs.475
      RegExp(
        r'redeemed?\s+(\d+(?:\.\d+)?)\s+units?\s+(?:of|from)\s+([A-Za-z\s\-]+).{0,50}(?:NAV|nav)[\s:]+(?:Rs\.?|INR)\s*(\d+(?:\.\d+)?).{0,50}(?:amount|amt)[\s:]+(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
        caseSensitive: false,
      ),
      // Pattern: redemption request of 10.5 units processed for Fund Name
      RegExp(
        r'redemption\s+(?:request|of)\s+(\d+(?:\.\d+)?)\s+units?\s+(?:processed|executed|approved)\s+(?:for|of)\s+([A-Za-z\s\-]+)',
        caseSensitive: false,
      ),
    ],
    'dividend': [
      // Pattern: Dividend of Rs.125.50 credited for Fund Name on 10-Nov-2025
      RegExp(
        r'dividend\s+of\s+(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+(?:credited|paid)\s+(?:for|on)\s+([A-Za-z\s\-]+)',
        caseSensitive: false,
      ),
      // Pattern: Rs.125.50 dividend credit in Fund Name Folio: 123
      RegExp(
        r'(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+dividend\s+(?:credit|credited|received)\s+(?:in|for)\s+([A-Za-z\s\-]+)',
        caseSensitive: false,
      ),
    ],
    'stock_buy': [
      // Pattern: bought 5 shares of RELIANCE at Rs.2450.00 on NSE
      RegExp(
        r'bought\s+(\d+)\s+shares?\s+of\s+([A-Z]+)\s+at\s+(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
        caseSensitive: false,
      ),
      // Pattern: BUY order executed: RELIANCE 5 @ Rs.2450.00
      RegExp(
        r'(?:BUY|buy)\s+order\s+(?:executed|filled)[\s:]+([A-Z]+)\s+(\d+)\s+@\s+(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
        caseSensitive: false,
      ),
    ],
    'stock_sell': [
      // Pattern: sold 5 shares of RELIANCE at Rs.2450.00 on NSE
      RegExp(
        r'sold\s+(\d+)\s+shares?\s+of\s+([A-Z]+)\s+at\s+(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
        caseSensitive: false,
      ),
      // Pattern: SELL order executed: RELIANCE 5 @ Rs.2450.00
      RegExp(
        r'(?:SELL|sell)\s+order\s+(?:executed|filled)[\s:]+([A-Z]+)\s+(\d+)\s+@\s+(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
        caseSensitive: false,
      ),
    ],
    'nav_update': [
      // Pattern: NAV of Fund Name as on 10-Nov-2025: Rs.45.23
      RegExp(
        r'(?:NAV|nav)\s+of\s+([A-Za-z\s\-]+)\s+as\s+on\s+([\d\-\/]+)[\s:]+(?:Rs\.?|INR)\s*(\d+(?:\.\d+)?)',
        caseSensitive: false,
      ),
    ],
    'ppf_deposit': [
      // Pattern: PPF account ... credited with Rs.10000
      RegExp(
        r'PPF\s+(?:account|A\/c).*?credited\s+with\s+(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
        caseSensitive: false,
      ),
      // Pattern: Rs.10000 deposited in your PPF account
      RegExp(
        r'(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+deposited\s+in\s+(?:your\s+)?PPF',
        caseSensitive: false,
      ),
      // Pattern: PPF deposit of Rs.10000 successful
      RegExp(
        r'PPF\s+deposit\s+of\s+(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+(?:successful|completed)',
        caseSensitive: false,
      ),
    ],
    'epf_contribution': [
      // Pattern: EPF contribution of Rs.5000 credited
      RegExp(
        r'EPF\s+(?:contribution|deposit)\s+of\s+(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
        caseSensitive: false,
      ),
      // Pattern: EPFO: Rs.5000 credited to your account
      RegExp(
        r'EPFO.*?(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+credited',
        caseSensitive: false,
      ),
      // Pattern: PF contribution Rs.5000 for month of Nov-2025
      RegExp(
        r'(?:PF|EPF)\s+contribution.*?(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
        caseSensitive: false,
      ),
    ],
    'nps_contribution': [
      // Pattern: NPS contribution of Rs.5000 successful
      RegExp(
        r'NPS\s+(?:contribution|deposit|investment)\s+of\s+(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
        caseSensitive: false,
      ),
      // Pattern: Rs.5000 credited to your NPS account PRAN
      RegExp(
        r'(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+credited\s+to\s+(?:your\s+)?NPS',
        caseSensitive: false,
      ),
      // Pattern: NPS-CRA: Your contribution Rs.5000 has been received
      RegExp(
        r'NPS.*?(?:contribution|deposit).*?(?:Rs\.?|INR)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
        caseSensitive: false,
      ),
    ],
  };

  /// Parse investment SMS and extract transaction details
  static Map<String, dynamic>? parseInvestmentSms(String smsText) {
    // Check for MF purchase
    for (final pattern in investmentPatterns['mf_purchase']!) {
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        try {
          final units = double.parse(match.group(1)!);
          final fundName = match.group(2)!.trim();
          // Try to extract scheme code (if present)
          final schemeCode = match.groupCount >= 3 ? match.group(3) : null;
          final navStr = match.groupCount >= 4 ? match.group(4) : null;
          final amountStr = match.groupCount >= 5 ? match.group(5)?.replaceAll(',', '') : null;

          return {
            'type': 'mf_purchase',
            'assetType': 'mutual_fund',
            'fundName': fundName,
            'schemeCode': schemeCode,
            'units': units,
            'nav': navStr != null ? double.tryParse(navStr) : null,
            'amount': amountStr != null ? double.tryParse(amountStr) : units * (double.tryParse(navStr ?? '0') ?? 0),
            'rawText': smsText,
          };
        } catch (e) {
          continue;
        }
      }
    }

    // Check for SIP
    for (final pattern in investmentPatterns['sip']!) {
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        try {
          final amountStr = match.group(1)!.replaceAll(',', '');
          final amount = double.parse(amountStr);
          final fundName = match.group(2)!.trim();
          final unitsStr = match.groupCount >= 3 ? match.group(3) : null;
          final navStr = match.groupCount >= 4 ? match.group(4) : null;

          return {
            'type': 'sip',
            'assetType': 'mutual_fund',
            'fundName': fundName,
            'amount': amount,
            'units': unitsStr != null ? double.tryParse(unitsStr) : null,
            'nav': navStr != null ? double.tryParse(navStr) : null,
            'rawText': smsText,
          };
        } catch (e) {
          continue;
        }
      }
    }

    // Check for MF redemption
    for (final pattern in investmentPatterns['mf_redemption']!) {
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        try {
          final units = double.parse(match.group(1)!);
          final fundName = match.group(2)!.trim();
          final navStr = match.groupCount >= 3 ? match.group(3) : null;
          final amountStr = match.groupCount >= 4 ? match.group(4)?.replaceAll(',', '') : null;

          return {
            'type': 'mf_redemption',
            'assetType': 'mutual_fund',
            'fundName': fundName,
            'units': units,
            'nav': navStr != null ? double.tryParse(navStr) : null,
            'amount': amountStr != null ? double.tryParse(amountStr) : null,
            'rawText': smsText,
          };
        } catch (e) {
          continue;
        }
      }
    }

    // Check for dividend
    for (final pattern in investmentPatterns['dividend']!) {
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        try {
          final amountStr = match.group(1)!.replaceAll(',', '');
          final amount = double.parse(amountStr);
          final fundName = match.group(2)!.trim();

          return {
            'type': 'dividend',
            'assetType': 'mutual_fund',
            'fundName': fundName,
            'amount': amount,
            'rawText': smsText,
          };
        } catch (e) {
          continue;
        }
      }
    }

    // Check for stock buy
    for (final pattern in investmentPatterns['stock_buy']!) {
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        try {
          // Handle both patterns (different group orders)
          String? symbol;
          String? quantityStr;
          String? priceStr;

          if (match.group(2)!.toUpperCase() == match.group(2)) {
            // Pattern 1: bought 5 shares of RELIANCE
            quantityStr = match.group(1);
            symbol = match.group(2);
            priceStr = match.group(3);
          } else {
            // Pattern 2: BUY order executed: RELIANCE 5
            symbol = match.group(1);
            quantityStr = match.group(2);
            priceStr = match.group(3);
          }

          final quantity = double.parse(quantityStr!);
          final price = double.parse(priceStr!.replaceAll(',', ''));

          return {
            'type': 'stock_buy',
            'assetType': 'equity',
            'symbol': symbol,
            'quantity': quantity,
            'price': price,
            'amount': quantity * price,
            'rawText': smsText,
          };
        } catch (e) {
          continue;
        }
      }
    }

    // Check for stock sell
    for (final pattern in investmentPatterns['stock_sell']!) {
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        try {
          // Handle both patterns (different group orders)
          String? symbol;
          String? quantityStr;
          String? priceStr;

          if (match.group(2)!.toUpperCase() == match.group(2)) {
            // Pattern 1: sold 5 shares of RELIANCE
            quantityStr = match.group(1);
            symbol = match.group(2);
            priceStr = match.group(3);
          } else {
            // Pattern 2: SELL order executed: RELIANCE 5
            symbol = match.group(1);
            quantityStr = match.group(2);
            priceStr = match.group(3);
          }

          final quantity = double.parse(quantityStr!);
          final price = double.parse(priceStr!.replaceAll(',', ''));

          return {
            'type': 'stock_sell',
            'assetType': 'equity',
            'symbol': symbol,
            'quantity': quantity,
            'price': price,
            'amount': quantity * price,
            'rawText': smsText,
          };
        } catch (e) {
          continue;
        }
      }
    }

    // Check for NAV update
    for (final pattern in investmentPatterns['nav_update']!) {
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        try {
          final fundName = match.group(1)!.trim();
          final date = match.group(2);
          final navStr = match.group(3);
          final nav = double.parse(navStr!);

          return {
            'type': 'nav_update',
            'assetType': 'mutual_fund',
            'fundName': fundName,
            'nav': nav,
            'date': date,
            'rawText': smsText,
          };
        } catch (e) {
          continue;
        }
      }
    }

    // Check for PPF deposit
    for (final pattern in investmentPatterns['ppf_deposit']!) {
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        try {
          final amountStr = match.group(1)!.replaceAll(',', '');
          final amount = double.parse(amountStr);

          return {
            'type': 'ppf_deposit',
            'assetType': 'ppf',
            'fundName': 'Public Provident Fund',
            'amount': amount,
            'rawText': smsText,
          };
        } catch (e) {
          continue;
        }
      }
    }

    // Check for EPF contribution
    for (final pattern in investmentPatterns['epf_contribution']!) {
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        try {
          final amountStr = match.group(1)!.replaceAll(',', '');
          final amount = double.parse(amountStr);

          return {
            'type': 'epf_contribution',
            'assetType': 'epf',
            'fundName': 'Employees Provident Fund',
            'amount': amount,
            'rawText': smsText,
          };
        } catch (e) {
          continue;
        }
      }
    }

    // Check for NPS contribution
    for (final pattern in investmentPatterns['nps_contribution']!) {
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        try {
          final amountStr = match.group(1)!.replaceAll(',', '');
          final amount = double.parse(amountStr);

          return {
            'type': 'nps_contribution',
            'assetType': 'nps',
            'fundName': 'National Pension System',
            'amount': amount,
            'rawText': smsText,
          };
        } catch (e) {
          continue;
        }
      }
    }

    return null; // No investment transaction detected
  }

  /// Save parsed investment SMS to Firestore for review
  static Future<String?> saveInvestmentSms({
    required String userId,
    required Map<String, dynamic> parsedData,
    required String smsText,
    required DateTime receivedAt,
  }) async {
    try {
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentSmsQueue')
          .add({
        'userId': userId,
        'type': parsedData['type'],
        'assetType': parsedData['assetType'],
        'fundName': parsedData['fundName'],
        'symbol': parsedData['symbol'],
        'schemeCode': parsedData['schemeCode'],
        'units': parsedData['units'],
        'quantity': parsedData['quantity'],
        'nav': parsedData['nav'],
        'price': parsedData['price'],
        'amount': parsedData['amount'],
        'date': parsedData['date'],
        'rawText': smsText,
        'receivedAt': Timestamp.fromDate(receivedAt),
        'status': 'pending', // pending, approved, rejected, imported
        'createdAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      print('Error saving investment SMS: $e');
      return null;
    }
  }

  /// Convert parsed SMS to investment transaction
  static Future<bool> importToInvestmentTransaction({
    required String userId,
    required String queueId,
    required Map<String, dynamic> parsedData,
    String? assetId, // Optional: link to existing asset
  }) async {
    try {
      final type = parsedData['type'] as String;
      final assetType = parsedData['assetType'] as String;
      final fundName = parsedData['fundName'] as String?;
      final symbol = parsedData['symbol'] as String?;
      final schemeCode = parsedData['schemeCode'] as String?;

      // Determine asset name
      final assetName = fundName ?? symbol ?? 'Unknown';

      // 1. Find or create asset
      String? targetAssetId = assetId;

      if (targetAssetId == null) {
        // Try to find existing asset by name or symbol
        targetAssetId = await _findAssetByNameOrSymbol(
          userId: userId,
          assetType: assetType,
          name: assetName,
          symbol: symbol,
          schemeCode: schemeCode,
        );

        // If not found, create new asset
        if (targetAssetId == null) {
          final asset = await _txnService.createAsset(
            userId: userId,
            assetType: assetType,
            name: assetName,
            symbol: symbol,
            schemeCode: schemeCode,
            tags: ['SMS_AUTO'],
          );

          if (asset == null) {
            print('❌ Failed to create asset for SMS import');
            return false;
          }

          targetAssetId = asset.assetId;
          print('✅ Created new asset: $assetName');
        } else {
          print('✅ Found existing asset: $assetName');
        }
      }

      // 2. Create investment transaction based on type
      final success = await _createTransactionFromSms(
        userId: userId,
        assetId: targetAssetId,
        type: type,
        parsedData: parsedData,
      );

      if (!success) {
        print('❌ Failed to create transaction for SMS import');
        return false;
      }

      // 3. Update queue item status to 'imported'
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentSmsQueue')
          .doc(queueId)
          .update({
        'status': 'imported',
        'importedAt': FieldValue.serverTimestamp(),
        'assetId': targetAssetId,
      });

      print('✅ SMS transaction imported successfully');
      return true;
    } catch (e) {
      print('❌ Error importing SMS transaction: $e');
      return false;
    }
  }

  /// Find existing asset by name or symbol
  static Future<String?> _findAssetByNameOrSymbol({
    required String userId,
    required String assetType,
    required String name,
    String? symbol,
    String? schemeCode,
  }) async {
    try {
      // Try to find by schemeCode first (most accurate)
      if (schemeCode != null && schemeCode.isNotEmpty) {
        final schemeQuery = await _firestore
            .collection('users')
            .doc(userId)
            .collection('investmentAssets')
            .where('schemeCode', isEqualTo: schemeCode)
            .limit(1)
            .get();

        if (schemeQuery.docs.isNotEmpty) {
          return schemeQuery.docs.first.id;
        }
      }

      // Try to find by symbol (for stocks)
      if (symbol != null && symbol.isNotEmpty) {
        final symbolQuery = await _firestore
            .collection('users')
            .doc(userId)
            .collection('investmentAssets')
            .where('symbol', isEqualTo: symbol)
            .where('assetType', isEqualTo: assetType)
            .limit(1)
            .get();

        if (symbolQuery.docs.isNotEmpty) {
          return symbolQuery.docs.first.id;
        }
      }

      // Try to find by name (fuzzy match)
      final nameQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentAssets')
          .where('assetType', isEqualTo: assetType)
          .get();

      for (final doc in nameQuery.docs) {
        final asset = InvestmentAsset.fromFirestore(doc);
        // Simple contains check (can be improved with better fuzzy matching)
        if (asset.name.toLowerCase().contains(name.toLowerCase()) ||
            name.toLowerCase().contains(asset.name.toLowerCase())) {
          return asset.assetId;
        }
      }

      return null;
    } catch (e) {
      print('Error finding asset: $e');
      return null;
    }
  }

  /// Create transaction from parsed SMS data
  static Future<bool> _createTransactionFromSms({
    required String userId,
    required String assetId,
    required String type,
    required Map<String, dynamic> parsedData,
  }) async {
    try {
      final date = DateTime.now(); // Use current date, or parse from SMS if available

      switch (type) {
        case 'mf_purchase':
        case 'stock_buy':
          final units = (parsedData['units'] as num?)?.toDouble() ??
                        (parsedData['quantity'] as num?)?.toDouble() ?? 0.0;
          final price = (parsedData['nav'] as num?)?.toDouble() ??
                        (parsedData['price'] as num?)?.toDouble() ?? 0.0;

          if (units <= 0 || price <= 0) {
            print('❌ Invalid units or price for BUY transaction');
            return false;
          }

          final txn = await _txnService.addBuyTransaction(
            userId: userId,
            assetId: assetId,
            date: date,
            quantity: units,
            price: price,
            source: 'SMS_AUTO',
            notes: 'Auto-imported from SMS',
          );

          return txn != null;

        case 'sip':
          final units = (parsedData['units'] as num?)?.toDouble() ?? 0.0;
          final price = (parsedData['nav'] as num?)?.toDouble() ?? 0.0;

          if (units <= 0 || price <= 0) {
            print('❌ Invalid units or price for SIP transaction');
            return false;
          }

          final txn = await _txnService.addSipTransaction(
            userId: userId,
            assetId: assetId,
            date: date,
            quantity: units,
            price: price,
            source: 'SMS_AUTO',
            notes: 'Auto-imported from SMS',
          );

          return txn != null;

        case 'mf_redemption':
        case 'stock_sell':
          final units = (parsedData['units'] as num?)?.toDouble() ??
                        (parsedData['quantity'] as num?)?.toDouble() ?? 0.0;
          final price = (parsedData['nav'] as num?)?.toDouble() ??
                        (parsedData['price'] as num?)?.toDouble() ?? 0.0;

          if (units <= 0 || price <= 0) {
            print('❌ Invalid units or price for SELL transaction');
            return false;
          }

          final txn = await _txnService.addSellTransaction(
            userId: userId,
            assetId: assetId,
            date: date,
            quantity: units,
            price: price,
            source: 'SMS_AUTO',
            notes: 'Auto-imported from SMS',
          );

          return txn != null;

        case 'dividend':
          final amount = (parsedData['amount'] as num?)?.toDouble() ?? 0.0;

          if (amount <= 0) {
            print('❌ Invalid amount for DIVIDEND transaction');
            return false;
          }

          final txn = await _txnService.addDividendTransaction(
            userId: userId,
            assetId: assetId,
            date: date,
            amount: amount,
            source: 'SMS_AUTO',
            notes: 'Auto-imported from SMS',
          );

          return txn != null;

        case 'ppf_deposit':
        case 'epf_contribution':
        case 'nps_contribution':
          final amount = (parsedData['amount'] as num?)?.toDouble() ?? 0.0;

          if (amount <= 0) {
            print('❌ Invalid amount for PPF/EPF/NPS deposit');
            return false;
          }

          // Treat as a BUY transaction with quantity=1, price=amount
          // This allows tracking cumulative contributions
          final txn = await _txnService.addBuyTransaction(
            userId: userId,
            assetId: assetId,
            date: date,
            quantity: 1.0, // Each contribution is 1 unit
            price: amount, // The amount contributed
            source: 'SMS_AUTO',
            notes: 'Auto-imported from SMS',
          );

          return txn != null;

        case 'nav_update':
          // NAV updates don't create transactions, just informational
          print('ℹ️ NAV update SMS - no transaction created');
          return true;

        default:
          print('❌ Unsupported transaction type: $type');
          return false;
      }
    } catch (e) {
      print('❌ Error creating transaction from SMS: $e');
      return false;
    }
  }

  /// Get pending investment SMS for user review
  static Stream<List<Map<String, dynamic>>> getPendingInvestmentSms({
    required String userId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('investmentSmsQueue')
        .where('status', isEqualTo: 'pending')
        .limit(50)
        .snapshots()
        .map((snapshot) {
      // Sort in memory instead of requiring a composite index
      final docs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by receivedAt descending
      docs.sort((a, b) {
        final aTime = a['receivedAt'] as Timestamp?;
        final bTime = b['receivedAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return docs;
    });
  }

  /// Update SMS queue item status
  static Future<void> updateSmsStatus({
    required String userId,
    required String queueId,
    required String status, // pending, approved, rejected, imported
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('investmentSmsQueue')
        .doc(queueId)
        .update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
