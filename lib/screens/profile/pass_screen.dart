import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../api/dio_client.dart';
import '../../providers/theme_provider.dart';

// ─── Tier config ──────────────────────────────────────────────────────────────
const _tierGradients = {
  'basic':     [Color(0xFF1a3a5c), Color(0xFF1e6fa8)],
  'mythic':    [Color(0xFF2d1b4e), Color(0xFF7c3aed)],
  'legendary': [Color(0xFF4a0a0a), Color(0xFFdc2626)],
};

const _tierBorders = {
  'basic':     Color(0xFF1e6fa8),
  'mythic':    Color(0xFF7c3aed),
  'legendary': Color(0xFFdc2626),
};

const _tierLabels = {
  'basic':     'Basic',
  'mythic':    'Mythic',
  'legendary': 'Legendary',
};

List<Color> _gradientFor(String? tier) => _tierGradients[tier] ?? _tierGradients['basic']!;
Color _borderFor(String? tier, Color fallback) => _tierBorders[tier] ?? fallback;

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
  Color get inputBg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class PassScreen extends ConsumerStatefulWidget {
  const PassScreen({super.key});
  @override
  ConsumerState<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends ConsumerState<PassScreen> {
  List<Map<String, dynamic>> _passes = [];
  bool _loading = true;
  bool _redeemVisible = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await dioClient.get('/v1/user/me/passes');
      if (mounted && res.data['success'] == true) {
        setState(() => _passes = List<Map<String, dynamic>>.from(
          (res.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        ));
      }
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: Stack(children: [
        Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border, width: 0.5))),
            child: Row(children: [
              GestureDetector(onTap: () => context.pop(), child: Container(width: 36, height: 36, alignment: Alignment.center, child: Icon(Icons.arrow_back, size: 22, color: t.text))),
              Expanded(child: Text('My Passes', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 17, color: t.text))),
              GestureDetector(
                onTap: () => setState(() => _redeemVisible = true),
                child: Container(width: 36, height: 36, alignment: Alignment.center, child: Icon(Icons.redeem, size: 22, color: t.primary)),
              ),
            ]),
          ),

          // Body
          Expanded(child: _loading
              ? Center(child: CircularProgressIndicator(color: t.primary))
              : _passes.isEmpty
                  ? _emptyState(t)
                  : _grid(t)),
        ]),

        // Redeem bottom sheet overlay
        if (_redeemVisible) _RedeemSheet(
          t: t,
          onDismiss: () => setState(() => _redeemVisible = false),
          onRedeemed: _fetch,
        ),
      ])),
    );
  }

  Widget _emptyState(_T t) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.confirmation_number, size: 56, color: t.textTertiary),
    const SizedBox(height: 10),
    Text('No passes yet', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text)),
    const SizedBox(height: 4),
    Text('Passes you earn will appear here', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary), textAlign: TextAlign.center),
  ]));

  Widget _grid(_T t) {
    final cardWidth = (MediaQuery.of(context).size.width - 48) / 2;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Wrap(spacing: 12, runSpacing: 12, children: _passes.map((p) => _PassCard(pass: p, t: t, cardWidth: cardWidth)).toList()),
    );
  }
}

// ─── Pass card ────────────────────────────────────────────────────────────────
class _PassCard extends StatefulWidget {
  final Map<String, dynamic> pass;
  final _T t;
  final double cardWidth;
  const _PassCard({required this.pass, required this.t, required this.cardWidth});
  @override
  State<_PassCard> createState() => _PassCardState();
}

class _PassCardState extends State<_PassCard> {
  bool _imgError = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.pass;
    final t = widget.t;
    final tier = p['pass_value']?.toString() ?? 'basic';
    final gradColors = _gradientFor(tier);
    final borderColor = _borderFor(tier, t.border);
    final quantity = (p['quantity'] as num?)?.toInt() ?? 1;
    final imageUrl = p['image_url']?.toString();

    return Container(
      width: widget.cardWidth,
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Image section
        AspectRatio(aspectRatio: 1.4, child: Stack(children: [
          Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors: gradColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: imageUrl != null && imageUrl.isNotEmpty && !_imgError
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    errorWidget: (_, __, ___) { _imgError = true; return _placeholder(); },
                  )
                : _placeholder(),
          ),
          if (quantity > 1) Positioned(top: 7, right: 7, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(10)),
            child: Text('×$quantity', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 11, color: Colors.white, letterSpacing: 0.2)),
          )),
        ])),
        // Info
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['name']?.toString() ?? 'Pass', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: t.text, height: 1.4)),
            if (p['description'] != null && p['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(p['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: t.textSecondary, height: 1.4)),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _placeholder() => Center(child: Icon(Icons.confirmation_number, size: 32, color: Colors.white.withValues(alpha: 0.5)));
}

