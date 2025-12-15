import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Overview',
              'FinLog is a personal finance tracking application that operates completely offline. Your privacy and data security are our top priorities.',
            ),
            _buildSection(
              'Data Collection',
              'We do NOT collect, transmit, or store any of your personal data on external servers. All data generated or processed by FinLog remains strictly on your local device.',
            ),
            _buildSection(
              'SMS Permission Usage',
              'FinLog requests the "READ_SMS" and "RECEIVE_SMS" permissions solely for the purpose of automatically tracking your financial transactions. \n\n'
              '• We scan ONLY messages from known bank sender IDs (e.g., "HDFCBK", "SBIUPI").\n'
              '• We ignore all personal messages, OTPs, and non-financial alerts.\n'
              '• The SMS content is processed locally to extract transaction details (Amount, Merchant, Date) and is never shared.',
            ),
            _buildSection(
              'Data Security',
              'Since FinLog does not connect to the internet, your financial data cannot be intercepted or leaked by the application. You are the sole owner of your data.',
            ),
            _buildSection(
              'User Rights',
              'You have the right to:\n'
              '• Revoke SMS permissions at any time via Android Settings.\n'
              '• Delete all stored data using the "Clear All Data" option in Settings.\n'
              '• Export your data for your own records.',
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'FinLog v1.0.0',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
