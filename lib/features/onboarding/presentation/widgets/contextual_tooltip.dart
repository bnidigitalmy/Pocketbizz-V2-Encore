import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../services/tooltip_service.dart';

/// Contextual tooltip widget untuk guide users
class ContextualTooltip extends StatelessWidget {
  final String moduleKey;
  final String title;
  final String message;
  final GlobalKey targetKey; // Key untuk target widget
  final VoidCallback? onDismiss;
  final bool showSkip;

  const ContextualTooltip({
    super.key,
    required this.moduleKey,
    required this.title,
    required this.message,
    required this.targetKey,
    this.onDismiss,
    this.showSkip = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Overlay background (semi-transparent)
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _dismiss(context),
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ),

        // Tooltip content
        _buildTooltipContent(context),
      ],
    );
  }

  Widget _buildTooltipContent(BuildContext context) {
    return Positioned(
      top: 100, // Adjust based on target position
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _dismiss(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Message
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (showSkip)
                    TextButton(
                      onPressed: () => _dismiss(context),
                      child: const Text(
                        'Langkau',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _dismiss(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Faham'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _dismiss(BuildContext context) async {
    final tooltipService = TooltipService();
    await tooltipService.markTooltipSeen(moduleKey);
    
    if (onDismiss != null) {
      onDismiss!();
    } else {
      Navigator.of(context).pop();
    }
  }
}

/// Helper untuk show tooltip dengan trigger condition
class TooltipHelper {
  static Future<bool> shouldShowTooltip(
    BuildContext context,
    String moduleKey, {
    bool checkEmptyState = false,
    bool Function()? emptyStateChecker,
  }) async {
    final tooltipService = TooltipService();
    
    // Check kalau dah pernah tengok
    final hasSeen = await tooltipService.hasSeenTooltip(moduleKey);
    if (hasSeen) return false;

    // Check empty state jika diperlukan
    if (checkEmptyState && emptyStateChecker != null) {
      final isEmpty = emptyStateChecker();
      if (!isEmpty) return false; // Jangan show kalau ada data
    }

    return true;
  }

  static Future<void> showTooltip(
    BuildContext context,
    String moduleKey,
    String title,
    String message, {
    GlobalKey? targetKey,
    VoidCallback? onDismiss,
    bool showSkip = true,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ContextualTooltip(
        moduleKey: moduleKey,
        title: title,
        message: message,
        targetKey: targetKey ?? GlobalKey(),
        onDismiss: onDismiss,
        showSkip: showSkip,
      ),
    );
  }
}
