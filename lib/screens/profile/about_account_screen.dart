import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../api/dio_client.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common/verification_badge.dart';

class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF0D1017) : const Color(0xFFFFFFFF);
  Color get surface => dark ? const Color(0xFF1a1f2e) : const Color(0xFFFFFFFF);
  Color get border => dark ? const Color(0xFF38383A) : const Color(0xFFE0E0E0);
  Color get text => dark ? Colors.white : Colors.black;
  Color get textSecondary => dark ? const Color(0xFFEBEBF5) : const Color(0xFF666666);
  Color get textTertiary => const Color(0xFF8E8E93);
  Color get primary => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  Color get iconBgBlue => dark ? const Color(0xFF2a3142) : const Color(0xFFE3F2FD);
  Color get iconBgGreen => dark ? const Color(0xFF2a3142) : const Color(0xFFE8F5E9);
  Color get iconBgOrange => dark ? const Color(0xFF2a3142) : const Color(0xFFFFF3E0);
  Color get chipBg => dark ? const Color(0xFF2a3142) : const Color(0xFFF5F5F5);
}

class AboutAccountScreen extends ConsumerStatefulWidget {
  final String userId;
  const AboutAccountScreen({super.key, required this.userId});

  @override
  ConsumerState<AboutAccountScreen> createState() => _AboutAccountScreenState();
}

class _AboutAccountScreenState extends ConsumerState<AboutAccountScreen> {
  Map<String, dynamic>? _userData;
  List<dynamic> _usernameHistory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() => _loading = true);
    try {
      final res = await dioClient.get('/v1/user/${widget.userId}');
      if (res.data['success'] == true) {
        final user = Map<String, dynamic>.from(res.data['data'] as Map);
        if (mounted) setState(() => _userData = user);

        try {
          final histRes = await dioClient.get('/v1/user/${widget.userId}/username-history');
          if (mounted && histRes.data['success'] == true) {
            setState(() => _usernameHistory = List<dynamic>.from(histRes.data['data'] ?? []));
          }
        } catch (_) {
          if (mounted) setState(() => _usernameHistory = []);
        }
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Unknown';
    try {
      final date = DateTime.parse(dateString).toLocal();
      const months = ['January','February','March','April','May','June',
          'July','August','September','October','November','December'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return 'Unknown';
    }
  }

  String _getAccountAge(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Unknown';
    try {
      final created = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final diffDays = now.difference(created).inDays.abs();
      if (diffDays < 30) return '$diffDays days old';
      if (diffDays < 365) return '${(diffDays / 30).floor()} months old';
      final years = (diffDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} old';
    } catch (_) {
      return 'Unknown';
    }
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
            _buildHeader(context, t),
            if (_loading)
              Expanded(
                child: Center(child: CircularProgressIndicator(color: t.primary)),
              )
            else if (_userData == null)
              Expanded(child: _buildError(t))
            else
              Expanded(child: _buildContent(context, t)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, _T t) {
    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(bottom: BorderSide(color: t.border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.arrow_back, size: 24, color: t.text),
            ),
          ),
          Expanded(
            child: Text(
              'Account Information',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                color: t.text,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildError(_T t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: t.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Unable to load account information',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Outfit',
                color: t.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, _T t) {
    final user = _userData!;
    final isVerified = user['is_verified'] == true;
    final verificationBadge = user['verification_badge'];
    final badgeMap = verificationBadge is Map
        ? Map<String, dynamic>.from(verificationBadge)
        : null;
    final usernameChangeCount = _usernameHistory.length;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Profile Card
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: (user['profile_pic'] as String?) ?? '',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: t.chipBg,
                      child: Icon(Icons.person, size: 40, color: t.textTertiary),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              (user['name'] as String?) ?? '',
                              style: TextStyle(
                                fontSize: 20,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w700,
                                color: t.text,
                              ),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            VerificationBadge(isVerified: true, badge: badgeMap, size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${user['username'] ?? ''}',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Outfit',
                          color: t.textSecondary,
                        ),
                      ),
                      if ((user['bio'] as String?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          user['bio'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Outfit',
                            color: t.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Account Details Section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Details',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "To help keep our community authentic, we're showing information about accounts on WiTalk.",
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Outfit',
                  color: t.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Account Age Card
              _DetailCard(
                t: t,
                iconBg: t.iconBgBlue,
                iconColor: const Color(0xFF2196F3),
                icon: Icons.calendar_today,
                label: 'Account Age',
                value: _getAccountAge(user['created_at'] as String?),
                subtext: 'Joined ${_formatDate(user['created_at'] as String?)}',
              ),
              const SizedBox(height: 12),

              // Location Card
              _DetailCard(
                t: t,
                iconBg: t.iconBgGreen,
                iconColor: const Color(0xFF4CAF50),
                icon: Icons.location_on,
                label: 'Location',
                value: (user['country'] as String?)?.isNotEmpty == true
                    ? user['country'] as String
                    : 'Not specified',
                subtext: (user['city'] as String?)?.isNotEmpty == true
                    ? user['city'] as String
                    : null,
              ),
              const SizedBox(height: 12),

              // Username History Card (tappable)
              GestureDetector(
                onTap: () => context.push('/former-usernames', extra: {
                  'username': user['username'],
                  'usernameHistory': _usernameHistory,
                }),
                child: Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.border),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: t.iconBgOrange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history, size: 20, color: Color(0xFFFF9800)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Username Changes',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Outfit',
                                color: t.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$usernameChangeCount ${usernameChangeCount == 1 ? 'time' : 'times'}',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                color: t.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap to view history',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Outfit',
                                color: t.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 24, color: t.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  final _T t;
  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String label;
  final String value;
  final String? subtext;

  const _DetailCard({
    required this.t,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.label,
    required this.value,
    this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Outfit',
                    color: t.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                if (subtext != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtext!,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      color: t.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
