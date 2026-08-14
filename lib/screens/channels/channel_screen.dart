import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../api/channel_api.dart';
import '../../theme/theme_colors.dart';
import '../../cache/witalk_image_cache.dart';

extension _CtxX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// Telegram-style bubble radius: all corners 16 except bottom-left = 6
const _kBubbleRadius = BorderRadius.only(
  topLeft: Radius.circular(16),
  topRight: Radius.circular(16),
  bottomRight: Radius.circular(16),
  bottomLeft: Radius.circular(6),
);

String _fmtViewCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}K';
  return '$n';
}

String _fmtTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
  } catch (_) { return ''; }
}

String _fmtDate(String? iso) {
  if (iso == null) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${mo[dt.month - 1]} ${dt.day}, ${dt.year}';
  } catch (_) { return ''; }
}

Map<String, dynamic>? _parseJson(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return raw;
  try { return json.decode(raw as String) as Map<String, dynamic>; } catch (_) { return null; }
}

Map<String, dynamic>? _resolvePoll(Map<String, dynamic> item) {
  var v = item['poll'] ?? item['poll_data'];
  if (v == null) return null;
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  final decoded = _parseJson(v);
  return decoded;
}

// ─── Date Divider ─────────────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final String label;
  const _DateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Container(height: 0.5, color: c.border.withValues(alpha: 0.5))),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: c.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border.withValues(alpha: 0.4), width: 0.5),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, color: c.textTertiary, fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Container(height: 0.5, color: c.border.withValues(alpha: 0.5))),
      ]),
    );
  }
}

// ─── Unread Divider ───────────────────────────────────────────────────────────
class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: Container(height: 1, color: c.primary.withValues(alpha: 0.35))),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('New messages', style: TextStyle(fontSize: 12, color: c.primary, fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Container(height: 1, color: c.primary.withValues(alpha: 0.35))),
      ]),
    );
  }
}

// ─── Pinned Banner ────────────────────────────────────────────────────────────
class _PinnedBanner extends StatelessWidget {
  final List<Map<String, dynamic>> pins;
  final int idx;
  final VoidCallback onTap;
  final VoidCallback onClose;
  const _PinnedBanner({required this.pins, required this.idx, required this.onTap, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pm = pins[idx];
    final t = pm['message_type'] as String? ?? 'text';
    final preview = t == 'image' ? '📷 Photo'
        : t == 'image_album' ? '📷 Photos'
        : (t == 'voice' || t == 'audio') ? '🎵 Voice message'
        : t == 'giphy_sticker' ? '😄 Sticker'
        : t == 'giphy_gif' ? '🎞️ GIF'
        : t == 'poll' ? '📊 ${_resolvePoll(pm)?['question'] ?? 'Poll'}'
        : (pm['content'] ?? '') as String;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
        ),
        child: Row(children: [
          if (pins.length > 1)
            Container(width: 3, height: 30, margin: const EdgeInsets.only(right: 6),
              child: Column(children: List.generate(pins.length, (i) => Expanded(
                child: Container(margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    color: i == idx ? c.primary : c.border,
                    borderRadius: BorderRadius.circular(2),
                  )),
              )))),
          Container(
            width: 3, height: 30, margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pins.length > 1 ? 'Pinned Message ${idx + 1} of ${pins.length}' : 'Pinned Message',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.primary)),
            const SizedBox(height: 1),
            Text(preview.toString(), style: TextStyle(fontSize: 13, color: c.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          GestureDetector(
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 18, color: c.textTertiary),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Compose Context Banner (reply / edit) ────────────────────────────────────
class _ComposeBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final String preview;
  final VoidCallback onDismiss;
  const _ComposeBanner({required this.icon, required this.label, required this.preview, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(children: [
        Container(width: 3, height: 28, margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(2))),
        Icon(icon, size: 16, color: c.primary),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.primary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(preview, style: TextStyle(fontSize: 13, color: c.textSecondary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        GestureDetector(onTap: onDismiss,
          child: Padding(padding: const EdgeInsets.all(4),
            child: Icon(Icons.close, size: 18, color: c.textTertiary))),
      ]),
    );
  }
}

// ─── Banned View ──────────────────────────────────────────────────────────────
class _BannedView extends StatelessWidget {
  final bool channelBanned;
  final String? reason;
  final bool isAdmin;
  final VoidCallback? onAction;
  const _BannedView({required this.channelBanned, this.reason, required this.isAdmin, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 90, height: 90,
            decoration: BoxDecoration(color: c.danger.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(channelBanned ? Icons.gavel_rounded : Icons.block_rounded, size: 44, color: c.danger)),
          const SizedBox(height: 18),
          Text(channelBanned ? 'Channel Banned' : "You've Been Banned",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text),
            textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(channelBanned
              ? 'This channel has been banned by the platform.'
              : 'You no longer have access to this channel.',
            style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.6), textAlign: TextAlign.center),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.danger.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.danger.withValues(alpha: 0.25)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 14, color: c.danger),
                const SizedBox(width: 6),
                Expanded(child: Text(reason!, style: TextStyle(fontSize: 13, color: c.danger, height: 1.5))),
              ]),
            ),
          ],
          if (onAction != null) ...[
            const SizedBox(height: 18),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: isAdmin ? c.surface : c.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isAdmin ? c.border : c.danger.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isAdmin ? Icons.mail_outline : Icons.exit_to_app,
                    size: 18, color: isAdmin ? c.text : c.danger),
                  const SizedBox(width: 8),
                  Text(isAdmin ? 'Contact Support' : 'Leave Channel',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                      color: isAdmin ? c.text : c.danger)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── Image Full-Screen Viewer ─────────────────────────────────────────────────
class _ImageViewer extends StatelessWidget {
  final List<String> urls;
  final int initial;
  const _ImageViewer({required this.urls, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(children: [
        PageView.builder(
          controller: PageController(initialPage: initial),
          itemCount: urls.length,
          itemBuilder: (ctx, i) => InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                cacheManager: WiTalkImageCache(),
                imageUrl: urls[i],
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Color(0xFFFFFFFF))),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Color(0xFFAAAAAA), size: 48),
              ),
            ),
          ),
        ),
        SafeArea(child: Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0x99000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Color(0xFFFFFFFF), size: 20),
            ),
          ),
        )),
      ]),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────
class _Bubble extends StatefulWidget {
  final Map<String, dynamic> item;
  final String channelName;
  final String? channelIcon;
  final bool highlighted;
  final bool pinned;
  final bool canVote;
  final bool isAdmin;
  final VoidCallback onLongPress;
  final void Function(String) onReact;
  final Future<void> Function(String) onScrollTo;
  final Future<void> Function(Map<String, dynamic>, List<int>) onVotePoll;

