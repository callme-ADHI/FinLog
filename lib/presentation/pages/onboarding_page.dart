import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../core/services/sms_service.dart';
import '../widgets/onboarding/onboarding_welcome.dart';
import '../widgets/onboarding/onboarding_permissions.dart';
import '../widgets/onboarding/onboarding_scanning.dart';
import '../widgets/onboarding/onboarding_balance.dart';
import '../widgets/onboarding/onboarding_complete.dart';
import 'home_shell.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({Key? key}) : super(key: key);

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  int _currentStep = 0;
  int _importedCount = 0;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _startScanning() async {
    setState(() => _isScanning = true);
    
    final smsService = context.read<SmsService>();
    try {
      final count = await smsService.scanAllSms();
      setState(() {
        _importedCount = count;
        _isScanning = false;
      });
      
      await Future.delayed(const Duration(seconds: 1));
      _nextStep();
    } catch (e) {
      setState(() => _isScanning = false);
      // Show error but allow to continue
      _nextStep();
    }
  }

  Future<void> _saveBalanceAndComplete(double currentBalance) async {
    final repo = context.read<TransactionRepository>();
    
    // Set the current balance
    await repo.updateCurrentBalance(currentBalance);
    
    // Calculate opening balance from current balance and transactions
    // Opening Balance = Current Balance - (Total Credits - Total Debits)
    final transactions = await repo.getTransactions();
    double totalCredits = 0;
    double totalDebits = 0;
    
    for (var transaction in transactions) {
      if (transaction.type == TransactionType.credit) {
        totalCredits += transaction.amount;
      } else {
        totalDebits += transaction.amount;
      }
    }
    
    // Opening balance is what you started with before all these transactions
    final openingBalance = currentBalance - (totalCredits - totalDebits);
    
    // Save opening balance to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('opening_balance', openingBalance);
    await prefs.setBool('onboarding_completed', true);
    
    _nextStep(); // Go to completion screen
    
    // Auto-navigate to main app after 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeShell(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0A0A),
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                ],
              ),
            ),
          ),
          
          // Page content
          FadeTransition(
            opacity: _fadeController,
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                OnboardingWelcome(onNext: _nextStep),
                OnboardingPermissions(
                  onPermissionGranted: () {
                    _nextStep();
                    // Auto-start scanning on next screen
                    Future.delayed(const Duration(milliseconds: 800), _startScanning);
                  },
                  onSkip: () => _nextStep(),
                ),
                OnboardingScanning(
                  isScanning: _isScanning,
                  importedCount: _importedCount,
                ),
                OnboardingBalance(onBalanceSet: _saveBalanceAndComplete),
                const OnboardingComplete(),
              ],
            ),
          ),
          
          // Progress indicator
          if (_currentStep < 4)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: _buildProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
              decoration: BoxDecoration(
                color: index <= _currentStep
                    ? Colors.tealAccent
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
