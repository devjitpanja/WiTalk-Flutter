import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';

// Hardcoded fallback categories per entity type — mirrors RN ReportScreen.jsx
const _postCategories = [
  {'value': 'dislike', 'label': 'I just don\'t like it'},
  {'value': 'harassment', 'label': 'Harassment or Bullying'},
  {'value': 'self_harm', 'label': 'Self-Harm or Suicide'},
  {'value': 'hate_speech', 'label': 'Hate Speech'},
  {'value': 'inappropriate_content', 'label': 'Inappropriate Content'},
  {'value': 'nudity', 'label': 'Nudity or Sexual Content'},
  {'value': 'scam', 'label': 'Scam or Fraud'},
  {'value': 'fake_account', 'label': 'Fake Account'},
  {'value': 'copyright', 'label': 'Copyright Violation'},
  {'value': 'other', 'label': 'Something Else'},
];

const _userCategories = [
  {'value': 'fake_account', 'label': 'Fake Account'},
  {'value': 'inappropriate_content', 'label': 'Inappropriate Content'},
  {'value': 'child_safety', 'label': 'Child Safety'},
  {'value': 'nudity', 'label': 'Nudity or Sexual Content'},
  {'value': 'harassment', 'label': 'Harassment or Bullying'},
  {'value': 'self_harm', 'label': 'Self-Harm or Suicide'},
  {'value': 'other', 'label': 'Something Else'},
];

List<Map<String, String>> _fallbackCategories(String entityType) {
  if (entityType == 'user') return List<Map<String, String>>.from(_userCategories);
  return List<Map<String, String>>.from(_postCategories);
}

class ReportScreen extends ConsumerStatefulWidget {
  final String targetType;
  final String targetId;
  final String? reportSource;
  final String? reportSourceId;

  const ReportScreen({
    super.key,
    required this.targetType,
    required this.targetId,
    this.reportSource,
    this.reportSourceId,
  });

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  String? _selectedCategory;
  final _detailCtrl = TextEditingController();
  bool _submitting = false;
  bool _loadingCategories = true;
  List<Map<String, String>> _categories = [];
  int? _lastSubmitTime;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await dioClient.get(AppEndpoints.reportCategories);
      final data = res.data?['data'];
      if (data is List && data.isNotEmpty) {
        final cats = data.map<Map<String, String>>((e) {
          final value = (e['value'] ?? e['key'] ?? '').toString();
          final label = (e['label'] ?? e['name'] ?? value).toString();
          return {'value': value, 'label': label};
        }).toList();
        if (mounted) {
          setState(() {
            _categories = cats;
            _loadingCategories = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _categories = _fallbackCategories(widget.targetType);
        _loadingCategories = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedCategory == null || _submitting) return;

    if (_selectedCategory == 'other' && _detailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the issue for "Something Else"')),
      );
      return;
    }

    // Client-side rate limit — 10 seconds between submissions
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastSubmitTime != null && now - _lastSubmitTime! < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait before submitting another report')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await dioClient.post(AppEndpoints.report, data: {
        'reported_entity_type': widget.targetType,
        'reported_entity_id': widget.targetId,
        'report_category': _selectedCategory,
        if (_detailCtrl.text.trim().isNotEmpty)
          'description': _detailCtrl.text.trim(),
        if (widget.reportSource != null) 'report_source': widget.reportSource,
        if (widget.reportSourceId != null)
          'report_source_id': widget.reportSourceId,
      });
      _lastSubmitTime = DateTime.now().millisecondsSinceEpoch;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you!')),
        );
        context.pop();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        // Already reported — treat gracefully, go back
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You\'ve already reported this.')),
          );
          context.pop();
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit report. Please try again.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit report. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Report',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        elevation: 0,
      ),
      body: _loadingCategories
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryButton))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Why are you reporting this?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your report is anonymous. We review all reports carefully.',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._categories.map((cat) => RadioListTile<String>(
                        value: cat['value']!,
                        groupValue: _selectedCategory,
                        onChanged: (v) =>
                            setState(() => _selectedCategory = v),
                        title: Text(
                          cat['label']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Outfit',
                            fontSize: 15,
                          ),
                        ),
                        activeColor: AppColors.primaryButton,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      )),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _detailCtrl,
                    style: const TextStyle(
                        color: Colors.white, fontFamily: 'Outfit'),
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: _selectedCategory == 'other'
                          ? 'Describe the issue (required)'
                          : 'Additional details (optional)',
                      hintStyle: const TextStyle(
                          color: AppColors.placeholder, fontFamily: 'Outfit'),
                      counterStyle:
                          const TextStyle(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primaryButton),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _selectedCategory != null ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedCategory != null
                          ? AppColors.error
                          : AppColors.border,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Text(
                            'Submit Report',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