  const _Bubble({
    required this.item, required this.channelName, this.channelIcon,
    required this.highlighted, required this.pinned,
    required this.canVote, required this.isAdmin,
    required this.onLongPress, required this.onReact,
    required this.onScrollTo, required this.onVotePoll,
  });

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _alpha;
  bool _voting = false;
  List<int> _selectedPollIndices = [];

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _alpha = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(_Bubble old) {
    super.didUpdateWidget(old);
    if (widget.highlighted && !old.highlighted) {
      _ac.forward(from: 0).then((_) async {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) _ac.reverse();
      });
    }
  }

  Map<String, int> get _reactions {
    final raw = widget.item['reactions_detail'];
    if (raw == null) return {};
    List<dynamic> arr;
    if (raw is List) { arr = raw; }
    else { try { arr = json.decode(raw.toString()) as List; } catch (_) { return {}; } }
    final m = <String, int>{};
    for (final r in arr) {
      final e = (r as Map)['emoji'] as String?;
      if (e != null) m[e] = (m[e] ?? 0) + 1;
    }
    return m;
  }

  // ── Sub-builders ─────────────────────────────────────────────────────────────

  Widget _header(ThemeColors c) {
    final icon = widget.channelIcon;
    final init = widget.channelName.isNotEmpty ? widget.channelName[0].toUpperCase() : 'C';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 18, height: 18,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c.primary),
        clipBehavior: Clip.antiAlias,
        child: icon != null
          ? CachedNetworkImage(cacheManager: WiTalkImageCache(), imageUrl: icon, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Center(child: Text(init,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)))))
          : Center(child: Text(init,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)))),
      ),
      const SizedBox(width: 5),
      Text(widget.channelName,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.primary)),
    ]);
  }

  Widget _footer(ThemeColors c, {bool onDark = false}) {
    final vc = _fmtViewCount((widget.item['view_count'] as num?)?.toInt() ?? 0);
    final t = _fmtTime(widget.item['created_at'] as String?);
    final color = onDark ? const Color(0xCCFFFFFF) : c.textTertiary;
    return Row(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      if (widget.pinned) ...[
        Icon(Icons.push_pin_rounded, size: 11, color: color),
        const SizedBox(width: 3),
      ],
      Icon(Icons.visibility_outlined, size: 11, color: color),
      const SizedBox(width: 3),
      Text(vc, style: TextStyle(fontSize: 11, color: color)),
      const SizedBox(width: 5),
      Text(t, style: TextStyle(fontSize: 11, color: color)),
    ]);
  }

  Widget _timeOverlay(ThemeColors c) {
    final vc = _fmtViewCount((widget.item['view_count'] as num?)?.toInt() ?? 0);
    final t = _fmtTime(widget.item['created_at'] as String?);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x88000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (widget.pinned) ...[
          const Icon(Icons.push_pin_rounded, size: 11, color: Color(0xFFFFFFFF)),
          const SizedBox(width: 3),
        ],
        const Icon(Icons.visibility_outlined, size: 11, color: Color(0xFFFFFFFF)),
        const SizedBox(width: 3),
        Text(vc, style: const TextStyle(fontSize: 11, color: Color(0xFFFFFFFF))),
        const SizedBox(width: 5),
        Text(t, style: const TextStyle(fontSize: 11, color: Color(0xFFFFFFFF))),
      ]),
    );
  }

  Widget _replySnippet(ThemeColors c) {
    final raw = widget.item['reply_to'];
    if (raw == null) return const SizedBox.shrink();
    final rt = raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw as Map);
    final msgType = rt['message_type'] as String? ?? 'text';
    final preview = msgType == 'voice' ? '🎵 Voice message'
        : msgType == 'image' ? '📷 Photo'
        : msgType == 'image_album' ? '📷 Photos'
        : msgType == 'giphy_sticker' ? '😄 Sticker'
        : msgType == 'giphy_gif' ? '🎞️ GIF'
        : msgType == 'poll' ? '📊 Poll'
        : (rt['content'] ?? '') as String;
    return GestureDetector(
      onTap: () => widget.onScrollTo(rt['id'].toString()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: c.primary, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(preview, style: TextStyle(fontSize: 12, color: c.textSecondary),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _reactionsRow(ThemeColors c) {
    final counts = _reactions;
    if (counts.isEmpty) return const SizedBox.shrink();
    final my = widget.item['my_reaction'] as String?;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 5, runSpacing: 4, children: [
        for (final e in counts.entries)
          GestureDetector(
            onTap: () => widget.onReact(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: my == e.key ? c.primary.withValues(alpha: 0.15) : c.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: my == e.key ? c.primary : c.border,
                  width: my == e.key ? 1.5 : 1,
                ),
              ),
              child: Text('${e.key} ${e.value}',
                style: TextStyle(fontSize: 13, color: my == e.key ? c.primary : c.text)),
            ),
          ),
      ]),
    );
  }

  // ── Text / Video ─────────────────────────────────────────────────────────────
  Widget _buildText(ThemeColors c, bool dark) {
    final content = widget.item['content'] as String? ?? '';
    final msgType = widget.item['message_type'] as String? ?? 'text';
    final bubbleColor = dark ? const Color(0xFF1C2B3A) : const Color(0xFFFFFFFF);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: _kBubbleRadius,
        border: Border.all(color: c.border.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _header(c),
          const SizedBox(height: 6),
          _replySnippet(c),
          if (msgType == 'video') ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity, height: 180,
                color: const Color(0xFF111111),
                child: const Center(child: Icon(Icons.play_circle_filled_rounded, size: 52, color: Color(0xCCFFFFFF))),
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (content.isNotEmpty)
            Text(content, style: TextStyle(fontSize: 15, color: c.text, height: 1.45)),
          _reactionsRow(c),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: _footer(c)),
        ]),
      ),
    );
  }

  // ── Single Image ──────────────────────────────────────────────────────────────
  Widget _buildImage(ThemeColors c, bool dark) {
    final url = widget.item['media_url'] as String?;
    final md = _parseJson(widget.item['media_data']);
    final rawW = (md?['width'] as num?)?.toDouble() ?? 1.0;
    final rawH = (md?['height'] as num?)?.toDouble() ?? 1.0;
    final ar = rawW > 0 && rawH > 0 ? rawW / rawH : 1.0;
    final screenW = MediaQuery.of(context).size.width - 24;
    final imgH = (screenW / ar).clamp(120.0, 380.0);
    final caption = widget.item['content'] as String? ?? '';
    final hasCaption = caption.isNotEmpty;
    final bubbleColor = dark ? const Color(0xFF1C2B3A) : const Color(0xFFFFFFFF);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: _kBubbleRadius,
        border: Border.all(color: c.border.withValues(alpha: 0.4), width: 0.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 6), child: _header(c)),
        if (widget.item['reply_to'] != null)
          Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 6), child: _replySnippet(c)),
        if (url != null)
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _ImageViewer(urls: [url], initial: 0), fullscreenDialog: true)),
            child: Stack(children: [
              CachedNetworkImage(
                cacheManager: WiTalkImageCache(),
                imageUrl: url,
                width: double.infinity, height: imgH,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: double.infinity, height: imgH,
                  color: c.border.withValues(alpha: 0.3),
                  child: Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2))),
                errorWidget: (_, __, ___) => Container(
                  width: double.infinity, height: imgH,
                  color: c.border.withValues(alpha: 0.3),
                  child: Icon(Icons.broken_image, color: c.textSecondary, size: 36)),
              ),
              if (!hasCaption)
                Positioned(bottom: 8, right: 10, child: _timeOverlay(c)),
            ]),
          ),
        if (hasCaption || _reactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (hasCaption)
                Text(caption, style: TextStyle(fontSize: 15, color: c.text, height: 1.45)),
              _reactionsRow(c),
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: _footer(c)),
            ]),
          )
        else if (url == null)
          const SizedBox(height: 6),
      ]),
    );
  }

  // ── Album ─────────────────────────────────────────────────────────────────────
  Widget _buildAlbum(ThemeColors c, bool dark) {
    final md = _parseJson(widget.item['media_data']);
    final images = (md?['images'] as List?) ?? [];
    if (images.isEmpty) return _buildText(c, dark);
    final caption = widget.item['content'] as String? ?? '';
    final bubbleColor = dark ? const Color(0xFF1C2B3A) : const Color(0xFFFFFFFF);
    const tileSize = 200.0;
    final urls = images.map((img) => img['url'] as String? ?? '').where((u) => u.isNotEmpty).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: _kBubbleRadius,
        border: Border.all(color: c.border.withValues(alpha: 0.4), width: 0.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 6), child: _header(c)),
        if (widget.item['reply_to'] != null)
          Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 6), child: _replySnippet(c)),
        SizedBox(
          height: tileSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (_, i) {
              final url = images[i]['url'] as String?;
              return GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _ImageViewer(urls: urls, initial: i), fullscreenDialog: true)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: url != null
                    ? CachedNetworkImage(
                        cacheManager: WiTalkImageCache(),
                        imageUrl: url, width: tileSize, height: tileSize, fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: tileSize, height: tileSize,
                          color: c.border.withValues(alpha: 0.3)),
                        errorWidget: (_, __, ___) => Container(
                          width: tileSize, height: tileSize,
                          color: c.border.withValues(alpha: 0.3),
                          child: Icon(Icons.broken_image, color: c.textSecondary)))
                    : Container(width: tileSize, height: tileSize, color: c.border),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (caption.isNotEmpty) ...[
              Text(caption, style: TextStyle(fontSize: 15, color: c.text, height: 1.45)),
            ],
            _reactionsRow(c),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight, child: _footer(c)),
          ]),
        ),
      ]),
    );
  }

  // ── Poll ──────────────────────────────────────────────────────────────────────
  Widget _buildPoll(ThemeColors c, bool dark) {
    final poll = _resolvePoll(widget.item);
    if (poll == null) return _buildText(c, dark);

    final question = poll['question'] as String? ?? '';
    final options = poll['options'] is List
        ? List<String>.from((poll['options'] as List).map((e) => e.toString()))
        : <String>[];
    final voteCounts = poll['vote_counts'] is List
        ? List<int>.from((poll['vote_counts'] as List).map((e) => (e as num?)?.toInt() ?? 0))
        : <int>[];
    final myVotes = poll['my_votes'] is List
        ? List<int>.from((poll['my_votes'] as List).map((e) => (e as num?)?.toInt() ?? 0))
        : <int>[];
    final hasVoted = poll['has_voted'] == true;
    final total = (poll['total_votes'] as num?)?.toInt() ?? 0;
    final settings = poll['settings'] is Map
        ? Map<String, dynamic>.from(poll['settings'] as Map)
        : <String, dynamic>{};
    final isQuiz = settings['quiz'] == true;
    final isMultiple = !isQuiz && settings['multiple'] == true;
    final correctOption = isQuiz ? (settings['correct_option'] as num?)?.toInt() : null;
    final isClosed = poll['is_closed'] == true;
    final bubbleColor = dark ? const Color(0xFF1C2B3A) : const Color(0xFFFFFFFF);

    final displayResults = hasVoted || isClosed;
    final canSelect = !_voting && widget.canVote && !hasVoted && !isClosed;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: _kBubbleRadius,
        border: Border.all(color: c.border.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _header(c),
          const SizedBox(height: 8),
          Text(question,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text, height: 1.35)),
          const SizedBox(height: 4),
          Text(
            isQuiz ? 'Quiz' : isClosed ? 'Closed Poll' : 'Poll',
            style: TextStyle(fontSize: 12, color: c.textTertiary),
          ),
          const SizedBox(height: 10),
          ...List.generate(options.length, (idx) {
            final label = options[idx];
            final votes = idx < voteCounts.length ? voteCounts[idx] : 0;
            final pct = total > 0 ? votes / total : 0.0;
            final pctInt = (pct * 100).round();
            final isMyVote = myVotes.contains(idx);
            final isCorrect = isQuiz && correctOption == idx;
            final isWrongMyVote = isQuiz && isMyVote && !isCorrect;
            final isSelected = _selectedPollIndices.contains(idx);

            if (displayResults) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  SizedBox(width: 22, child: isCorrect
                    ? const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF4CAF50))
                    : isMyVote
                      ? Container(width: 8, height: 8, margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isWrongMyVote ? const Color(0xFFFF453A) : c.primary,
                          ))
                      : const SizedBox()),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      SizedBox(
                        width: 38,
                        child: Text('$pctInt%',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(label,
                        style: TextStyle(fontSize: 14, color: c.text), maxLines: 2)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 4,
                        child: LayoutBuilder(builder: (_, box) => Stack(children: [
                          Container(color: c.border),
                          Container(
                            width: box.maxWidth * pct,
                            color: isCorrect
                              ? const Color(0xFF4CAF50)
                              : isMyVote ? c.primary : c.textTertiary,
                          ),
                        ])),
                      ),
                    ),
                  ])),
                ]),
              );
            }

            return GestureDetector(
              onTap: canSelect ? () {
                setState(() {
                  if (isMultiple) {
                    if (_selectedPollIndices.contains(idx)) {
                      _selectedPollIndices = _selectedPollIndices.where((i) => i != idx).toList();
                    } else {
                      _selectedPollIndices = [..._selectedPollIndices, idx];
                    }
                  } else {
                    _selectedPollIndices = [idx];
                  }
                });
              } : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? c.primary : c.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 20, height: 20, margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      shape: isMultiple ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: isMultiple ? BorderRadius.circular(5) : null,
                      border: Border.all(color: isSelected ? c.primary : c.border, width: 2),
                      color: isSelected ? c.primary : null,
                    ),
                    child: isSelected
                      ? (isMultiple
                          ? const Icon(Icons.check, size: 13, color: Color(0xFFFFFFFF))
                          : Center(child: Container(width: 8, height: 8,
                              decoration: const BoxDecoration(shape: BoxShape.circle,
                                color: Color(0xFFFFFFFF)))))
                      : null,
                  ),
                  Expanded(child: Text(label,
                    style: TextStyle(fontSize: 15, color: c.text))),
                ]),
              ),
            );
          }),
          if (!displayResults && canSelect && _selectedPollIndices.isNotEmpty)
            GestureDetector(
              onTap: _voting ? null : () async {
                setState(() => _voting = true);
                try { await widget.onVotePoll(widget.item, List<int>.from(_selectedPollIndices)); }
                finally {
                  if (mounted) setState(() {
                    _voting = false;
                    _selectedPollIndices = [];
                  });
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _voting ? c.border : c.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: _voting
                    ? SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFFFFFFFF)))
                    : const Text('Vote',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                          color: Color(0xFFFFFFFF))),
                ),
              ),
            ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              total > 0 ? '$total vote${total == 1 ? '' : 's'}' : 'No votes',
              style: TextStyle(fontSize: 13, color: c.textSecondary)),
            if (isClosed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: c.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6)),
                child: Text('Closed', style: TextStyle(fontSize: 11, color: c.textTertiary))),
          ]),
          _reactionsRow(c),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: _footer(c)),
        ]),
      ),
    );
  }

  // ── Voice ─────────────────────────────────────────────────────────────────────
  Widget _buildVoice(ThemeColors c, bool dark) {
    final md = _parseJson(widget.item['media_data']);
    final dur = (md?['duration'] as num?)?.toInt() ?? 0;
    final m = dur ~/ 60;
    final s = (dur % 60).toString().padLeft(2, '0');
    final bubbleColor = dark ? const Color(0xFF1C2B3A) : const Color(0xFFFFFFFF);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: _kBubbleRadius,
        border: Border.all(color: c.border.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _header(c),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow_rounded, size: 28, color: c.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      c.primary,
                      c.primary.withValues(alpha: 0.2),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text('$m:$s', style: TextStyle(fontSize: 12, color: c.textTertiary)),
            ])),
          ]),
          _reactionsRow(c),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: _footer(c)),
        ]),
      ),
    );
  }

  // ── GIF ───────────────────────────────────────────────────────────────────────
  Widget _buildGif(ThemeColors c, bool dark) {
    final url = widget.item['media_url'] as String?;
    final md = _parseJson(widget.item['media_data']);
    final ar = (md?['aspectRatio'] as num?)?.toDouble() ?? 1.0;
    final safeAr = ar > 0 ? ar : 1.0;
    final screenW = MediaQuery.of(context).size.width - 24;
    final displayW = screenW * 0.72;
    final h = (displayW / safeAr).clamp(80.0, 280.0);
    final isSticker = widget.item['message_type'] == 'giphy_sticker';

    if (isSticker) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (url != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              cacheManager: WiTalkImageCache(),
              imageUrl: url,
              width: 140, height: 140, fit: BoxFit.contain,
              placeholder: (_, __) => Container(width: 140, height: 140,
                decoration: BoxDecoration(color: c.border.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12))),
              errorWidget: (_, __, ___) => Container(width: 140, height: 140, color: c.border.withValues(alpha: 0.2))),
          ),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _footer(c),
        ]),
        _reactionsRow(c),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (url != null)
        ClipRRect(
          borderRadius: _kBubbleRadius,
          child: Stack(children: [
            CachedNetworkImage(
              cacheManager: WiTalkImageCache(),
              imageUrl: url,
              width: displayW, height: h, fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: displayW, height: h,
                color: c.border.withValues(alpha: 0.3)),
              errorWidget: (_, __, ___) => Container(
                width: displayW, height: h,
                color: c.border.withValues(alpha: 0.3))),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0x44000000),
                  borderRadius: _kBubbleRadius,
                ),
              ),
            ),
            Center(
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xBB000000),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Center(
                  child: Text('GIF',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                      color: Color(0xFFFFFFFF), letterSpacing: 0.5)),
                ),
              ),
            ),
            Positioned(bottom: 8, right: 8, child: _timeOverlay(c)),
          ]),
        ),
      if (_reactions.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 4), child: _reactionsRow(c)),
    ]);
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = context.isDark;
    final type = widget.item['message_type'] as String? ?? 'text';

    Widget inner;
    if (type == 'image') inner = _buildImage(c, dark);
    else if (type == 'image_album') inner = _buildAlbum(c, dark);
    else if (type == 'poll') inner = _buildPoll(c, dark);
    else if (type == 'voice' || type == 'audio') inner = _buildVoice(c, dark);
    else if (type == 'giphy_gif' || type == 'giphy_sticker') inner = _buildGif(c, dark);
    else inner = _buildText(c, dark);

    return AnimatedBuilder(
      animation: _alpha,
      builder: (_, child) => Container(
        color: c.primary.withValues(alpha: _alpha.value * 0.15),
        child: child,
      ),
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 12, right: 12),
          child: inner,
        ),
      ),
    );
  }
}

