import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:dio/dio.dart';

import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme_colors.dart';

class CommunityInfoScreen extends ConsumerStatefulWidget {
  final String communityId;
  const CommunityInfoScreen({super.key, required this.communityId});
  @override
  ConsumerState<CommunityInfoScreen> createState() =>
      _CommunityInfoScreenState();
}

class _CommunityInfoScreenState extends ConsumerState<CommunityInfoScreen> {
  Map<String, dynamic>? _group;
  bool _loading = true;
  bool _joining = false;

  // Tabs: 0=Overview, live=-1/1, admins=1/2
  int _activeTab = 0;

  // Admins
  List<Map<String, dynamic>> _admins = [];
  bool _adminsLoading = false;
  bool _adminsFetched = false;

  // Live addas
  List<Map<String, dynamic>> _liveAddas = [];
  bool _liveAddasLoading = false;

  // Location
  Position? _userPosition;
  bool _locationLoading = false;
  bool _gpsDisabled = false;
  bool _locationPermDenied = false;

  // Community reverse-geocode name
  String? _communityLocationName;

  // Alert state
  _AlertConfig? _alert;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> _loadGroup() async {
    final uid = ref.read(authProvider).uid ?? '';
    final params = uid.isNotEmpty ? {'userId': uid} : <String, dynamic>{};
    Map<String, dynamic>? data;
    try {
      // Try by group ID first
      final res = await dioClient.get(
        '/v1/groups/${widget.communityId}',
        queryParameters: params,
      );
      data = res.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      // Fall back to invite code endpoint
      try {
        final res = await dioClient.get(
          '/v1/groups/invite/${widget.communityId}',
          queryParameters: params,
        );
        data = res.data['data'] as Map<String, dynamic>?;
      } catch (_) {}
    }
    if (!mounted) return;
    if (data == null) {
      setState(() => _loading = false);
      _showSnackbar('Failed to load community info.', isError: true);
      return;
    }
    setState(() {
      _group = data;
      _loading = false;
    });
    _afterGroupLoaded();
  }

  void _afterGroupLoaded() {
    final g = _group;
    if (g == null) return;
    _reverseGeocode();
    if (_needsLocation && _userPosition == null && !_locationLoading) {
      _fetchUserLocation();
    }
    _fetchLiveAddas();
  }

