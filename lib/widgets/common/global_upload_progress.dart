import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';

class UploadProgressState {
  final bool isVisible;
  final String text;
  final String icon; // 'cloud-upload', 'check-circle', 'error'
  final Color backgroundColor;
  final Color textColor;
  final bool showProgressBar;
  final double progress; // 0.0 to 100.0
  final bool showDismiss;

  const UploadProgressState({
    this.isVisible = false,
    this.text = '',
    this.icon = 'cloud-upload',
    this.backgroundColor = const Color(0xFF323232),
    this.textColor = Colors.white,
    this.showProgressBar = true,
    this.progress = 0.0,
    this.showDismiss = false,
  });

  UploadProgressState copyWith({
    bool? isVisible,
    String? text,
    String? icon,
    Color? backgroundColor,
    Color? textColor,
    bool? showProgressBar,
    double? progress,
    bool? showDismiss,
  }) {
    return UploadProgressState(
      isVisible: isVisible ?? this.isVisible,
      text: text ?? this.text,
      icon: icon ?? this.icon,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      showProgressBar: showProgressBar ?? this.showProgressBar,
      progress: progress ?? this.progress,
      showDismiss: showDismiss ?? this.showDismiss,
    );
  }
}

class UploadProgressNotifier extends StateNotifier<UploadProgressState> {
  UploadProgressNotifier() : super(const UploadProgressState());

  void show({
    required String text,
    String icon = 'cloud-upload',
    Color backgroundColor = const Color(0xFF323232),
    Color textColor = Colors.white,
    bool showProgressBar = true,
    double progress = 0.0,
    bool showDismiss = false,
  }) {
    state = UploadProgressState(
      isVisible: true,
      text: text,
      icon: icon,
      backgroundColor: backgroundColor,
      textColor: textColor,
      showProgressBar: showProgressBar,
      progress: progress,
      showDismiss: showDismiss,
    );
  }

  void update({
    String? text,
    String? icon,
    Color? backgroundColor,
    Color? textColor,
    bool? showProgressBar,
    double? progress,
    bool? showDismiss,
  }) {
    state = state.copyWith(
      text: text,
      icon: icon,
      backgroundColor: backgroundColor,
      textColor: textColor,
      showProgressBar: showProgressBar,
      progress: progress,
      showDismiss: showDismiss,
    );
  }

  void hide() {
    state = state.copyWith(isVisible: false);
  }
}

final globalUploadProgressProvider =
    StateNotifierProvider<UploadProgressNotifier, UploadProgressState>((ref) {
  return UploadProgressNotifier();
});

class GlobalUploadProgressOverlay extends ConsumerWidget {
  const GlobalUploadProgressOverlay({super.key});

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'check-circle':
        return Icons.check_circle_rounded;
      case 'error':
        return Icons.error_rounded;
      case 'cloud-upload':
      default:
        return Icons.cloud_upload_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(globalUploadProgressProvider);

    if (!uploadState.isVisible) return const SizedBox.shrink();

    final clampedProgress = (uploadState.progress / 100.0).clamp(0.0, 1.0);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        color: uploadState.backgroundColor,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _getIconData(uploadState.icon),
                    color: uploadState.textColor,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      uploadState.text,
                      style: TextStyle(
                        color: uploadState.textColor,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (uploadState.showDismiss)
                    IconButton(
                      icon: Icon(Icons.close, color: uploadState.textColor, size: 20),
                      onPressed: () {
                        ref.read(globalUploadProgressProvider.notifier).hide();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              if (uploadState.showProgressBar) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: clampedProgress,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryButton),
                    minHeight: 4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