// ─── ChannelScreen ────────────────────────────────────────────────────────────
class ChannelScreen extends StatefulWidget {
  final String channelId;
  final Map<String, dynamic>? initialChannel;
  final String? focusMessageId;

  const ChannelScreen({
    super.key,
    required this.channelId,
    this.initialChannel,
    this.focusMessageId,
  });

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  final _storage = const FlutterSecureStorage();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  Map<String, dynamic>? _channel;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _loadingOlder = false;
  bool _hasOlderMessages = false;
  bool _hasNewerMessages = false;
  bool _showScrollToBottom = false;

  String? _myUserId;
  String? _myRole;

  bool _isSubscribed = false;
  bool _isNotMember = false;
  bool _isBannedFromChannel = false;
  bool _isChannelAdminBanned = false;
  String? _banReason;

  List<Map<String, dynamic>> _pins = [];
  int _pinIdx = 0;
  bool _pinDismissed = false;
  String? _firstUnreadId;

  Map<String, dynamic>? _replyingTo;
  Map<String, dynamic>? _editingMsg;
  bool _uploadingImage = false;
  double _uploadProgress = 0;
  List<Map<String, dynamic>> _pendingImages = [];

  String? _highlightId;

  final Set<String> _viewedIds = {};
  final Set<String> _pendingViews = {};
  Timer? _viewTimer;

