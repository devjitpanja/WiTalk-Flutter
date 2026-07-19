import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/chat_api_service.dart';

class GroupToolsScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupToolsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupToolsScreen> createState() => _GroupToolsScreenState();
}

class _GroupToolsScreenState extends ConsumerState<GroupToolsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Slow mode
  bool _slowModeEnabled = false;
  String _slowModeDuration = '30s'; // off/10s/30s/1m/5m/10m

  // Disappearing messages
  bool _disappearingEnabled = false;
  String _disappearDuration = '7d'; // 1d/7d/30d

  static const _slowOptions = [
    _Option(value: '10s', label: '10 seconds'),
    _Option(value: '30s', label: '30 seconds'),
    _Option(value: '1m', label: '1 minute'),
    _Option(value: '5m', label: '5 minutes'),
    _Option(value: '10m', label: '10 minutes'),
  ];

  static const _disappearOptions = [
    _Option(value: '1d', label: '1 day'),
    _Option(value: '7d', label: '7 days'),
    _Option(value: '30d', label: '30 days'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await dioClient.get(AppEndpoints.groupDisappearingMessages(widget.groupId));
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      _disappearingEnabled = data['enabled'] == true;
      _disappearDuration = data['duration'] as String? ?? '7d';

      // Slow mode is stored in group detail
      final detail = await chatApiService.getGroupDetail(widget.groupId);
      if (detail != null) {
        final sm = detail['slow_mode'] as Map<String, dynamic>?;
        _slowModeEnabled = sm?['enabled'] == true;
        _slowModeDuration = sm?['duration'] as String? ?? '30s';
      }

      setState(() => _loading = false);
    } catch (_) {
      // If endpoint doesn't exist yet, show defaults
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSlowMode(bool enabled, String duration) async {
    setState(() => _saving = true);
    try {
      await dioClient.put(AppEndpoints.groupDetail(widget.groupId), data: {
        'slow_mode': {'enabled': enabled, 'duration': duration},
      });
      setState(() {
        _slowModeEnabled = enabled;
        _slowModeDuration = duration;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update slow mode', style: TextStyle(fontFamily: 'Outfit'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDisappearing(bool enabled, String duration) async {
    setState(() => _saving = true);
    try {
      await dioClient.post(AppEndpoints.groupDisappearingMessages(widget.groupId), data: {
        'enabled': enabled,
        'duration': duration,
      });
      setState(() {
        _disappearingEnabled = enabled;
        _disappearDuration = duration;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update disappearing messages', style: TextStyle(fontFamily: 'Outfit'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickSlowDuration() async {
    final c = context.colors;
    final picked = await _showOptionSheet<String>(
      context: context,
      c: c,
      title: 'Slow Mode Duration',
      options: _slowOptions,
      current: _slowModeDuration,
    );
    if (picked != null) await _saveSlowMode(true, picked);
  }

  Future<void> _pickDisappearDuration() async {
    final c = context.colors;
    final picked = await _showOptionSheet<String>(
      context: context,
      c: c,
      title: 'Messages Disappear After',
      options: _disappearOptions,
      current: _disappearDuration,
    );
    if (picked != null) await _saveDisappearing(true, picked);
  }

  String _slowLabel(String v) =>
      _slowOptions.firstWhere((o) => o.value == v, orElse: () => _Option(value: '', label: v)).label;

  String _disappearLabel(String v) =>
      _disappearOptions.firstWhere((o) => o.value == v, orElse: () => _Option(value: '', label: v)).label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        title: Text('Group Tools',
            style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          if (_saving)
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)),
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _error != null
              ? _buildError(c)
              : _buildBody(c),
    );
  }

  Widget _buildBody(ThemeColors c) {
    return ListView(
      children: [
        // ── Slow Mode ──────────────────────────────────────────────────────
        _SectionHeader(label: 'Slow Mode', c: c),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.timer_outlined, color: c.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Slow Mode', style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 15)),
                    Text('Limit how often members can send messages',
                        style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 12)),
                  ]),
                ),
                Switch(
                  value: _slowModeEnabled,
                  onChanged: (v) {
                    if (v) {
                      _pickSlowDuration();
                    } else {
                      _saveSlowMode(false, _slowModeDuration);
                    }
                  },
                  activeColor: c.primary,
                ),
              ]),
            ),
            if (_slowModeEnabled) ...[
              Divider(color: c.border, height: 1, indent: 66, endIndent: 16),
              InkWell(
                onTap: _pickSlowDuration,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(66, 12, 16, 12),
                  child: Row(children: [
                    Expanded(
                      child: Text('Interval',
                          style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 15)),
                    ),
                    Text(_slowLabel(_slowModeDuration),
                        style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 14)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: c.textTertiary, size: 18),
                  ]),
                ),
              ),
            ],
          ]),
        ),

        // ── Welcome Message ────────────────────────────────────────────────
        _SectionHeader(label: 'Messaging', c: c),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Column(children: [
            InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              onTap: () => context.push('/chat/welcome-message/${widget.groupId}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: c.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.waving_hand_outlined, color: c.success, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Welcome Message',
                          style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 15)),
                      Text('Greet new members automatically',
                          style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 12)),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: c.textTertiary),
                ]),
              ),
            ),
            Divider(color: c.border, height: 1),
            InkWell(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              onTap: () => context.push('/chat/group-spam-protection/${widget.groupId}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: c.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.security_outlined, color: c.warning, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Spam Protection',
                          style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 15)),
                      Text('Block spam and unwanted content',
                          style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 12)),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: c.textTertiary),
                ]),
              ),
            ),
          ]),
        ),

        // ── Disappearing Messages ──────────────────────────────────────────
        _SectionHeader(label: 'Privacy', c: c),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: c.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_delete_outlined, color: c.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Disappearing Messages',
                        style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 15)),
                    Text('Auto-delete messages after a set time',
                        style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 12)),
                  ]),
                ),
                Switch(
                  value: _disappearingEnabled,
                  onChanged: (v) {
                    if (v) {
                      _pickDisappearDuration();
                    } else {
                      _saveDisappearing(false, _disappearDuration);
                    }
                  },
                  activeColor: c.primary,
                ),
              ]),
            ),
            if (_disappearingEnabled) ...[
              Divider(color: c.border, height: 1, indent: 66, endIndent: 16),
              InkWell(
                onTap: _pickDisappearDuration,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(66, 12, 16, 12),
                  child: Row(children: [
                    Expanded(
                      child: Text('Delete After',
                          style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 15)),
                    ),
                    Text(_disappearLabel(_disappearDuration),
                        style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 14)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: c.textTertiary, size: 18),
                  ]),
                ),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildError(ThemeColors c) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, color: c.textTertiary, size: 48),
        const SizedBox(height: 12),
        Text('Failed to load tools', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 15)),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _load,
          child: Text('Retry', style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

Future<T?> _showOptionSheet<T>({
  required BuildContext context,
  required ThemeColors c,
  required String title,
  required List<_Option> options,
  required String current,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(title,
                style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          ...options.map((o) => ListTile(
            title: Text(o.label, style: TextStyle(color: c.text, fontFamily: 'Outfit')),
            trailing: o.value == current ? Icon(Icons.check, color: c.primary) : null,
            onTap: () => Navigator.pop(ctx, o.value as T),
          )),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _Option {
  final String value;
  final String label;
  const _Option({required this.value, required this.label});
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final ThemeColors c;
  const _SectionHeader({required this.label, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(label.toUpperCase(),
          style: TextStyle(color: c.textTertiary, fontSize: 11, fontFamily: 'Outfit',
              fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }
}
