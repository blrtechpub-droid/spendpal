/// Detailed progress tracking for SMS scanning
class SmsScanProgress {
  // Total messages in date range
  final int totalMessages;

  // Messages that passed bank sender filter
  final int filteredBankSms;

  // Messages already processed (duplicates)
  final int alreadyProcessed;

  // New messages to analyze
  final int newToAnalyze;

  // Messages matched by regex patterns
  final int regexMatched;

  // Messages that need AI processing
  final int needsAI;

  // Messages processed by AI so far
  final int aiProcessed;

  // Current message being processed
  final int currentMessage;

  // Transactions found
  final int foundTransactions;

  SmsScanProgress({
    this.totalMessages = 0,
    this.filteredBankSms = 0,
    this.alreadyProcessed = 0,
    this.newToAnalyze = 0,
    this.regexMatched = 0,
    this.needsAI = 0,
    this.aiProcessed = 0,
    this.currentMessage = 0,
    this.foundTransactions = 0,
  });

  SmsScanProgress copyWith({
    int? totalMessages,
    int? filteredBankSms,
    int? alreadyProcessed,
    int? newToAnalyze,
    int? regexMatched,
    int? needsAI,
    int? aiProcessed,
    int? currentMessage,
    int? foundTransactions,
  }) {
    return SmsScanProgress(
      totalMessages: totalMessages ?? this.totalMessages,
      filteredBankSms: filteredBankSms ?? this.filteredBankSms,
      alreadyProcessed: alreadyProcessed ?? this.alreadyProcessed,
      newToAnalyze: newToAnalyze ?? this.newToAnalyze,
      regexMatched: regexMatched ?? this.regexMatched,
      needsAI: needsAI ?? this.needsAI,
      aiProcessed: aiProcessed ?? this.aiProcessed,
      currentMessage: currentMessage ?? this.currentMessage,
      foundTransactions: foundTransactions ?? this.foundTransactions,
    );
  }

  /// Get messages that were skipped (non-bank)
  int get skippedNonBank => totalMessages - filteredBankSms;

  /// Get percentage progress
  double get progressPercentage {
    if (newToAnalyze == 0) return 0.0;
    return currentMessage / newToAnalyze;
  }
}
