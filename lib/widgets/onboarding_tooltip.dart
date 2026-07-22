import 'package:flutter/material.dart';

/// Onboarding balonu widget'ı
class OnboardingTooltip extends StatelessWidget {
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onNext;
  final bool isLastStep;

  const OnboardingTooltip({
    super.key,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onNext,
    this.isLastStep = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.9),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isLastStep)
                  TextButton(
                    onPressed: () => onNext(),
                    child: const Text('Atla'),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onNext,
                  child: Text(buttonText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Target widget'ı gösteren overlay
class OnboardingOverlay extends StatelessWidget {
  final GlobalKey targetKey;
  final Widget tooltip;
  final VoidCallback onDismiss;

  const OnboardingOverlay({
    super.key,
    required this.targetKey,
    required this.tooltip,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Karartma katmanı
        GestureDetector(
          onTap: onDismiss,
          child: Container(
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        // Hedef widget pozisyonu
        _TargetPosition(
          targetKey: targetKey,
          child: tooltip,
        ),
      ],
    );
  }
}

class _TargetPosition extends StatelessWidget {
  final GlobalKey targetKey;
  final Widget child;

  const _TargetPosition({
    required this.targetKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;

    // Tooltip pozisyonu: Widget'in altında veya üstünde
    final showBelow = position.dy + size.height + 150 < screenHeight;
    
    return Stack(
      children: [
        // Hedef widget'ı vurgula (delik efekti)
        Positioned(
          left: position.dx - 8,
          top: position.dy - 8,
          child: Container(
            width: size.width + 16,
            height: size.height + 16,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // Tooltip
        Positioned(
          left: 16,
          right: 16,
          top: showBelow ? position.dy + size.height + 16 : null,
          bottom: showBelow ? null : screenHeight - position.dy + 16,
          child: child,
        ),
      ],
    );
  }
}
