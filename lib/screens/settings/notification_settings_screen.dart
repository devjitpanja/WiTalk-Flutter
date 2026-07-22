import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../api/dio_client.dart';
import '../../providers/theme_provider.dart';

class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
  Color get surface => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get border => dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  Color get text => dark ? Colors.white : Colors.black;
  Color get textTertiary => const Color(0xFF8E8E93);
  Color get primary => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  Color get skBase => dark ? const Color(0xFF1a1f2e) : const Color(0xFFE1E9EE);
  Color get skHi => dark ? const Color(0xFF242938) : const Color(0xFFF2F8FC);
  Color get headerBg => dark ? const Color(0xFF1C1C1E) : Colors.white;
}

const _sections = [
  (
    'Posts',
    Icons.article,
    [
      ('posts_enabled', 'Posts', 'Notifications about your posts', Icons.article),
      ('likes_enabled', 'Likes', 'When someone likes your content', Icons.favorite),
    ],
  ),
  (
    'Comments',
    Icons.chat_bubble,
    [
      ('comments_enabled', 'Comments', 'When someone comments on your posts', Icons.comment),
    ],
  ),
  (
    'Social',
    Icons.people,
    [
      ('follows_enabled', 'New Followers', 'When someone follows you', Icons.person_add),
    ],
  ),
  (
    'Messages',
    Icons.message,
    [
      ('messages_enabled', 'Private Messages', 'When you receive a private message', Icons.mail),
      ('group_messages_enabled', 'Group Messages', 'When you receive a group message', Icons.groups),
    ],
  ),
  (
    'System',
    Icons.settings,
    [
      ('system_enabled', 'System Notifications', 'Important updates and announcements', Icons.notifications_active),
      ('missions_enabled', 'Mission Completed', 'When you complete missions', Icons.emoji_events),
    ],
  ),
];

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _loading = true;
  bool _updating = false;
  Map<String, bool> _prefs = {
    'posts_enabled': true, 'comments_enabled': true, 'likes_enabled': true,
    'follows_enabled': true, 'social_interactions_enabled': true, 'system_enabled': true,
    'messages_enabled': true, 'group_messages_enabled': true, 'profile_like_enabled': true,
    'profile_visit_enabled': true, 'missions_enabled': true,
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await dioClient.get('/v1/notification-settings/preferences');
      if (mounted && res.data['success'] == true && res.data['data']['preferences'] != null) {
        final p = Map<String, dynamic>.from(res.data['data']['preferences'] as Map);
        setState(() => _prefs = _prefs.map((k, _) => MapEntry(k, p[k] == true || p[k] == 1)));
      }
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() { _prefs[key] = value; _updating = true; });
    try {
      await dioClient.patch('/v1/notification-settings/preferences/$key', data: {'enabled': value});
    } catch (_) { if (mounted) setState(() => _prefs[key] = !value); }
    finally { if (mounted) setState(() => _updating = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);

    if (_loading) return _skeleton(t);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(color: t.headerBg, boxShadow: const [BoxShadow(color: Color(0x0D000000), offset: Offset(0, 2), blurRadius: 4)]),
          child: Row(children: [
            GestureDetector(onTap: () => context.pop(), child: Icon(Icons.arrow_back, color: t.text, size: 24)),
            Expanded(child: Text('Notification Settings', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text))),
            const SizedBox(width: 32),
          ]),
        ),
        Expanded(child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: () async { await _load(); }),
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              sliver: SliverToBoxAdapter(
                child: Column(children: [
                  // Info card
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: t.primary.withAlpha(0x15), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(Icons.info_outline, size: 20, color: t.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Control which notifications you want to receive. All notifications are enabled by default.', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.text, height: 1.5))),
                    ]),
                  ),
                  for (final section in _sections) _buildSection(section.$1, section.$2, section.$3, t),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        )),
        if (_updating) const LinearProgressIndicator(minHeight: 2),
      ])),
    );
  }

  Widget _buildSection(String title, IconData sectionIcon, List<(String, String, String, IconData)> items, _T t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Row(children: [
      Icon(sectionIcon, size: 18, color: t.textTertiary),
      const SizedBox(width: 8),
      Text(title.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: t.textTertiary, letterSpacing: 1.0)),
    ])),
    Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
      child: Column(children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) Container(height: 0.5, color: t.border),
          _notifItem(items[i].$1, items[i].$2, items[i].$3, items[i].$4, t),
        ],
      ]),
    ),
  ]);

  Widget _notifItem(String key, String title, String desc, IconData icon, _T t) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: t.primary.withAlpha(0x15), shape: BoxShape.circle), child: Icon(icon, size: 20, color: t.primary)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: t.text)),
        const SizedBox(height: 3),
        Text(desc, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary)),
      ])),
      Switch(
        value: _prefs[key] ?? true,
        onChanged: _updating ? null : (v) => _toggle(key, v),
        activeTrackColor: t.primary,
        activeThumbColor: Colors.white,
        inactiveTrackColor: dark(ref) ? const Color(0xFF3a3a3c) : const Color(0xFFE0E0E0),
      ),
    ]),
  );

  bool dark(WidgetRef ref) => ref.read(themeProvider);

  Widget _skeleton(_T t) => Scaffold(
    backgroundColor: t.bg,
    body: SafeArea(child: Column(children: [
      Container(height: 56, color: t.headerBg, child: Center(child: Text('Notification Settings', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text)))),
      Expanded(child: Shimmer.fromColors(baseColor: t.skBase, highlightColor: t.skHi, child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(height: 60, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: t.skBase, borderRadius: BorderRadius.circular(12))),
        for (int i = 0; i < 3; i++) ...[
          Container(width: 100, height: 16, margin: const EdgeInsets.only(bottom: 8, left: 4), color: t.skBase),
          Container(height: 130, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: t.skBase, borderRadius: BorderRadius.circular(12))),
        ],
      ]))),
    ])),
  );
}
