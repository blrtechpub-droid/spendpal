import 'package:flutter/material.dart';
import '../models/account_tracker_model.dart';

/// Template for creating account trackers
class TrackerTemplate {
  final String name;
  final TrackerType type;
  final TrackerCategory category;
  final List<String> emailDomains;
  final List<String> smsSenders; // SMS sender IDs for filtering SMS (e.g., 'VM-HDFCBK', 'PAYTM')
  final String emoji; // Emoji icon for display
  final String colorHex; // Brand color
  final List<String> keywords; // Keywords for better email filtering

  const TrackerTemplate({
    required this.name,
    required this.type,
    required this.category,
    required this.emailDomains,
    this.smsSenders = const [],
    required this.emoji,
    required this.colorHex,
    this.keywords = const [],
  });

  /// Get color from hex
  Color get color => Color(int.parse('0xFF${colorHex.replaceAll('#', '')}'));
}

/// Registry of predefined tracker templates
///
/// This makes it easy for users to add common trackers without manual configuration
class TrackerRegistry {
  /// Get all available tracker templates
  static const Map<TrackerCategory, TrackerTemplate> templates = {
    // ========== BANKING ==========
    TrackerCategory.hdfcBank: TrackerTemplate(
      name: 'HDFC Bank',
      type: TrackerType.banking,
      category: TrackerCategory.hdfcBank,
      emailDomains: ['hdfcbank.com', 'hdfcbank.net'],
      smsSenders: ['VM-HDFCBK', 'AD-HDFCBK', 'AX-HDFCBK', 'BK-HDFCBK', 'TX-HDFCBK', 'HDFCBK', 'HDFC'],
      emoji: '🏦',
      colorHex: '004C8F',
      keywords: ['debited', 'credited', 'transaction', 'INR'],
    ),

    TrackerCategory.iciciBank: TrackerTemplate(
      name: 'ICICI Bank',
      type: TrackerType.banking,
      category: TrackerCategory.iciciBank,
      emailDomains: ['icicibank.com'],
      smsSenders: ['VM-ICICIB', 'AD-ICICIB', 'AX-ICICIB', 'ICICIB', 'ICICI'],
      emoji: '🏦',
      colorHex: 'FF6B00',
      keywords: ['debited', 'credited', 'txn', 'Rs.'],
    ),

    TrackerCategory.sbiBank: TrackerTemplate(
      name: 'SBI Bank',
      type: TrackerType.banking,
      category: TrackerCategory.sbiBank,
      emailDomains: ['sbi.co.in', 'onlinesbi.com'],
      smsSenders: ['VM-SBIINB', 'AD-SBIINB', 'SBI', 'SBIINB', 'SBMSMS'],
      emoji: '🏦',
      colorHex: '22409A',
      keywords: ['debited', 'credited', 'transaction'],
    ),

    TrackerCategory.axisBank: TrackerTemplate(
      name: 'Axis Bank',
      type: TrackerType.banking,
      category: TrackerCategory.axisBank,
      emailDomains: ['axisbank.com'],
      smsSenders: ['VM-AXISBK', 'AD-AXISBK', 'AXISBK', 'AXIS'],
      emoji: '🏦',
      colorHex: '97144D',
      keywords: ['debited', 'credited', 'INR'],
    ),

    TrackerCategory.kotakBank: TrackerTemplate(
      name: 'Kotak Mahindra Bank',
      type: TrackerType.banking,
      category: TrackerCategory.kotakBank,
      emailDomains: ['kotak.com'],
      smsSenders: ['VM-KOTAKB', 'AD-KOTAKB', 'KOTAK', 'KOTAKB'],
      emoji: '🏦',
      colorHex: 'ED232A',
      keywords: ['debited', 'credited', 'transaction'],
    ),

    TrackerCategory.yesBankIndia: TrackerTemplate(
      name: 'Yes Bank',
      type: TrackerType.banking,
      category: TrackerCategory.yesBankIndia,
      emailDomains: ['yesbank.in'],
      smsSenders: ['VM-YESBK', 'YESBK', 'YESBNK'],
      emoji: '🏦',
      colorHex: '0066B2',
      keywords: ['debited', 'credited'],
    ),

    TrackerCategory.indusIndBank: TrackerTemplate(
      name: 'IndusInd Bank',
      type: TrackerType.banking,
      category: TrackerCategory.indusIndBank,
      emailDomains: ['indusind.com'],
      smsSenders: ['VM-INDUSB', 'INDUSB', 'INDIND'],
      emoji: '🏦',
      colorHex: '005EB8',
      keywords: ['debited', 'credited'],
    ),

    TrackerCategory.pnbBank: TrackerTemplate(
      name: 'Punjab National Bank',
      type: TrackerType.banking,
      category: TrackerCategory.pnbBank,
      emailDomains: ['pnbindia.in'],
      smsSenders: ['VM-PNBSMS', 'PNBSMS', 'PNB'],
      emoji: '🏦',
      colorHex: '4B0082',
      keywords: ['debited', 'credited'],
    ),

    TrackerCategory.standardChartered: TrackerTemplate(
      name: 'Standard Chartered',
      type: TrackerType.banking,
      category: TrackerCategory.standardChartered,
      emailDomains: ['sc.com', 'standardchartered.com'],
      smsSenders: ['VM-SCBANK', 'SCBANK', 'SCBL'],
      emoji: '🏦',
      colorHex: '0072C6',
      keywords: ['debited', 'credited'],
    ),

    // ========== INVESTMENTS ==========
    TrackerCategory.zerodha: TrackerTemplate(
      name: 'Zerodha',
      type: TrackerType.investment,
      category: TrackerCategory.zerodha,
      emailDomains: ['zerodha.com'],
      emoji: '📈',
      colorHex: '387ED1',
      keywords: ['purchased', 'sold', 'order executed', 'stock', 'shares'],
    ),

    TrackerCategory.groww: TrackerTemplate(
      name: 'Groww',
      type: TrackerType.investment,
      category: TrackerCategory.groww,
      emailDomains: ['groww.in'],
      emoji: '📈',
      colorHex: '00D09C',
      keywords: ['SIP', 'mutual fund', 'invested', 'purchased'],
    ),

    TrackerCategory.angelOne: TrackerTemplate(
      name: 'Angel One',
      type: TrackerType.investment,
      category: TrackerCategory.angelOne,
      emailDomains: ['angelbroking.com', 'angelone.in'],
      emoji: '📈',
      colorHex: 'E31E24',
      keywords: ['order executed', 'purchased', 'sold'],
    ),

    TrackerCategory.upstox: TrackerTemplate(
      name: 'Upstox',
      type: TrackerType.investment,
      category: TrackerCategory.upstox,
      emailDomains: ['upstox.com'],
      emoji: '📈',
      colorHex: '6C5CE7',
      keywords: ['order', 'purchased', 'sold', 'stock'],
    ),

    TrackerCategory.paisa5: TrackerTemplate(
      name: '5Paisa',
      type: TrackerType.investment,
      category: TrackerCategory.paisa5,
      emailDomains: ['5paisa.com'],
      emoji: '📈',
      colorHex: 'FF6B35',
      keywords: ['order', 'buy', 'sell'],
    ),

    // ========== GOVERNMENT SCHEMES ==========
    TrackerCategory.nps: TrackerTemplate(
      name: 'National Pension System (NPS)',
      type: TrackerType.governmentScheme,
      category: TrackerCategory.nps,
      emailDomains: ['npscan.com', 'npstrust.org.in'],
      emoji: '💰',
      colorHex: '1B5E20',
      keywords: ['contribution', 'PRAN', 'NPS', 'tier'],
    ),

    TrackerCategory.ppf: TrackerTemplate(
      name: 'Public Provident Fund (PPF)',
      type: TrackerType.governmentScheme,
      category: TrackerCategory.ppf,
      emailDomains: ['sbi.co.in', 'pnbindia.in', 'icicibank.com'], // Bank-specific
      emoji: '💰',
      colorHex: 'FF9800',
      keywords: ['PPF', 'Public Provident Fund', 'deposited'],
    ),

    TrackerCategory.epf: TrackerTemplate(
      name: 'Employees Provident Fund (EPF)',
      type: TrackerType.governmentScheme,
      category: TrackerCategory.epf,
      emailDomains: ['epfindia.gov.in', 'epfoservices.in'],
      emoji: '💰',
      colorHex: '2E7D32',
      keywords: ['EPF', 'PF', 'provident fund', 'contribution'],
    ),

    // ========== DIGITAL WALLETS ==========
    TrackerCategory.paytm: TrackerTemplate(
      name: 'Paytm',
      type: TrackerType.digitalWallet,
      category: TrackerCategory.paytm,
      emailDomains: ['paytm.com'],
      smsSenders: ['PAYTMB', 'PAYTMP', 'PYTMPB', 'PAYTM'],
      emoji: '📱',
      colorHex: '00B9F5',
      keywords: ['paid', 'received', 'wallet'],
    ),

    TrackerCategory.phonePe: TrackerTemplate(
      name: 'PhonePe',
      type: TrackerType.digitalWallet,
      category: TrackerCategory.phonePe,
      emailDomains: ['phonepe.com'],
      smsSenders: ['PHONEPE', 'PHNPE', 'VM-PHNPE'],
      emoji: '📱',
      colorHex: '5F259F',
      keywords: ['sent', 'received', 'UPI'],
    ),

    TrackerCategory.googlePay: TrackerTemplate(
      name: 'Google Pay',
      type: TrackerType.digitalWallet,
      category: TrackerCategory.googlePay,
      emailDomains: ['google.com', 'googlepay.com'],
      smsSenders: ['GOOGLEPAY', 'GPAY', 'VM-GPAY', 'BHIMUPI'],
      emoji: '📱',
      colorHex: '4285F4',
      keywords: ['sent', 'received', 'UPI', 'Google Pay'],
    ),

    TrackerCategory.amazonPay: TrackerTemplate(
      name: 'Amazon Pay',
      type: TrackerType.digitalWallet,
      category: TrackerCategory.amazonPay,
      emailDomains: ['amazon.in', 'amazon.com'],
      smsSenders: ['AMAZON', 'AMZPAY', 'VM-AMAZON'],
      emoji: '📱',
      colorHex: 'FF9900',
      keywords: ['Amazon Pay', 'paid', 'wallet'],
    ),
  };

  /// Get template by category
  static TrackerTemplate? getTemplate(TrackerCategory category) {
    return templates[category];
  }

  /// Get all templates for a specific type
  static List<TrackerTemplate> getTemplatesByType(TrackerType type) {
    return templates.values.where((t) => t.type == type).toList();
  }

  /// Get all templates grouped by type
  static Map<TrackerType, List<TrackerTemplate>> getGroupedTemplates() {
    final grouped = <TrackerType, List<TrackerTemplate>>{};

    for (final type in TrackerType.values) {
      grouped[type] = getTemplatesByType(type);
    }

    return grouped;
  }

  /// Search templates by name
  static List<TrackerTemplate> searchTemplates(String query) {
    if (query.isEmpty) return templates.values.toList();

    final lowerQuery = query.toLowerCase();
    return templates.values
        .where((t) => t.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Get popular trackers (most commonly used)
  static List<TrackerTemplate> getPopularTrackers() {
    return [
      templates[TrackerCategory.hdfcBank]!,
      templates[TrackerCategory.iciciBank]!,
      templates[TrackerCategory.sbiBank]!,
      templates[TrackerCategory.zerodha]!,
      templates[TrackerCategory.groww]!,
      templates[TrackerCategory.nps]!,
      templates[TrackerCategory.googlePay]!,
      templates[TrackerCategory.paytm]!,
    ];
  }

  /// Get SMS senders for a specific tracker category
  /// Returns empty list if category not found or has no SMS senders
  static List<String> getSmsSendersForCategory(TrackerCategory category) {
    final template = templates[category];
    return template?.smsSenders ?? [];
  }

  /// Match SMS sender against tracker category
  /// Returns true if the sender matches any of the category's SMS senders
  /// Normalizes both sender and template by removing special characters
  /// Example: "CP-AXISBK-S" matches "AXISBK" (both become "CPAXISBKS" and "AXISBK")
  static bool matchesSmsSender(TrackerCategory category, String sender) {
    final smsSenders = getSmsSendersForCategory(category);
    if (smsSenders.isEmpty) return false;

    final normalizedSender = sender.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    return smsSenders.any((smsSender) {
      final normalizedTemplate = smsSender.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      return normalizedSender.contains(normalizedTemplate);
    });
  }

  /// Get email domains for a specific tracker category
  /// Returns empty list if category not found or has no email domains
  static List<String> getEmailDomainsForCategory(TrackerCategory category) {
    final template = templates[category];
    return template?.emailDomains ?? [];
  }

  /// Match email sender against tracker category
  /// Returns true if the email domain matches any of the category's email domains
  /// Example: noreply@hdfcbank.com matches HDFC Bank
  static bool matchesEmailDomain(TrackerCategory category, String emailAddress) {
    final emailDomains = getEmailDomainsForCategory(category);
    if (emailDomains.isEmpty) return false;

    // Extract domain from email address (everything after @)
    final atIndex = emailAddress.indexOf('@');
    if (atIndex == -1) return false;

    final domain = emailAddress.substring(atIndex + 1).toLowerCase();

    // Check if domain matches or is a subdomain of any tracker domain
    return emailDomains.any((trackerDomain) {
      final normalizedTrackerDomain = trackerDomain.toLowerCase();
      return domain == normalizedTrackerDomain ||
             domain.endsWith('.$normalizedTrackerDomain');
    });
  }

  /// Find all matching tracker categories for an SMS sender
  /// Returns list of categories that match the sender
  static List<TrackerCategory> findMatchingCategoriesForSms(String sender) {
    return TrackerCategory.values
        .where((category) => matchesSmsSender(category, sender))
        .toList();
  }

  /// Find all matching tracker categories for an email sender
  /// Returns list of categories that match the email domain
  static List<TrackerCategory> findMatchingCategoriesForEmail(String emailAddress) {
    return TrackerCategory.values
        .where((category) => matchesEmailDomain(category, emailAddress))
        .toList();
  }
}
