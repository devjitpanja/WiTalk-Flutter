import 'package:flutter/material.dart';

class RatingBottomSheet extends StatefulWidget {
  final String roomId;
  final Function(int)? onSubmitted;
  final String variant; // 'rate' or 'leave'

  const RatingBottomSheet({
    super.key,
    required this.roomId,
    this.onSubmitted,
    this.variant = 'rate',
  });

  @override
  State<RatingBottomSheet> createState() => _RatingBottomSheetState();
}

class _RatingBottomSheetState extends State<RatingBottomSheet> {
  int _rating = 0;
  String _reviewText = '';
  List<String> _selectedTags = [];
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  static const _lowTags = ['Not following rules', 'Inappropriate language', 'Poor moderation', 'Boring', 'Technical issues'];
  static const _highTags = ['Great conversation', 'Friendly users', 'Helpful discussion', 'Fun vibe', 'Learned a lot'];
  static const _neutralTags = ['It was okay', 'Average experience', 'Could be better'];

  List<String> get _availableTags {
    if (_rating == 0) return [];
    if (_rating <= 2) return _lowTags;
    if (_rating == 3) return _neutralTags;
    return _highTags;
  }

  void _handleStarPress(int r) {
    setState(() {
      _rating = r;
      _selectedTags = [];
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_rating == 0) return;
    
    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        setState(() {
          _submitted = true;
          _submitting = false;
        });
        
        if (widget.onSubmitted != null) {
          widget.onSubmitted!(_rating);
        }
        
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = 'Failed to submit rating. Please try again.';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLeavePrompt = widget.variant == 'leave';
    final headerTitle = isLeavePrompt ? 'How was the Adda?' : 'Rate this Adda';
    final headerSubtitle = isLeavePrompt ? 'Rate it from 1 to 5' : 'How was your experience?';

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2A3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 24,
                top: 12,
              ),
              child: _submitted
                  ? _buildSuccessState()
                  : Column(
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            children: [
                              Text(
                                headerTitle,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                headerSubtitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.55),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Stars
                        Padding(
                          padding: const EdgeInsets.only(bottom: 30),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final star = index + 1;
                              return GestureDetector(
                                onTap: () => _handleStarPress(star),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    _rating >= star ? Icons.star : Icons.star_border,
                                    size: 48,
                                    color: _rating >= star
                                        ? const Color(0xFFFFD700)
                                        : Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                        // Tags
                        if (_rating > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    'What stood out?',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _availableTags.map((tag) {
                                    final isSelected = _selectedTags.contains(tag);
                                    return GestureDetector(
                                      onTap: () => _toggleTag(tag),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFF4A90E2) : Colors.white.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF4A90E2) : Colors.white.withOpacity(0.1),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isSelected)
                                              const Padding(
                                                padding: EdgeInsets.only(right: 4),
                                                child: Icon(Icons.check, size: 14, color: Colors.white),
                                              ),
                                            Text(
                                              tag,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),

                        // Review Input
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  'Tell us more (Optional)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ),
                              TextField(
                                onChanged: (val) => setState(() => _reviewText = val),
                                maxLength: 500,
                                maxLines: 3,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Write your review here...',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.06),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFF4A90E2)),
                                  ),
                                  counterStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Error Inline
                        if (_error != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, size: 16, color: Color(0xFFFF6B6B)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFFF6B6B)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Submit Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: (_rating == 0 || _submitting) ? null : _handleSubmit,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A90E2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Opacity(
                                opacity: (_rating == 0 || _submitting) ? 0.4 : 1.0,
                                child: _submitting
                                    ? const SizedBox(
                                        width: 19,
                                        height: 19,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text(
                                        'Submit Rating',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
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

  Widget _buildSuccessState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.done, size: 52, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Feedback Received!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Thank you for helping us improve the community.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.55),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

Future<void> showRatingBottomSheet({
  required BuildContext context,
  required String roomId,
  Function(int)? onSubmitted,
  String variant = 'rate',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => RatingBottomSheet(
      roomId: roomId,
      onSubmitted: onSubmitted,
      variant: variant,
    ),
  );
}
