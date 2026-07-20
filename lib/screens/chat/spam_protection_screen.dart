import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_api_service.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';

// ── Defaults ──────────────────────────────────────────────────────────────────

const _defaultSpam = {
  'spam_protection_enabled': 1,
  'spam_rate_limit_enabled': 1,
  'spam_rate_limit_count': 5,
  'spam_duplicate_enabled': 1,
  'spam_duplicate_threshold': 3,
  'spam_link_enabled': 1,
  'spam_link_max': 4,
  'spam_no_links_enabled': 0,
  'spam_promo_enabled': 1,
  'spam_mention_enabled': 1,
  'spam_mention_max': 6,
};

Map<String, dynamic> _fromPerms(Map<String, dynamic> perms) {
  final result = <String, dynamic>{};
  for (final k in _defaultSpam.keys) {
    result[k] = perms.containsKey(k) ? perms[k] : _defaultSpam[k];
  }
  return result;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SpamProtectionScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String? groupName;

  const SpamProtectionScreen({super.key, required this.groupId, this.groupName});

  @override
  ConsumerState<SpamProtectionScreen> createState() => _SpamProtectionScreenState();
}

class _SpamProtectionScreenState extends ConsumerState<SpamProtectionScreen> {
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic> _settings = Map.from(_defaultSpam);

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    final myUid = ref.read(authProvider).uid;
    setState(() => _loading = true);
    try {
      final data = await chatApiService.getGroupPermissions(widget.groupId, userId: myUid);
      if (data != null) {
        final perms = data['permissions'] as Map<String, dynamic>? ?? {};
        if (mounted) setState(() => _settings = _fromPerms(perms));
      }
    } catch (_) {
      // Use defaults if fetch fails
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _set(String key, dynamic value) => setState(() => _settings[key] = value);
  void _toggle(String key) => _set(key, (_settings[key] == 1 || _settings[key] == true) ? 0 : 1);

  bool _isEnabled(String key) {
    final v = _settings[key];
    return v == 1 || v == true;
  }

  bool get _masterOn => _isEnabled('spam_protection_enabled');

  int _clamp(int val, int min, int max) => val.clamp(min, max);

  Future<void> _save() async {
    final myUid = ref.read(authProvider).uid;
    if (myUid == null) return;

    setState(() => _saving = true);
    try {
      await dioClient.put(
        AppEndpoints.groupPermissions(widget.groupId),
        data: _settings,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spam settings saved', style: TextStyle(fontFamily: 'Outfit')),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString(), style: const TextStyle(fontFamily: 'Outfit')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              'Spam Protection',
              style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18),
            ),
            if (widget.groupName != null)
              Text(
                widget.groupName!,
                style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 12),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          const SizedBox(width: 40),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _buildBody(c),
    );
  }

