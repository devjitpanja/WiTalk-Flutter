import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../api/dio_client.dart';
import '../../providers/theme_provider.dart';

// ─── Theme helper ─────────────────────────────────────────────────────────────
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
  Color get avatarFallback => dark ? const Color(0x26007AFF) : const Color(0x14007AFF);
  Color get typeDotBorder => dark ? const Color(0xFF0d1017) : Colors.white;
  Color get subBlockBg => dark ? const Color(0x14DC2626) : const Color(0x0DDC2626);
  Color get subBlockBorder => const Color(0x33DC2626);
  Color get refundBg => dark ? const Color(0x1A2563EB) : const Color(0xFFDBEAFE);
  Color get emptyIconBg => dark ? const Color(0x1FD97706) : const Color(0xFFFEF3C7);
}

// ─── Status config ────────────────────────────────────────────────────────────
class _StatusCfg {
  final String label;
  final Color color;
  final Color bg;
  final IconData icon;
  const _StatusCfg(this.label, this.color, this.bg, this.icon);
}

const _statusMap = {
  'verified':  _StatusCfg('Active',     Color(0xFF16A34A), Color(0x1A16A34A), Icons.check_circle),
  'pending':   _StatusCfg('Pending',    Color(0xFFD97706), Color(0x1AD97706), Icons.schedule),
  'failed':    _StatusCfg('Failed',     Color(0xFFDC2626), Color(0x1ADC2626), Icons.error_outline),
  'refunded':  _StatusCfg('Refunded',   Color(0xFF2563EB), Color(0x1A2563EB), Icons.undo),
  'expired':   _StatusCfg('Expired',    Color(0xFF6B7280), Color(0x1A6B7280), Icons.history_toggle_off),
  'cancelled': _StatusCfg('Cancelled',  Color(0xFFDC2626), Color(0x1ADC2626), Icons.cancel),
};

_StatusCfg _statusCfg(String status) => _statusMap[status] ?? const _StatusCfg('Pending', Color(0xFFD97706), Color(0x1AD97706), Icons.schedule);

// ─── Filters ──────────────────────────────────────────────────────────────────
const _filters = [
  ('all',       'All'),
  ('verified',  'Active'),
  ('expired',   'Expired'),
  ('cancelled', 'Cancelled'),
  ('refunded',  'Refunded'),
];

// ─── Helpers ──────────────────────────────────────────────────────────────────
String _fmtDate(String? s) {
  if (s == null || s.isEmpty) return '—';
  try {
    final d = DateTime.parse(s).toLocal();
    return DateFormat('d MMM yyyy').format(d);
  } catch (_) { return '—'; }
}

String _fmtTime(String? s) {
  if (s == null || s.isEmpty) return '';
  try {
    final d = DateTime.parse(s).toLocal();
    return DateFormat('h:mm a').format(d);
  } catch (_) { return ''; }
}

String? _fmtPrice(dynamic micros, dynamic currency) {
  if (micros == null || currency == null) return null;
  try {
    final amt = (micros as num).toDouble() / 1_000_000;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(amt);
  } catch (_) {
    return '${((micros as num).toDouble() / 1_000_000).toStringAsFixed(2)} $currency';
  }
}

class _ExpiryInfo {
  final String label;
  final String time;
  final bool expired;
  _ExpiryInfo(this.label, this.time, this.expired);
}

_ExpiryInfo? _fmtMillis(dynamic ms) {
  if (ms == null) return null;
  try {
    final d = DateTime.fromMillisecondsSinceEpoch((ms as num).toInt()).toLocal();
    return _ExpiryInfo(DateFormat('d MMM yyyy').format(d), DateFormat('h:mm a').format(d), d.isBefore(DateTime.now()));
  } catch (_) { return null; }
}

