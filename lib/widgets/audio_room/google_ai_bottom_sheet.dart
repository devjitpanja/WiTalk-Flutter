import 'package:flutter/material.dart';

class GoogleAIBottomSheet extends StatefulWidget {
  final String? roomContext;
  final String? initialQuery;

  const GoogleAIBottomSheet({
    super.key,
    this.roomContext,
    this.initialQuery,
  });

  @override
  State<GoogleAIBottomSheet> createState() => _GoogleAIBottomSheetState();
}

class _GoogleAIBottomSheetState extends State<GoogleAIBottomSheet> {
  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _handleCustomSearch() {
    // In a real implementation with webview_flutter, this would navigate the webview.
    // For now, it just closes the sheet or you could use url_launcher.
    Navigator.pop(context);
  }

  void _handleLatestNews() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF0751DF).withOpacity(0.35),
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
                      child: const Icon(Icons.search, size: 18, color: Color(0xFF4285F4)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Google AI',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC8D2FF).withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.minimize, size: 20, color: const Color(0xFFC8D2FF).withOpacity(0.8)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: const Color(0xFFC8D2FF).withOpacity(0.8)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 32,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              child: Column(
                children: [
                  Text(
                    'Quick Google Search',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFC8D2FF).withOpacity(0.95),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get latest news or search anything',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFFC8D2FF).withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Latest News Card
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleLatestNews,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4285F4).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Text('📰', style: TextStyle(fontSize: 28)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Latest News',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFC8D2FF).withOpacity(0.9),
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward, size: 20, color: const Color(0xFFC8D2FF).withOpacity(0.6)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Custom Query
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Or search your own query',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFC8D2FF).withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4285F4).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 20, color: const Color(0xFFC8D2FF).withOpacity(0.4)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _queryController,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFFC8D2FF).withOpacity(0.95),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Type your search query...',
                                  hintStyle: TextStyle(color: const Color(0xFFC8D2FF).withOpacity(0.4)),
                                  border: InputBorder.none,
                                ),
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _handleCustomSearch(),
                              ),
                            ),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _queryController,
                              builder: (context, value, child) {
                                if (value.text.trim().isEmpty) return const SizedBox.shrink();
                                return GestureDetector(
                                  onTap: _handleCustomSearch,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4285F4).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.send, size: 18, color: Color(0xFF4285F4)),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showGoogleAIBottomSheet({
  required BuildContext context,
  String? roomContext,
  String? initialQuery,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => GoogleAIBottomSheet(
      roomContext: roomContext,
      initialQuery: initialQuery,
    ),
  );
}
