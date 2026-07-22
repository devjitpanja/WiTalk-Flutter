import 'package:flutter/material.dart';

class ReportBottomSheet extends StatefulWidget {
  final Map<String, dynamic> participant;
  final bool canBan;
  final Function(Map<String, dynamic>, String)? onBanUser;

  const ReportBottomSheet({
    super.key,
    required this.participant,
    this.canBan = false,
    this.onBanUser,
  });

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  String? _selectedReason;
  String _otherDescription = '';
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  final List<Map<String, String>> _reportReasons = [
    {
      'value': 'harassment',
      'label': 'Harassment',
      'description': 'Bullying, threatening, or abusive behavior',
    },
    {
      'value': 'hate_speech',
      'label': 'Hate Speech',
      'description': 'Attacks based on identity, race, or religion',
    },
    {
      'value': 'violence',
      'label': 'Violence / Threats',
      'description': 'Violent content or direct threats',
    },
    {
      'value': 'inappropriate_content',
      'label': 'Inappropriate Behavior',
      'description': 'Content that violates community guidelines',
    },
    {
      'value': 'other',
      'label': 'Other',
      'description': 'Something not listed above',
    },
  ];

  IconData _getIconForReason(String value) {
    switch (value) {
      case 'harassment':
        return Icons.gavel;
      case 'hate_speech':
        return Icons.warning;
      case 'violence':
        return Icons.dangerous;
      case 'inappropriate_content':
        return Icons.block;
      case 'other':
        return Icons.more_horiz;
      default:
        return Icons.report;
    }
  }

  Future<void> _handleSubmit(bool shouldBan) async {
    if (_selectedReason == null || widget.participant['userID'] == null) return;
    
    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 1));

      if (shouldBan && widget.onBanUser != null) {
        final banReason = _selectedReason == 'other'
            ? (_otherDescription.trim().isEmpty ? 'other' : _otherDescription.trim())
            : _selectedReason!;
        widget.onBanUser!(widget.participant, banReason);
      }

      if (mounted) {
        setState(() {
          _submitted = true;
          _submitting = false;
        });
        
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = 'Failed to submit report. Please try again.';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF16202E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle Indicator
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
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
              ),
              child: _submitted
                  ? _buildSuccessState()
                  : (_error != null && !_submitting
                      ? _buildErrorState()
                      : _buildForm()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
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
            child: const Icon(Icons.check_circle, size: 52, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Report Submitted',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Thank you for helping keep WiTalk safe. We will review this report shortly.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.55),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFFFA500).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.info, size: 52, color: Color(0xFFFFA500)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Notice',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.55),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final userName = widget.participant['userName'] ?? '';
    
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.flag, size: 22, color: Color(0xFFFF6B6B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report${userName.isNotEmpty ? ' $userName' : ''}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select a reason for your report',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Reasons List
        Column(
          children: _reportReasons.map((reason) {
            final isSelected = _selectedReason == reason['value'];
            return GestureDetector(
              onTap: () => setState(() => _selectedReason = reason['value']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF4A90E2).withOpacity(0.1) : Colors.white.withOpacity(0.04),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF4A90E2).withOpacity(0.35) : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF4A90E2).withOpacity(0.15) : Colors.white.withOpacity(0.07),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _getIconForReason(reason['value']!),
                        size: 20,
                        color: isSelected ? const Color(0xFF4A90E2) : Colors.white.withOpacity(0.55),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reason['label']!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.white.withOpacity(0.85),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            reason['description']!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF4A90E2) : Colors.white.withOpacity(0.25),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isSelected
                          ? Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4A90E2),
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // Other Input
        if (_selectedReason == 'other') ...[
          const SizedBox(height: 10),
          TextField(
            onChanged: (val) => setState(() => _otherDescription = val),
            maxLength: 500,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Describe the issue in your own words...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4A90E2))),
              counterStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
            ),
          ),
        ],

        // Error Inline
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
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

        const SizedBox(height: 16),

        // Actions
        Column(
          children: [
            if (widget.canBan)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildActionButton(
                  icon: Icons.block,
                  label: 'Report & Ban',
                  backgroundColor: const Color(0xFFCC2222),
                  onTap: () => _handleSubmit(true),
                ),
              ),
            _buildActionButton(
              icon: Icons.flag,
              label: 'Report',
              backgroundColor: widget.canBan ? Colors.transparent : const Color(0xFF4A90E2),
              borderColor: widget.canBan ? const Color(0xFF4A90E2) : Colors.transparent,
              onTap: () => _handleSubmit(false),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Disclaimer
        Text(
          'Reports are reviewed by our moderation team. False reports may result in action on your account.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.3),
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    Color borderColor = Colors.transparent,
    required VoidCallback onTap,
  }) {
    final isDisabled = _selectedReason == null || _submitting;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: borderColor != Colors.transparent ? 1.5 : 0,
            ),
          ),
          child: Opacity(
            opacity: isDisabled ? 0.4 : 1.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_submitting && backgroundColor != Colors.transparent && backgroundColor != const Color(0xFFCC2222))
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                else ...[
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showReportBottomSheet({
  required BuildContext context,
  required Map<String, dynamic> participant,
  bool canBan = false,
  Function(Map<String, dynamic>, String)? onBanUser,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ReportBottomSheet(
      participant: participant,
      canBan: canBan,
      onBanUser: onBanUser,
    ),
  );
}