  bool get _isAdmin => _myRole == 'owner' || _myRole == 'admin';
  String get _chName => (_channel?['name'] ?? widget.initialChannel?['name'] ?? '') as String;
  String? get _chIcon => (_channel?['icon'] ?? widget.initialChannel?['icon']) as String?;

  @override
  void initState() {
    super.initState();
    _channel = widget.initialChannel;
    _isSubscribed = widget.initialChannel?['is_subscribed'] == 1 || widget.initialChannel?['is_subscribed'] == true;
    _isChannelAdminBanned = widget.initialChannel?['is_banned'] == true || widget.initialChannel?['is_banned'] == 1;
    _banReason = widget.initialChannel?['ban_reason'] as String?;
    _scrollCtrl.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _textCtrl.dispose(); _scrollCtrl.dispose(); _focusNode.dispose();
    _viewTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollCtrl.position;
    final fromBottom = pos.maxScrollExtent - pos.pixels;
    final show = fromBottom > 150;
    if (show != _showScrollToBottom) setState(() => _showScrollToBottom = show);
    if (pos.pixels <= 100 && _hasOlderMessages && !_loadingOlder) _loadOlder();
  }

  Future<void> _init() async {
    _myUserId = await _storage.read(key: 'uid');
    if (_isChannelAdminBanned) {
      _myRole = widget.initialChannel?['my_role'] as String?;
      if (mounted) setState(() { _loading = false; _isSubscribed = true; });
      return;
    }
    _fetchMeta();
    if (widget.focusMessageId != null) {
      await _loadAround(widget.focusMessageId!);
    } else {
      await _loadMessages();
    }
    _loadPins();
  }

