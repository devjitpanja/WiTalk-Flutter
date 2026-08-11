import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../cache/app_cache_manager.dart';
import '../../providers/theme_provider.dart';
import '../../theme/theme_colors.dart';

const _prefWifi   = 'media_auto_dl_wifi';
const _prefMobile = 'media_auto_dl_mobile';

// ── Max cache labels ───────────────────────────────────────────────────────────

const _cacheLimits = [
  _CacheLimit('5 GB',     kCacheSize5GB),
  _CacheLimit('16 GB',    kCacheSize16GB),
  _CacheLimit('32 GB',    kCacheSize32GB),
  _CacheLimit('No Limit', kCacheSizeNoLimit),
];

class _CacheLimit {
  final String label;
  final int bytes;
  const _CacheLimit(this.label, this.bytes);
}

// ── Donut segment ─────────────────────────────────────────────────────────────

class _Segment {
  final String label;
  final int bytes;
  final Color color;
  const _Segment(this.label, this.bytes, this.color);
  double fraction(int total) => total == 0 ? 0 : bytes / total;
}

// ── Custom painter ────────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final List<_Segment> segments;
  final int total;
  _DonutPainter(this.segments, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final outer = size.width / 2;
    final inner = outer * 0.56;
    double startAngle = -1.5707963267948966; // -π/2

    for (final seg in segments) {
      if (seg.bytes == 0) continue;
      final sweep = seg.fraction(total) * 6.283185307179586; // 2π
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer - inner
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(
            center: Offset(cx, cy), radius: (outer + inner) / 2),
        startAngle,
        sweep - 0.015,
        false,
        paint,
      );
      startAngle += sweep;
    }

    // Empty state ring
    if (total == 0) {
      canvas.drawArc(
        Rect.fromCircle(
            center: Offset(cx, cy), radius: (outer + inner) / 2),
        0,
        6.283185307179586,
        false,
        Paint()
          ..color = const Color(0xFF2C2C2E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = outer - inner,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.total != total || old.segments != segments;
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class StorageDataScreen extends ConsumerStatefulWidget {
  const StorageDataScreen({super.key});
  @override
  ConsumerState<StorageDataScreen> createState() => _StorageDataScreenState();
}

class _StorageDataScreenState extends ConsumerState<StorageDataScreen> {
  CacheSnapshot? _snap;
  bool _calculating = true;
  bool _clearing = false;

  bool _autoWifi   = true;
  bool _autoMobile = false;

  int _maxCacheBytes = kCacheSize16GB;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _calculating = true);
    final prefs = await SharedPreferences.getInstance();
    _autoWifi   = prefs.getBool(_prefWifi)   ?? true;
    _autoMobile = prefs.getBool(_prefMobile) ?? false;
    _maxCacheBytes = await appCacheManager.getMaxCacheBytes();
    final snap = await appCacheManager.measure();
    if (mounted) setState(() { _snap = snap; _calculating = false; });
  }

  Future<void> _clearCategory({
    required String title,
    required String description,
    required Future<void> Function() action,
  }) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _clearing = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared'),
            backgroundColor: Color(0xFF30D158),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clear cache'),
            backgroundColor: Color(0xFFFF453A),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
      await _load();
    }
  }

  Future<void> _clearAll() => _clearCategory(
        title: 'Clear Entire Cache',
        description:
            'All cached images and videos will be deleted from this device. '
            'Messages and chat data are not affected. '
            'Media will re-download when needed.',
        action: () => appCacheManager.clearAllMediaCache(),
      );

  Future<void> _clearImages() => _clearCategory(
        title: 'Clear Image Cache',
        description:
            'All cached images will be deleted. They will re-download when '
            'you open a chat or profile.',
        action: () => appCacheManager.clearImageCache(),
      );

  Future<void> _clearVideos() => _clearCategory(
        title: 'Clear Video Cache',
        description: 'Cached video files will be deleted from this device.',
        action: () => appCacheManager.clearVideoCache(),
      );

  Future<void> _setMaxCache(int bytes) async {
    await appCacheManager.setMaxCacheBytes(bytes);
    setState(() => _maxCacheBytes = bytes);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final c = context.colors;
    final snap = _snap;
    final total = snap?.totalMediaBytes ?? 0;

    final segments = [
      _Segment('Images',   snap?.imageBytes ?? 0, const Color(0xFFFF9F0A)),
      _Segment('Videos',   snap?.videoBytes ?? 0, const Color(0xFF30D158)),
      _Segment('Messages', snap?.dbBytes    ?? 0, const Color(0xFF5E6AD2)),
    ].where((s) => s.bytes > 0).toList();

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(children: [
          _header(c),
          Expanded(
            child: _calculating
                ? Center(child: CupertinoActivityIndicator(color: c.textTertiary))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: c.primary,
                    child: CustomScrollView(slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            if (snap != null) ...[
                              _donut(c, snap, segments, total),
                              const SizedBox(height: 28),
                              _sectionLabel('STORAGE USAGE', c),
                              const SizedBox(height: 8),
                              _categoryList(c, snap),
                              const SizedBox(height: 20),
                              _clearAllButton(c, snap),
                              const SizedBox(height: 8),
                              Text(
                                'All media will remain available from the server '
                                'and can be re-downloaded if you need it again.',
                                style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 12,
                                    color: c.textTertiary,
                                    height: 1.5),
                              ),
                              const SizedBox(height: 28),
                            ],
                            _sectionLabel('MAXIMUM CACHE SIZE', c),
                            const SizedBox(height: 8),
                            _maxCacheCard(c),
                            const SizedBox(height: 8),
                            Text(
                              'If your cache size exceeds this limit, the oldest '
                              'unused media will be removed from your device.',
                              style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  color: c.textTertiary,
                                  height: 1.5),
                            ),
                            const SizedBox(height: 28),
                            _sectionLabel('MEDIA AUTO-DOWNLOAD', c),
                            const SizedBox(height: 8),
                            _autoDownloadCard(c),
                            const SizedBox(height: 8),
                            Text(
                              'When auto-download is off, images show a blurred '
                              'preview. Tap to download and view them.',
                              style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  color: c.textTertiary,
                                  height: 1.5),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(ThemeColors c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border, width: 0.5))),
        child: Row(children: [
          GestureDetector(
              onTap: () => context.pop(),
              child: Icon(Icons.arrow_back, color: c.text, size: 24)),
          const SizedBox(width: 12),
          Text(
            'Storage & Data',
            style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: c.text),
          ),
          if (_clearing) ...[
            const Spacer(),
            CupertinoActivityIndicator(color: c.textTertiary, radius: 9),
          ],
        ]),
      );

  // ── Donut ──────────────────────────────────────────────────────────────────

  Widget _donut(ThemeColors c, CacheSnapshot snap, List<_Segment> segs,
      int total) {
    return Column(children: [
      SizedBox(
        width: 200,
        height: 200,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
              size: const Size(200, 200),
              painter: _DonutPainter(segs, total)),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              fmtBytes(total),
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: c.text),
            ),
            Text(
              'Total',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: c.textTertiary),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Text(
        'Storage Usage',
        style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: c.text),
      ),
      const SizedBox(height: 4),
      Text(
        'WiTalk uses ${fmtBytes(snap.totalBytes)} on your device.',
        style: TextStyle(
            fontFamily: 'Outfit', fontSize: 13, color: c.textTertiary),
      ),
    ]);
  }

  // ── Category list ──────────────────────────────────────────────────────────

  Widget _categoryList(ThemeColors c, CacheSnapshot snap) {
    return _card(c, [
      _categoryRow(
        c: c,
        color: const Color(0xFFFF9F0A),
        icon: Icons.image_outlined,
        label: 'Images',
        bytes: snap.imageBytes,
        onClear: snap.imageBytes > 0 ? _clearImages : null,
        first: true,
      ),
      _divider(c),
      _categoryRow(
        c: c,
        color: const Color(0xFF30D158),
        icon: Icons.videocam_outlined,
        label: 'Videos',
        bytes: snap.videoBytes,
        onClear: snap.videoBytes > 0 ? _clearVideos : null,
      ),
      _divider(c),
      _categoryRow(
        c: c,
        color: const Color(0xFF5E6AD2),
        icon: Icons.chat_bubble_outline,
        label: 'Messages & Chats',
        bytes: snap.dbBytes,
        // DB is persistent — no clear button
      ),
    ]);
  }

  Widget _categoryRow({
    required ThemeColors c,
    required Color color,
    required IconData icon,
    required String label,
    required int bytes,
    VoidCallback? onClear,
    bool first = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: c.text)),
            const SizedBox(height: 2),
            Text(fmtBytes(bytes),
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    color: c.textTertiary)),
          ]),
        ),
        if (onClear != null)
          GestureDetector(
            onTap: _clearing ? null : onClear,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.border.withAlpha(60),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Clear',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: c.error),
              ),
            ),
          ),
      ]),
    );
  }

  // ── Clear all button ───────────────────────────────────────────────────────

  Widget _clearAllButton(ThemeColors c, CacheSnapshot snap) {
    final hasMedia = snap.totalMediaBytes > 0;
    return GestureDetector(
      onTap: (_clearing || !hasMedia) ? null : _clearAll,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: hasMedia ? c.error : c.error.withAlpha(60),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          _clearing
              ? 'Clearing…'
              : 'Clear Entire Cache${snap.totalMediaBytes > 0 ? '  ${fmtBytes(snap.totalMediaBytes)}' : ''}',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: hasMedia ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }

  // ── Max cache card ─────────────────────────────────────────────────────────

  Widget _maxCacheCard(ThemeColors c) {
    return _card(c, [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _cacheLimits.map((lim) {
            final selected = _maxCacheBytes == lim.bytes;
            return GestureDetector(
              onTap: () => _setMaxCache(lim.bytes),
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 52,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? c.primary : c.border.withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    lim.label,
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: selected ? Colors.white : c.textTertiary),
                  ),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  // ── Auto-download card ─────────────────────────────────────────────────────

  Widget _autoDownloadCard(ThemeColors c) {
    return _card(c, [
      _prefRow(
        c: c,
        icon: Icons.wifi,
        iconColor: c.primary,
        title: 'When on Wi-Fi',
        subtitle: _autoWifi
            ? 'Images download automatically'
            : 'Tap image to download',
        value: _autoWifi,
        onChanged: _toggleWifi,
      ),
      _divider(c),
      _prefRow(
        c: c,
        icon: Icons.signal_cellular_alt,
        iconColor: c.warning,
        title: 'When on Mobile Data',
        subtitle: _autoMobile
            ? 'Images download automatically'
            : 'Tap image to download',
        value: _autoMobile,
        onChanged: _toggleMobile,
      ),
    ]);
  }

  Widget _prefRow({
    required ThemeColors c,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: c.text)),
                  const SizedBox(height: 1),
                  Text(subtitle,
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: c.textTertiary)),
                ]),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: c.primary,
          ),
        ]),
      );

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, ThemeColors c) => Text(
        text,
        style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 11,
            color: c.textTertiary,
            letterSpacing: 0.8),
      );

  Widget _card(ThemeColors c, List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: c.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border, width: 0.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(children: children),
      );

  Widget _divider(ThemeColors c) =>
      Container(height: 0.5, color: c.border, margin: const EdgeInsets.symmetric(horizontal: 16));

  Future<void> _toggleWifi(bool v) async {
    setState(() => _autoWifi = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefWifi, v);
  }

  Future<void> _toggleMobile(bool v) async {
    setState(() => _autoMobile = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefMobile, v);
  }
}
