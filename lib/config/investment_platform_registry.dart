import 'package:flutter/material.dart';

/// Represents an investment platform/broker configuration
class InvestmentPlatform {
  final String id;
  final String name;
  final String emailDomain;
  final Color color;
  final IconData icon;
  final List<String> supportedAssetTypes; // ['equity', 'mutual_fund', 'etf', etc.]
  final List<String> smsKeywords; // Keywords to detect SMS from this platform

  const InvestmentPlatform({
    required this.id,
    required this.name,
    required this.emailDomain,
    required this.color,
    required this.icon,
    required this.supportedAssetTypes,
    this.smsKeywords = const [],
  });
}

/// Registry of supported investment platforms in India
final List<InvestmentPlatform> investmentPlatforms = [
  // Discount Brokers
  InvestmentPlatform(
    id: 'zerodha',
    name: 'Zerodha Kite',
    emailDomain: 'zerodha.com',
    color: Color(0xFF387ED1), // Zerodha blue
    icon: Icons.show_chart,
    supportedAssetTypes: ['equity', 'mutual_fund', 'etf'],
    smsKeywords: ['ZERODHA', 'ZER0DHA', 'KITE'],
  ),

  InvestmentPlatform(
    id: 'groww',
    name: 'Groww',
    emailDomain: 'groww.in',
    color: Color(0xFF00D09C), // Groww green
    icon: Icons.trending_up,
    supportedAssetTypes: ['equity', 'mutual_fund', 'etf', 'fd'],
    smsKeywords: ['GROWW'],
  ),

  InvestmentPlatform(
    id: 'upstox',
    name: 'Upstox',
    emailDomain: 'upstox.com',
    color: Color(0xFF6C5CE7), // Upstox purple
    icon: Icons.analytics,
    supportedAssetTypes: ['equity', 'mutual_fund', 'etf'],
    smsKeywords: ['UPSTOX', 'RKSV'],
  ),

  InvestmentPlatform(
    id: 'angelone',
    name: 'Angel One',
    emailDomain: 'angelbroking.com',
    color: Color(0xFFE74C3C), // Angel red
    icon: Icons.auto_graph,
    supportedAssetTypes: ['equity', 'mutual_fund', 'etf'],
    smsKeywords: ['ANGELONE', 'ANGEL'],
  ),

  InvestmentPlatform(
    id: '5paisa',
    name: '5paisa',
    emailDomain: '5paisa.com',
    color: Color(0xFFFF6B35), // 5paisa orange
    icon: Icons.account_balance,
    supportedAssetTypes: ['equity', 'mutual_fund', 'etf'],
    smsKeywords: ['5PAISA'],
  ),

  // Traditional Brokers
  InvestmentPlatform(
    id: 'icici_direct',
    name: 'ICICI Direct',
    emailDomain: 'icicidirect.com',
    color: Color(0xFFB95B1E), // ICICI orange
    icon: Icons.business,
    supportedAssetTypes: ['equity', 'mutual_fund', 'etf', 'fd'],
    smsKeywords: ['ICICID', 'ICICI'],
  ),

  InvestmentPlatform(
    id: 'hdfc_securities',
    name: 'HDFC Securities',
    emailDomain: 'hdfcsec.com',
    color: Color(0xFF004C8F), // HDFC blue
    icon: Icons.account_balance_wallet,
    supportedAssetTypes: ['equity', 'mutual_fund', 'etf', 'fd'],
    smsKeywords: ['HDFCSE', 'HDFC'],
  ),

  InvestmentPlatform(
    id: 'kotak_securities',
    name: 'Kotak Securities',
    emailDomain: 'kotaksecurities.com',
    color: Color(0xFFED1C24), // Kotak red
    icon: Icons.security,
    supportedAssetTypes: ['equity', 'mutual_fund', 'etf', 'fd'],
    smsKeywords: ['KOTAK'],
  ),

  // Mutual Fund Platforms
  InvestmentPlatform(
    id: 'kuvera',
    name: 'Kuvera',
    emailDomain: 'kuvera.in',
    color: Color(0xFF6C63FF), // Kuvera purple
    icon: Icons.pie_chart,
    supportedAssetTypes: ['mutual_fund'],
    smsKeywords: ['KUVERA'],
  ),

  InvestmentPlatform(
    id: 'paytm_money',
    name: 'Paytm Money',
    emailDomain: 'paytmmoney.com',
    color: Color(0xFF00B9F1), // Paytm blue
    icon: Icons.attach_money,
    supportedAssetTypes: ['mutual_fund', 'equity', 'etf'],
    smsKeywords: ['PAYTMM', 'PYTMON'],
  ),

  InvestmentPlatform(
    id: 'mfu_online',
    name: 'MFU Online',
    emailDomain: 'mfuonline.com',
    color: Color(0xFF2E7D32), // Green
    icon: Icons.account_balance_wallet,
    supportedAssetTypes: ['mutual_fund'],
    smsKeywords: ['MFUONL'],
  ),

  // Gold Platforms
  InvestmentPlatform(
    id: 'safegold',
    name: 'SafeGold',
    emailDomain: 'safegold.com',
    color: Color(0xFFFFD700), // Gold color
    icon: Icons.diamond,
    supportedAssetTypes: ['gold'],
    smsKeywords: ['SAFEGO'],
  ),

  InvestmentPlatform(
    id: 'mmtc_pamp',
    name: 'MMTC-PAMP',
    emailDomain: 'mmtcpamp.com',
    color: Color(0xFFFFA500), // Orange-gold
    icon: Icons.diamond_outlined,
    supportedAssetTypes: ['gold'],
    smsKeywords: ['MMTCPA'],
  ),

  // Government Schemes (for tracking)
  InvestmentPlatform(
    id: 'nps',
    name: 'NPS (National Pension System)',
    emailDomain: 'npscra.nsdl.co.in',
    color: Color(0xFF1976D2), // Blue
    icon: Icons.elderly,
    supportedAssetTypes: ['nps'],
    smsKeywords: ['NPSCRA', 'NPS'],
  ),

  InvestmentPlatform(
    id: 'ppf',
    name: 'PPF (Public Provident Fund)',
    emailDomain: 'sbi.co.in', // Most common PPF provider
    color: Color(0xFF1565C0), // Dark blue
    icon: Icons.savings,
    supportedAssetTypes: ['ppf'],
    smsKeywords: ['PPF'],
  ),

  InvestmentPlatform(
    id: 'epf',
    name: 'EPF (Employee Provident Fund)',
    emailDomain: 'epfindia.gov.in',
    color: Color(0xFF0D47A1), // Navy blue
    icon: Icons.work,
    supportedAssetTypes: ['epf'],
    smsKeywords: ['EPFO', 'EPF'],
  ),
];

/// Helper function to find platform by ID
InvestmentPlatform? getPlatformById(String id) {
  try {
    return investmentPlatforms.firstWhere((p) => p.id == id);
  } catch (e) {
    return null;
  }
}

/// Helper function to find platform by email domain
InvestmentPlatform? getPlatformByEmail(String email) {
  final lowerEmail = email.toLowerCase();
  try {
    return investmentPlatforms.firstWhere(
      (p) => lowerEmail.contains(p.emailDomain.toLowerCase()),
    );
  } catch (e) {
    return null;
  }
}

/// Helper function to find platform by SMS keyword
InvestmentPlatform? getPlatformBySms(String smsText) {
  final upperSms = smsText.toUpperCase();
  try {
    return investmentPlatforms.firstWhere(
      (p) => p.smsKeywords.any((keyword) => upperSms.contains(keyword)),
    );
  } catch (e) {
    return null;
  }
}

/// Get platforms that support a specific asset type
List<InvestmentPlatform> getPlatformsByAssetType(String assetType) {
  return investmentPlatforms
      .where((p) => p.supportedAssetTypes.contains(assetType))
      .toList();
}
