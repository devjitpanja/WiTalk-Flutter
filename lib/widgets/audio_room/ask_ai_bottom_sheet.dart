import 'package:flutter/material.dart';

class AskAIBottomSheet extends StatefulWidget {
  final String? message;
  final Function(String)? onAskGemini;

  const AskAIBottomSheet({
    super.key,
    this.message,
    this.onAskGemini,
  });

  @override
  State<AskAIBottomSheet> createState() => _AskAIBottomSheetState();
}

class _AskAIBottomSheetState extends State<AskAIBottomSheet> {
  final TextEditingController _promptController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _handleAsk() {
    final customPrompt = _promptController.text.trim();
    if (customPrompt.isEmpty) return;

    final fullPrompt = 'Regarding this message: "${widget.message}"\n\nUser\'s question: $customPrompt';
    widget.onAskGemini?.call(fullPrompt);
    
    _promptController.clear();
    Navigator.pop(context);
  }

  void _handleQuickAction(String action) {
    String prompt = '';
    switch (action) {
      case 'translate':
        prompt = 'Translate this message: "${widget.message}". Ask the user for their preferred language.';
        break;
      case 'explain':
        prompt = 'What\'s the meaning and context of this message: "${widget.message}"';
        break;
      case 'summarize':
        prompt = 'Summarize this message in simpler terms: "${widget.message}"';
        break;
      case 'elaborate':
        prompt = 'Explain this message in more detail: "${widget.message}"';
        break;
    }

    if (prompt.isNotEmpty) {
      widget.onAskGemini?.call(prompt);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1017),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: const Color(0xFF0751DF).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Handle Indicator
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF0751DF).withOpacity(0.45),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4285F4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF4285F4)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ask AI',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC8D2FF).withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: const Color(0xFFC8D2FF).withOpacity(0.8)),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selected Message Preview
                  if (widget.message != null && widget.message!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4285F4).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SELECTED MESSAGE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFC8D2FF).withOpacity(0.6),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.message!,
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFFC8D2FF).withOpacity(0.9),
                              height: 1.38,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                  // Quick Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick actions',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFC8D2FF).withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildQuickActionCard(
                              icon: Icons.translate,
                              color: const Color(0xFF4285F4),
                              label: 'Translate',
                              onTap: () => _handleQuickAction('translate'),
                            ),
                            const SizedBox(width: 10),
                            _buildQuickActionCard(
                              icon: Icons.lightbulb_outline,
                              color: const Color(0xFFFFA000),
                              label: 'Explain',
                              onTap: () => _handleQuickAction('explain'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildQuickActionCard(
                              icon: Icons.short_text,
                              color: const Color(0xFF00ACC1),
                              label: 'Summarize',
                              onTap: () => _handleQuickAction('summarize'),
                            ),
                            const SizedBox(width: 10),
                            _buildQuickActionCard(
                              icon: Icons.notes,
                              color: const Color(0xFF9C27B0),
                              label: 'Elaborate',
                              onTap: () => _handleQuickAction('elaborate'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Custom Query Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Or ask your own question',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFC8D2FF).withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4285F4).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.15)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _promptController,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFFC8D2FF).withOpacity(0.95),
                                  ),
                                  maxLines: null,
                                  maxLength: 500,
                                  decoration: InputDecoration(
                                    hintText: 'e.g., Translate this message to Hindi',
                                    hintStyle: TextStyle(
                                      color: const Color(0xFFC8D2FF).withOpacity(0.4),
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    counterText: '',
                                  ),
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _handleAsk(),
                                ),
                              ),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _promptController,
                                builder: (context, value, child) {
                                  if (value.text.trim().isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return GestureDetector(
                                    onTap: _handleAsk,
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4285F4),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.send, size: 20, color: Colors.white),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFC8D2FF).withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showAskAIBottomSheet({
  required BuildContext context,
  String? message,
  Function(String)? onAskGemini,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AskAIBottomSheet(
      message: message,
      onAskGemini: onAskGemini,
    ),
  );
}
