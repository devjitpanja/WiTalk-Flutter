import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  List<dynamic> _categories = [];
  bool _loading = true;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString('uid');
    try {
      final res = await dioClient.get('/v1/tutorial/categories');
      if (res.data['success'] == true) {
        setState(() => _categories = res.data['data'] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markComplete() async {
    try {
      await dioClient.post('/v1/user/$_uid/tutorial-complete');
    } catch (_) {}
    if (mounted) context.go('/home');
  }

  String _thumbUrl(String youtubeId) => 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';

  Future<void> _openVideo(String youtubeId) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=$youtubeId');
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Get started', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Outfit')),
                SizedBox(height: 4),
                Text('Watch these to make the most of WiTalk', style: TextStyle(fontSize: 14, color: AppColors.textTertiary, fontFamily: 'Outfit')),
              ])),
              TextButton(
                onPressed: _markComplete,
                child: const Text('Skip', style: TextStyle(color: AppColors.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              ),
            ]),
          ),

          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryButton))
            : _categories.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) => _buildCategory(_categories[i]),
                ),
          ),

          // Bottom CTA
          Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).padding.bottom + 16),
            child: ElevatedButton(
              onPressed: _markComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('Start Exploring WiTalk', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCategory(Map<String, dynamic> cat) {
    final videos = (cat['videos'] as List?) ?? [];
    final color = Color(int.tryParse((cat['color'] as String? ?? '#007AFF').replaceFirst('#', '0xFF')) ?? 0xFF007AFF);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text(cat['title'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Outfit')),
        ]),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
        itemCount: videos.length,
        itemBuilder: (_, i) => _buildVideoCard(videos[i], color),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildVideoCard(Map<String, dynamic> video, Color catColor) {
    final youtubeId = video['youtube_id'] as String? ?? '';
    return GestureDetector(
      onTap: () => _openVideo(youtubeId),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Stack(children: [
              CachedNetworkImage(imageUrl: _thumbUrl(youtubeId), width: double.infinity, height: 95, fit: BoxFit.cover,
                placeholder: (_, __) => Container(height: 95, color: AppColors.border),
                errorWidget: (_, __, ___) => Container(height: 95, color: AppColors.border, child: const Icon(Icons.play_circle_outline, color: Colors.white54, size: 32))),
              Positioned.fill(child: Center(child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 22),
              ))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(video['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: catColor, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(video['play_count'] != null && (video['play_count'] as int) > 0 ? '${video['play_count']} plays' : 'New',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontFamily: 'Outfit')),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('🎓', style: TextStyle(fontSize: 56)),
    const SizedBox(height: 16),
    const Text('Tutorials coming soon', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    const Text('Check back later for guides', style: TextStyle(color: AppColors.textTertiary, fontSize: 14, fontFamily: 'Outfit')),
  ]));
}
