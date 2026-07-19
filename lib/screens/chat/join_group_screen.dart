import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/chat_api_service.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _codeCtrl = TextEditingController();
  final _focusNode = FocusNode();

  bool _checking = false;
  bool _joining = false;
  Map<String, dynamic>? _preview;
  String? _error;
  bool _alreadyMember = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    _focusNode.unfocus();
    setState(() {
      _checking = true;
      _preview = null;
      _error = null;
      _alreadyMember = false;
    });
    try {
      final data = await chatApiService.getGroupByInviteCode(code);
      if (data == null) {
        setState(() => _error = 'Invalid or expired invite code.');
      } else {
        final uid = ref.read(authProvider).uid ?? '';
        final members = data['members'] as List? ?? [];
        final alreadyIn = members.any(
          (m) =>
              m['user_id']?.toString() == uid ||
              m['id']?.toString() == uid,
        );
        setState(() {
          _preview = data;
          _alreadyMember = alreadyIn;
        });
      }
    } catch (_) {
      setState(() => _error = 'Could not verify the invite code. Try again.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || _joining) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final result = await chatApiService.joinGroupByInviteCode(code);
      final groupId = result?['data']?['id'] as String? ??
          result?['data']?['group_id'] as String? ??
          _preview?['id'] as String?;
      if (!mounted) return;
      if (groupId != null) {
        context.pushReplacement('/chat/group/$groupId');
      } else {
        // Joined but ID unclear — go back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Joined successfully!',
              style: const TextStyle(fontFamily: 'Outfit'),
            ),
            backgroundColor: context.colors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      final msg = e.toString().contains('already')
          ? 'You are already a member of this group.'
          : 'Failed to join group. Please try again.';
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

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
        title: Text(
          'Join Group',
          style: TextStyle(
            color: c.text,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header illustration area
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: c.primaryButton.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.group_add_outlined,
                    size: 40, color: c.primaryButton),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Enter Invite Code',
                style: TextStyle(
                  color: c.text,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Ask your group admin for an invite code\nand paste it below.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontFamily: 'Outfit',
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Code input
            TextField(
              controller: _codeCtrl,
              focusNode: _focusNode,
              style: TextStyle(
                color: c.text,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: 2,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) {
                if (_preview != null || _error != null) {
                  setState(() {
                    _preview = null;
                    _error = null;
                  });
                }
              },
              onSubmitted: (_) => _checkCode(),
              decoration: InputDecoration(
                hintText: 'e.g. ABC123',
                hintStyle: TextStyle(
                  color: c.placeholder,
                  fontFamily: 'Outfit',
                  letterSpacing: 0,
                ),
                filled: true,
                fillColor: c.surface,
                prefixIcon:
                    Icon(Icons.vpn_key_outlined, color: c.textTertiary),
                suffixIcon: _codeCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: c.textTertiary),
                        onPressed: () {
                          _codeCtrl.clear();
                          setState(() {
                            _preview = null;
                            _error = null;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.primaryButton, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Check Code button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _codeCtrl.text.trim().isNotEmpty && !_checking
                    ? _checkCode
                    : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.primaryButton),
                  foregroundColor: c.primaryButton,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _checking
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.primaryButton,
                        ),
                      )
                    : Text(
                        'Check Code',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: c.primaryButton,
                        ),
                      ),
              ),
            ),

            // Error state
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: c.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: c.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: c.error,
                          fontFamily: 'Outfit',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Preview card
            if (_preview != null) ...[
              const SizedBox(height: 24),
              _GroupPreviewCard(
                group: _preview!,
                alreadyMember: _alreadyMember,
                c: c,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _alreadyMember || _joining ? null : _join,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _alreadyMember
                        ? c.primaryButtonDisabled
                        : c.primaryButton,
                    disabledBackgroundColor: c.primaryButtonDisabled,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _joining
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _alreadyMember
                              ? 'Already a Member'
                              : 'Join Group',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupPreviewCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final bool alreadyMember;
  final ThemeColors c;

  const _GroupPreviewCard({
    required this.group,
    required this.alreadyMember,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final name = group['name'] as String? ?? 'Unknown Group';
    final description = group['description'] as String?;
    final pic = group['image'] as String? ?? group['avatar'] as String?;
    final memberCount = group['member_count'] ?? group['members_count'] ?? 0;
    final isPublic = group['is_public'] == true;
    final category = group['category'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: c.primaryButton.withOpacity(0.15),
                backgroundImage:
                    pic != null ? CachedNetworkImageProvider(pic) : null,
                child: pic == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: c.primaryButton,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: c.text,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isPublic ? Icons.public : Icons.lock_outline,
                          size: 13,
                          color: c.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPublic ? 'Public' : 'Private',
                          style: TextStyle(
                            color: c.textTertiary,
                            fontFamily: 'Outfit',
                            fontSize: 12,
                          ),
                        ),
                        if (category != null) ...[
                          Text(
                            ' · $category',
                            style: TextStyle(
                              color: c.textTertiary,
                              fontFamily: 'Outfit',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (alreadyMember)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Joined',
                    style: TextStyle(
                      color: c.success,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.textSecondary,
                fontFamily: 'Outfit',
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.people_outline, size: 16, color: c.textTertiary),
              const SizedBox(width: 6),
              Text(
                '$memberCount member${memberCount == 1 ? '' : 's'}',
                style: TextStyle(
                  color: c.textSecondary,
                  fontFamily: 'Outfit',
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
