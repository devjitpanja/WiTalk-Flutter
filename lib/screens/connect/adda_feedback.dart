import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AddaFeedbackScreen extends StatefulWidget {
  final String? roomId;

  const AddaFeedbackScreen({super.key, this.roomId});

  @override
  State<AddaFeedbackScreen> createState() => _AddaFeedbackScreenState();
}

class _AddaFeedbackScreenState extends State<AddaFeedbackScreen> {
  static const List<String> _feedbackOptions = [
    'Nobody was talking',
    'Topic wasn\'t interesting',
    'Someone was rude or inappropriate',
    'Audio / technical problem',
    'Room felt empty or boring',
  ];

  String? _selectedOption;
  bool _submitting = false;

  Future<void> _handleOptionPress(String option) async {
    if (_submitting) return;
    setState(() {
      _selectedOption = option;
      _submitting = true;
    });

    try {
      // TODO: POST to feedback endpoint
      await Future.delayed(const Duration(milliseconds: 600)); // Simulate network request
    } catch (e) {
      debugPrint('[AddaFeedback] Could not log feedback: $e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
        _goHome();
      }
    }
  }

  void _goHome() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12111F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24).copyWith(top: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'What could be better?',
                style: TextStyle(color: Colors.white, fontSize: 22, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your feedback helps improve Adda rooms',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, fontFamily: 'Outfit'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              ..._feedbackOptions.map((option) {
                final isSelected = _selectedOption == option;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: _submitting ? null : () => _handleOptionPress(option),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      constraints: const BoxConstraints(minHeight: 52),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFAFA9EC).withOpacity(0.15) : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFAFA9EC) : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: _submitting && isSelected
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Color(0xFFAFA9EC), strokeWidth: 2),
                            )
                          : Text(
                              option,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFFAFA9EC) : Colors.white.withOpacity(0.8),
                                fontSize: 15,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),
              TextButton(
                onPressed: _submitting ? null : _goHome,
                child: Text(
                  'Skip',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, fontFamily: 'Outfit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