// ─── Redeem bottom sheet ──────────────────────────────────────────────────────
class _RedeemSheet extends StatefulWidget {
  final _T t;
  final VoidCallback onDismiss;
  final VoidCallback onRedeemed;
  const _RedeemSheet({required this.t, required this.onDismiss, required this.onRedeemed});
  @override
  State<_RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends State<_RedeemSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _slide = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  Future<void> _redeem() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _result = null; });
    try {
      final res = await dioClient.post('/v1/user/me/passes/redeem', data: {'code': code});
      if (res.data['success'] == true && mounted) {
        setState(() => _result = Map<String, dynamic>.from(res.data['data'] as Map));
        widget.onRedeemed();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text((e as dynamic)?.response?.data?['message'] ?? 'Failed to redeem code', style: const TextStyle(fontFamily: 'Outfit')),
        backgroundColor: const Color(0xFFFF453A),
      ));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return GestureDetector(
      onTap: _close,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Column(children: [
          Expanded(child: GestureDetector(onTap: _close, child: const SizedBox.expand())),
          GestureDetector(
            onTap: () {},
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(_slide),
              child: Container(
                decoration: BoxDecoration(color: t.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)))),
                  if (_result != null)
                    _successState(t)
                  else
                    _inputState(t),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _inputState(_T t) {
    final canRedeem = _codeCtrl.text.trim().isNotEmpty && !_loading;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Redeem a Pass', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 17, color: t.text)),
        GestureDetector(onTap: _close, child: Icon(Icons.close, size: 20, color: t.textSecondary)),
      ]),
      const SizedBox(height: 4),
      Text('Enter your code below to claim your pass', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.textSecondary, height: 1.4)),
      const SizedBox(height: 12),
      Container(
        height: 52,
        decoration: BoxDecoration(color: t.inputBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.border)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Icon(Icons.vpn_key, size: 17, color: t.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: _codeCtrl,
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: t.text, letterSpacing: 1.5),
            decoration: InputDecoration(
              hintText: 'ENTER CODE',
              hintStyle: TextStyle(fontFamily: 'Outfit', color: t.textTertiary, letterSpacing: 1.5),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
            ),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]'))],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => canRedeem ? _redeem() : null,
            enabled: !_loading,
          )),
          if (_codeCtrl.text.isNotEmpty && !_loading)
            GestureDetector(onTap: () { _codeCtrl.clear(); setState(() {}); }, child: Icon(Icons.cancel, size: 16, color: t.textSecondary)),
        ]),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: canRedeem ? _redeem : null,
        child: Opacity(
          opacity: canRedeem ? 1.0 : 0.35,
          child: Container(
            height: 50, width: double.infinity,
            decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(14)),
            child: _loading
                ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : const Center(child: Text('Redeem', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white))),
          ),
        ),
      ),
    ]);
  }

  Widget _successState(_T t) {
    final passData = _result!['pass'] as Map? ?? {};
    final tier = passData['pass_value']?.toString() ?? 'basic';
    final gradColors = _gradientFor(tier);
    final tierLabel = _tierLabels[tier] ?? 'Basic';
    final qty = (_result!['quantity_granted'] as num?)?.toInt() ?? 1;
    final passName = passData['name']?.toString() ?? 'Pass';

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Accent bar
      Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(gradient: LinearGradient(colors: gradColors), borderRadius: BorderRadius.circular(2)),
      ),
      // Icon
      Stack(clipBehavior: Clip.none, children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(gradient: LinearGradient(colors: gradColors, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.confirmation_number, size: 34, color: Colors.white)),
        Positioned(bottom: -4, right: -4, child: Container(
          width: 22, height: 22,
          decoration: BoxDecoration(color: gradColors[1], shape: BoxShape.circle, border: Border.all(color: t.surface, width: 2)),
          child: const Icon(Icons.check, size: 11, color: Colors.white),
        )),
      ]),
      const SizedBox(height: 12),
      Text('Redeemed!', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 22, color: t.text)),
      const SizedBox(height: 3),
      Text('${qty > 1 ? '×$qty  ' : ''}$passName', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: gradColors[1].withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: gradColors[1].withValues(alpha: 0.27))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: gradColors[1], shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$tierLabel Pass', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 12, color: gradColors[1], letterSpacing: 0.3)),
        ]),
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: _close,
        child: Container(
          height: 50, width: double.infinity,
          decoration: BoxDecoration(gradient: LinearGradient(colors: gradColors), borderRadius: BorderRadius.circular(14)),
          child: const Center(child: Text('Done', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white, letterSpacing: 0.3))),
        ),
      ),
    ]);
  }
}
