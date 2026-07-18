import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class CreateAudioRoomScreen extends StatefulWidget {
  const CreateAudioRoomScreen({super.key});
  @override
  State<CreateAudioRoomScreen> createState() => _CreateAudioRoomScreenState();
}

class _CreateAudioRoomScreenState extends State<CreateAudioRoomScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  bool _isPublic = true;
  bool _creating = false;

  @override
  void dispose() { _titleCtrl.dispose(); _descCtrl.dispose(); _tagsCtrl.dispose(); super.dispose(); }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final tags = _tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      final res = await dioClient.post('/v1/audio-rooms/create', data: {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'tags': tags,
        'is_public': _isPublic,
      });
      final id = res.data['data']?['id'] as String?;
      if (id != null && mounted) context.pushReplacement('/live-audio/$id');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red.shade700));
    } finally { if (mounted) setState(() => _creating = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: const Text('Start a Room', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => context.pop()),
    ),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _field(_titleCtrl, 'Room Title *', Icons.mic_none_outlined),
      const SizedBox(height: 16),
      _field(_descCtrl, 'Description (optional)', Icons.info_outline, maxLines: 3),
      const SizedBox(height: 16),
      _field(_tagsCtrl, 'Tags (comma separated)', Icons.tag),
      const SizedBox(height: 20),
      SwitchListTile(
        value: _isPublic,
        onChanged: (v) => setState(() => _isPublic = v),
        title: const Text('Public Room', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        subtitle: const Text('Anyone can join', style: TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 12)),
        activeColor: AppColors.primaryButton,
        contentPadding: EdgeInsets.zero,
      ),
      const SizedBox(height: 32),
      ElevatedButton.icon(
        onPressed: _titleCtrl.text.isNotEmpty ? _create : null,
        icon: _creating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.mic, size: 20),
        label: const Text('Start Room', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16)),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryButton, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    ])),
  );

  Widget _field(TextEditingController c, String hint, IconData icon, {int maxLines = 1}) => TextField(
    controller: c,
    maxLines: maxLines,
    style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 20), filled: true, fillColor: AppColors.surface, hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryButton))),
  );
}