  Widget _buildBody(ThemeColors c) {
    return ListView(
      children: [
        // ── Master switch ──────────────────────────────────────────────────────
        Container(
          color: c.surface,
          margin: const EdgeInsets.only(top: 12),
          child: _SettingRow(
            c: c,
            icon: Icons.security_outlined,
            iconColor: _masterOn ? const Color(0xFF10B981) : null,
            title: 'Enable spam protection',
            description: 'Master switch. When off, all checks below are disabled and every message passes through.',
            value: _masterOn,
            onToggle: () => _toggle('spam_protection_enabled'),
          ),
        ),

        // ── Individual checks ─────────────────────────────────────────────────
        Container(
          color: c.surface,
          margin: const EdgeInsets.only(top: 12),
          child: Opacity(
            opacity: _masterOn ? 1.0 : 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'CHECKS',
                    style: TextStyle(
                      color: c.textTertiary,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ),

                // Rate limit
                _SettingRow(
                  c: c,
                  icon: Icons.timer_outlined,
                  title: 'Rate limiting',
                  description: 'Block members who send more than ${_settings['spam_rate_limit_count']} messages within 5 seconds.',
                  value: _isEnabled('spam_rate_limit_enabled'),
                  onToggle: _masterOn ? () => _toggle('spam_rate_limit_enabled') : null,
                  disabled: !_masterOn,
                ),
                if (_isEnabled('spam_rate_limit_enabled') && _masterOn)
                  _Stepper(
                    c: c,
                    label: 'Messages per 5 s',
                    value: (_settings['spam_rate_limit_count'] as num).toInt(),
                    min: 2,
                    max: 20,
                    onChange: (v) => _set('spam_rate_limit_count', _clamp(v, 2, 20)),
                  ),

                Divider(height: 0.5, color: c.border, indent: 56),

                // Duplicate flood
                _SettingRow(
                  c: c,
                  icon: Icons.content_copy_outlined,
                  title: 'Duplicate flood',
                  description: 'Block identical messages sent ${_settings['spam_duplicate_threshold']} or more times in a row.',
                  value: _isEnabled('spam_duplicate_enabled'),
                  onToggle: _masterOn ? () => _toggle('spam_duplicate_enabled') : null,
                  disabled: !_masterOn,
                ),
                if (_isEnabled('spam_duplicate_enabled') && _masterOn)
                  _Stepper(
                    c: c,
                    label: 'Repeat threshold',
                    value: (_settings['spam_duplicate_threshold'] as num).toInt(),
                    min: 2,
                    max: 10,
                    onChange: (v) => _set('spam_duplicate_threshold', _clamp(v, 2, 10)),
                  ),

                Divider(height: 0.5, color: c.border, indent: 56),

                // Link spam
                _SettingRow(
                  c: c,
                  icon: Icons.link_outlined,
                  title: 'Link spam',
                  description: 'Block messages containing more than ${_settings['spam_link_max']} link(s).',
                  value: _isEnabled('spam_link_enabled'),
                  onToggle: _masterOn ? () => _toggle('spam_link_enabled') : null,
                  disabled: !_masterOn,
                ),
                if (_isEnabled('spam_link_enabled') && _masterOn)
                  _Stepper(
                    c: c,
                    label: 'Max links per message',
                    value: (_settings['spam_link_max'] as num).toInt(),
                    min: 1,
                    max: 20,
                    onChange: (v) => _set('spam_link_max', _clamp(v, 1, 20)),
                  ),

                Divider(height: 0.5, color: c.border, indent: 56),

                // Block all links
                _SettingRow(
                  c: c,
                  icon: Icons.link_off,
                  iconColor: _isEnabled('spam_no_links_enabled') && _masterOn ? const Color(0xFFEF4444) : null,
                  title: 'Block all links',
                  description: 'Prevent any message containing a link from being sent. Overrides the link count limit above.',
                  value: _isEnabled('spam_no_links_enabled'),
                  onToggle: _masterOn ? () => _toggle('spam_no_links_enabled') : null,
                  disabled: !_masterOn,
                  activeTrackColor: const Color(0xFFEF4444),
                ),

                Divider(height: 0.5, color: c.border, indent: 56),

                // Self-promotion
                _SettingRow(
                  c: c,
                  icon: Icons.campaign_outlined,
                  title: 'Self-promotion',
                  description: 'Block messages containing invite links, referral codes, or promotional keywords.',
                  value: _isEnabled('spam_promo_enabled'),
                  onToggle: _masterOn ? () => _toggle('spam_promo_enabled') : null,
                  disabled: !_masterOn,
                ),

                Divider(height: 0.5, color: c.border, indent: 56),

                // Mention bomb
                _SettingRow(
                  c: c,
                  icon: Icons.alternate_email,
                  title: 'Mention bomb',
                  description: 'Block messages that contain ${_settings['spam_mention_max']} or more @mentions.',
                  value: _isEnabled('spam_mention_enabled'),
                  onToggle: _masterOn ? () => _toggle('spam_mention_enabled') : null,
                  disabled: !_masterOn,
                ),
                if (_isEnabled('spam_mention_enabled') && _masterOn)
                  _Stepper(
                    c: c,
                    label: 'Max mentions per message',
                    value: (_settings['spam_mention_max'] as num).toInt(),
                    min: 2,
                    max: 20,
                    onChange: (v) => _set('spam_mention_max', _clamp(v, 2, 20)),
                  ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // ── Notice ────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            Icon(Icons.info_outline, size: 16, color: c.textTertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Admins and owners are exempt from all spam checks.',
                style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 12, height: 1.5),
              ),
            ),
          ]),
        ),

        // ── Save button ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                disabledBackgroundColor: c.primary.withOpacity(0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Sub-components ────────────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  final ThemeColors c;
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? description;
  final bool value;
  final VoidCallback? onToggle;
  final bool disabled;
  final Color? activeTrackColor;

  const _SettingRow({
    required this.c,
    required this.icon,
    this.iconColor,
    required this.title,
    this.description,
    required this.value,
    required this.onToggle,
    this.disabled = false,
    this.activeTrackColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? (value && !disabled ? c.primary : c.textTertiary);
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 22, color: resolvedIconColor),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        description!,
                        style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: value,
                onChanged: onToggle != null ? (_) => onToggle!() : null,
                activeColor: activeTrackColor ?? c.primary,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: c.border,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final ThemeColors c;
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChange;

  const _Stepper({
    required this.c,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: c.background.withOpacity(0.8),
      padding: const EdgeInsets.fromLTRB(56, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: value > min ? () => onChange(value - 1) : null,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.remove, size: 18, color: value > min ? c.primary : c.textTertiary),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 28,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: value < max ? () => onChange(value + 1) : null,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add, size: 18, color: value < max ? c.primary : c.textTertiary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
