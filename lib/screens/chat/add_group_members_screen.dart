import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/chat_api_service.dart';

class AddGroupMembersScreen extends ConsumerStatefulWidget {
  final String groupId;
  final List<String> existingMemberIds;

  const AddGroupMembersScreen({
    super.key,
    required this.groupId,
    required this.existingMemberIds,
  });

  @override
  ConsumerState<AddGroupMembersScreen> createState() =>
      _AddGroupMembersScreenState();
}

class _AddGroupMembersScreenState
    extends ConsumerState<AddGroupMembersScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _allContacts = [];
  List<Map<String, dynamic>> _filtered = [];
  final Set<String> _selectedIds = {};
  bool _loading = true;
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _loadContacts();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilter);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final contacts = await chatApiService.getContacts();
      setState(() {
        _allContacts = contacts;
        _filtered = contacts;
      });
    } catch (_) {
      setState(() => _error = 'Failed to load contacts.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = _allContacts;
      } else {
        _filtered = _allContacts.where((c) {
          final name = (c['name'] as String? ?? '').toLowerCase();
          final username = (c['username'] as String? ?? '').toLowerCase();
          return name.contains(query) || username.contains(query);
        }).toList();
      }
    });
  }

  bool _isExisting(String id) => widget.existingMemberIds.contains(id);

  Future<void> _addMembers() async {
    if (_selectedIds.isEmpty || _adding) return;
    setState(() => _adding = true);
    final errors = <String>[];
    for (final userId in _selectedIds) {
      try {
        await chatApiService.addGroupMember(widget.groupId, userId);
      } catch (_) {
        errors.add(userId);
      }
    }
    if (!mounted) return;
    setState(() => _adding = false);
    if (errors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedIds.length} member${_selectedIds.length == 1 ? '' : 's'} added!',
            style: const TextStyle(fontFamily: 'Outfit'),
          ),
          backgroundColor: context.colors.success,
        ),
      );
      context.pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${errors.length} member${errors.length == 1 ? '' : 's'} could not be added.',
            style: const TextStyle(fontFamily: 'Outfit'),
          ),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selectedCount = _selectedIds.length;

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
          'Add Members',
          style: TextStyle(
            color: c.text,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          if (selectedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _adding ? null : _addMembers,
                child: _adding
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.primaryButton,
                        ),
                      )
                    : Text(
                        'Add $selectedCount',
                        style: TextStyle(
                          color: c.primaryButton,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: c.text, fontFamily: 'Outfit'),
              decoration: InputDecoration(
                hintText: 'Search contacts…',
                hintStyle: TextStyle(
                  color: c.placeholder,
                  fontFamily: 'Outfit',
                ),
                prefixIcon: Icon(Icons.search, color: c.textTertiary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: c.textTertiary),
                        onPressed: () {
                          _searchCtrl.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: c.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.primaryButton, width: 1.5),
                ),
              ),
            ),
          ),

          // Selected chips bar
          if (_selectedIds.isNotEmpty) ...[
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _selectedIds.map((id) {
                  final contact = _allContacts.firstWhere(
                    (c) =>
                        c['id']?.toString() == id ||
                        c['user_id']?.toString() == id,
                    orElse: () => {'name': id},
                  );
                  final name = contact['name'] as String? ?? id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8, top: 8),
                    child: Chip(
                      label: Text(
                        name,
                        style: TextStyle(
                          color: c.text,
                          fontFamily: 'Outfit',
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: c.primaryButton.withOpacity(0.15),
                      side: BorderSide(
                          color: c.primaryButton.withOpacity(0.4)),
                      deleteIcon:
                          Icon(Icons.close, size: 14, color: c.textTertiary),
                      onDeleted: () =>
                          setState(() => _selectedIds.remove(id)),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Divider
          Divider(color: c.border, height: 1),

          // Contact list
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: c.primaryButton))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 40, color: c.error),
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: TextStyle(
                                  color: c.textSecondary,
                                  fontFamily: 'Outfit'),
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: _loadContacts,
                              child: Text(
                                'Retry',
                                style: TextStyle(
                                    color: c.primaryButton,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Text(
                              _searchCtrl.text.isNotEmpty
                                  ? 'No results for "${_searchCtrl.text}"'
                                  : 'No contacts found.',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontFamily: 'Outfit',
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final contact = _filtered[i];
                              final id = contact['id']?.toString() ??
                                  contact['user_id']?.toString() ??
                                  '';
                              final name = contact['name'] as String? ??
                                  contact['username'] as String? ??
                                  'Unknown';
                              final username =
                                  contact['username'] as String?;
                              final pic = contact['profile_pic'] as String? ??
                                  contact['avatar'] as String?;
                              final existing = _isExisting(id);
                              final selected = _selectedIds.contains(id);

                              return _ContactTile(
                                id: id,
                                name: name,
                                username: username,
                                pic: pic,
                                selected: selected,
                                existing: existing,
                                c: c,
                                onToggle: existing
                                    ? null
                                    : () {
                                        setState(() {
                                          if (selected) {
                                            _selectedIds.remove(id);
                                          } else {
                                            _selectedIds.add(id);
                                          }
                                        });
                                      },
                              );
                            },
                          ),
          ),

          // Bottom Add button
          if (selectedCount > 0)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _adding ? null : _addMembers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primaryButton,
                      disabledBackgroundColor: c.primaryButtonDisabled,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _adding
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Add $selectedCount Member${selectedCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final String id;
  final String name;
  final String? username;
  final String? pic;
  final bool selected;
  final bool existing;
  final ThemeColors c;
  final VoidCallback? onToggle;

  const _ContactTile({
    required this.id,
    required this.name,
    required this.username,
    required this.pic,
    required this.selected,
    required this.existing,
    required this.c,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = existing ? c.textTertiary : c.text;

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: c.surface,
              backgroundImage:
                  pic != null ? CachedNetworkImageProvider(pic!) : null,
              child: pic == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: textColor,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
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
                      color: textColor,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (username != null)
                    Text(
                      '@$username',
                      style: TextStyle(
                        color: c.textTertiary,
                        fontFamily: 'Outfit',
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (existing)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Member',
                  style: TextStyle(
                    color: c.textTertiary,
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? c.primaryButton : Colors.transparent,
                  border: Border.all(
                    color: selected ? c.primaryButton : c.border,
                    width: 1.5,
                  ),
                  shape: BoxShape.circle,
                ),
                child: selected
                    ? const Icon(Icons.check,
                        size: 14, color: Colors.white)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
