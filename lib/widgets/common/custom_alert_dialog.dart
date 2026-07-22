import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class DialogButtonConfig {
  final String text;
  final VoidCallback? onPress;
  final bool isDestructive;
  final bool isCancel;

  const DialogButtonConfig({
    required this.text,
    this.onPress,
    this.isDestructive = false,
    this.isCancel = false,
  });
}

class CustomAlertDialog extends StatelessWidget {
  final bool visible;
  final String title;
  final String message;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final String confirmText;
  final String cancelText;
  final bool showCancel;
  final String type; // 'info' | 'warning' | 'danger' | 'success'
  final List<DialogButtonConfig>? buttons;

  const CustomAlertDialog({
    super.key,
    required this.visible,
    required this.title,
    required this.message,
    this.onConfirm,
    this.onCancel,
    this.confirmText = 'OK',
    this.cancelText = 'Cancel',
    this.showCancel = false,
    this.type = 'info',
    this.buttons,
  });

  Color _getPrimaryColor() {
    switch (type) {
      case 'danger':
        return Colors.redAccent;
      case 'warning':
        return Colors.orangeAccent;
      case 'success':
        return Colors.greenAccent;
      default:
        return AppColors.primaryButton;
    }
  }

  IconData _getIcon() {
    switch (type) {
      case 'danger':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'success':
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final primaryColor = _getPrimaryColor();

    return Container(
      color: Colors.black54,
      child: Center(
        child: SingleChildScrollView(
          child: Dialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getIcon(), color: primaryColor, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (buttons != null && buttons!.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: buttons!.map((btn) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: TextButton(
                            onPressed: () {
                              btn.onPress?.call();
                            },
                            child: Text(
                              btn.text,
                              style: TextStyle(
                                color: btn.isDestructive
                                    ? Colors.redAccent
                                    : btn.isCancel
                                        ? AppColors.textSecondary
                                        : AppColors.primaryButton,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Row(
                      children: [
                        if (showCancel) ...[
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: onCancel,
                              child: Text(
                                cancelText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: onConfirm,
                            child: Text(
                              confirmText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
