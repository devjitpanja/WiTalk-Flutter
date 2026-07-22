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

// ─── Theme Helper ─────────────────────────────────────────────────────────────
extension ChannelScreenColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ─── Formatters ───────────────────────────────────────────────────────────────
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

// ─── ReplySnippet ─────────────────────────────────────────────────────────────
class _ReplySnippet extends StatelessWidget {
  final Map<String, dynamic> replyTo;
  final VoidCallback onTap;
  const _ReplySnippet({required this.replyTo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = replyTo['message_type'] ?? 'text';
    final preview = t == 'voice' ? '🎵 Voice message'
        : t == 'image' ? '📷 Photo'
        : t == 'image_album' ? '📷 Photos'
        : t == 'giphy_sticker' ? '😄 Sticker'
        : t == 'giphy_gif' ? '🎞️ GIF'
        : t == 'poll' ? '📊 Poll'
        : (replyTo['content'] ?? '') as String;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: c.background.withValues(alpha: 0.67),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Text(preview, style: TextStyle(fontSize: 12, color: c.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── ReactionPill ─────────────────────────────────────────────────────────────
class _ReactionPill extends StatelessWidget {
  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback onTap;
  const _ReactionPill({required this.emoji, required this.count, required this.mine, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: mine ? c.primary.withValues(alpha: 0.13) : c.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: mine ? c.primary : c.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 3),
          Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text)),
        ]),
      ),
    );
  }
}

// ─── Date Divider ─────────────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final String label;
  const _DateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(children: [
        Expanded(child: Divider(color: c.border.withValues(alpha: 0.3), thickness: 1)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary)),
        ),
        Expanded(child: Divider(color: c.border.withValues(alpha: 0.3), thickness: 1)),
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: Row(children: [
        Expanded(child: Container(height: 1, color: c.primary.withValues(alpha: 0.33))),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('Unread messages',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.primary)),
        ),
        Expanded(child: Container(height: 1, color: c.primary.withValues(alpha: 0.33))),
      ]),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────
class _Bubble extends StatefulWidget {
  final Map<String, dynamic> item;
  final String channelName;
  final bool highlighted;
  final bool pinned;
  final bool canVote;
  final bool isAdmin;
  final VoidCallback onLongPress;
  final void Function(String emoji) onReact;
  final void Function(String id) onScrollTo;

  const _Bubble({
    required this.item, required this.channelName, required this.highlighted,
    required this.pinned, required this.canVote, required this.isAdmin,
    required this.onLongPress, required this.onReact, required this.onScrollTo,
  });

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _alpha;

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

