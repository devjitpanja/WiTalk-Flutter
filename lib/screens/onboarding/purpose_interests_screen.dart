import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

// ---- Data ----
const _purposeOptions = [
  {'id': 'learn_language', 'emoji': '🌐', 'label': 'Learn a new language', 'subtitle': 'Practice and improve language skills globally'},
  {'id': 'improve_communication', 'emoji': '🗣️', 'label': 'Improve communication skills', 'subtitle': 'Build confidence and fluency in real conversations'},
  {'id': 'find_startup_teammates', 'emoji': '🚀', 'label': 'Find startup teammates', 'subtitle': 'Connect with builders and future co-founders'},
  {'id': 'find_a_friend', 'emoji': '🤗', 'label': 'Find a friend', 'subtitle': 'Make new meaningful friendships'},
  {'id': 'professional_networking', 'emoji': '💼', 'label': 'Professional networking', 'subtitle': 'Career connections and opportunities'},
  {'id': 'activity_partners', 'emoji': '⚽', 'label': 'Activity/hobby partners', 'subtitle': 'Sports, gym, music, etc.'},
];

const _interestCategories = [
  {'id': 'hobbies_creative', 'title': 'Hobbies & Creative', 'emoji': '🎨', 'interests': [
    {'id': 'video_gaming', 'label': 'Video gaming'}, {'id': 'reading', 'label': 'Reading'}, {'id': 'drawing_art', 'label': 'Drawing/Art'},
    {'id': 'cooking_baking', 'label': 'Cooking/Baking'}, {'id': 'photography', 'label': 'Photography'}, {'id': 'board_games', 'label': 'Board games'},
    {'id': 'crafting', 'label': 'Crafting/DIY'}, {'id': 'gardening', 'label': 'Gardening'}, {'id': 'journaling', 'label': 'Journaling'},
    {'id': 'woodworking', 'label': 'Woodworking'}, {'id': 'sewing', 'label': 'Sewing'}, {'id': 'origami', 'label': 'Origami'},
  ]},
  {'id': 'entertainment_media', 'title': 'Entertainment & Media', 'emoji': '🎬', 'interests': [
    {'id': 'streaming', 'label': 'Netflix/Streaming'}, {'id': 'youtube', 'label': 'YouTube'}, {'id': 'tiktok', 'label': 'TikTok'},
    {'id': 'podcasts', 'label': 'Podcasts'}, {'id': 'anime', 'label': 'Anime'}, {'id': 'manga', 'label': 'Manga/Webtoons'},
    {'id': 'kpop_kdrama', 'label': 'K-pop/K-drama'}, {'id': 'comedy_memes', 'label': 'Comedy/Memes'}, {'id': 'true_crime', 'label': 'True crime'},
    {'id': 'reality_tv', 'label': 'Reality TV'}, {'id': 'documentaries', 'label': 'Documentaries'},
  ]},
  {'id': 'music_genres', 'title': 'Music Genres', 'emoji': '🎵', 'interests': [
    {'id': 'hiphop', 'label': 'Hip-hop'}, {'id': 'rap', 'label': 'Rap'}, {'id': 'pop', 'label': 'Pop'},
    {'id': 'rnb', 'label': 'R&B/Soul'}, {'id': 'rock', 'label': 'Rock'}, {'id': 'indie', 'label': 'Indie'},
    {'id': 'electronic', 'label': 'Electronic/EDM'}, {'id': 'classical', 'label': 'Classical'}, {'id': 'jazz', 'label': 'Jazz'},
    {'id': 'country', 'label': 'Country'}, {'id': 'metal', 'label': 'Metal'},
  ]},
  {'id': 'sports_fitness', 'title': 'Sports & Fitness', 'emoji': '💪', 'interests': [
    {'id': 'gym_fitness', 'label': 'Gym/Fitness'}, {'id': 'running', 'label': 'Running'}, {'id': 'cycling', 'label': 'Cycling'},
    {'id': 'yoga', 'label': 'Yoga'}, {'id': 'swimming', 'label': 'Swimming'}, {'id': 'hiking', 'label': 'Hiking'},
    {'id': 'football', 'label': 'Football/Soccer'}, {'id': 'basketball', 'label': 'Basketball'}, {'id': 'cricket', 'label': 'Cricket'},
    {'id': 'tennis', 'label': 'Tennis'}, {'id': 'martial_arts', 'label': 'Martial arts'},
  ]},
  {'id': 'tech_science', 'title': 'Tech & Science', 'emoji': '💻', 'interests': [
    {'id': 'coding', 'label': 'Coding/Programming'}, {'id': 'ai_ml', 'label': 'AI/Machine learning'}, {'id': 'cybersecurity', 'label': 'Cybersecurity'},
    {'id': 'gaming', 'label': 'PC/Console gaming'}, {'id': 'robotics', 'label': 'Robotics'}, {'id': 'space', 'label': 'Space/Astronomy'},
    {'id': 'gadgets', 'label': 'Gadgets/Tech reviews'}, {'id': 'open_source', 'label': 'Open source'},
  ]},
  {'id': 'lifestyle_wellness', 'title': 'Lifestyle & Wellness', 'emoji': '🌿', 'interests': [
    {'id': 'mental_health', 'label': 'Mental health/Mindfulness'}, {'id': 'nutrition', 'label': 'Nutrition/Healthy eating'},
    {'id': 'skincare', 'label': 'Skincare'}, {'id': 'fashion', 'label': 'Fashion/Style'}, {'id': 'travel', 'label': 'Travel'},
    {'id': 'sustainability', 'label': 'Sustainability/Environment'}, {'id': 'spirituality', 'label': 'Spirituality'},
  ]},
];

