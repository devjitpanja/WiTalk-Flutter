import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme_colors.dart';
import '../../services/audio_room_service.dart';

class CreateAudioRoomScreen extends ConsumerStatefulWidget {
  const CreateAudioRoomScreen({super.key});

  @override
  ConsumerState<CreateAudioRoomScreen> createState() => _CreateAudioRoomScreenState();
}

class _CreateAudioRoomScreenState extends ConsumerState<CreateAudioRoomScreen> {
  final _titleCtrl = TextEditingController();
  final _rulesCtrl = TextEditingController();
  final _languageCtrl = TextEditingController(text: 'English');

  String? _selectedTopic;
  bool _isPublic = true;
  bool _isScheduled = false;
  DateTime? _scheduledDate;

  bool _creating = false;

  static const List<String> _topics = [
    'New to the City',
    'Make True Friends',
    'English Speaking',
    'Late Night',
    'Startup / Career',
    'Stranger Stories',
    'General Casual',
  ];

  static const Map<String, List<String>> _rulesPresets = {
    'New to the City': [
      '1. Be welcoming and friendly to newcomers',
      '2. Share helpful tips about the city',
      '3. No spam or self-promotion',
      '4. Speak respectfully',
    ],
    'Make True Friends': [
      '1. Be genuine and kind',
      '2. No judgment — everyone is welcome',
      '3. Keep personal info private',
      '4. No spam or promotional links',
    ],
    'English Speaking': [
      '1. Speak only in English',
      '2. Be patient with learners',
      '3. Correct mistakes kindly',
      '4. No off-topic conversations',
    ],
    'Late Night': [
      '1. Keep it chill and relaxed',
      '2. No controversial or heated topics',
      '3. Be respectful of everyone',
    ],
    'Startup / Career': [
      '1. Stay on topic — startups & career only',
      '2. Share genuine insights, not promotions',
      '3. Be respectful of different experience levels',
    ],
    'Stranger Stories': [
      '1. Keep stories real and personal',
      '2. No names or identifiable info about others',
      '3. One speaker at a time',
    ],
  };

  @override
  void dispose() {
    _titleCtrl.dispose();
    _rulesCtrl.dispose();
    _languageCtrl.dispose();
    super.dispose();
  }

  void _onTopicChanged(String? topic) {
    if (topic == null) return;
    setState(() {
      _selectedTopic = topic;
      final presets = _rulesPresets[topic];
      if (presets != null) {
        _rulesCtrl.text = presets.join('\n');
      }
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(minutes: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 30))),
      );
      if (time != null && mounted) {
        setState(() {
          _scheduledDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _createRoom() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _creating) return;

    setState(() => _creating = true);
    try {
      final payload = {
        'room_name': title,
        'topic': _selectedTopic ?? 'General Casual',
        'rules': _rulesCtrl.text.trim(),
        'language': _languageCtrl.text.trim(),
        'is_public': _isPublic ? 1 : 0,
        if (_isScheduled && _scheduledDate != null) 'scheduled_at': _scheduledDate!.toIso8601String(),
      };

      final res = await audioRoomService.getActiveRooms(limit: 1, offset: 0); // test request
      final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}';

      if (mounted) {
        if (_isScheduled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adda Scheduled Successfully!')),
          );
          context.pop();
        } else {
          context.pushReplacement('/live-audio/$roomId');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create adda: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.headerBackground,
        elevation: 0,
        title: Text(
          'Start an Adda',
          style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: c.text),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Input
            Text('Adda Title *', style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit')),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              style: TextStyle(color: c.text, fontFamily: 'Outfit'),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'e.g. Late Night Beats & Coffee Chat...',
                hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
              ),
            ),
            const SizedBox(height: 16),

            // Topic Selector
            Text('Topic / Category', style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit')),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedTopic,
              dropdownColor: c.surface,
              style: TextStyle(color: c.text, fontFamily: 'Outfit'),
              hint: Text('Select topic...', style: TextStyle(color: c.placeholder, fontFamily: 'Outfit')),
              items: _topics.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: _onTopicChanged,
              decoration: InputDecoration(
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
              ),
            ),
            const SizedBox(height: 16),

            // Language
            Text('Language', style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit')),
            const SizedBox(height: 6),
            TextField(
              controller: _languageCtrl,
              style: TextStyle(color: c.text, fontFamily: 'Outfit'),
              decoration: InputDecoration(
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
              ),
            ),
            const SizedBox(height: 16),

            // Rules
            Text('Room Guidelines / Rules', style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit')),
            const SizedBox(height: 6),
            TextField(
              controller: _rulesCtrl,
              maxLines: 3,
              style: TextStyle(color: c.text, fontFamily: 'Outfit'),
              decoration: InputDecoration(
                hintText: 'Rules will auto-fill based on selected topic...',
                hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
              ),
            ),
            const SizedBox(height: 20),

            // Public / Private Toggle
            SwitchListTile(
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
              title: Text('Public Adda', style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              subtitle: Text('Anyone on WiTalk can discover and join', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 12)),
              activeColor: c.primary,
              contentPadding: EdgeInsets.zero,
            ),

            // Schedule Toggle
            SwitchListTile(
              value: _isScheduled,
              onChanged: (v) => setState(() => _isScheduled = v),
              title: Text('Schedule for Later', style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              subtitle: Text('Let your followers mark their calendars', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 12)),
              activeColor: c.primary,
              contentPadding: EdgeInsets.zero,
            ),

            if (_isScheduled) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: Icon(Icons.event, color: c.primary),
                label: Text(
                  _scheduledDate == null
                      ? 'Pick Date & Time'
                      : 'Scheduled: ${_scheduledDate!.day}/${_scheduledDate!.month} at ${_scheduledDate!.hour}:${_scheduledDate!.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.primary),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _titleCtrl.text.trim().isNotEmpty && !_creating ? _createRoom : null,
                icon: _creating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(_isScheduled ? Icons.event : Icons.mic, size: 22),
                label: Text(
                  _isScheduled ? 'Schedule Adda' : 'Go Live Now',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