  Widget _reactions_row(ThemeColors c) {
    final counts = _reactions;
    if (counts.isEmpty) return const SizedBox.shrink();
    final my = widget.item['my_reaction'] as String?;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Wrap(spacing: 5, runSpacing: 4, children: [
        for (final e in counts.entries)
          _ReactionPill(emoji: e.key, count: e.value, mine: my == e.key,
            onTap: () => widget.onReact(e.key)),
      ]),
    );
  }

  Widget _footer(ThemeColors c) {
    final vc = _fmtViewCount((widget.item['view_count'] as num?)?.toInt() ?? 0);
    final t = _fmtTime(widget.item['created_at'] as String?);
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      if (widget.pinned) ...[
        Icon(Icons.push_pin, size: 11, color: c.textSecondary),
        const SizedBox(width: 2),
      ],
      Icon(Icons.visibility, size: 11, color: c.textSecondary),
      const SizedBox(width: 2),
      Text(vc, style: TextStyle(fontSize: 11, color: c.textSecondary)),
      const SizedBox(width: 4),
      Text(t, style: TextStyle(fontSize: 11, color: c.textSecondary)),
    ]);
  }

  Widget _replySnippet(ThemeColors c) {
    final rt = widget.item['reply_to'];
    if (rt == null) return const SizedBox.shrink();
    return _ReplySnippet(
      replyTo: rt as Map<String, dynamic>,
      onTap: () => widget.onScrollTo(rt['id'].toString()),
    );
  }

  // ── Message type renderers ────────────────────────────────────────────────
  Widget _text(ThemeColors c) {
    final content = widget.item['content'] as String? ?? '';
    final msgType = widget.item['message_type'] as String? ?? 'text';
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16), topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4), bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(widget.channelName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.primary)),
        _replySnippet(c),
        if (msgType == 'video') ...[
          const SizedBox(height: 6),
          Container(width: double.infinity, height: 180,
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Icon(Icons.play_circle_filled, size: 48, color: Colors.white))),
        ],
        if (content.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(content, style: TextStyle(fontSize: 15, color: c.text)),
        ],
        _reactions_row(c),
        const SizedBox(height: 6),
        _footer(c),
      ]),
    );
  }

  Widget _image(ThemeColors c) {
    final url = widget.item['media_url'] as String?;
    final md = _parseJson(widget.item['media_data']);
    final w = (md?['width'] as num?)?.toDouble() ?? 1.0;
    final h = (md?['height'] as num?)?.toDouble() ?? 1.0;
    final dw = 240.0;
    final dh = (dw / (w / h)).clamp(80.0, 320.0);
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Text(widget.channelName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.primary))),
        _replySnippet(c),
        if (url != null)
          CachedNetworkImage(imageUrl: url, width: dw, height: dh, fit: BoxFit.cover,
            placeholder: (_, __) => Container(width: dw, height: dh,
              color: c.border.withValues(alpha: 0.3),
              child: Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2))),
            errorWidget: (_, __, ___) => Container(width: dw, height: dh,
              color: c.border.withValues(alpha: 0.3),
              child: Icon(Icons.broken_image, color: c.textSecondary))),
        Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((widget.item['content'] as String? ?? '').isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(widget.item['content'] as String, style: TextStyle(fontSize: 15, color: c.text))),
          _reactions_row(c), _footer(c),
        ])),
      ]),
    );
  }

  Widget _album(ThemeColors c) {
    final md = _parseJson(widget.item['media_data']);
    final images = (md?['images'] as List?) ?? [];
    const tile = 200.0;
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border)),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Text(widget.channelName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.primary))),
        _replySnippet(c),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: images.map<Widget>((img) {
            final url = img['url'] as String?;
            return Container(width: tile, height: tile, margin: const EdgeInsets.only(right: 4),
              child: url != null
                ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: c.border.withValues(alpha: 0.3)),
                    errorWidget: (_, __, ___) => Icon(Icons.broken_image, color: c.textSecondary))
                : Container(color: c.border));
          }).toList()),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((widget.item['content'] as String? ?? '').isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(widget.item['content'] as String, style: TextStyle(fontSize: 15, color: c.text))),
          _reactions_row(c), _footer(c),
        ])),
      ]),
    );
  }

  Widget _poll(ThemeColors c) {
    final poll = widget.item['poll'] as Map<String, dynamic>?;
    if (poll == null) return _text(c);
    final question = poll['question'] as String? ?? '';
    final options = (poll['options'] as List?) ?? [];
    final hasVoted = poll['has_voted'] == true;
    final total = (poll['total_votes'] as num?)?.toInt() ?? 0;
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 20, minWidth: 260),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(widget.channelName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.primary)),
        const SizedBox(height: 8),
        Text('📊 $question', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
        const SizedBox(height: 10),
        ...options.map((opt) {
          final o = opt as Map<String, dynamic>;
          final label = o['text'] as String? ?? '';
          final votes = (o['vote_count'] as num?)?.toInt() ?? 0;
          final pct = total > 0 ? votes / total : 0.0;
          final sel = o['is_selected'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? c.primary : c.border),
              color: sel ? c.primary.withValues(alpha: 0.1) : c.background,
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(children: [
              if (hasVoted) Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: pct,
                  child: Container(color: c.primary.withValues(alpha: 0.13)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: c.text))),
                  if (hasVoted) Text('${(pct * 100).round()}%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary)),
                ]),
              ),
            ]),
          );
        }),
        if (total > 0) Text('$total votes', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        const SizedBox(height: 8),
        _reactions_row(c),
        _footer(c),
      ]),
    );
  }

  Widget _voice(ThemeColors c) {
    final md = _parseJson(widget.item['media_data']);
    final dur = (md?['duration'] as num?)?.toInt() ?? 0;
    final m = dur ~/ 60;
    final s = (dur % 60).toString().padLeft(2, '0');
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(widget.channelName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.primary)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.play_circle_filled, size: 36, color: c.primary),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 3, decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 4),
            Text('🎵 $m:$s', style: TextStyle(fontSize: 13, color: c.textSecondary)),
          ])),
        ]),
        _reactions_row(c),
        _footer(c),
      ]),
    );
  }

  Widget _gif(ThemeColors c) {
    final url = widget.item['media_url'] as String?;
    final md = _parseJson(widget.item['media_data']);
    final ar = (md?['aspectRatio'] as num?)?.toDouble() ?? 1.0;
    const w = 200.0;
    final h = w / ar;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (url != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(children: [
            CachedNetworkImage(imageUrl: url, width: w, height: h, fit: BoxFit.cover,
              placeholder: (_, __) => Container(width: w, height: h, color: c.border.withValues(alpha: 0.3)),
              errorWidget: (_, __, ___) => Container(width: w, height: h, color: c.border)),
            Positioned(bottom: 4, right: 4, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.visibility, size: 10, color: Colors.white),
                const SizedBox(width: 2),
                Text(_fmtViewCount((widget.item['view_count'] as num?)?.toInt() ?? 0),
                  style: const TextStyle(fontSize: 11, color: Colors.white)),
                const SizedBox(width: 4),
                Text(_fmtTime(widget.item['created_at'] as String?),
                  style: const TextStyle(fontSize: 11, color: Colors.white)),
              ]),
            )),
          ]),
        ),
      _reactions_row(c),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = widget.item['message_type'] as String? ?? 'text';
    Widget inner;
    if (type == 'image') inner = _image(c);
    else if (type == 'image_album') inner = _album(c);
    else if (type == 'poll') inner = _poll(c);
    else if (type == 'voice' || type == 'audio') inner = _voice(c);
    else if (type == 'giphy_gif' || type == 'giphy_sticker') inner = _gif(c);
    else inner = _text(c);

    return AnimatedBuilder(
      animation: _alpha,
      builder: (_, child) => Container(
        color: c.primary.withValues(alpha: _alpha.value * 0.2),
        child: child,
      ),
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 10, right: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Flexible(child: inner),
          ]),
        ),
      ),
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
    final preview = t == 'text' ? (pm['content'] ?? '')
        : t == 'image' ? '📷 Photo'
        : t == 'image_album' ? '📷 Photos'
        : (t == 'voice' || t == 'audio') ? '🎵 Voice message'
        : t == 'giphy_sticker' ? '😄 Sticker'
        : t == 'giphy_gif' ? '🎞️ GIF'
        : t == 'poll' ? '📊 ${pm['poll']?['question'] ?? 'Poll'}'
        : (pm['content'] ?? pm['message_type'] ?? '');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
        child: Row(children: [
          if (pins.length > 1)
            Container(width: 3, height: 28, margin: const EdgeInsets.only(right: 4),
              child: Column(children: List.generate(pins.length, (i) => Expanded(child: Container(
                margin: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(
                  color: i == idx ? c.primary : c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ))))),
          Transform.rotate(angle: 0.785,
            child: Icon(Icons.push_pin, size: 16, color: c.primary)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pins.length > 1 ? 'Pinned Message ${idx + 1} of ${pins.length}' : 'Pinned Message',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.primary)),
            Text(preview.toString(), style: TextStyle(fontSize: 13, color: c.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          GestureDetector(onTap: onClose, child: Icon(Icons.close, size: 18, color: c.textSecondary)),
        ]),
      ),
    );
  }
}

