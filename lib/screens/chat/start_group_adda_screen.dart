import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/chat_api_service.dart';

class StartGroupAddaScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const StartGroupAddaScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<StartGroupAddaScreen> createState() =>
      _StartGroupAddaScreenState();
}

class _StartGroupAddaScreenState
    extends ConsumerState<StartGroupAddaScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _scheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  bool _starting = false;
  bool _loadingActive = true;
  Map<String, dynamic>? _activeRoom;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(() => setState(() {}));
    _checkActiveRoom();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkActiveRoom() async {
    setState(() => _loadingActive = true);
    try {
      final res = await dioClient.get(
          AppEndpoints.audioRoomGroupActive(widget.groupId));
      final data = res.data['data'];
      if (data is List && data.isNotEmpty) {
        setState(() => _activeRoom = Map<String, dynamic>.from(data.first as Map));
      } else if (data is Map && data.isNotEmpty) {
        setState(() => _activeRoom = Map<String, dynamic>.from(data as Map));
      }
    } catch (_) {
      // Non-blocking — active room check failure is acceptable
    } finally {
      if (mounted) setState(() => _loadingActive = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: context.colors.primaryButton,
            surface: context.colors.surface,
            onSurface: context.colors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: context.colors.primaryButton,
            surface: context.colors.surface,
            onSurface: context.colors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  DateTime? get _scheduledAt {
    if (!_scheduled) return null;
    final d = _scheduledDate;
    final t = _scheduledTime;
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  bool get _canStart {
    if (_titleCtrl.text.trim().isEmpty) return false;
    if (_scheduled) {
      final at = _scheduledAt;
      if (at == null) return false;
      if (at.isBefore(DateTime.now())) return false;
    }
    return true;
  }

  Future<void> _start() async {
    if (!_canStart || _starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      final uid = ref.read(authProvider).uid;
      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'group_id': widget.groupId,
        if (uid != null) 'host_id': uid,
        if (_scheduled && _scheduledAt != null)
          'scheduled_at': _scheduledAt!.toUtc().toIso8601String(),
      };

      final res =
          await dioClient.post(AppEndpoints.audioRooms, data: payload);
      final roomId = res.data['data']?['id'] as String?;

      if (!mounted) return;
      if (roomId != null) {
        context.pushReplacement('/live-audio/$roomId');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _scheduled
                  ? 'Adda scheduled successfully!'
                  : 'Adda started!',
              style: const TextStyle(fontFamily: 'Outfit'),
            ),
            backgroundColor: context.colors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      final msg = e.toString().contains('already')
          ? 'An Adda is already active in this group.'
          : 'Failed to start Adda. Please try again.';
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _starting = false);
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
          icon: Icon(Icons.close, color: c.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Start Group Adda',
          style: TextStyle(
            color: c.text,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active room banner
            if (_loadingActive)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(
                  color: c.primaryButton,
                  backgroundColor: c.border,
                ),
              )
            else if (_activeRoom != null)
              _ActiveRoomBanner(room: _activeRoom!, c: c, groupId: widget.groupId),

            // Group context pill
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_outlined, size: 16, color: c.textTertiary),
                  const SizedBox(width: 6),
                  Text(
                    'For: ${widget.groupName}',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontFamily: 'Outfit',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Title field
            _label('Room Title *', c),
            const SizedBox(height: 8),
            _buildField(
              controller: _titleCtrl,
              hint: 'Give your Adda a catchy title…',
              icon: Icons.mic_none_outlined,
              c: c,
            ),
            const SizedBox(height: 16),

            // Description field
            _label('Description', c),
            const SizedBox(height: 8),
            _buildField(
              controller: _descCtrl,
              hint: 'What will you talk about? (optional)',
              icon: Icons.notes_outlined,
              maxLines: 3,
              c: c,
            ),
            const SizedBox(height: 20),

            // Schedule toggle
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: SwitchListTile(
                value: _scheduled,
                onChanged: (v) => setState(() {
                  _scheduled = v;
                  if (!v) {
                    _scheduledDate = null;
                    _scheduledTime = null;
                  }
                }),
                activeColor: c.primaryButton,
                title: Text(
                  'Schedule for Later',
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  _scheduled
                      ? 'Pick a date & time below'
                      : 'Start immediately',
                  style: TextStyle(
                    color: c.textTertiary,
                    fontFamily: 'Outfit',
                    fontSize: 12,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),

            // Date/time pickers
            if (_scheduled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateTimeTile(
                      label: 'Date',
                      value: _scheduledDate != null
                          ? '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'
                          : 'Pick date',
                      icon: Icons.calendar_today_outlined,
                      c: c,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateTimeTile(
                      label: 'Time',
                      value: _scheduledTime != null
                          ? _scheduledTime!.format(context)
                          : 'Pick time',
                      icon: Icons.access_time_outlined,
                      c: c,
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              if (_scheduledAt != null &&
                  _scheduledAt!.isBefore(DateTime.now())) ...[
                const SizedBox(height: 8),
                Text(
                  'Scheduled time must be in the future.',
                  style: TextStyle(
                    color: c.error,
                    fontFamily: 'Outfit',
                    fontSize: 12,
                  ),
                ),
              ],
            ],

            // Error message
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

            const SizedBox(height: 32),

            // Start button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _canStart && !_starting ? _start : null,
                icon: _starting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _scheduled ? Icons.schedule : Icons.mic,
                        size: 22,
                        color: Colors.white,
                      ),
                label: Text(
                  _scheduled ? 'Schedule Adda' : 'Start Adda',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primaryButton,
                  disabledBackgroundColor: c.primaryButtonDisabled,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, ThemeColors c) => Text(
        text,
        style: TextStyle(
          color: c.text,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ThemeColors c,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: c.text, fontFamily: 'Outfit'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
        prefixIcon: Icon(icon, color: c.textTertiary, size: 20),
        filled: true,
        fillColor: c.surface,
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
    );
  }
}

class _ActiveRoomBanner extends StatelessWidget {
  final Map<String, dynamic> room;
  final ThemeColors c;
  final String groupId;

  const _ActiveRoomBanner({
    required this.room,
    required this.c,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    final title = room['title'] as String? ?? 'Live Adda';
    final participants = room['participant_count'] ??
        room['participants_count'] ??
        0;
    final roomId = room['id']?.toString() ?? '';

    return GestureDetector(
      onTap: roomId.isNotEmpty
          ? () => context.push('/live-audio/$roomId')
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B30).withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            // Live indicator dot
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFFF3B30),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$participants listener${participants == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontFamily: 'Outfit',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final ThemeColors c;
  final VoidCallback onTap;

  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: c.textTertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: c.textTertiary,
                      fontFamily: 'Outfit',
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
