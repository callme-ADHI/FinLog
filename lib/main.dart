import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/datasources/db_helper.dart';
import 'data/repositories/transaction_repository_impl.dart';
import 'domain/repositories/transaction_repository.dart';
import 'domain/usecases/process_sms.dart';
import 'core/services/sms_service.dart';
import 'presentation/pages/home_shell.dart';
import 'presentation/pages/onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Singleton Services
  final dbHelper = DBHelper.instance;
  final transactionRepository = TransactionRepositoryImpl(dbHelper);
  final processSms = ProcessSms(transactionRepository);
  final smsService = SmsService(processSms: processSms);

  // Initialize Services
  smsService.initialize();
  
  // Auto-scan on startup (once)
  MyApp.autoScanSmsOnStartup(smsService);
  
  // Check if onboarding is completed
  final prefs = await SharedPreferences.getInstance();
  final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
  
  runApp(MyApp(
    showOnboarding: !onboardingCompleted,
    transactionRepository: transactionRepository,
    processSms: processSms,
    smsService: smsService,
  ));
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  final TransactionRepository transactionRepository;
  final ProcessSms processSms;
  final SmsService smsService;
  
  const MyApp({
    super.key, 
    required this.showOnboarding,
    required this.transactionRepository,
    required this.processSms,
    required this.smsService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TransactionRepository>.value(value: transactionRepository),
        Provider<ProcessSms>.value(value: processSms),
        Provider<SmsService>.value(value: smsService),
      ],
      child: MaterialApp(
        title: 'FinLog',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          primaryColor: Colors.teal,
          colorScheme: const ColorScheme.dark(
            primary: Colors.teal,
            secondary: Colors.tealAccent,
            surface: Color(0xFF1E1E1E),

          ),
          useMaterial3: true,
          fontFamily: 'Roboto', // Default, but explicit
          cardTheme: CardThemeData(
            color: const Color(0xFF1E1E1E),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.05))
            ),
          ),
        ),
        home: showOnboarding ? const OnboardingPage() : const HomeShell(),
      ),
    );
  }

  // Background SMS scan on startup
  static void autoScanSmsOnStartup(SmsService smsService) async {
    try {
      // Check if SMS permission is granted
      final status = await Permission.sms.status;
      if (status.isGranted) {
        print('🔄 Auto-scanning SMS on app startup...');
        // Run in background without blocking UI
        Future.delayed(const Duration(milliseconds: 500), () async {
          try {
            final count = await smsService.scanAllSms();
            print('✅ Background scan complete: $count new transactions imported');
          } catch (e) {
            print('❌ Background scan error: $e');
          }
        });
      }
    } catch (e) {
      print('❌ Auto-scan check failed: $e');
    }
  }
}

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Request SMS permissions
    final status = await Permission.sms.request();
    if (status.isGranted) {
      // Navigate to HomeShell
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      }
    } else {
      // Show error or retry
      // For now, just navigate anyway but maybe show banner
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