  Future<void> _reverseGeocode() async {
    final g = _group;
    if (g == null) return;
    final lat = g['location_lat'];
    final lng = g['location_lng'];
    if (lat == null || lng == null) return;
    try {
      final nominatim = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      nominatim.options.headers['User-Agent'] = 'WiTalk App';
      final res = await nominatim.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': lat.toString(),
          'lon': lng.toString(),
          'addressdetails': '1',
        },
      );
      if (!mounted) return;
      final addr = (res.data['address'] as Map?)?.cast<String, dynamic>() ?? {};
      final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['suburb'];
      final state = addr['state'];
      final parts = [city, state].whereType<String>().toList();
      if (parts.isNotEmpty) {
        setState(() => _communityLocationName = parts.join(', '));
      }
    } catch (_) {}
  }

  Future<void> _fetchAdmins() async {
    final g = _group;
    if (g == null || _adminsFetched || _adminsLoading) return;
    final uid = ref.read(authProvider).uid ?? '';
    setState(() => _adminsLoading = true);
    try {
      final res = await dioClient.get(
        '/v1/groups/${g['id']}',
        queryParameters: {'userId': uid},
      );
      if (!mounted) return;
      final members =
          ((res.data['data']?['members'] ?? []) as List).cast<Map<String, dynamic>>();
      setState(() {
        _admins = members
            .where((m) => m['role'] == 'super_admin' || m['role'] == 'admin')
            .toList();
        _adminsFetched = true;
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _adminsLoading = false);
    }
  }

  Future<void> _fetchLiveAddas() async {
    final g = _group;
    if (g == null) return;
    setState(() => _liveAddasLoading = true);
    try {
      final res =
          await dioClient.get('/v1/audio-rooms/group/${g['id']}/all-active');
      if (!mounted) return;
      final data = res.data['data'];
      setState(() {
        _liveAddas = data is List ? data.cast<Map<String, dynamic>>() : [];
      });
    } catch (_) {
      if (mounted) setState(() => _liveAddas = []);
    } finally {
      if (mounted) setState(() => _liveAddasLoading = false);
    }
  }

  // ── Location ───────────────────────────────────────────────────────────────

  bool get _needsLocation {
    final g = _group;
    if (g == null) return false;
    return g['location_radius_km'] != null &&
        g['location_lat'] != null &&
        g['location_lng'] != null &&
        g['is_member'] != true;
  }

  double? get _distanceKm {
    final g = _group;
    final pos = _userPosition;
    if (!_needsLocation || pos == null || g == null) return null;
    return _haversine(
      pos.latitude,
      pos.longitude,
      double.tryParse(g['location_lat'].toString()) ?? 0.0,
      double.tryParse(g['location_lng'].toString()) ?? 0.0,
    );
  }

  bool get _withinRange {
    final d = _distanceKm;
    final g = _group;
    if (d == null || g == null) return false;
    return d <= (double.tryParse(g['location_radius_km'].toString()) ?? 0.0);
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final p1 = lat1 * pi / 180;
    final p2 = lat2 * pi / 180;
    final dp = (lat2 - lat1) * pi / 180;
    final dl = (lng2 - lng1) * pi / 180;
    final a =
        sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  Future<void> _fetchUserLocation({bool forceRefresh = false}) async {
    setState(() {
      _locationLoading = true;
      _gpsDisabled = false;
      _locationPermDenied = false;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _gpsDisabled = true);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          if (mounted) setState(() => _locationPermDenied = true);
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationPermDenied = true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) setState(() => _userPosition = pos);
    } catch (_) {
      if (mounted) setState(() => _gpsDisabled = true);
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  // ── Join logic ─────────────────────────────────────────────────────────────

  bool get _allowsOneTime =>
      (_group?['monetization_type'] as String? ?? '').contains('one_time');
  bool get _allowsSubscription =>
      (_group?['monetization_type'] as String? ?? '').contains('subscription');
  bool get _allowsPass =>
      (_group?['monetization_type'] as String? ?? '').contains('pass') ||
      _group?['pass_required'] == true;
  bool get _canJoinWithPass =>
      _allowsPass && ((_group?['required_passes'] as List?)?.isNotEmpty ?? false);
  bool get _hasTrial =>
      _group != null &&
      _group!['trial_free_hours'] != null &&
      (double.tryParse(_group!['trial_free_hours'].toString()) ?? 0) > 0 &&
      _group!['trial_already_used'] != true;
  bool get _trialActive {
    final g = _group;
    if (g == null) return false;
    if (g['my_join_method'] != 'trial') return false;
    final endsAt = g['my_trial_ends_at'];
    if (endsAt == null) return false;
    return DateTime.tryParse(endsAt.toString())?.isAfter(DateTime.now()) ?? false;
  }

  bool get _trialExpired {
    final g = _group;
    if (g == null) return false;
    return g['my_join_method'] == 'trial' && !_trialActive;
  }

  void _handleJoin({String? type}) {
    final g = _group;
    if (g == null) return;

    if (_needsLocation) {
      if (_locationLoading) return;
      if (_gpsDisabled || _locationPermDenied) {
        _showSnackbar(
            'Please enable GPS to join this location-based community.',
            isError: true);
        return;
      }
      if (!_withinRange) {
        final d = _distanceKm;
        _showSnackbar(
          d != null
              ? 'You are ${d.round()} km away. Must be within ${g['location_radius_km']} km to join.'
              : 'Could not verify your location. Please try again.',
          isError: true,
        );
        return;
      }
    }

    if (g['can_join'] == false) {
      setState(() => _alert = _AlertConfig(
            title: 'Access Restricted',
            message: g['restriction_reason'] as String? ??
                'You do not meet the requirements to join this community.',
            type: 'error',
          ));
      return;
    }

    if (g['is_monetized'] != true && _canJoinWithPass) {
      _showSnackbar('Pass join not yet supported.', isError: false);
      return;
    }

    if (g['is_monetized'] == true && _hasTrial && g['is_member'] != true) {
      _joinFree();
      return;
    }

    if (g['is_monetized'] == true &&
        (g['is_member'] != true ||
            g['my_join_method'] == 'free' ||
            _trialExpired)) {
      _showSnackbar('Paid join not yet supported.', isError: false);
      return;
    }

    _joinFree();
  }

  Future<void> _joinFree() async {
    if (_joining) return;
    final g = _group;
    if (g == null) return;
    final uid = ref.read(authProvider).uid ?? '';
    setState(() => _joining = true);
    try {
      final body = <String, dynamic>{
        'invite_code': g['invite_code'],
        'user_id': uid,
      };
      if (_userPosition != null) {
        body['coords'] = {
          'latitude': _userPosition!.latitude,
          'longitude': _userPosition!.longitude,
        };
      }
      final res = await dioClient.post('/v1/groups/join', data: body);
      if (!mounted) return;
      if (res.data['requiresApproval'] == true) {
        setState(() => _alert = const _AlertConfig(
              title: 'Request Sent',
              message:
                  "Your join request has been sent. You'll be notified once approved.",
              type: 'success',
              goBack: true,
            ));
      } else {
        context.pushReplacement('/chat/group/${g['id']}');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Failed to join community.', isError: true);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _handleOpen() {
    final g = _group;
    if (g == null) return;
    context.pushReplacement('/chat/group/${g['id']}');
  }

  // ── Tabs ───────────────────────────────────────────────────────────────────

  bool get _hasLiveAddas => _liveAddas.isNotEmpty;
  List<String> get _tabs =>
      _hasLiveAddas ? ['Overview', 'Live Addas', 'Admins'] : ['Overview', 'Admins'];
  int get _liveTab => _hasLiveAddas ? 1 : -1;
  int get _adminsTab => _hasLiveAddas ? 2 : 1;

  void _onTabTap(int i) {
    setState(() => _activeTab = i);
    if (i == _adminsTab && !_adminsFetched) _fetchAdmins();
    if (i == _liveTab) _fetchLiveAddas();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnackbar(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Outfit')),
      backgroundColor: isError ? const Color(0xFFFF6B6B) : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading && _group == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: colors.primary),
                const SizedBox(height: 12),
                Text('Loading community...',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        color: colors.textSecondary,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    if (_group == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _BackButton(onTap: () => context.pop()),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: colors.textSecondary),
                      const SizedBox(height: 12),
                      Text('Could not load community info.',
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              color: colors.textSecondary,
                              fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final g = _group!;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildBanner(g, isDark, colors),
                _buildIdentityBlock(g, isDark, colors),
                _buildTabBar(isDark, colors),
                Expanded(child: _buildTabContent(g, isDark, colors)),
                _buildFooter(g, isDark, colors),
              ],
            ),
            if (_alert != null)
              _AlertOverlay(
                config: _alert!,
                colors: colors,
                onDismiss: () {
                  final goBack = _alert?.goBack ?? false;
                  setState(() => _alert = null);
                  if (goBack && mounted) context.pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Banner hero ────────────────────────────────────────────────────────────

  Widget _buildBanner(
      Map<String, dynamic> g, bool isDark, ThemeColors colors) {
    final pic = g['picture'] as String?;
    return SizedBox(
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          if (pic != null)
            CachedNetworkImage(
              imageUrl: pic,
              fit: BoxFit.cover,
              imageBuilder: (_, img) => ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Image(image: img, fit: BoxFit.cover),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF0A84FF).withOpacity(0.35),
                          const Color(0xFF0A84FF).withOpacity(0.10),
                        ]
                      : [
                          const Color(0xFF007AFF).withOpacity(0.22),
                          const Color(0xFF007AFF).withOpacity(0.07),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          // Overlay
          Container(
            color: isDark
                ? Colors.black.withOpacity(0.56)
                : Colors.black.withOpacity(0.24),
          ),
          // Back button
          Positioned(
            top: 14,
            left: 16,
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.28), width: 1),
                ),
                child: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
              ),
            ),
          ),
          // Avatar
          Center(
            child: pic != null
                ? CachedNetworkImage(
                    imageUrl: pic,
                    imageBuilder: (_, img) => Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.75), width: 2.5),
                        image: DecorationImage(image: img, fit: BoxFit.cover),
                      ),
                    ),
                  )
                : Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? const Color(0xFF0A84FF).withOpacity(0.18)
                          : const Color(0xFF007AFF).withOpacity(0.10),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.75), width: 2.5),
                    ),
                    child: Icon(Icons.group, size: 48, color: colors.primary),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Identity block ─────────────────────────────────────────────────────────

  Widget _buildIdentityBlock(
      Map<String, dynamic> g, bool isDark, ThemeColors colors) {
    final name = g['name'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.text),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: _buildBadges(g, isDark, colors),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBadges(
      Map<String, dynamic> g, bool isDark, ThemeColors colors) {
    final chips = <Widget>[];

    if (g['is_monetized'] == true && _allowsOneTime) {
      chips.add(_Chip(
        icon: Icons.bolt,
        label: 'One-time',
        color: const Color(0xFFD97706),
        bgColor: isDark
            ? const Color(0xFFD97706).withOpacity(0.18)
            : const Color(0xFFFEF3C7),
        borderColor: isDark
            ? const Color(0xFFD97706).withOpacity(0.4)
            : const Color(0xFFFDE68A),
      ));
    }
    if (g['is_monetized'] == true && _allowsSubscription) {
      chips.add(_Chip(
        icon: Icons.workspace_premium,
        label: 'Subscription',
        color: const Color(0xFFD97706),
        bgColor: isDark
            ? const Color(0xFFD97706).withOpacity(0.18)
            : const Color(0xFFFEF3C7),
        borderColor: isDark
            ? const Color(0xFFD97706).withOpacity(0.4)
            : const Color(0xFFFDE68A),
      ));
    }
    if (g['is_monetized'] == true ? _allowsPass : g['pass_required'] == true) {
      chips.add(_Chip(
        icon: Icons.confirmation_number,
        label: 'Pass',
        color: const Color(0xFFB45309),
        bgColor: isDark
            ? const Color(0xFFD97706).withOpacity(0.18)
            : const Color(0xFFFEF3C7),
        borderColor: isDark
            ? const Color(0xFFD97706).withOpacity(0.4)
            : const Color(0xFFFDE68A),
      ));
    }
    if (g['is_monetized'] != true && g['pass_required'] != true) {
      chips.add(_Chip(
        icon: Icons.lock_open,
        label: 'Free to Join',
        color: const Color(0xFF047857),
        bgColor: isDark
            ? const Color(0xFF047857).withOpacity(0.18)
            : const Color(0xFFD1FAE5),
        borderColor: isDark
            ? const Color(0xFF047857).withOpacity(0.4)
            : const Color(0xFFA7F3D0),
      ));
    }
    if (_trialActive) {
      chips.add(_Chip(
        icon: Icons.timer,
        label: 'Trial Active',
        color: const Color(0xFFB45309),
        bgColor: isDark
            ? const Color(0xFFD97706).withOpacity(0.18)
            : const Color(0xFFFEF3C7),
        borderColor: isDark
            ? const Color(0xFFD97706).withOpacity(0.4)
            : const Color(0xFFFDE68A),
      ));
    }
    if (g['can_join'] == false) {
      chips.add(_Chip(
        icon: Icons.block,
        label: 'Restricted',
        color: const Color(0xFFDC2626),
        bgColor: isDark
            ? const Color(0xFFDC2626).withOpacity(0.15)
            : const Color(0xFFFEE2E2),
        borderColor: isDark
            ? const Color(0xFFDC2626).withOpacity(0.4)
            : const Color(0xFFFECACA),
      ));
    }
    if (g['verified_only'] == true) {
      chips.add(_Chip(
        icon: Icons.verified,
        label: 'Verified Only',
        color: const Color(0xFF2563EB),
        bgColor: isDark
            ? const Color(0xFF2563EB).withOpacity(0.18)
            : const Color(0xFFDBEAFE),
        borderColor: isDark
            ? const Color(0xFF2563EB).withOpacity(0.4)
            : const Color(0xFFBFDBFE),
      ));
    }
    // Location chip
    if (g['location_lat'] != null && g['location_lng'] != null) {
      if (_communityLocationName != null) {
        chips.add(_Chip(
          icon: Icons.place,
          label: _communityLocationName!,
          color: const Color(0xFF0891B2),
          bgColor: isDark
              ? const Color(0xFF0891B2).withOpacity(0.18)
              : const Color(0xFFCFFAFE),
          borderColor: isDark
              ? const Color(0xFF0891B2).withOpacity(0.4)
              : const Color(0xFFA5F3FC),
        ));
      }
    } else {
      chips.add(_Chip(
        icon: Icons.public,
        label: 'Global',
        color: const Color(0xFF7C3AED),
        bgColor: isDark
            ? const Color(0xFF7C3AED).withOpacity(0.18)
            : const Color(0xFFEDE9FE),
        borderColor: isDark
            ? const Color(0xFF7C3AED).withOpacity(0.4)
            : const Color(0xFFDDD6FE),
      ));
    }
    return chips;
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar(bool isDark, ThemeColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.background,
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final tab = _tabs[i];
          final isActive = _activeTab == i;
          final isLive = tab == 'Live Addas';
          return Expanded(
            child: GestureDetector(
              onTap: () => _onTabTap(i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isLive)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? const Color(0xFFFF3B30)
                                  : colors.textTertiary,
                            ),
                          ),
                        Text(
                          tab,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isActive
                                ? (isLive
                                    ? const Color(0xFFFF3B30)
                                    : colors.primary)
                                : colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (isActive)
                      Positioned(
                        bottom: 0,
                        left: '20%' == '20%'
                            ? null
                            : null, // resolved below via FractionallySizedBox
                        child: FractionallySizedBox(
                          widthFactor: 0.6,
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: isLive
                                  ? const Color(0xFFFF3B30)
                                  : colors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Tab content ────────────────────────────────────────────────────────────

  Widget _buildTabContent(
      Map<String, dynamic> g, bool isDark, ThemeColors colors) {
    if (_activeTab == 0) return _buildOverviewTab(g, isDark, colors);
    if (_activeTab == _liveTab) return _buildLiveAddasTab(isDark, colors);
    return _buildAdminsTab(isDark, colors);
  }

  // Overview tab
  Widget _buildOverviewTab(
      Map<String, dynamic> g, bool isDark, ThemeColors colors) {
    final hasRequirements = g['verified_only'] == true ||
        (g['city'] != null && g['city'] != '') ||
        g['location_radius_km'] != null ||
        (g['gender_allowed'] != null && g['gender_allowed'] != 'all') ||
        g['min_age'] != null ||
        g['max_age'] != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        // Stats row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0A84FF).withOpacity(0.08)
                : const Color(0xFF007AFF).withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF0A84FF).withOpacity(0.2)
                  : const Color(0xFF007AFF).withOpacity(0.12),
            ),
          ),
          child: Row(
            children: [
              _StatItem(
                icon: Icons.group,
                value: '${g['member_count'] ?? 0}',
                label: 'Members',
                colors: colors,
              ),
              _StatDivider(isDark: isDark),
              _StatItem(
                icon: g['group_type'] == 'private' ? Icons.lock : Icons.public,
                value: g['group_type'] == 'private' ? 'Private' : 'Public',
                label: 'Visibility',
                colors: colors,
              ),
              _StatDivider(isDark: isDark),
              _StatItem(
                icon: Icons.chat_bubble_outline,
                value: 'Community',
                label: 'Type',
                colors: colors,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // About
        if ((g['description'] as String? ?? '').isNotEmpty)
          _SectionCard(
            icon: Icons.info_outline,
            title: 'About',
            isDark: isDark,
            colors: colors,
            child: Text(
              g['description'] as String,
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.57),
            ),
          ),

        if ((g['rules'] as String? ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.gavel,
            title: 'Community Rules',
            isDark: isDark,
            colors: colors,
            child: Text(
              g['rules'] as String,
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.57),
            ),
          ),
        ],

        if (hasRequirements) ...[
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.rule,
            title: 'Join Requirements',
            isDark: isDark,
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (g['verified_only'] == true)
                  _RequirementRow(
                    iconBg: isDark
                        ? const Color(0xFF2563EB).withOpacity(0.18)
                        : const Color(0xFFDBEAFE),
                    icon: Icons.verified,
                    iconColor: const Color(0xFF2563EB),
                    text: 'Verified account required',
                    colors: colors,
                  ),
                if (g['gender_allowed'] != null &&
                    g['gender_allowed'] != 'all')
                  _RequirementRow(
                    iconBg: isDark
                        ? const Color(0xFF7C3AED).withOpacity(0.18)
                        : const Color(0xFFEDE9FE),
                    icon: Icons.person,
                    iconColor: const Color(0xFF7C3AED),
                    text:
                        '${(g['gender_allowed'] as String).substring(0, 1).toUpperCase()}${(g['gender_allowed'] as String).substring(1)} members only',
                    colors: colors,
                  ),
                if (g['min_age'] != null || g['max_age'] != null)
                  _RequirementRow(
                    iconBg: isDark
                        ? const Color(0xFF059669).withOpacity(0.18)
                        : const Color(0xFFD1FAE5),
                    icon: Icons.cake,
                    iconColor: const Color(0xFF059669),
                    text: g['min_age'] != null && g['max_age'] != null
                        ? 'Age: ${g['min_age']}–${g['max_age']}'
                        : g['min_age'] != null
                            ? 'Age: ${g['min_age']}+'
                            : 'Age: up to ${g['max_age']}',
                    colors: colors,
                  ),
                if ((g['city'] as String? ?? '').isNotEmpty &&
                    g['location_radius_km'] == null)
                  _RequirementRow(
                    iconBg: isDark
                        ? const Color(0xFFD97706).withOpacity(0.18)
                        : const Color(0xFFFFFBEB),
                    icon: Icons.location_city,
                    iconColor: const Color(0xFFD97706),
                    text: 'Open to users from ${g['city']}',
                    colors: colors,
                  ),
                if (g['location_radius_km'] != null)
                  _buildLocationRequirement(g, isDark, colors),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationRequirement(
      Map<String, dynamic> g, bool isDark, ThemeColors colors) {
    final d = _distanceKm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFFD97706).withOpacity(0.18)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.my_location,
                  size: 14, color: Color(0xFFD97706)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Within ',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: colors.textSecondary,
                          height: 1.54),
                      children: [
                        TextSpan(
                          text: '${g['location_radius_km']} km',
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              color: colors.text),
                        ),
                        const TextSpan(text: ' of community location'),
                      ],
                    ),
                  ),
                  if (_communityLocationName != null)
                    Text(
                      _communityLocationName!,
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: colors.textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (g['is_member'] != true) ...[
          const SizedBox(height: 8),
          if (_locationLoading)
            Row(
              children: [
                const SizedBox(width: 36),
                SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.primary)),
                const SizedBox(width: 8),
                Text('Checking your location...',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: colors.textSecondary)),
              ],
            )
          else if (_gpsDisabled || _locationPermDenied)
            _LocationStatusCard(
              icon: Icons.location_off,
              iconColor: const Color(0xFFDC2626),
              title: _locationPermDenied
                  ? 'Location permission denied'
                  : 'GPS is disabled',
              body: _locationPermDenied
                  ? 'Grant location permission so we can verify you are nearby.'
                  : 'Enable GPS so we can verify you are within range to join.',
              bgColor: isDark
                  ? const Color(0xFFDC2626).withOpacity(0.10)
                  : const Color(0xFFFEE2E2),
              borderColor: isDark
                  ? const Color(0xFFDC2626).withOpacity(0.35)
                  : const Color(0xFFFECACA),
              actionLabel: _locationPermDenied ? 'Settings' : 'Enable',
              onAction: _locationPermDenied
                  ? _openLocationSettings
                  : () => _fetchUserLocation(),
              colors: colors,
            )
          else if (d != null)
            _LocationStatusCard(
              icon: _withinRange ? Icons.check_circle : Icons.warning,
              iconColor: _withinRange
                  ? const Color(0xFF059669)
                  : const Color(0xFFD97706),
              title: _withinRange
                  ? 'You are within range'
                  : 'You are too far away',
              body:
                  'Distance: ${d < 1 ? '${(d * 1000).round()} m' : '${d.toStringAsFixed(1)} km'} · Required: within ${g['location_radius_km']} km',
              bgColor: _withinRange
                  ? (isDark
                      ? const Color(0xFF059669).withOpacity(0.10)
                      : const Color(0xFFD1FAE5))
                  : (isDark
                      ? const Color(0xFFD97706).withOpacity(0.10)
                      : const Color(0xFFFFFBEB)),
              borderColor: _withinRange
                  ? (isDark
                      ? const Color(0xFF059669).withOpacity(0.35)
                      : const Color(0xFFA7F3D0))
                  : (isDark
                      ? const Color(0xFFD97706).withOpacity(0.35)
                      : const Color(0xFFFDE68A)),
              actionIcon: Icons.refresh,
              onAction: () => _fetchUserLocation(forceRefresh: true),
              colors: colors,
            ),
        ],
      ],
    );
  }

  // Live addas tab
  Widget _buildLiveAddasTab(bool isDark, ThemeColors colors) {
    if (_liveAddasLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFF3B30)),
            const SizedBox(height: 10),
            Text('Loading live addas...',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    color: colors.textSecondary,
                    fontSize: 13)),
          ],
        ),
      );
    }
    if (_liveAddas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_off, size: 42, color: colors.textSecondary),
            const SizedBox(height: 10),
            Text('No active addas right now',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    color: colors.textSecondary,
                    fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _liveAddas.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFFFF3B30))),
                const SizedBox(width: 6),
                Text(
                  '${_liveAddas.length} live ${_liveAddas.length == 1 ? 'adda' : 'addas'}',
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Color(0xFFFF3B30),
                      letterSpacing: 0.4),
                ),
              ],
            ),
          );
        }
        final item = _liveAddas[i - 1];
        return _buildAddaCard(item, isDark, colors);
      },
    );
  }

  Widget _buildAddaCard(
      Map<String, dynamic> item, bool isDark, ThemeColors colors) {
    return GestureDetector(
      onTap: () {
        if (_group?['is_member'] != true) {
          setState(() => _alert = const _AlertConfig(
                title: 'Join Community First',
                message:
                    'You need to join this community before you can enter its live addas.',
                type: 'info',
              ));
          return;
        }
        final roomId = item['room_id'] as String? ?? '';
        context.push('/live-audio/$roomId');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFFFF3B30).withOpacity(0.07)
              : const Color(0xFFFF3B30).withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                _avatar(item['host_profile_pic'] as String?, 44,
                    fallbackIcon: Icons.person,
                    fallbackBg: isDark
                        ? const Color(0xFFFF3B30).withOpacity(0.18)
                        : const Color(0xFFFF3B30).withOpacity(0.10),
                    fallbackIconColor: const Color(0xFFFF3B30)),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF3B30),
                      border: Border.all(
                          color:
                              isDark ? const Color(0xFF121212) : Colors.white,
                          width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['room_name'] as String? ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: colors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'by ${item['host_name'] ?? item['host_username'] ?? 'Host'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFFF3B30).withOpacity(0.15)
                        : const Color(0xFFFF3B30).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.headset,
                          size: 11, color: Color(0xFFFF3B30)),
                      const SizedBox(width: 3),
                      Text(
                        '${item['current_participants_count'] ?? 0}',
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: Color(0xFFFF3B30)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Join',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Admins tab
  Widget _buildAdminsTab(bool isDark, ThemeColors colors) {
    if (_adminsLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colors.primary),
            const SizedBox(height: 10),
            Text('Loading admins...',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    color: colors.textSecondary,
                    fontSize: 13)),
          ],
        ),
      );
    }
    if (_admins.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings,
                size: 42, color: colors.textSecondary),
            const SizedBox(height: 10),
            Text('No admins found',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    color: colors.textSecondary,
                    fontSize: 14)),
          ],
        ),
      );
    }
    final uid = ref.read(authProvider).uid ?? '';
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _admins.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${_admins.length} ${_admins.length == 1 ? 'admin' : 'admins'} · Tap to view profile',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: colors.textSecondary),
            ),
          );
        }
        final admin = _admins[i - 1];
        return _buildAdminCard(admin, isDark, colors, uid);
      },
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> admin, bool isDark,
      ThemeColors colors, String currentUid) {
    final adminUid = admin['user_id'] as String? ?? '';
    return GestureDetector(
      onTap: () {
        if (adminUid.isEmpty) return;
        if (adminUid == currentUid) {
          context.push('/profile');
        } else {
          context.push('/user/$adminUid');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                _avatar(admin['profile_pic'] as String?, 46,
                    fallbackIcon: Icons.person,
                    fallbackBg: isDark
                        ? const Color(0xFF0A84FF).withOpacity(0.18)
                        : const Color(0xFF007AFF).withOpacity(0.10),
                    fallbackIconColor: colors.primary),
                if (admin['role'] == 'super_admin')
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFD97706),
                        border: Border.all(
                            color: colors.background, width: 1.5),
                      ),
                      child: const Icon(Icons.star,
                          size: 9, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (admin['name'] as String? ?? 'Unknown'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    admin['role'] == 'super_admin' ? 'Owner' : 'Admin',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }

  // ── Footer (join/open buttons) ─────────────────────────────────────────────

  Widget _buildFooter(
      Map<String, dynamic> g, bool isDark, ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border, width: 1)),
      ),
      child: _buildFooterContent(g, isDark, colors),
    );
  }

  Widget _buildFooterContent(
      Map<String, dynamic> g, bool isDark, ThemeColors colors) {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(
              color: colors.primary, strokeWidth: 2));
    }

    if (_needsLocation && _locationLoading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: colors.primary)),
          const SizedBox(width: 10),
          Text('Verifying your location...',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: colors.textSecondary)),
        ],
      );
    }

    // Open Community — already a member (and not in a state that needs re-purchase)
    final isMember = g['is_member'] == true;
    final needsRepurchase = isMember &&
        g['is_monetized'] == true &&
        (g['my_join_method'] == 'free' || _trialExpired);

    if (isMember && !needsRepurchase) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _handleOpen,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 20, color: Colors.white),
                  SizedBox(width: 7),
                  Text('Open Community',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Determine join methods
    final methods = <String>[];
    if (g['is_monetized'] == true && _allowsOneTime) methods.add('one_time');
    if (g['is_monetized'] == true && _allowsSubscription) methods.add('subscription');
    if (_canJoinWithPass) methods.add('pass');
    if (methods.isEmpty) methods.add('free');

    final isBlocked = (_needsLocation && !_locationLoading &&
            (_gpsDisabled || _locationPermDenied || !_withinRange)) ||
        g['can_join'] == false;
    final btnDisabled = _joining || isBlocked;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Banners
        if (isMember && g['is_monetized'] == true && g['my_join_method'] == 'free')
          _FooterBanner(
            icon: Icons.lock,
            iconColor: const Color(0xFFD97706),
            text: 'Paid community — get access below',
            bgColor: isDark
                ? const Color(0xFFD97706).withOpacity(0.12)
                : const Color(0xFFFFFBEB),
            borderColor: isDark
                ? const Color(0xFFD97706).withOpacity(0.35)
                : const Color(0xFFFDE68A),
          ),
        if (_trialExpired)
          _FooterBanner(
            icon: Icons.timer_off,
            iconColor: const Color(0xFFDC2626),
            text: 'Trial ended — subscribe to keep access',
            bgColor: isDark
                ? const Color(0xFFDC2626).withOpacity(0.12)
                : const Color(0xFFFEE2E2),
            borderColor: isDark
                ? const Color(0xFFDC2626).withOpacity(0.35)
                : const Color(0xFFFECACA),
          ),
        if (g['can_join'] == false)
          _FooterBanner(
            icon: Icons.block,
            iconColor: const Color(0xFFDC2626),
            text: g['restriction_reason'] as String? ??
                'You cannot join this community',
            bgColor: isDark
                ? const Color(0xFFDC2626).withOpacity(0.12)
                : const Color(0xFFFEE2E2),
            borderColor: isDark
                ? const Color(0xFFDC2626).withOpacity(0.35)
                : const Color(0xFFFECACA),
          ),

        // Buttons
        if (methods.length == 1) ...[
          if (methods.isNotEmpty && (methods.isNotEmpty ? true : false))
            _buildSingleMethodBtn(
                methods[0], isDark, colors, btnDisabled, g),
        ] else if (methods.length == 2)
          _buildTwoMethodBtns(methods, isDark, colors, btnDisabled)
        else
          _buildThreeMethodBtns(isDark, colors, btnDisabled),
      ],
    );
  }

  Widget _buildSingleMethodBtn(String m, bool isDark, ThemeColors colors,
      bool disabled, Map<String, dynamic> g) {
    IconData icon;
    String label;
    switch (m) {
      case 'subscription':
        icon = Icons.workspace_premium;
        label = _hasTrial && g['is_member'] != true
            ? 'Start Free Trial'
            : 'Subscribe to Join';
        break;
      case 'one_time':
        icon = Icons.bolt;
        label = _hasTrial && g['is_member'] != true
            ? 'Start Free Trial'
            : 'Buy to Join';
        break;
      case 'pass':
        icon = Icons.confirmation_number;
        label = 'Join with Pass';
        break;
      default:
        icon = Icons.group_add;
        label = 'Join Community';
    }
    return GestureDetector(
      onTap: disabled ? null : () => _handleJoin(type: m == 'free' ? null : m),
      child: Opacity(
        opacity: disabled ? 0.45 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(28),
          ),
          child: _joining
              ? const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: 7),
                    Text(label,
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.white)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTwoMethodBtns(
      List<String> methods, bool isDark, ThemeColors colors, bool disabled) {
    return Row(
      children: methods.map((m) {
        final isPass = m == 'pass';
        final icon = m == 'subscription'
            ? Icons.workspace_premium
            : m == 'one_time'
                ? Icons.bolt
                : Icons.confirmation_number;
        final label = m == 'subscription'
            ? 'Subscribe'
            : m == 'one_time'
                ? 'Buy Access'
                : 'Use Pass';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                left: methods.indexOf(m) == 0 ? 0 : 4,
                right: methods.indexOf(m) == 0 ? 4 : 0),
            child: GestureDetector(
              onTap: disabled ? null : () => _handleJoin(type: m),
              child: Opacity(
                opacity: disabled ? 0.45 : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: isPass
                        ? (isDark
                            ? const Color(0xFF0A84FF).withOpacity(0.10)
                            : const Color(0xFF007AFF).withOpacity(0.07))
                        : colors.primary,
                    borderRadius: BorderRadius.circular(28),
                    border: isPass
                        ? Border.all(color: colors.primary, width: 1.5)
                        : null,
                  ),
                  child: _joining
                      ? Center(
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isPass ? colors.primary : Colors.white)))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon,
                                size: 15,
                                color: isPass ? colors.primary : Colors.white),
                            const SizedBox(width: 6),
                            Text(label,
                                style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: isPass
                                        ? colors.primary
                                        : Colors.white)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildThreeMethodBtns(
      bool isDark, ThemeColors colors, bool disabled) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _gradientBtn(Icons.bolt, 'Buy Access', disabled, colors, () => _handleJoin(type: 'one_time'), isDark)),
            const SizedBox(width: 8),
            Expanded(child: _gradientBtn(Icons.workspace_premium, 'Subscribe', disabled, colors, () => _handleJoin(type: 'subscription'), isDark)),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: disabled ? null : () => _handleJoin(type: 'pass'),
          child: Opacity(
            opacity: disabled ? 0.45 : 1.0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A84FF).withOpacity(0.10)
                    : const Color(0xFF007AFF).withOpacity(0.07),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: colors.primary, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.confirmation_number,
                      size: 15, color: colors.primary),
                  const SizedBox(width: 6),
                  Text('Use Pass',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: colors.primary)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _gradientBtn(IconData icon, String label, bool disabled,
      ThemeColors colors, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _avatar(
    String? url,
    double size, {
    required IconData fallbackIcon,
    required Color fallbackBg,
    required Color fallbackIconColor,
  }) {
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        imageBuilder: (_, img) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(image: img, fit: BoxFit.cover),
          ),
        ),
        placeholder: (_, __) => _avatarPlaceholder(
            size, fallbackIcon, fallbackBg, fallbackIconColor),
        errorWidget: (_, __, ___) => _avatarPlaceholder(
            size, fallbackIcon, fallbackBg, fallbackIconColor),
      );
    }
    return _avatarPlaceholder(size, fallbackIcon, fallbackBg, fallbackIconColor);
  }

  Widget _avatarPlaceholder(double size, IconData icon, Color bg, Color iconColor) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: Icon(icon, size: size * 0.48, color: iconColor),
    );
  }
}

