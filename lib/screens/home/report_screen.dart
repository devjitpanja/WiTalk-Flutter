import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../providers/theme_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';

// ── Theme helper (same pattern as rest of codebase) ─────────────────────────
class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
  Color get surface => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get border => dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  Color get text => dark ? Colors.white : Colors.black;
  Color get textSecondary => dark ? const Color(0xFFEBEBF5) : const Color(0xFF3C3C43);
  Color get textTertiary => const Color(0xFF8E8E93);
  Color get primary => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  Color get error => dark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);
}

// ── Fallback categories ──────────────────────────────────────────────────────
const _postCategories = [
  {'value': 'dislike', 'label': "I just don't like it"},
  {'value': 'harassment', 'label': 'Bullying or unwanted contact'},
  {'value': 'self_harm', 'label': 'Suicide, self-injury or eating disorders'},
  {'value': 'hate_speech', 'label': 'Violence, hate or exploitation'},
  {'value': 'inappropriate_content', 'label': 'Selling or promoting restricted items'},
  {'value': 'nudity', 'label': 'Nudity or sexual activity'},
  {'value': 'scam', 'label': 'Scam, fraud or spam'},
  {'value': 'fake_account', 'label': 'False information'},
  {'value': 'copyright', 'label': 'Intellectual property'},
  {'value': 'other', 'label': 'Other'},
];

const _userCategories = [
  {'value': 'fake_account', 'label': 'Fake profile, scammer, not one person'},
  {'value': 'inappropriate_content', 'label': 'Someone is selling something'},
  {'value': 'child_safety', 'label': 'Someone under 18 is involved'},
  {'value': 'nudity', 'label': 'Nudity or something sexually explicit'},
  {'value': 'harassment', 'label': 'Abusive/hateful/threatening behavior'},
  {'value': 'self_harm', 'label': 'Possible threat to themselves or others'},
  {'value': 'other', 'label': 'Other'},
];

List<Map<String, String>> _fallbackFor(String entityType) {
  if (entityType == 'user') return List<Map<String, String>>.from(_userCategories);
  return List<Map<String, String>>.from(_postCategories);
}

