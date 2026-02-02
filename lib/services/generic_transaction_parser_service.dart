import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/local_transaction_model.dart';
import '../models/local_pattern_model.dart';
import 'local_db_service.dart';
import 'encryption_service.dart';
import 'tracker_matching_service.dart';

/// Generic transaction parser service
///
/// REUSABLE for SMS, Email, and any text-based transactions
/// Privacy-First: Saves all data to local SQLite, never to Firebase
///
/// Flow:
/// 1. Text (SMS/Email) → Cloud Function (temporary)
/// 2. AI parses and returns data
/// 3. Save to local SQLite (encrypted)
/// 4. Cloud Function forgets everything
class GenericTransactionParserService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final LocalDBService _localDB = LocalDBService.instance;

  /// Parse multiple transactions in bulk using AI with INCREMENTAL LEARNING
  ///
  /// UNIVERSAL: Works for SMS, Email, or any text source
  /// OPTIMIZED: Re-checks patterns after each AI batch to reduce costs
  ///
  /// Returns list of saved transactions
  static Future<List<LocalTransactionModel>> parseBulkTransactions({
    required List<BulkTransactionItem> items,
    required String userId,
    String? deviceId,
    Function(int processedCount)? onProgress,
  }) async {
    if (items.isEmpty) {
      print('⚠️ No items to parse');
      return [];
    }

    print('🚀 Parsing ${items.length} transactions (${items.first.source.name} source)');

    try {
      // Ensure encryption is initialized
      if (!EncryptionService.isInitialized) {
        await EncryptionService.initialize();
      }

      final parsedTransactions = <LocalTransactionModel>[];
      var itemsNeedingAI = <BulkTransactionItem>[];

      // Step 0: Filter out OTP and informational messages
      print('🔍 Filtering OTP and informational messages...');
      final validItems = items.where((item) => !_isOtpOrInfoMessage(item.text)).toList();
      final filteredCount = items.length - validItems.length;
      if (filteredCount > 0) {
        print('⚠️ Filtered out $filteredCount OTP/info messages');
      }

      // Step 1: Try pattern matching first (faster, no AI cost)
      print('🔍 Trying pattern matching (initial)...');
      int initialPatternMatched = 0;
      for (final item in validItems) {
        final matched = await _tryPatternMatch(
          item: item,
          userId: userId,
          deviceId: deviceId,
        );

        if (matched != null) {
          parsedTransactions.add(matched);
          initialPatternMatched++;
          if (onProgress != null) {
            onProgress(parsedTransactions.length);
          }
        } else {
          itemsNeedingAI.add(item);
        }
      }

      print('✅ Initial pattern matched: $initialPatternMatched/${validItems.length}');

      // Step 2: INCREMENTAL LEARNING - Process AI items in batches and re-check patterns
      if (itemsNeedingAI.isEmpty) {
        print('✅ All transactions matched by patterns!');
      } else {
        print('🧠 INCREMENTAL LEARNING MODE: Processing ${itemsNeedingAI.length} items');

        const batchSize = 50; // Process 50 items at a time
        int totalAIProcessed = 0;
        int totalLearnedPatterns = 0;
        int batchNumber = 0;

        while (itemsNeedingAI.isNotEmpty) {
          batchNumber++;

          // Take next batch
          final currentBatch = itemsNeedingAI.take(batchSize).toList();
          print('\n📦 Batch $batchNumber: Processing ${currentBatch.length} items...');

          // Match trackers for this batch
          final trackerMatches = await TrackerMatchingService.matchBatch(
            userId: userId,
            items: currentBatch,
          );

          // Prepare batch data for Cloud Function
          final batchData = currentBatch.map((item) => {
            'smsText': item.text,
            'sender': item.sender,
            'date': item.date.toIso8601String(),
            'index': item.index,
          }).toList();

          // Call Cloud Function
          final callable = _functions.httpsCallable('parseBulkSmsWithAI');
          final result = await callable.call({
            'smsMessages': batchData,
          });

          totalAIProcessed += currentBatch.length;
          print('✅ Batch $batchNumber: AI response received');

        // Parse results
        if (result.data['success'] != true || result.data['results'] == null) {
          print('❌ Bulk AI parsing failed');
        } else {
          final results = result.data['results'] as List<dynamic>;

          // Process each result
          for (var i = 0; i < results.length; i++) {
            try {
              // Fix: Use Map.from() for proper type conversion
              final resultItem = results[i];
              if (resultItem == null) {
                print('⚠️ Result #$i is null, skipping');
                continue;
              }

              final resultData = Map<String, dynamic>.from(resultItem as Map);
              final index = resultData['index'] as int;
              final originalItem = itemsNeedingAI.firstWhere((item) => item.index == index);

              // Update progress
              if (onProgress != null) {
                onProgress(parsedTransactions.length + 1);
              }

          // Check if parsing succeeded
          if (resultData['success'] != true || resultData['data'] == null) {
            print('⚠️ Transaction #$index failed to parse');
            continue;
          }

          // Extract parsed data
          final dataMap = resultData['data'];
          if (dataMap == null) {
            print('⚠️ Transaction #$index has null data');
            continue;
          }
          final data = Map<String, dynamic>.from(dataMap as Map);

          // Only process debit transactions (expenses) for now
          // TODO: Add support for credit transactions (investments)
          if (data['isDebit'] == false) {
            print('ℹ️ Transaction #$index: Skipping credit transaction');
            continue;
          }

          // Check for duplicate by transaction ID
          if (data['transactionId'] != null && data['transactionId'].isNotEmpty) {
            final isDuplicate = await _localDB.isDuplicate(
              userId: userId,
              transactionId: data['transactionId'] as String,
            );

            if (isDuplicate) {
              print('⚠️ Duplicate transaction ID detected, skipping');
              continue;
            }
          } else {
            // No transaction ID - check by merchant, amount, and date
            final isDuplicate = await _localDB.isDuplicateByDetails(
              userId: userId,
              merchant: data['merchant'] as String,
              amount: (data['amount'] as num).toDouble(),
              transactionDate: DateTime.parse(data['date']),
            );

            if (isDuplicate) {
              print('⚠️ Duplicate transaction (merchant/amount/date) detected, skipping');
              continue;
            }
          }

          // Get matched tracker for this transaction
          final trackerMatch = trackerMatches[index];
          final trackerId = trackerMatch?.trackerId;
          final trackerConfidence = trackerMatch?.confidence;

          if (trackerId != null) {
            print('✅ Transaction #$index matched to tracker $trackerId (confidence: ${(trackerConfidence! * 100).toStringAsFixed(0)}%)');
          }

          // Create local transaction model
          final transaction = LocalTransactionModel(
            id: const Uuid().v4(),
            source: originalItem.source,
            sourceIdentifier: originalItem.sender,
            trackerId: trackerId,
            trackerConfidence: trackerConfidence,
            amount: (data['amount'] as num).toDouble(),
            merchant: data['merchant'] as String,
            category: data['category'] as String,
            transactionDate: DateTime.parse(data['date']),
            transactionId: data['transactionId'] as String?,
            accountInfo: data['accountInfo'] as String?,
            rawContent: originalItem.text, // Will be encrypted by DB service
            status: TransactionStatus.pending,
            isDebit: true,
            userId: userId,
            deviceId: deviceId,
            parsedBy: ParseMethod.ai,
            confidence: 0.95, // AI parsing confidence
          );

          parsedTransactions.add(transaction);

          // Save regex pattern if generated (for future fast parsing)
          if (resultData['regexPattern'] != null) {
            try {
              final patternData = Map<String, dynamic>.from(resultData['regexPattern'] as Map);

              // Hash sender for privacy
              final senderHash = _hashSender(originalItem.sender);

              // Create pattern model
              final localPattern = LocalPatternModel(
                id: const Uuid().v4(),
                senderHash: senderHash,
                source: originalItem.source,
                pattern: patternData['pattern'] as String? ?? '',
                extractionMap: Map<String, dynamic>.from(patternData['extractionMap'] as Map? ?? {}),
                category: data['category'] as String,
                isDebit: true,
                sampleText: originalItem.text,
                description: 'AI-generated pattern for ${data['merchant']}',
                accuracy: 100.0, // Start with 100% (first successful match)
                matchCount: 1, // This is the first match
                failCount: 0,
                lastMatchDate: DateTime.now(),
                userId: userId,
                isActive: true,
              );

              // Save to local database IMMEDIATELY
              await _localDB.insertPattern(localPattern);
              totalLearnedPatterns++;
              print('✅ Pattern saved: ${originalItem.sender}');
            } catch (e) {
              print('⚠️ Error saving pattern: $e');
            }
          }

            } catch (e) {
              print('⚠️ Error processing transaction #$i: $e');
              continue;
            }
          }
        }

        // Remove processed batch from queue
        itemsNeedingAI = itemsNeedingAI.skip(currentBatch.length).toList();

        // INCREMENTAL LEARNING: Re-check remaining items against newly learned patterns
        if (itemsNeedingAI.isNotEmpty && totalLearnedPatterns > 0) {
          print('\n🔄 Re-checking ${itemsNeedingAI.length} remaining items against ${totalLearnedPatterns} new patterns...');

          final newlyMatched = <LocalTransactionModel>[];
          final stillUnmatched = <BulkTransactionItem>[];

          for (final item in itemsNeedingAI) {
            final matched = await _tryPatternMatch(
              item: item,
              userId: userId,
              deviceId: deviceId,
            );

            if (matched != null) {
              newlyMatched.add(matched);
              if (onProgress != null) {
                onProgress(parsedTransactions.length + newlyMatched.length);
              }
            } else {
              stillUnmatched.add(item);
            }
          }

          if (newlyMatched.isNotEmpty) {
            parsedTransactions.addAll(newlyMatched);
            print('✅ Incremental learning: ${newlyMatched.length} items matched with new patterns!');
            print('💰 AI cost saved: ₹${(newlyMatched.length * 0.13).toStringAsFixed(2)}');
          }

          itemsNeedingAI = stillUnmatched;
          print('📊 Remaining for AI: ${itemsNeedingAI.length}');
        }
      }

      // Summary
      print('\n🎯 INCREMENTAL LEARNING SUMMARY:');
      print('   Total batches: $batchNumber');
      print('   Items sent to AI: $totalAIProcessed');
      print('   New patterns learned: $totalLearnedPatterns');
      print('   Final unmatched: ${itemsNeedingAI.length}');
      }

      // Save all transactions to local SQLite in batch (faster)
      if (parsedTransactions.isNotEmpty) {
        print('💾 Saving ${parsedTransactions.length} transactions to local database...');
        final savedCount = await _localDB.insertBatch(parsedTransactions);
        print('✅ Saved $savedCount/${parsedTransactions.length} transactions locally');
      }

      print('✅ Bulk processing complete!');
      print('   Total SMS: ${items.length}');
      print('   Filtered (OTP/Info): $filteredCount');
      print('   Parsed: ${parsedTransactions.length}/${validItems.length}');
      print('   Source: ${items.first.source.name}');
      print('   Storage: Local SQLite (encrypted)');

      return parsedTransactions;
    } catch (e) {
      print('❌ Error in bulk transaction parsing: $e');
      return [];
    }
  }

  /// Parse single transaction (wrapper around bulk for convenience)
  static Future<LocalTransactionModel?> parseTransaction({
    required String text,
    required String sender,
    required DateTime date,
    required TransactionSource source,
    required String userId,
    String? deviceId,
  }) async {
    final items = [
      BulkTransactionItem(
        index: 0,
        text: text,
        sender: sender,
        date: date,
        source: source,
      ),
    ];

    final results = await parseBulkTransactions(
      items: items,
      userId: userId,
      deviceId: deviceId,
    );

    return results.isNotEmpty ? results.first : null;
  }

  /// Get transaction statistics
  static Future<Map<String, dynamic>> getStatistics({
    required String userId,
    TransactionSource? source,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final transactions = await _localDB.getTransactions(
        userId: userId,
        source: source,
        startDate: startDate,
        endDate: endDate,
        status: TransactionStatus.confirmed,
      );

      final totalAmount = transactions.fold<double>(
        0,
        (sum, t) => sum + (t.isDebit ? t.amount : 0),
      );

      final categoryTotals = await _localDB.getCategoryTotals(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );

      return {
        'totalTransactions': transactions.length,
        'totalAmount': totalAmount,
        'categoryTotals': categoryTotals,
        'averageAmount': transactions.isEmpty ? 0 : totalAmount / transactions.length,
      };
    } catch (e) {
      print('❌ Error getting statistics: $e');
      return {};
    }
  }

  /// Export transactions for backup
  static Future<List<Map<String, dynamic>>> exportTransactions({
    required String userId,
    TransactionSource? source,
  }) async {
    try {
      return await _localDB.exportTransactions(userId: userId);
    } catch (e) {
      print('❌ Error exporting transactions: $e');
      return [];
    }
  }

  /// Import transactions from backup
  static Future<int> importTransactions({
    required List<Map<String, dynamic>> data,
    required String userId,
  }) async {
    try {
      final transactions = data.map((map) {
        map['user_id'] = userId; // Override user ID
        return LocalTransactionModel.fromMap(map);
      }).toList();

      return await _localDB.insertBatch(transactions);
    } catch (e) {
      print('❌ Error importing transactions: $e');
      return 0;
    }
  }

  /// Check if SMS is OTP or informational (not a transaction)
  static bool _isOtpOrInfoMessage(String text) {
    final lowerText = text.toLowerCase();

    // OTP keywords
    final otpKeywords = [
      'otp is',
      'otp for',
      'one time password',
      'one-time password',
      'verification code',
      'valid till',
      'do not share otp',
      'for txn of',  // "for transaction of" indicates pending
    ];

    // Informational keywords (not actual debits)
    final infoKeywords = [
      'available balance',
      'avl bal',
      'credit limit',
      'minimum due',
      'statement generated',
      'payment due',
      'reward points',
      'cashback credited',
      'autopay',
    ];

    // Check for OTP patterns
    for (final keyword in otpKeywords) {
      if (lowerText.contains(keyword)) {
        return true; // Skip OTP messages
      }
    }

    // Check for informational patterns
    for (final keyword in infoKeywords) {
      if (lowerText.contains(keyword)) {
        // Only skip if it doesn't also contain debit keywords
        if (!lowerText.contains('debited') &&
            !lowerText.contains('spent') &&
            !lowerText.contains('withdrawn')) {
          return true; // Skip info-only messages
        }
      }
    }

    return false; // Valid transaction message
  }

  /// Hash sender name for privacy (SHA-256)
  static String _hashSender(String sender) {
    final bytes = utf8.encode(sender);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Try to match transaction using existing patterns
  /// Returns parsed transaction if successful, null otherwise
  static Future<LocalTransactionModel?> _tryPatternMatch({
    required BulkTransactionItem item,
    required String userId,
    String? deviceId,
  }) async {
    try {
      // Get patterns for this sender
      final senderHash = _hashSender(item.sender);
      final patterns = await _localDB.getPatternsBySender(
        userId: userId,
        senderHash: senderHash,
        source: item.source,
      );

      if (patterns.isEmpty) {
        return null; // No patterns available
      }

      // Try each pattern in order of accuracy
      for (final pattern in patterns) {
        try {
          final regex = RegExp(pattern.pattern);
          final match = regex.firstMatch(item.text);

          if (match != null) {
            // Extract data using extraction map
            final amount = _extractField(match, pattern.extractionMap['amount']);
            final merchant = _extractField(match, pattern.extractionMap['merchant']);
            final dateStr = _extractField(match, pattern.extractionMap['date']);

            if (amount == null || merchant == null) {
              // Pattern matched but couldn't extract required fields
              await _localDB.incrementPatternFail(pattern.id);
              continue;
            }

            // Parse amount
            final parsedAmount = double.tryParse(amount.replaceAll(',', ''));
            if (parsedAmount == null) {
              await _localDB.incrementPatternFail(pattern.id);
              continue;
            }

            // Parse date (use item date if extraction fails)
            DateTime transactionDate = item.date;
            if (dateStr != null) {
              try {
                transactionDate = DateTime.parse(dateStr);
              } catch (_) {
                // Keep item date if parsing fails
              }
            }

            // Extract optional fields
            final transactionId = _extractField(match, pattern.extractionMap['transactionId']);
            final accountInfo = _extractField(match, pattern.extractionMap['accountInfo']);

            // Pattern matched successfully!
            await _localDB.incrementPatternMatch(pattern.id);

            // Match tracker for this transaction
            final trackerMatch = await TrackerMatchingService.matchTransaction(
              userId: userId,
              source: item.source,
              sender: item.sender,
            );

            // Create transaction model
            final transaction = LocalTransactionModel(
              id: const Uuid().v4(),
              source: item.source,
              sourceIdentifier: item.sender,
              trackerId: trackerMatch?.trackerId,
              trackerConfidence: trackerMatch?.confidence,
              amount: parsedAmount,
              merchant: merchant,
              category: pattern.category,
              transactionDate: transactionDate,
              transactionId: transactionId,
              accountInfo: accountInfo,
              rawContent: item.text,
              status: TransactionStatus.pending,
              isDebit: pattern.isDebit,
              userId: userId,
              deviceId: deviceId,
              parsedBy: ParseMethod.regex,
              patternId: pattern.id,
              confidence: pattern.accuracy / 100, // Convert percentage to 0-1
            );

            if (trackerMatch != null) {
              print('✅ Pattern match: ${pattern.senderHash} (${pattern.accuracy}%) + Tracker: ${trackerMatch.trackerId} (${(trackerMatch.confidence * 100).toStringAsFixed(0)}%)');
            } else {
              print('✅ Pattern match: ${pattern.senderHash} (${pattern.accuracy}%)');
            }
            return transaction;
          }
        } catch (e) {
          print('⚠️ Error matching pattern ${pattern.id}: $e');
          await _localDB.incrementPatternFail(pattern.id);
          continue;
        }
      }

      return null; // No pattern matched
    } catch (e) {
      print('❌ Error in pattern matching: $e');
      return null;
    }
  }

  /// Extract field from regex match using extraction map
  static String? _extractField(RegExpMatch match, dynamic fieldInfo) {
    if (fieldInfo == null) return null;

    try {
      // fieldInfo could be "group1", "group2", etc.
      final groupStr = fieldInfo.toString().replaceAll('group', '');
      final groupNum = int.tryParse(groupStr);

      if (groupNum != null && groupNum <= match.groupCount) {
        return match.group(groupNum)?.trim();
      }
    } catch (e) {
      print('⚠️ Error extracting field: $e');
    }

    return null;
  }
}
