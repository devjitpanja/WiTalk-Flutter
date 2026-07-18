import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;
  List<dynamic> _results = [];
  bool _searching = false;

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _searchCtrl.dispose(); _tabCtrl.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() => _results = []); return; }
    setState(() => _searching = true);
    try {
      final tab = ['people', 'posts', 'communities', 'channels'][_tabCtrl.index];
      final res = await dioClient.get('/v1/search?q=${Uri.encodeComponent(q)}&type=$tab');
      setState(() => _results = res.data['data'] ?? []);
    } catch (_) {} finally { if (mounted) setState(() => _searching = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
          Expanded(child: TextField(controller: _searchCtrl, autofocus: true, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
            onChanged: _search,
            decoration: InputDecoration(hintText: 'Search WiTalk...', hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'),
              filled: true, fillColor: AppColors.surface, prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: AppColors.textTertiary), onPressed: () { _searchCtrl.clear(); setState(() => _results = []); }) : null))),
        ])),
        TabBar(controller: _tabCtrl, labelColor: Colors.white, unselectedLabelColor: AppColors.textTertiary, indicatorColor: AppColors.primaryButton,
          labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [Tab(text: 'People'), Tab(text: 'Posts'), Tab(text: 'Groups'), Tab(text: 'Channels')],
          onTap: (_) => _search(_searchCtrl.text)),
        Expanded(child: _searching
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryButton))
            : _results.isEmpty
              ? Center(child: Text(_searchCtrl.text.isEmpty ? 'Search for people, posts, communities...' : 'No results found', style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit'), textAlign: TextAlign.center))
              : ListView.builder(itemCount: _results.length, itemBuilder: (_, i) => _SearchResultTile(item: _results[i], type: ['people', 'posts', 'communities', 'channels'][_tabCtrl.index]))),
      ])),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String type;
  const _SearchResultTile({required this.item, required this.type});
  @override
  Widget build(BuildContext context) {
    final name = item['name'] ?? item['title'] ?? '';
    final pic = item['profile_pic'] ?? item['image'];
    final id = item['id'] ?? '';
    return ListTile(
      leading: CircleAvatar(radius: 20, backgroundColor: AppColors.border, backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null, child: pic == null ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Colors.white)) : null),
      title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      subtitle: item['username'] != null ? Text('@${item['username']}', style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 12)) : null,
      onTap: () {
        switch (type) {
          case 'people': context.push('/user/$id'); break;
          case 'posts': context.push('/post/$id'); break;
          case 'communities': context.push('/community-info/$id'); break;
          case 'channels': context.push('/channel/$id'); break;
        }
      },
    );
  }
}