// ── Screen ───────────────────────────────────────────────────────────────────
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
  final _descCtrl = TextEditingController();
  bool _submitting = false;
  bool _loadingCategories = true;
  List<Map<String, String>> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await dioClient.get(AppEndpoints.reportCategories);
      final cats = res.data?['data']?['categories'];
      if (cats is List && cats.isNotEmpty) {
        final mapped = cats.map<Map<String, String>>((e) {
          return {
            'value': (e['value'] ?? e['key'] ?? '').toString(),
            'label': (e['label'] ?? e['name'] ?? '').toString(),
          };
        }).toList();
        if (mounted) {
          setState(() {
            _categories = mapped;
            _loadingCategories = false;
          });
        }
        return;
      }
    } catch (_) {}
    // Fallback: use hardcoded categories by entity type (same as RN)
    if (mounted) {
      setState(() {
        _categories = _fallbackFor(widget.targetType);
        _loadingCategories = false;
      });
    }
  }

  // RN: getDisplayCategories() always returns entity-type-specific hardcoded list
  List<Map<String, String>> get _displayCategories {
    if (_categories.isEmpty) return _fallbackFor(widget.targetType);
    return _fallbackFor(widget.targetType);
  }

  void _handleCategorySelect(String value) {
    setState(() {
      _selectedCategory = value;
      _descCtrl.clear(); // RN clears description on category switch
    });
  }

  String get _entityTypeLabel {
    switch (widget.targetType) {
      case 'post': return 'post';
      case 'user': return 'user';
      case 'comment': return 'comment';
      case 'group': return 'group';
      case 'message': return 'message';
      case 'group_message': return 'group message';
      default: return 'content';
    }
  }

  Future<void> _submit() async {
    if (_selectedCategory == null || _submitting) return;

    // If "other" is selected, description is required (matches RN)
    if (_selectedCategory == 'other' && _descCtrl.text.trim().isEmpty) {
      _showToast('Please provide details about the issue when selecting "Other".');
      return;
    }

    setState(() => _submitting = true);
    try {
      final data = <String, dynamic>{
        'reported_entity_type': widget.targetType,
        'reported_entity_id': widget.targetId,
        'report_category': _selectedCategory,
      };

      final trimmed = _descCtrl.text.trim();
      if (trimmed.isNotEmpty) data['description'] = trimmed;
      if (widget.reportSource != null) data['report_source'] = widget.reportSource;
      if (widget.reportSourceId != null) data['report_source_id'] = widget.reportSourceId;

      await dioClient.post(AppEndpoints.report, data: data);

      if (mounted) {
        _showToast('Report submitted. Thank you!');
        context.pop();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        // Already reported — treat as informational (matches RN behaviour)
        if (mounted) {
          _showToast('You have already reported this content.');
          context.pop();
        }
        return;
      }
      if (mounted) {
        final msg = e.response?.data?['message']?.toString() ?? 'Failed to submit report. Please try again.';
        _showToast(msg);
      }
    } catch (_) {
      if (mounted) _showToast('Failed to submit report. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Outfit')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(t),
            Expanded(
              child: _loadingCategories
                  ? _buildLoading(t)
                  : _buildContent(t),
            ),
            if (_selectedCategory != null) _buildFooter(t),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_T t) => Container(
    decoration: BoxDecoration(
      color: t.surface,
      boxShadow: const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 2), blurRadius: 4)],
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 48, height: 52,
            alignment: Alignment.center,
            child: Icon(Icons.arrow_back, size: 24, color: t.text),
          ),
        ),
        Expanded(
          child: Text(
            'Report',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: t.text,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 48, height: 52,
            alignment: Alignment.center,
            child: Icon(Icons.close, size: 24, color: t.text),
          ),
        ),
      ],
    ),
  );

  Widget _buildLoading(_T t) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: t.primary),
        const SizedBox(height: 12),
        Text(
          'Loading categories...',
          style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary),
        ),
      ],
    ),
  );

  Widget _buildContent(_T t) => SingleChildScrollView(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title section
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why are you reporting this $_entityTypeLabel?',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your report is anonymous. If someone is in immediate danger, call the local emergency services - don\'t wait.',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  height: 1.4,
                  color: t.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Category cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: _displayCategories.map((cat) => _buildCategoryCard(cat, t)).toList(),
          ),
        ),

        // Description section — only shown when a category is selected
        if (_selectedCategory != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: _buildDescriptionSection(t),
          ),
      ],
    ),
  );

  Widget _buildCategoryCard(Map<String, String> cat, _T t) {
    final isSelected = _selectedCategory == cat['value'];
    return GestureDetector(
      onTap: () => _handleCategorySelect(cat['value']!),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? t.primary : t.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                cat['label']!,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  color: isSelected ? t.text : t.textSecondary,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 20, color: t.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(_T t) {
    final isOther = _selectedCategory == 'other';
    final descValue = _descCtrl.text;
    final showError = isOther && descValue.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isOther ? 'Please describe the issue *' : 'Additional details (optional)',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: t.text,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descCtrl,
          maxLines: 4,
          maxLength: 500,
          textAlignVertical: TextAlignVertical.top,
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.text),
          decoration: InputDecoration(
            hintText: isOther
                ? 'Please describe the exact problem...'
                : 'Provide more information about this report...',
            hintStyle: TextStyle(fontFamily: 'Outfit', color: t.textTertiary),
            counterStyle: TextStyle(fontFamily: 'Outfit', color: t.textTertiary, fontSize: 12),
            filled: true,
            fillColor: t.surface,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: showError ? t.error : t.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: showError ? t.error : t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: showError ? t.error : t.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (isOther) ...[
          const SizedBox(height: 8),
          Text(
            '* Description is required when selecting "Other"',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.error),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(_T t) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    decoration: BoxDecoration(
      color: t.bg,
      border: Border(top: BorderSide(color: t.border.withValues(alpha: 0.5))),
    ),
    child: GestureDetector(
      onTap: _submitting ? null : _submit,
      child: AnimatedOpacity(
        opacity: _submitting ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: double.infinity,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
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
      ),
    ),
  );
}