  Future<void> _fetchMeta() async {
    try {
      final res = await ChannelApi.getById(widget.channelId);
      final ch = res.data?['channel'] as Map<String, dynamic>?;
      if (ch == null || !mounted) return;
      setState(() {
        _channel = ch;
        _isSubscribed = ch['is_subscribed'] == 1 || ch['is_subscribed'] == true;
        _myRole = ch['my_role'] as String?;
        if (ch['is_banned'] == true || ch['is_banned'] == 1) {
          _isChannelAdminBanned = true;
          _banReason = ch['ban_reason'] as String?;
          _loading = false;
        }
        if (ch['is_banned_from_channel'] == true) {
          _isBannedFromChannel = true;
          _loading = false;
        }
      });
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final res = await ChannelApi.getMessages(widget.channelId, params: {'limit': 20});
      final data = res.data as Map<String, dynamic>?;
      final msgs = List<Map<String, dynamic>>.from(data?['messages'] ?? []);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _hasOlderMessages = data?['has_older'] == true;
        _firstUnreadId = data?['first_unread_id'] as String?;
        if (data?['is_member'] == false) _isNotMember = true;
        _loading = false;
      });
      if (msgs.isNotEmpty && data?['is_member'] != false) {
        unawaited(ChannelApi.markRead(widget.channelId, msgs.last['id'].toString()).then((_) {}).catchError((_) {}));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAround(String id) async {
    try {
      final res = await ChannelApi.getMessagesAround(widget.channelId, id);
      final data = res.data as Map<String, dynamic>?;
      final msgs = List<Map<String, dynamic>>.from(data?['messages'] ?? []);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _hasOlderMessages = data?['has_older'] == true;
        _hasNewerMessages = data?['has_newer'] == true;
        _firstUnreadId = null;
        _loading = false;
      });
    } catch (_) { await _loadMessages(); }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasOlderMessages || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final oldest = _messages.first['created_at'] as String?;
      final res = await ChannelApi.getMessages(widget.channelId, params: {'limit': 10, 'before': oldest});
      final older = List<Map<String, dynamic>>.from(res.data?['messages'] ?? []);
      if (older.isNotEmpty && mounted) {
        setState(() {
          _messages = [...older, ..._messages];
          _hasOlderMessages = res.data?['has_older'] == true;
        });
      } else {
        if (mounted) setState(() => _hasOlderMessages = false);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingOlder = false);
  }

  Future<void> _loadPins() async {
    try {
      final res = await ChannelApi.getPinnedMessages(widget.channelId);
      final p = List<Map<String, dynamic>>.from(res.data?['pinned_messages'] ?? []);
      if (mounted) setState(() => _pins = p);
    } catch (_) {}
  }

  void _trackView(String id) {
    if (_viewedIds.contains(id)) return;
    _pendingViews.add(id);
    _viewTimer?.cancel();
    _viewTimer = Timer(const Duration(milliseconds: 1500), () {
      if (_pendingViews.isEmpty) return;
      final ids = List<String>.from(_pendingViews);
      _pendingViews.clear(); _viewedIds.addAll(ids);
      unawaited(ChannelApi.trackViews(widget.channelId, ids).then((_) {}).catchError((_) {}));
    });
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollCtrl.hasClients) return;
    if (animated) {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    }
  }

  Future<void> _scrollToMsg(String id) async {
    final idx = _messages.indexWhere((m) => m['id'].toString() == id);
    if (idx != -1) {
      final est = _messages.length * 140.0;
      final target = (idx / _messages.length) * est;
      _scrollCtrl.animateTo(target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      setState(() => _highlightId = id);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) setState(() => _highlightId = null);
    } else {
      await _loadAround(id);
    }
  }

  Future<void> _scrollToLatest() async {
    setState(() => _showScrollToBottom = false);
    if (_hasNewerMessages) {
      setState(() => _hasNewerMessages = false);
      await _loadMessages();
    } else {
      _scrollToBottom();
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────────
  void _onLongPress(Map<String, dynamic> msg) {
    if (!_isSubscribed) { _snack('Join the channel to interact'); return; }
    final type = msg['message_type'] as String? ?? 'text';
    final poll = _resolvePoll(msg);
    final hasVoted = poll?['has_voted'] == true;
    final isQuiz = poll?['settings'] is Map && (poll!['settings'] as Map)['quiz'] == true;
    final isMyMsg = msg['sender_id']?.toString() == _myUserId;

    _showActionsSheet(
      msg: msg,
      onReact: (e) => _react(msg['id'].toString(), e),
      onCopy: () => _copy(msg),
      onReply: _isAdmin ? () => _reply(msg) : null,
      onEdit: (_isAdmin && isMyMsg && type == 'text') ? () => _edit(msg) : null,
      onPin: _isAdmin ? () => _pin(msg) : null,
      onDelete: _isAdmin ? () => _delete(msg) : null,
      onTranslate: (!_isAdmin && type == 'text') ? () => _snack('Translation coming soon') : null,
      onReport: !_isAdmin ? () => _snack('Report submitted') : null,
      onRetractVote: (type == 'poll' && hasVoted && !isQuiz) ? () => _retractVote(msg) : null,
    );
  }

  Future<void> _votePoll(Map<String, dynamic> msg, List<int> optionIndices) async {
    try {
      final res = await ChannelApi.votePoll(widget.channelId, msg['id'].toString(), optionIndices);
      final updatedPoll = res.data?['poll'] as Map<String, dynamic>?;
      if (updatedPoll != null && mounted) {
        setState(() {
          _messages = _messages.map((m) =>
            m['id'].toString() == msg['id'].toString()
              ? {...m, 'poll': updatedPoll, 'poll_data': null}
              : m).toList();
        });
      }
    } catch (_) { _snack('Failed to vote', error: true); }
  }

  Future<void> _react(String msgId, String emoji) async {
    try {
      final res = await ChannelApi.react(widget.channelId, msgId, emoji);
      final reactions = (res.data?['reactions'] as List?) ?? [];
      final action = res.data?['action'] as String?;
      final my = action == 'added' ? emoji : null;
      if (!mounted) return;
      setState(() {
        _messages = _messages.map((m) {
          if (m['id'].toString() != msgId) return m;
          final detail = reactions.expand<Map<String, dynamic>>((r) {
            final count = int.tryParse(r['count'].toString()) ?? 0;
            return List.generate(count, (_) => {'emoji': r['emoji'], 'user_id': _myUserId});
          }).toList();
          return {...m, 'reactions_detail': detail, 'my_reaction': my};
        }).toList();
      });
    } catch (_) {}
  }

  void _copy(Map<String, dynamic> msg) {
    final c = msg['content'] as String?;
    if (c != null && c.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: c));
      _snack('Copied', success: true);
    }
  }

  void _reply(Map<String, dynamic> msg) {
    setState(() { _replyingTo = msg; _editingMsg = null; });
    _focusNode.requestFocus();
  }

  void _edit(Map<String, dynamic> msg) {
    setState(() {
      _editingMsg = msg; _replyingTo = null;
      _textCtrl.text = msg['content'] as String? ?? '';
    });
    _focusNode.requestFocus();
  }

  Future<void> _pin(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    final isPinned = item['is_pinned'] == 1 || item['is_pinned'] == true;
    try {
      if (isPinned) {
        await ChannelApi.unpinMessage(widget.channelId, id);
        if (!mounted) return;
        setState(() {
          _messages = _messages.map((m) => m['id'].toString() == id ? {...m, 'is_pinned': 0} : m).toList();
          _pins = _pins.where((p) => p['id'].toString() != id).toList();
          _pinIdx = 0;
        });
      } else {
        await ChannelApi.pinMessage(widget.channelId, id);
        if (!mounted) return;
        setState(() {
          _messages = _messages.map((m) => m['id'].toString() == id ? {...m, 'is_pinned': 1} : m).toList();
          _pinDismissed = false;
        });
        _loadPins();
      }
    } catch (_) { _snack('Could not update pin', error: true); }
  }

  Future<void> _delete(Map<String, dynamic> msg) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) {
      final c = context.colors;
      return AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete Message', style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w600)),
        content: Text('This message will be permanently deleted.', style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: c.danger, fontWeight: FontWeight.w600))),
        ],
      );
    });
    if (ok != true) return;
    try {
      await ChannelApi.deleteMessage(widget.channelId, msg['id'].toString());
      if (!mounted) return;
      setState(() {
        _messages = _messages.where((m) => m['id'].toString() != msg['id'].toString()).toList();
        _pins = _pins.where((p) => p['id'].toString() != msg['id'].toString()).toList();
      });
    } catch (_) { _snack('Could not delete', error: true); }
  }

  Future<void> _retractVote(Map<String, dynamic> msg) async {
    try {
      final res = await ChannelApi.retractVote(widget.channelId, msg['id'].toString());
      final updatedPoll = res.data?['poll'] as Map<String, dynamic>?;
      if (updatedPoll != null && mounted) {
        setState(() {
          _messages = _messages.map((m) =>
            m['id'].toString() == msg['id'].toString()
              ? {...m, 'poll': updatedPoll, 'poll_data': null}
              : m).toList();
        });
      }
    } catch (_) {}
  }

  // ── Send ──────────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final trimmed = _textCtrl.text.trim();
    if ((trimmed.isEmpty && _pendingImages.isEmpty) || _sending) return;
    setState(() => _sending = true);

    if (_pendingImages.isNotEmpty) {
      final imgs = List<Map<String, dynamic>>.from(_pendingImages);
      final cap = trimmed;
      final rid = _replyingTo?['id']?.toString();
      setState(() {
        _pendingImages.clear(); _textCtrl.clear(); _replyingTo = null;
        _uploadingImage = true; _uploadProgress = 0;
      });
      try {
        final uploaded = imgs.map((i) => {'url': i['uri'] as String, 'width': i['width'] ?? 1080, 'height': i['height'] ?? 1080}).toList();
        final single = uploaded.length == 1;
        final res = await ChannelApi.sendMessage(widget.channelId, {
          'content': cap.isEmpty ? null : cap,
          'message_type': single ? 'image' : 'image_album',
          'media_url': uploaded.first['url'],
          'media_data': single
            ? {'width': uploaded.first['width'], 'height': uploaded.first['height']}
            : {'images': uploaded},
          if (rid != null) 'reply_to_id': rid,
        });
        final m = res.data?['message'] as Map<String, dynamic>?;
        if (m != null && mounted) {
          setState(() {
            if (!_messages.any((x) => x['id'].toString() == m['id'].toString())) {
              _messages = [..._messages, m];
            }
          });
          _scrollToBottom();
        }
      } catch (_) { _snack('Failed to send image', error: true); }
      finally {
        if (mounted) setState(() { _uploadingImage = false; _uploadProgress = 0; _sending = false; });
      }
      return;
    }

    _textCtrl.clear();

    if (_editingMsg != null) {
      final editing = _editingMsg!;
      setState(() => _editingMsg = null);
      try {
        await ChannelApi.editMessage(widget.channelId, editing['id'].toString(), trimmed);
        if (!mounted) return;
        setState(() {
          _messages = _messages.map((m) =>
            m['id'].toString() == editing['id'].toString()
              ? {...m, 'content': trimmed, 'is_edited': 1}
              : m).toList();
        });
      } catch (_) {
        _snack('Failed to edit', error: true);
        _textCtrl.text = trimmed;
        if (mounted) setState(() => _editingMsg = editing);
      }
      finally { if (mounted) setState(() => _sending = false); }
      return;
    }

    final rid = _replyingTo?['id']?.toString();
    setState(() => _replyingTo = null);
    try {
      final res = await ChannelApi.sendMessage(widget.channelId, {
        'content': trimmed, 'message_type': 'text',
        if (rid != null) 'reply_to_id': rid,
      });
      final m = res.data?['message'] as Map<String, dynamic>?;
      if (m != null && mounted) {
        setState(() {
          if (!_messages.any((x) => x['id'].toString() == m['id'].toString())) {
            _messages = [..._messages, m];
          }
        });
        _scrollToBottom();
        unawaited(ChannelApi.markRead(widget.channelId, m['id'].toString()).then((_) {}).catchError((_) {}));
      }
    } catch (_) {
      _snack('Failed to send', error: true);
      _textCtrl.text = trimmed;
    }
    finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _pickImages() async {
    final rem = 10 - _pendingImages.length;
    if (rem <= 0) { _snack('Max 10 photos'); return; }
    final res = await ImagePicker().pickMultiImage(limit: rem);
    if (res.isEmpty) return;
    final picked = res.map((f) => {'uri': f.path, 'width': 1080, 'height': 1080}).toList();
    if (mounted) setState(() => _pendingImages = [..._pendingImages, ...picked].take(10).toList());
  }

  Future<void> _subscribe() async {
    try {
      if (_isSubscribed) {
        await ChannelApi.unsubscribe(widget.channelId);
        if (mounted) setState(() => _isSubscribed = false);
      } else {
        await ChannelApi.subscribe(widget.channelId);
        if (mounted) setState(() { _isSubscribed = true; _isNotMember = false; });
        _loadMessages();
      }
    } catch (_) { _snack('Could not update subscription', error: true); }
  }

  void _snack(String t, {bool error = false, bool success = false}) {
    if (!mounted) return;
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t, style: const TextStyle(color: Color(0xFFFFFFFF))),
      backgroundColor: error ? c.danger : success ? c.success : c.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(milliseconds: 2500),
    ));
  }

  void _showActionsSheet({
    required Map<String, dynamic> msg,
    required void Function(String) onReact,
    required VoidCallback onCopy,
    VoidCallback? onReply, VoidCallback? onEdit, VoidCallback? onPin,
    VoidCallback? onDelete, VoidCallback? onTranslate, VoidCallback? onReport,
    VoidCallback? onRetractVote,
  }) {
    final c = context.colors;
    const emojis = ['👍','❤️','😂','😮','😢','🔥','🎉','👏'];
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: c.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
        // Emoji reaction bar
        Container(
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: emojis.map((e) => GestureDetector(
              onTap: () { Navigator.pop(ctx); onReact(e); },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 8),
        if (onReply != null) _actionTile(ctx, Icons.reply_rounded, 'Reply', c.text, onReply),
        _actionTile(ctx, Icons.copy_rounded, 'Copy', c.text, onCopy),
        if (onEdit != null) _actionTile(ctx, Icons.edit_outlined, 'Edit', c.text, onEdit),
        if (onPin != null) _actionTile(ctx,
          msg['is_pinned'] == 1 ? Icons.push_pin : Icons.push_pin_outlined,
          msg['is_pinned'] == 1 ? 'Unpin' : 'Pin', c.text, onPin),
        if (onRetractVote != null) _actionTile(ctx, Icons.undo_rounded, 'Retract Vote', c.text, onRetractVote),
        if (onTranslate != null) _actionTile(ctx, Icons.translate_rounded, 'Translate', c.text, onTranslate),
        if (onReport != null) _actionTile(ctx, Icons.flag_outlined, 'Report', c.danger, onReport),
        if (onDelete != null) _actionTile(ctx, Icons.delete_outline_rounded, 'Delete', c.danger, onDelete),
        const SizedBox(height: 4),
      ])),
    );
  }

  Widget _actionTile(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(color: color, fontSize: 15)),
      onTap: () { Navigator.pop(ctx); onTap(); },
      dense: true,
      horizontalTitleGap: 8,
    );
  }

  // ── List data ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _listData {
    final out = <Map<String, dynamic>>[];
    String? lastDate;
    bool unreadDone = false;
    for (final m in _messages) {
      if (_firstUnreadId != null && !unreadDone && m['id'].toString() == _firstUnreadId) {
        out.add({'type': 'unread', 'id': 'ud'});
        unreadDone = true;
      }
      final iso = m['created_at'] as String?;
      if (iso != null) {
        try {
          final d = DateTime.parse(iso).toLocal();
          final ds = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
          if (ds != lastDate) {
            out.add({'type': 'date', 'id': 'date_$ds', 'iso': iso});
            lastDate = ds;
          }
        } catch (_) {}
      }
      out.add(m);
    }
    return out;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = context.isDark;
    final bgColor = dark ? const Color(0xFF0E1621) : const Color(0xFFE4EDF5);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(child: Column(children: [
        _buildHeader(c, dark),
        if (_isChannelAdminBanned)
          Expanded(child: _BannedView(channelBanned: true, reason: _banReason, isAdmin: _isAdmin,
            onAction: _isAdmin ? () {} : null))
        else
          Expanded(child: Column(children: [
            if (_pins.isNotEmpty && !_pinDismissed)
              _PinnedBanner(
                pins: _pins, idx: _pinIdx,
                onTap: () {
                  _scrollToMsg(_pins[_pinIdx]['id'].toString());
                  if (_pins.length > 1) setState(() => _pinIdx = (_pinIdx + 1) % _pins.length);
                },
                onClose: () => setState(() => _pinDismissed = true),
              ),
            Expanded(child: _loading
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : _buildList(c, dark)),
            if (_isBannedFromChannel)
              Container(
                padding: const EdgeInsets.all(14),
                color: c.danger.withValues(alpha: 0.08),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.block_rounded, size: 16, color: c.danger),
                  const SizedBox(width: 8),
                  Text('You have been banned from this channel',
                    style: TextStyle(color: c.danger, fontSize: 13, fontWeight: FontWeight.w500)),
                ])),
            if (_isNotMember && !_isBannedFromChannel) _buildJoinBar(c),
            if (_isAdmin && !_isChannelAdminBanned) _buildInputArea(c, dark),
          ])),
      ])),
    );
  }

  Widget _buildHeader(ThemeColors c, bool dark) {
    final sub = (_channel?['subscriber_count'] as num?)?.toInt() ?? 0;
    final verified = _channel?['is_verified'] == 1;
    final icon = _chIcon;
    final init = _chName.isNotEmpty ? _chName[0].toUpperCase() : 'C';
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF17212B) : const Color(0xFFFFFFFF),
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(children: [
        IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.primary, size: 20),
          onPressed: () => context.pop()),
        GestureDetector(
          onTap: _isSubscribed && !_isChannelAdminBanned
            ? () => context.push('/channel-info/${widget.channelId}') : null,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.primary),
            clipBehavior: Clip.antiAlias,
            child: icon != null
              ? CachedNetworkImage(
                  cacheManager: WiTalkImageCache(),
                  imageUrl: icon, width: 40, height: 40, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Center(child: Text(init,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)))))
              : Center(child: Text(init,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF))))),
        ),
        const SizedBox(width: 10),
        Expanded(child: GestureDetector(
          onTap: _isSubscribed && !_isChannelAdminBanned
            ? () => context.push('/channel-info/${widget.channelId}') : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(_chName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (verified) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF0751df)),
              ],
            ]),
            Text(
              sub > 0 ? '$sub subscriber${sub == 1 ? '' : 's'}' : 'Channel',
              style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ]),
        )),
      ]),
    );
  }

  Widget _buildList(ThemeColors c, bool dark) {
    final data = _listData;
    final hasMessages = data.any((d) => d['type'] == null);
    return Stack(children: [
      ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: data.length + (_loadingOlder ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (_loadingOlder && i == 0) {
            return Padding(padding: const EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2)));
          }
          final item = data[_loadingOlder ? i - 1 : i];
          final t = item['type'] as String?;
          if (t == 'date') return _DateDivider(label: _fmtDate(item['iso'] as String?));
          if (t == 'unread') return const _UnreadDivider();
          final id = item['id']?.toString() ?? '';
          _trackView(id);
          final pinned = _pins.any((p) => p['id'].toString() == id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _Bubble(
              item: item,
              channelName: _chName,
              channelIcon: _chIcon,
              highlighted: _highlightId == id,
              pinned: pinned,
              canVote: _isSubscribed,
              isAdmin: _isAdmin,
              onLongPress: () => _onLongPress(item),
              onReact: (e) => _react(id, e),
              onScrollTo: _scrollToMsg,
              onVotePoll: _votePoll,
            ),
          );
        },
      ),

      // Empty state
      if (!hasMessages && !_loading)
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.campaign_outlined, size: 36, color: c.primary.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 14),
          Text('No posts yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textSecondary)),
          const SizedBox(height: 4),
          Text('Check back later', style: TextStyle(fontSize: 13, color: c.textTertiary)),
        ])),

      // Back to latest button (context load)
      if (_hasNewerMessages)
        Positioned(bottom: 12, left: 0, right: 0, child: Center(child: GestureDetector(
          onTap: _scrollToLatest,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: c.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFFFFFFFF)),
              SizedBox(width: 4),
              Text('Back to Latest', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))),
            ]),
          ),
        ))),

      // Scroll to bottom FAB
      if (!_hasNewerMessages && _showScrollToBottom)
        Positioned(bottom: 14, right: 14, child: GestureDetector(
          onTap: _scrollToLatest,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF1C2B3A) : const Color(0xFFFFFFFF),
              shape: BoxShape.circle,
              border: Border.all(color: c.border.withValues(alpha: 0.5), width: 0.5),
              boxShadow: [BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: dark ? 0.35 : 0.15),
                blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Icon(Icons.keyboard_arrow_down_rounded, size: 24,
              color: dark ? const Color(0xFFCCCCCC) : const Color(0xFF333333))),
        )),
    ]);
  }

  Widget _buildJoinBar(ThemeColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: SizedBox(width: double.infinity,
        child: GestureDetector(
          onTap: _subscribe,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Center(
              child: Text('Join Channel',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))),
            ),
          ),
        )),
    );
  }

  Widget _buildInputArea(ThemeColors c, bool dark) {
    final hasContent = _textCtrl.text.trim().isNotEmpty || _pendingImages.isNotEmpty;
    final inputBg = dark ? const Color(0xFF17212B) : const Color(0xFFFFFFFF);
    final fieldBg = dark ? const Color(0xFF0E1621) : const Color(0xFFF0F2F5);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_replyingTo != null)
        _ComposeBanner(
          icon: Icons.reply_rounded,
          label: _replyingTo?['sender_name'] as String? ?? 'Unknown',
          preview: _previewType(_replyingTo!),
          onDismiss: () => setState(() => _replyingTo = null)),
      if (_editingMsg != null)
        _ComposeBanner(
          icon: Icons.edit_outlined,
          label: 'Editing message',
          preview: _editingMsg?['content'] as String? ?? '',
          onDismiss: () => setState(() { _editingMsg = null; _textCtrl.clear(); })),

      // Pending images strip
      if (_pendingImages.isNotEmpty)
        Container(
          height: 88,
          color: inputBg,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _pendingImages.length + (_pendingImages.length < 10 ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              if (i == _pendingImages.length) {
                return GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.border, width: 1.5)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 22, color: c.textSecondary),
                      const SizedBox(height: 2),
                      Text('${10 - _pendingImages.length} left',
                        style: TextStyle(fontSize: 10, color: c.textTertiary)),
                    ])));
              }
              return Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(width: 72, height: 72, color: c.border),
                ),
                Positioned(top: 2, right: 2, child: GestureDetector(
                  onTap: () {
                    final list = [..._pendingImages]; list.removeAt(i);
                    setState(() => _pendingImages = list);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xBB000000),
                      borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close, size: 13, color: Color(0xFFFFFFFF))))),
              ]);
            },
          )),

      // Upload progress
      if (_uploadingImage)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          color: inputBg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: c.border,
                valueColor: AlwaysStoppedAnimation<Color>(c.primary),
                minHeight: 3)),
            const SizedBox(height: 4),
            Text('Uploading…', style: TextStyle(fontSize: 11, color: c.textTertiary)),
          ])),

      // Input row
      Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: inputBg,
          border: Border(top: BorderSide(color: c.border, width: 0.5)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Attach button
          GestureDetector(
            onTap: () => _attachSheet(c),
            child: Container(
              width: 38, height: 38,
              margin: const EdgeInsets.only(right: 8, bottom: 3),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.attach_file_rounded, size: 20, color: c.primary)),
          ),
          // Text field
          Expanded(child: Container(
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(22),
            ),
            constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: TextField(
                  controller: _textCtrl,
                  focusNode: _focusNode,
                  style: TextStyle(fontSize: 15, color: c.text),
                  maxLines: null,
                  maxLength: 2000,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  decoration: InputDecoration(
                    hintText: _editingMsg != null ? 'Edit message…'
                      : _pendingImages.isNotEmpty ? 'Add a caption…'
                      : 'Broadcast a message…',
                    hintStyle: TextStyle(color: c.textTertiary, fontSize: 15),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              )),
              if (_pendingImages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 10),
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                    child: Center(child: Text('${_pendingImages.length}',
                      style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 11, fontWeight: FontWeight.bold)))),
                ),
            ])),
          ),
          const SizedBox(width: 8),
          // Send button
          GestureDetector(
            onTap: hasContent ? _send : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: hasContent ? c.primary : c.primary.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: _sending
                ? const Center(child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Color(0xFFFFFFFF), strokeWidth: 2)))
                : Icon(
                    hasContent ? Icons.send_rounded : Icons.mic_none_rounded,
                    size: 20, color: const Color(0xFFFFFFFF)),
            ),
          ),
        ]),
      ),
    ]);
  }

  String _previewType(Map<String, dynamic> m) {
    final t = m['message_type'] as String? ?? 'text';
    if (t == 'voice') return '🎵 Voice message';
    if (t == 'image') return '📷 Photo';
    if (t == 'image_album') return '📷 Photos';
    if (t == 'giphy_sticker') return '😄 Sticker';
    if (t == 'giphy_gif') return '🎞️ GIF';
    if (t == 'poll') return '📊 Poll';
    return m['content'] as String? ?? '';
  }

  void _attachSheet(ThemeColors c) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: c.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _AttachOpt(icon: Icons.photo_library_outlined, label: 'Photos', color: c.primary,
              onTap: () { Navigator.pop(ctx); _pickImages(); }),
            _AttachOpt(icon: Icons.poll_outlined, label: 'Poll', color: c.primary,
              onTap: () { Navigator.pop(ctx); _snack('Poll creation coming soon'); }),
            _AttachOpt(icon: Icons.gif_box_outlined, label: 'GIF', color: c.primary,
              onTap: () { Navigator.pop(ctx); _snack('GIF picker coming soon'); }),
          ]),
        ]),
      )),
    );
  }
}

// ─── Attach Option ────────────────────────────────────────────────────────────
class _AttachOpt extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachOpt({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 28, color: color)),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 13, color: c.text, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
