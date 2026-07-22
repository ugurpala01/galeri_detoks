import 'package:flutter/material.dart';

class AnimatedScanMessage extends StatefulWidget {
  final List<String> messages;
  final VoidCallback? onComplete;

  const AnimatedScanMessage({
    super.key,
    required this.messages,
    this.onComplete,
  });

  @override
  State<AnimatedScanMessage> createState() => _AnimatedScanMessageState();
}

class _AnimatedScanMessageState extends State<AnimatedScanMessage>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _startAnimation();
  }

  @override
  void didUpdateWidget(AnimatedScanMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length ||
        (widget.messages.isNotEmpty && 
         oldWidget.messages.isNotEmpty && 
         widget.messages[0] != oldWidget.messages[0])) {
      _currentIndex = 0;
      _fadeController.reset();
      _startAnimation();
    }
  }

  void _startAnimation() async {
    if (widget.messages.isEmpty) return;
    
    for (int i = 0; i < widget.messages.length; i++) {
      if (!mounted) return;
      
      setState(() => _currentIndex = i);
      
      // Fade in
      await _fadeController.forward();
      
      // Mesaji goster (2-4 saniye arasi)
      final displayDuration = i == 0 
          ? const Duration(seconds: 3)
          : const Duration(seconds: 4);
      await Future.delayed(displayDuration);
      
      if (!mounted) return;
      
      // Son mesaj degilse fade out
      if (i < widget.messages.length - 1) {
        await _fadeController.reverse();
      }
    }
    
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIconForIndex(_currentIndex),
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.messages[_currentIndex],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.folder_open_rounded;
      case 1:
        return Icons.photo_library_rounded;
      case 2:
        return Icons.access_time_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}