Future<void> _openPlaySubscriptions() async {
  final url = Uri.parse('https://play.google.com/store/account/subscriptions');
  if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class MyPurchasesScreen extends ConsumerStatefulWidget {
  const MyPurchasesScreen({super.key});
  @override
  ConsumerState<MyPurchasesScreen> createState() => _MyPurchasesScreenState();
}

class _MyPurchasesScreenState extends ConsumerState<MyPurchasesScreen> {
  List<Map<String, dynamic>> _purchases = [];
  int _total = 0;
  int _offset = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _syncing = false;
  String _filter = 'all';

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetch(0, append: false);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && _hasMore && !_loadingMore) {
      _fetch(_offset + 20, append: true);
    }
  }

  Future<void> _fetch(int offset, {required bool append, String? status}) async {
    final s = status ?? _filter;
    if (offset == 0 && !append) {
      if (!mounted) return;
      setState(() => _loading = true);
    } else {
      if (!mounted) return;
      setState(() => _loadingMore = true);
    }
    try {
      final res = await dioClient.get('/v1/user/me/purchases', queryParameters: {
        'limit': 20,
        'offset': offset,
        'status': s,
      });
      final list = (res.data['purchases'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final pag = res.data['pagination'] as Map? ?? {};
      if (mounted) {
        setState(() {
          _purchases = append ? [..._purchases, ...list] : list;
          _total = (pag['total'] as num?)?.toInt() ?? 0;
          _offset = offset;
          _hasMore = pag['hasMore'] == true;
        });
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load purchases.'), backgroundColor: Color(0xFFDC2626)));
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  Future<void> _syncAndRefresh() async {
    setState(() => _syncing = true);
    try { await dioClient.post('/v1/user/me/sync-subscriptions'); } catch (_) {}
    await _fetch(0, append: false);
    if (mounted) setState(() => _syncing = false);
  }

  void _setFilter(String f) {
    if (f == _filter) return;
    setState(() { _filter = f; _purchases = []; _total = 0; _offset = 0; _hasMore = false; });
    _fetch(0, append: false, status: f);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: t.bg,
          child: Row(children: [
            GestureDetector(onTap: () => context.pop(), child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.arrow_back, color: t.text, size: 24))),
            const SizedBox(width: 12),
            Expanded(child: Text('Purchases & Subscriptions', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text))),
          ]),
        ),

        // ── Filter pills ─────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border, width: 0.5))),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              for (final (key, label) in _filters) ...[
                GestureDetector(
                  onTap: () => _setFilter(key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _filter == key ? t.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _filter == key ? t.primary : t.border),
                    ),
                    child: Text(label, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 12, color: _filter == key ? Colors.white : t.textSecondary)),
                  ),
                ),
              ],
              if (_syncing) Padding(padding: const EdgeInsets.only(left: 4), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: t.primary))),
            ]),
          ),
        ),

        // ── Count ────────────────────────────────────────────────────────────
        if (!_loading && _total > 0) Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Align(alignment: Alignment.centerLeft, child: Text('$_total purchase${_total != 1 ? 's' : ''}', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: t.textTertiary))),
        ),

        // ── Body ─────────────────────────────────────────────────────────────
        Expanded(child: _loading
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(color: t.primary),
                const SizedBox(height: 12),
                Text('Loading purchases…', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textTertiary)),
              ]))
            : CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _syncAndRefresh),
                  if (_purchases.isEmpty)
                    SliverFillRemaining(child: _emptyState(t))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            if (i == _purchases.length) return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: t.primary)));
                            return _card(_purchases[i], t, isDark);
                          },
                          childCount: _purchases.length + (_loadingMore ? 1 : 0),
                        ),
                      ),
                    ),
                ],
              )),
      ])),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────────
  Widget _emptyState(_T t) => ListView(children: [
    const SizedBox(height: 60),
    Column(children: [
      Container(width: 76, height: 76, decoration: BoxDecoration(color: t.emptyIconBg, shape: BoxShape.circle), child: const Icon(Icons.receipt_long, size: 38, color: Color(0xFFD97706))),
      const SizedBox(height: 16),
      Text('No purchases yet', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 17, color: t.text), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(
        _filter == 'all'
            ? 'When you buy or subscribe to a paid community, your transaction history will appear here.'
            : 'No $_filter purchases found.',
        style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.textSecondary, height: 1.5),
        textAlign: TextAlign.center,
      )),
    ]),
  ]);

  // ── Purchase card ─────────────────────────────────────────────────────────
  Widget _card(Map<String, dynamic> item, _T t, bool isDark) {
    final status = item['status']?.toString() ?? 'pending';
    final cfg = _statusCfg(status);
    final isSub = item['play_product_type'] == 'subscription';
    final price = _fmtPrice(item['price_amount_micros'], item['price_currency_code']);
    final expiry = isSub ? _fmtMillis(item['expiry_time_millis']) : null;
    final startDate = _fmtDate(item['purchased_at']?.toString());
    final startTime = _fmtTime(item['purchased_at']?.toString());
    final isCancelled = status == 'cancelled';
    final isExpired = status == 'expired' || isCancelled || (expiry?.expired == true && status != 'refunded');
    final communityPic = item['community_picture']?.toString();
    final communityName = item['community_name']?.toString() ?? item['entity_name']?.toString() ?? 'Community';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.border)),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Community header ─────────────────────────────────────────────────
        Row(children: [
          // Avatar + type dot
          SizedBox(width: 46, height: 46, child: Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(23), child: communityPic != null && communityPic.isNotEmpty
                ? CachedNetworkImage(imageUrl: communityPic, width: 46, height: 46, fit: BoxFit.cover)
                : Container(width: 46, height: 46, decoration: BoxDecoration(color: t.avatarFallback, shape: BoxShape.circle), child: Icon(Icons.group, size: 22, color: t.primary))),
            Positioned(bottom: -2, right: -2, child: Container(
              width: 18, height: 18,
              decoration: BoxDecoration(color: isSub ? const Color(0xFF7C3AED) : const Color(0xFF0891B2), shape: BoxShape.circle, border: Border.all(color: t.typeDotBorder, width: 1.5)),
              child: Icon(isSub ? Icons.autorenew : Icons.bolt, size: 9, color: Colors.white),
            )),
          ])),
          const SizedBox(width: 10),
          // Name + type
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(communityName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 14, color: t.text)),
            const SizedBox(height: 2),
            Text(isSub ? 'Subscription' : 'One-time Purchase', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: t.textSecondary)),
          ])),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: cfg.bg, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(cfg.icon, size: 12, color: cfg.color),
              const SizedBox(width: 4),
              Text(cfg.label, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 11, color: cfg.color)),
            ]),
          ),
        ]),

        // ── Divider ──────────────────────────────────────────────────────────
        Container(height: 0.5, margin: const EdgeInsets.symmetric(vertical: 12), color: t.border),

        // ── Price row ────────────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isSub ? 'SUBSCRIPTION FEE' : 'AMOUNT PAID', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: t.textSecondary, letterSpacing: 0.6)),
            const SizedBox(height: 2),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(price ?? '—', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 22, color: t.text)),
              if (isSub && price != null) Text(' / month', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.textSecondary)),
            ]),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('STARTED', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: t.textSecondary, letterSpacing: 0.6)),
            const SizedBox(height: 2),
            Text(startDate, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: t.text)),
            Text(startTime, style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: t.textTertiary)),
          ]),
        ]),

        // ── Subscription status block ─────────────────────────────────────
        if (isSub && isExpired && (expiry != null || isCancelled)) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: t.subBlockBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.subBlockBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (expiry != null) Row(children: [
                Icon(isExpired ? Icons.event_busy : Icons.event_available, size: 15, color: isExpired ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isCancelled ? 'CANCELLED ON' : isExpired ? 'EXPIRED ON' : 'ACCESS UNTIL', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: t.textTertiary, letterSpacing: 0.5)),
                  Text('${expiry.label} · ${expiry.time}', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: isExpired ? const Color(0xFFDC2626) : const Color(0xFF16A34A))),
                ])),
              ]),
              if (isCancelled) ...[
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline, size: 15, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('You cancelled this subscription. Community access has been removed.', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFFDC2626), height: 1.4))),
                ]),
              ],
            ]),
          ),
        ],

        // ── Subscription action buttons ───────────────────────────────────
        if (isSub) ...[
          const SizedBox(height: 12),
          isExpired
              ? GestureDetector(
                  onTap: _openPlaySubscriptions,
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.refresh, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(isCancelled ? 'Resubscribe' : 'Renew Subscription', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                    ]),
                  ),
                )
              : GestureDetector(
                  onTap: _openPlaySubscriptions,
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: t.border)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.settings, size: 14, color: t.textSecondary),
                      const SizedBox(width: 6),
                      Text('Manage / Cancel Subscription', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: t.textSecondary)),
                    ]),
                  ),
                ),
        ],

        // ── Refund notice ─────────────────────────────────────────────────
        if (status == 'refunded') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: t.refundBg, borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.undo, size: 13, color: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Expanded(child: Text('This purchase was refunded. Access has been removed.', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFF2563EB), height: 1.4))),
            ]),
          ),
        ],
      ]),
    );
  }
}
