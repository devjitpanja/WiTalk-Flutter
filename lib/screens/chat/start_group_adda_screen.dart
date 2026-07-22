import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme_colors.dart';

class StartGroupAddaScreen extends StatefulWidget {
  final String? groupId;
  final String? groupName;
  final String? userRole;

  const StartGroupAddaScreen({
    super.key,
    this.groupId,
    this.groupName,
    this.userRole,
  });

  @override
  State<StartGroupAddaScreen> createState() => _StartGroupAddaScreenState();
}

class _StartGroupAddaScreenState extends State<StartGroupAddaScreen> {
  final List<String> _topics = [
    'New to the City', 'Make True Friends', 'English Speaking',
    'Late Night', 'Startup / Career', 'Stranger Stories',
  ];

  String _roomName = '';
  String? _topic;
  bool _isScheduled = false;
  DateTime? _scheduledDate;
  bool _creating = false;

  bool get _canSchedule => widget.userRole == 'admin' || widget.userRole == 'super_admin';

  Future<void> _handleGoLive() async {
    if (_topic == null) {
      _showError('Please select a category');
      return;
    }
    if (_roomName.trim().length < 5) {
      _showError('Adda topic must be at least 5 characters');
      return;
    }

    setState(() => _creating = true);
    
    try {
      await Future.delayed(const Duration(seconds: 1)); // Mock API
      final roomId = 'group_${widget.groupId ?? 'adda'}_${DateTime.now().millisecondsSinceEpoch}';
      if (mounted) context.pushReplacement('/live-audio/$roomId');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _handleSchedule() async {
    if (!_canSchedule) {
      _showError('Only group admins and owners can schedule a community adda.');
      return;
    }
    if (_topic == null) {
      _showError('Please select a category');
      return;
    }
    if (_roomName.trim().length < 5) {
      _showError('Adda topic must be at least 5 characters');
      return;
    }
    if (_scheduledDate == null) {
      _showError('Please select a date and time');
      return;
    }
    
    setState(() => _creating = true);
    
    try {
      await Future.delayed(const Duration(seconds: 1)); // Mock API
      if (mounted) {
        _showSuccess('Adda Scheduled!');
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now),
      );
      if (time != null) {
        setState(() {
          _scheduledDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0B18) : const Color(0xFFF8FAFC);
    final surface = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03);
    const accent = Color(0xFF7C3AED);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        title: Text('Community Adda', style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 17)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: c.border, height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.graphic_eq, size: 48, color: accent),
          ),
          const SizedBox(height: 20),
          Text(widget.groupName ?? 'Group', style: TextStyle(color: c.text, fontSize: 22, fontFamily: 'Outfit', fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Start a live adda or schedule one for later', style: TextStyle(color: c.textSecondary, fontSize: 14, fontFamily: 'Outfit'), textAlign: TextAlign.center),
          const SizedBox(height: 24),

          // Mode Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _creating ? null : () => setState(() => _isScheduled = false),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: !_isScheduled ? accent : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, size: 16, color: !_isScheduled ? Colors.white : c.textSecondary),
                          const SizedBox(width: 6),
                          Text('Go Live Now', style: TextStyle(color: !_isScheduled ? Colors.white : c.textSecondary, fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _creating ? null : () {
                      if (!_canSchedule) {
                        _showError('Only group admins and owners can schedule a community adda.');
                        return;
                      }
                      setState(() => _isScheduled = true);
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: _isScheduled ? accent : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event, size: 16, color: _isScheduled ? Colors.white : c.textSecondary),
                          const SizedBox(width: 6),
                          Text('Schedule', style: TextStyle(color: _isScheduled ? Colors.white : c.textSecondary, fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Category
          Text('Category', style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _topic,
            items: _topics.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(color: c.text, fontFamily: 'Outfit')))).toList(),
            onChanged: _creating ? null : (v) => setState(() => _topic = v),
            decoration: InputDecoration(
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
              hintText: 'Select a Category',
              hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
            ),
            dropdownColor: c.surface,
            icon: Icon(Icons.keyboard_arrow_down, color: c.textSecondary),
          ),
          const SizedBox(height: 20),

          // Adda Topic
          Text('Adda Topic', style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => _roomName = v),
            enabled: !_creating,
            maxLength: 80,
            style: TextStyle(color: c.text, fontFamily: 'Outfit'),
            decoration: InputDecoration(
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
              hintText: 'What\'s your adda about?',
              hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
            ),
          ),
          const SizedBox(height: 20),

          // Schedule Date/Time
          if (_isScheduled) ...[
            Text('Scheduled Time', style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _creating ? null : _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 20, color: accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_scheduledDate != null ? '${_scheduledDate!.toLocal()}'.split('.')[0] : 'Tap to select date & time', style: TextStyle(color: _scheduledDate != null ? c.text : c.placeholder, fontFamily: 'Outfit'))),
                    Icon(Icons.chevron_right, size: 20, color: c.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Minimum 15 minutes from now', style: TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'Outfit')),
            const SizedBox(height: 20),
          ],

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _creating ? null : (_isScheduled ? _handleSchedule : _handleGoLive),
              icon: _creating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(_isScheduled ? Icons.event : Icons.graphic_eq, size: 22),
              label: Text(_creating ? (_isScheduled ? 'Scheduling...' : 'Starting...') : (_isScheduled ? 'Schedule Adda' : 'Go Live'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: accent.withOpacity(0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