// ─── Compose Banner (Reply / Edit) ───────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border, width: 0.5))),
      child: Row(children: [
        Icon(icon, size: 16, color: c.primary),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.primary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(preview, style: TextStyle(fontSize: 13, color: c.textSecondary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        GestureDetector(onTap: onDismiss, child: Icon(Icons.close, size: 18, color: c.textSecondary)),
      ]),
    );
  }
}

// ─── Banned Screen ────────────────────────────────────────────────────────────
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
          Container(width: 100, height: 100,
            decoration: BoxDecoration(color: c.danger.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(channelBanned ? Icons.gavel : Icons.block, size: 64, color: c.danger)),
          const SizedBox(height: 16),
          Text(channelBanned ? 'Channel Banned' : "You've been banned",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.text),
            textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(channelBanned
              ? 'This channel has been banned by the platform and is no longer accessible.'
              : 'You no longer have access to this channel.',
            style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.6),
            textAlign: TextAlign.center),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.danger.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.danger.withValues(alpha: 0.3)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 14, color: c.danger),
                const SizedBox(width: 6),
                Expanded(child: Text(reason!, style: TextStyle(fontSize: 13, color: c.danger, height: 1.5))),
              ]),
            ),
          ],
          if (onAction != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: isAdmin ? c.surface : c.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isAdmin ? c.border : c.danger.withValues(alpha: 0.4)),
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
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
  );
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
  int _uploadingCount = 0;
  List<Map<String, dynamic>> _pendingImages = [];

  String? _highlightId;
  String? _pendingScrollId;

  final Set<String> _viewedIds = {};
  final Set<String> _pendingViews = {};
  Timer? _viewTimer;

  bool get _isAdmin => _myRole == 'owner' || _myRole == 'admin';
  bool get _isOwner => _myRole == 'owner';
  String get _chName => (_channel?['name'] ?? widget.initialChannel?['name'] ?? '') as String;

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
        ChannelApi.markRead(widget.channelId, msgs.last['id'].toString()).catchError((_) {});
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
      _pendingScrollId = id;
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
      ChannelApi.trackViews(widget.channelId, ids).catchError((_) {});
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
      final est = _messages.length * 100.0;
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

  // ── Actions ───────────────────────────────────────────────────────────────
  void _onLongPress(Map<String, dynamic> msg) {
    if (!_isSubscribed) { _snack('Join the channel to interact with messages'); return; }
    final type = msg['message_type'] as String? ?? 'text';
    final poll = msg['poll'] as Map<String, dynamic>?;
    final hasVoted = poll?['has_voted'] == true;
    final isQuiz = poll?['settings']?['quiz'] == true;
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
      _snack('Copied to clipboard', success: true);
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
        title: Text('Delete Message', style: TextStyle(color: c.text)),
        content: Text('Delete this message?', style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: c.danger))),
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
    } catch (_) { _snack('Could not delete message', error: true); }
  }

  Future<void> _retractVote(Map<String, dynamic> msg) async {
    try {
      final res = await ChannelApi.retractVote(widget.channelId, msg['id'].toString());
      if (res.data?['poll'] != null && mounted) {
        setState(() {
          _messages = _messages.map((m) =>
            m['id'].toString() == msg['id'].toString() ? {...m, 'poll': res.data!['poll']} : m).toList();
        });
      }
    } catch (_) {}
  }

  // ── Send ──────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final trimmed = _textCtrl.text.trim();
    if ((trimmed.isEmpty && _pendingImages.isEmpty) || _sending) return;
    setState(() => _sending = true);

    if (_pendingImages.isNotEmpty) {
      final imgs = List<Map<String, dynamic>>.from(_pendingImages);
      final cap = trimmed;
      final rid = _replyingTo?['id']?.toString();
      setState(() { _pendingImages.clear(); _textCtrl.clear(); _replyingTo = null;
        _uploadingImage = true; _uploadProgress = 0; _uploadingCount = imgs.length; });
      try {
        final uploaded = imgs.map((i) => {'url': i['uri'] as String, 'width': i['width'] ?? 1080, 'height': i['height'] ?? 1080}).toList();
        final single = uploaded.length == 1;
        final res = await ChannelApi.sendMessage(widget.channelId, {
          'content': cap.isEmpty ? null : cap,
          'message_type': single ? 'image' : 'image_album',
          'media_url': uploaded.first['url'],
          'media_data': single ? {'width': uploaded.first['width'], 'height': uploaded.first['height']} : {'images': uploaded},
          if (rid != null) 'reply_to_id': rid,
        });
        final m = res.data?['message'] as Map<String, dynamic>?;
        if (m != null && mounted) {
          setState(() { if (!_messages.any((x) => x['id'].toString() == m['id'].toString())) _messages = [..._messages, m]; });
          _scrollToBottom();
        }
      } catch (_) { _snack('Failed to send image', error: true); }
      finally {
        if (mounted) setState(() { _uploadingImage = false; _uploadProgress = 0; _uploadingCount = 0; _sending = false; });
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
        setState(() { _messages = _messages.map((m) => m['id'].toString() == editing['id'].toString() ? {...m, 'content': trimmed, 'is_edited': 1} : m).toList(); });
      } catch (_) { _snack('Failed to edit', error: true); _textCtrl.text = trimmed; if (mounted) setState(() => _editingMsg = editing); }
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
        setState(() { if (!_messages.any((x) => x['id'].toString() == m['id'].toString())) _messages = [..._messages, m]; });
        _scrollToBottom();
        ChannelApi.markRead(widget.channelId, m['id'].toString()).catchError((_) {});
      }
    } catch (_) { _snack('Failed to send', error: true); _textCtrl.text = trimmed; }
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
      content: Text(t, style: const TextStyle(color: Colors.white)),
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
      context: context,
      backgroundColor: c.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: emojis.map((e) => GestureDetector(
                onTap: () { Navigator.pop(ctx); onReact(e); },
                child: Text(e, style: const TextStyle(fontSize: 26)),
              )).toList())),
          const Divider(),
          if (onReply != null) ListTile(leading: Icon(Icons.reply, color: c.text, size: 22),
            title: Text('Reply', style: TextStyle(color: c.text, fontSize: 15)),
            onTap: () { Navigator.pop(ctx); onReply(); }, dense: true),
          ListTile(leading: Icon(Icons.copy, color: c.text, size: 22),
            title: Text('Copy', style: TextStyle(color: c.text, fontSize: 15)),
            onTap: () { Navigator.pop(ctx); onCopy(); }, dense: true),
          if (onEdit != null) ListTile(leading: Icon(Icons.edit, color: c.text, size: 22),
            title: Text('Edit', style: TextStyle(color: c.text, fontSize: 15)),
            onTap: () { Navigator.pop(ctx); onEdit(); }, dense: true),
          if (onPin != null) ListTile(
            leading: Icon(msg['is_pinned'] == 1 ? Icons.push_pin : Icons.push_pin_outlined, color: c.text, size: 22),
            title: Text(msg['is_pinned'] == 1 ? 'Unpin' : 'Pin', style: TextStyle(color: c.text, fontSize: 15)),
            onTap: () { Navigator.pop(ctx); onPin(); }, dense: true),
          if (onRetractVote != null) ListTile(leading: Icon(Icons.undo, color: c.text, size: 22),
            title: Text('Retract Vote', style: TextStyle(color: c.text, fontSize: 15)),
            onTap: () { Navigator.pop(ctx); onRetractVote(); }, dense: true),
          if (onTranslate != null) ListTile(leading: Icon(Icons.translate, color: c.text, size: 22),
            title: Text('Translate', style: TextStyle(color: c.text, fontSize: 15)),
            onTap: () { Navigator.pop(ctx); onTranslate(); }, dense: true),
          if (onReport != null) ListTile(leading: Icon(Icons.flag_outlined, color: c.danger, size: 22),
            title: Text('Report', style: TextStyle(color: c.danger, fontSize: 15)),
            onTap: () { Navigator.pop(ctx); onReport(); }, dense: true),
          if (onDelete != null) ListTile(leading: Icon(Icons.delete_outline, color: c.danger, size: 22),
            title: Text('Delete', style: TextStyle(color: c.danger, fontSize: 15)),
            onTap: () { Navigator.pop(ctx); onDelete(); }, dense: true),
        ]),
      )),
    );
  }

  // ── List data ─────────────────────────────────────────────────────────────
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
          if (ds != lastDate) { out.add({'type': 'date', 'id': 'date_$ds', 'iso': iso}); lastDate = ds; }
        } catch (_) {}
      }
      out.add(m);
    }
    return out;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = context.isDark;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(child: Column(children: [
        _header(c),
        if (_isChannelAdminBanned)
          Expanded(child: _BannedView(channelBanned: true, reason: _banReason, isAdmin: _isAdmin,
            onAction: _isAdmin ? () {} : null))
        else
          Expanded(child: Stack(children: [
            // Wallpaper
            Positioned.fill(child: Image.asset(
              dark ? 'assets/images/chatbg.jpeg' : 'assets/images/LightchatBg.jpeg',
              fit: BoxFit.cover,
              color: dark ? Colors.black.withValues(alpha: 0.85) : null,
              colorBlendMode: dark ? BlendMode.darken : null,
              errorBuilder: (_, __, ___) => Container(color: c.background),
            )),
            Column(children: [
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
                : _list(c, dark)),
              if (_isBannedFromChannel)
                Container(padding: const EdgeInsets.all(16), color: c.cardBackground,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.block, size: 18, color: c.danger),
                    const SizedBox(width: 8),
                    Text('You have been banned from this channel',
                      style: TextStyle(color: c.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                  ])),
              if (_isNotMember && !_isBannedFromChannel) _joinBar(c),
              if (_isAdmin && !_isChannelAdminBanned) _inputArea(c),
            ]),
          ])),
      ])),
    );
  }

  Widget _header(ThemeColors c) {
    final sub = (_channel?['subscriber_count'] as num?)?.toInt() ?? 0;
    final verified = _channel?['is_verified'] == 1;
    final icon = _channel?['icon'] as String?;
    final init = _chName.isNotEmpty ? _chName[0].toUpperCase() : 'C';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(color: c.background, border: Border(bottom: BorderSide(color: c.border))),
      child: Row(children: [
        IconButton(icon: Icon(Icons.arrow_back, color: c.text), onPressed: () => context.pop()),
        Expanded(child: GestureDetector(
          onTap: _isSubscribed && !_isChannelAdminBanned
            ? () => context.push('/channel-info/${widget.channelId}') : null,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(_chName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (verified) ...[const SizedBox(width: 3), const Icon(Icons.verified, size: 16, color: Color(0xFF0751df))],
            ]),
            Text('$sub subscribers', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ]),
        )),
        GestureDetector(
          onTap: _isSubscribed && !_isChannelAdminBanned
            ? () => context.push('/channel-info/${widget.channelId}') : null,
          child: Container(width: 38, height: 38,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.primary),
            clipBehavior: Clip.hardEdge,
            child: icon != null
              ? CachedNetworkImage(imageUrl: icon, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Center(child: Text(init, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))))
              : Center(child: Text(init, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))),
        ),
        const SizedBox(width: 4),
      ]),
    );
  }

  Widget _list(ThemeColors c, bool dark) {
    final data = _listData;
    return Stack(children: [
      ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.only(top: 10, bottom: 20),
        itemCount: data.length + (_loadingOlder ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (_loadingOlder && i == 0) {
            return Center(child: Padding(padding: const EdgeInsets.all(8),
              child: CircularProgressIndicator(color: c.primary, strokeWidth: 2)));
          }
          final item = data[_loadingOlder ? i - 1 : i];
          final t = item['type'] as String?;
          if (t == 'date') return _DateDivider(label: _fmtDate(item['iso'] as String?));
          if (t == 'unread') return const _UnreadDivider();
          final id = item['id']?.toString() ?? '';
          _trackView(id);
          final pinned = _pins.any((p) => p['id'].toString() == id);
          return _Bubble(
            item: item, channelName: _chName,
            highlighted: _highlightId == id,
            pinned: pinned, canVote: _isSubscribed, isAdmin: _isAdmin,
            onLongPress: () => _onLongPress(item),
            onReact: (e) => _react(id, e),
            onScrollTo: _scrollToMsg,
          );
        },
      ),
      if (data.where((d) => d['type'] == null).isEmpty && !_loading)
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.campaign, size: 48, color: c.textTertiary),
          const SizedBox(height: 12),
          Text('No updates yet. Check back later!', style: TextStyle(fontSize: 14, color: c.textSecondary)),
        ])),
      if (_hasNewerMessages)
        Positioned(bottom: 16, left: 0, right: 0, child: Center(child: GestureDetector(
          onTap: _scrollToLatest,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2))]),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white),
              SizedBox(width: 4),
              Text('Back to Latest', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ]),
          ),
        ))),
      if (!_hasNewerMessages && _showScrollToBottom)
        Positioned(bottom: 16, right: 16, child: GestureDetector(
          onTap: _scrollToLatest,
          child: Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF2C2C2E) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.4 : 0.2), blurRadius: 3, offset: const Offset(0, 2))]),
            child: Icon(Icons.keyboard_arrow_down, size: 22, color: dark ? Colors.white : Colors.black)),
        )),
    ]);
  }

  Widget _joinBar(ThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SizedBox(width: double.infinity,
        child: ElevatedButton(
          onPressed: _subscribe,
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(60)),
            side: const BorderSide(color: Colors.white, width: 3),
          ),
          child: const Text('Join Channel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        )),
    );
  }

  Widget _inputArea(ThemeColors c) {
    final dark = context.isDark;
    final hasContent = _textCtrl.text.trim().isNotEmpty || _pendingImages.isNotEmpty;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_replyingTo != null)
        _ComposeBanner(icon: Icons.reply,
          label: _replyingTo?['sender_name'] as String? ?? 'Unknown',
          preview: _previewType(_replyingTo!),
          onDismiss: () => setState(() => _replyingTo = null)),
      if (_editingMsg != null)
        _ComposeBanner(icon: Icons.edit, label: 'Editing',
          preview: _editingMsg?['content'] as String? ?? '',
          onDismiss: () { setState(() { _editingMsg = null; _textCtrl.clear(); }); }),
      if (_pendingImages.isNotEmpty)
        Container(height: 84, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _pendingImages.length + (_pendingImages.length < 10 ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              if (i == _pendingImages.length) {
                return GestureDetector(onTap: _pickImages,
                  child: Container(width: 68, height: 68,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.border, width: 1.5)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate, size: 22, color: c.textSecondary),
                      Text('${10 - _pendingImages.length} left',
                        style: TextStyle(fontSize: 10, color: c.textSecondary)),
                    ])));
              }
              return Stack(children: [
                Container(width: 68, height: 68,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: c.border)),
                Positioned(top: -4, right: -4, child: GestureDetector(
                  onTap: () {
                    final list = [..._pendingImages]; list.removeAt(i);
                    setState(() => _pendingImages = list);
                  },
                  child: Container(padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close, size: 13, color: Colors.white)))),
              ]);
            },
          )),
      if (_uploadingImage)
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: c.surface,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: _uploadProgress,
                backgroundColor: c.border, valueColor: AlwaysStoppedAnimation(c.primary), minHeight: 4)),
            const SizedBox(height: 4),
            Text('Uploading ${(_uploadProgress * 100).round()}%',
              style: TextStyle(fontSize: 12, color: c.textSecondary), textAlign: TextAlign.center),
          ])),
      Container(padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Container(
            decoration: BoxDecoration(
              color: dark ? c.cardBackground : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.border),
            ),
            constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.emoji_emotions_outlined, size: 22, color: c.textSecondary),
                padding: const EdgeInsets.all(8)),
              Expanded(child: TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                style: TextStyle(fontSize: 15, color: c.text),
                maxLines: null,
                maxLength: 2000,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                decoration: InputDecoration(
                  hintText: _editingMsg != null ? 'Edit message...'
                    : _pendingImages.isNotEmpty ? 'Add a caption...' : 'Message',
                  hintStyle: TextStyle(color: c.textTertiary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              )),
              IconButton(
                onPressed: _pendingImages.isNotEmpty ? _pickImages : () => _attachSheet(c),
                icon: _pendingImages.isNotEmpty
                  ? Container(width: 24, height: 24,
                      decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                      child: Center(child: Text('${_pendingImages.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))))
                  : Icon(Icons.attach_file, size: 20, color: c.textSecondary),
                padding: const EdgeInsets.all(8)),
            ])),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: hasContent ? _send : null,
            child: Container(width: 48, height: 48,
              decoration: BoxDecoration(color: c.text, shape: BoxShape.circle),
              child: _sending
                ? Center(child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: c.background, strokeWidth: 2)))
                : Center(child: Icon(hasContent ? Icons.send : Icons.mic, size: 20, color: c.background))),
          ),
        ])),
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
      context: context,
      backgroundColor: c.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _AttachOpt(icon: Icons.photo_library, label: 'Photos', color: c.primary,
              onTap: () { Navigator.pop(ctx); _pickImages(); }),
            _AttachOpt(icon: Icons.poll, label: 'Poll', color: c.primary,
              onTap: () { Navigator.pop(ctx); _snack('Poll creation coming soon'); }),
          ]),
        ]),
      )),
    );
  }
}

class _AttachOpt extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachOpt({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(onTap: onTap, child: Column(children: [
      Container(width: 60, height: 60,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, size: 28, color: color)),
      const SizedBox(height: 8),
      Text(label, style: TextStyle(fontSize: 13, color: c.text)),
    ]));
  }
}