// ── Private data class ─────────────────────────────────────────────────────

class _AlertConfig {
  final String title;
  final String message;
  final String type;
  final bool goBack;
  const _AlertConfig({
    required this.title,
    required this.message,
    required this.type,
    this.goBack = false,
  });
}

// ── Small reusable sub-widgets ─────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        child: Icon(Icons.arrow_back,
            size: 22, color: context.colors.text),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: color)),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final ThemeColors colors;
  const _StatItem(
      {required this.icon,
      required this.value,
      required this.label,
      required this.colors});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: colors.text)),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  color: colors.textSecondary)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  final bool isDark;
  const _StatDivider({required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: isDark
          ? const Color(0xFF0A84FF).withOpacity(0.25)
          : const Color(0xFF007AFF).withOpacity(0.15),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDark;
  final ThemeColors colors;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.isDark,
    required this.colors,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0A84FF).withOpacity(0.18)
                      : const Color(0xFF007AFF).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: colors.primary),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: colors.text)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String text;
  final ThemeColors colors;
  const _RequirementRow({
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    color: colors.textSecondary,
                    height: 1.54)),
          ),
        ],
      ),
    );
  }
}

class _LocationStatusCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Color bgColor;
  final Color borderColor;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback onAction;
  final ThemeColors colors;
  const _LocationStatusCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.bgColor,
    required this.borderColor,
    this.actionLabel,
    this.actionIcon,
    required this.onAction,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: iconColor)),
                const SizedBox(height: 2),
                Text(body,
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.33)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.primary),
              ),
              child: actionLabel != null
                  ? Text(actionLabel!,
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: colors.primary))
                  : Icon(actionIcon!, size: 14, color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterBanner extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color bgColor;
  final Color borderColor;
  const _FooterBanner({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.bgColor,
    required this.borderColor,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF374151),
                  height: 1.33),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertOverlay extends StatelessWidget {
  final _AlertConfig config;
  final ThemeColors colors;
  final VoidCallback onDismiss;
  const _AlertOverlay(
      {required this.config,
      required this.colors,
      required this.onDismiss});
  @override
  Widget build(BuildContext context) {
    Color iconColor;
    IconData iconData;
    switch (config.type) {
      case 'success':
        iconColor = const Color(0xFF30D158);
        iconData = Icons.check_circle_outline;
        break;
      case 'error':
        iconColor = const Color(0xFFFF453A);
        iconData = Icons.error_outline;
        break;
      default:
        iconColor = const Color(0xFF0A84FF);
        iconData = Icons.info_outline;
    }
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconData, size: 48, color: iconColor),
                  const SizedBox(height: 16),
                  Text(config.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: colors.text)),
                  const SizedBox(height: 10),
                  Text(config.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          color: colors.textSecondary,
                          height: 1.5)),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Text('OK',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