class PurposeInterestsScreen extends StatefulWidget {
  const PurposeInterestsScreen({super.key});

  @override
  State<PurposeInterestsScreen> createState() => _PurposeInterestsScreenState();
}

class _PurposeInterestsScreenState extends State<PurposeInterestsScreen> {
  int _step = 1; // 1 = purpose, 2 = interests
  String? _selectedPurpose;
  final Set<String> _selectedInterests = {};
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _saving = false;
  String? _uid;

  static const _totalSteps = 5;
  int get _stepIndex => _step + 3; // steps 4 and 5

  @override
  void initState() {
    super.initState();
    _loadUid();
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUid() async {
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString('uid');
  }

  List<Map<String, dynamic>> get _filteredCategories {
    if (_searchQuery.isEmpty) return List<Map<String, dynamic>>.from(_interestCategories);
    return _interestCategories
        .map((cat) {
          final interests = (cat['interests'] as List).where((i) => (i['label'] as String).toLowerCase().contains(_searchQuery)).toList();
          return {...cat, 'interests': interests};
        })
        .where((cat) => (cat['interests'] as List).isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    if (_saving || _uid == null) return;
    setState(() => _saving = true);
    try {
      await dioClient.post('/v1/user/$_uid/purpose-interests', data: {
        'purpose': _selectedPurpose,
        'interests': _selectedInterests.toList(),
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('onboardingComplete', 'true');
      if (mounted) context.go('/tutorial');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildProgressBar(),
          Expanded(child: _step == 1 ? _buildPurposeStep() : _buildInterestsStep()),
          _buildBottomButton(),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      if (_step == 2)
        GestureDetector(
          onTap: () => setState(() => _step = 1),
          child: Container(width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18)),
        ),
      const Spacer(),
      Text('Step $_stepIndex of $_totalSteps', style: const TextStyle(color: AppColors.textTertiary, fontSize: 13, fontFamily: 'Outfit')),
    ]),
  );

  Widget _buildProgressBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: Row(children: List.generate(_totalSteps, (i) => Expanded(
      child: Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: i < _stepIndex ? AppColors.primaryButton : AppColors.border, borderRadius: BorderRadius.circular(2))),
    ))),
  );

  Widget _buildPurposeStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 4),
      child: Text('Why are you here?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Outfit')),
    ),
    const Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Text('Choose your main goal', style: TextStyle(fontSize: 15, color: AppColors.textTertiary, fontFamily: 'Outfit')),
    ),
    Expanded(child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _purposeOptions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p = _purposeOptions[i];
        final selected = _selectedPurpose == p['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedPurpose = p['id'] as String),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryButton.withOpacity(0.15) : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? AppColors.primaryButton : AppColors.border, width: selected ? 1.5 : 1)),
            child: Row(children: [
              Text(p['emoji'] as String, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['label'] as String, style: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(p['subtitle'] as String, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13, fontFamily: 'Outfit')),
              ])),
              if (selected) const Icon(Icons.check_circle, color: AppColors.primaryButton, size: 22),
            ]),
          ),
        );
      },
    )),
  ]);

  Widget _buildInterestsStep() => Column(children: [
    const Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 4),
      child: Align(alignment: Alignment.centerLeft, child: Text('What are your interests?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Outfit'))),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Align(alignment: Alignment.centerLeft, child: Text('Pick at least 3 · ${_selectedInterests.length} selected', style: const TextStyle(fontSize: 14, color: AppColors.textTertiary, fontFamily: 'Outfit'))),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
        decoration: InputDecoration(
          hintText: 'Search interests...', hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'),
          prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
          filled: true, fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        ),
      ),
    ),
    Expanded(child: ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredCategories.length,
      itemBuilder: (_, catIdx) {
        final cat = _filteredCategories[catIdx];
        final interests = cat['interests'] as List;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('${cat['emoji']}  ${cat['title']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Outfit')),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: interests.map((interest) {
            final id = interest['id'] as String;
            final label = interest['label'] as String;
            final selected = _selectedInterests.contains(id);
            return GestureDetector(
              onTap: () => setState(() { if (selected) _selectedInterests.remove(id); else _selectedInterests.add(id); }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryButton : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? AppColors.primaryButton : AppColors.border)),
                child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 13, fontFamily: 'Outfit', fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
              ),
            );
          }).toList()),
          const SizedBox(height: 8),
        ]);
      },
    )),
  ]);

  Widget _buildBottomButton() {
    final canProceed = _step == 1 ? _selectedPurpose != null : _selectedInterests.length >= 3;
    final isLastStep = _step == 2;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).padding.bottom + 16),
      child: ElevatedButton(
        onPressed: canProceed ? (isLastStep ? _submit : () => setState(() => _step = 2)) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canProceed ? AppColors.primaryButton : AppColors.border,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: _saving
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(isLastStep ? 'Get Started' : 'Next', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
      ),
    );
  }
}
