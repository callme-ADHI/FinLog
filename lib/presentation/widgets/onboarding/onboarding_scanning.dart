import 'package:flutter/material.dart';

class OnboardingScanning extends StatefulWidget {
  final bool isScanning;
  final int importedCount;

  const OnboardingScanning({
    Key? key,
    required this.isScanning,
    required this.importedCount,
  }) : super(key: key);

  @override
  State<OnboardingScanning> createState() => _OnboardingScanningState();
}

class _OnboardingScanningState extends State<OnboardingScanning>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            
            // Pulsing Animation
            if (widget.isScanning)
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.purple.shade400,
                        Colors.purple.shade900,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.5),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade900.withOpacity(0.3),
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 60,
                  color: Colors.green.shade400,
                ),
              ),
            
            const SizedBox(height: 40),
            
            // Status Text
            Text(
              widget.isScanning ? 'Scanning Messages...' : 'Scan Complete!',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // Count Text
            if (widget.importedCount > 0)
              Text(
                'Found ${widget.importedCount} transactions',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (widget.isScanning)
              Text(
                'This may take a moment...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            
            const Spacer(),
            
            // Info Text
            if (widget.isScanning)
              Text(
                'Reading your transaction history',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
