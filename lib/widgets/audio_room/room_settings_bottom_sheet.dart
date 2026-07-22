import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;

class RoomSettingsBottomSheet extends StatefulWidget {
  final String roomName;
  final String channelName;
  final String roomId;
  final bool stageRequestEnabled;
  final ValueChanged<bool> onToggleStageRequest;
  final Function(String) onSaveRoomName;
  final bool saving;
  final bool isCommunityAdda;
  final bool coolDownMode;
  final ValueChanged<bool>? onToggleCoolDownMode;
  
  // Host/Admin management
  final bool isHost;
  final bool isAdmin;
  final List<Map<String, dynamic>> admins;
  final List<Map<String, dynamic>> bannedUsers;
  final bool bannedLoading;
  final Function(String)? onRemoveAdmin;
  final Function(String)? onUnbanUser;
  final VoidCallback? onLoadBannedUsers;
  
  // Dynamic seat count
  final int maxSeats;
  final VoidCallback? onExpandSeats;
  final VoidCallback? onCollapseSeats;

  const RoomSettingsBottomSheet({
    super.key,
    required this.roomName,
    required this.channelName,
    required this.roomId,
    required this.stageRequestEnabled,
    required this.onToggleStageRequest,
    required this.onSaveRoomName,
    this.saving = false,
    this.isCommunityAdda = false,
    this.coolDownMode = false,
    this.onToggleCoolDownMode,
    this.isHost = false,
    this.isAdmin = false,
    this.admins = const [],
    this.bannedUsers = const [],
    this.bannedLoading = false,
    this.onRemoveAdmin,
    this.onUnbanUser,
    this.onLoadBannedUsers,
    this.maxSeats = 4,
    this.onExpandSeats,
    this.onCollapseSeats,
  });

  @override
  State<RoomSettingsBottomSheet> createState() => _RoomSettingsBottomSheetState();
}

class _RoomSettingsBottomSheetState extends State<RoomSettingsBottomSheet> {
  String _activeTab = 'settings';
  bool _isEditingName = false;
  late TextEditingController _nameController;
  bool _linkCopied = false;

  // Reviews (Mock for now, normally fetched)
  final List<Map<String, dynamic>> _reviews = [];
  final bool _reviewsLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.roomName);
  }

  @override
  void didUpdateWidget(RoomSettingsBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomName != widget.roomName && !_isEditingName) {
      _nameController.text = widget.roomName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleTabChange(String tab) {
    setState(() => _activeTab = tab);
    if (tab == 'banned') widget.onLoadBannedUsers?.call();
    // if (tab == 'reviews') fetchReviews();
  }

  void _handleSaveName() {
    final trimmed = _nameController.text.trim();
    if (trimmed.isNotEmpty && trimmed != widget.roomName) {
      widget.onSaveRoomName(trimmed);
    }
    setState(() => _isEditingName = false);
  }

  void _handleCancelEdit() {
    setState(() {
      _nameController.text = widget.roomName;
      _isEditingName = false;
    });
  }

  void _handleCopyLink() {
    Clipboard.setData(ClipboardData(text: 'https://witalk.in/adda/${widget.roomId}'));
    setState(() => _linkCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _linkCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2A3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Text(
                  'Room Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage your room preferences',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 10),
                Divider(color: Colors.white.withOpacity(0.1), height: 1),
              ],
            ),
          ),

          // Tabs (Host only)
          if (widget.isHost)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
              ),
              child: Row(
                children: [
                  _buildTab('settings', 'Settings'),
                  _buildTab('admins', 'Admins', count: widget.admins.length),
                  _buildTab('banned', 'Banned', count: widget.bannedUsers.length, isDanger: true),
                  _buildTab('reviews', 'Reviews', count: _reviews.length),
                ],
              ),
            ),

          // Content
          Expanded(
            child: widget.isHost && _activeTab == 'reviews'
                ? _buildReviewsTab()
                : SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 10,
                      bottom: MediaQuery.of(context).padding.bottom + 20,
                    ),
                    child: _buildCurrentTabContent(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String id, String title, {int? count, bool isDanger = false}) {
    final isActive = _activeTab == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => _handleTabChange(id),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFF4A90E2) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? const Color(0xFF4A90E2) : Colors.white.withOpacity(0.5),
                ),
              ),
              if (count != null && count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isDanger ? const Color(0xFFEF4444) : const Color(0xFF4A90E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_activeTab) {
      case 'settings':
        return _buildSettingsTab();
      case 'admins':
        return _buildAdminsTab();
      case 'banned':
        return _buildBannedTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSettingsTab() {
    final maxAllowed = 12;
    final expandDisabled = widget.maxSeats >= maxAllowed;

    return Column(
      children: [
        // Username / Share
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ROOM USERNAME',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.5,
                        color: Colors.white.withOpacity(0.45),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${widget.channelName}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'witalk.in/adda/${widget.roomId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.45),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleCopyLink,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _linkCopied ? Icons.check : Icons.content_copy,
                          size: 18,
                          color: _linkCopied ? const Color(0xFF4CAF50) : Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _linkCopied ? 'Copied' : 'Copy',
                          style: TextStyle(
                            fontSize: 11,
                            color: _linkCopied ? const Color(0xFF4CAF50) : Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(color: Colors.white.withOpacity(0.08), height: 1),
        const SizedBox(height: 12),

        // Stage Request
        _buildSettingOption(
          icon: Icons.front_hand,
          iconColor: const Color(0xFFFFA500),
          title: 'Require Stage Request',
          description: 'Users must request to come on stage',
          trailing: Switch(
            value: widget.stageRequestEnabled,
            onChanged: widget.onToggleStageRequest,
            activeColor: const Color(0xFF4CAF50),
            activeTrackColor: const Color(0xFF4CAF50).withOpacity(0.5),
            inactiveTrackColor: Colors.white.withOpacity(0.2),
          ),
        ),

        // Stage Seats
        if (widget.isHost || widget.isAdmin)
          _buildSettingOption(
            icon: Icons.event_seat,
            iconColor: const Color(0xFFA855F7),
            title: 'Stage Seats',
            description: widget.maxSeats >= maxAllowed 
              ? 'Tap − to reduce seats' 
              : widget.maxSeats == 4 ? 'Tap + to add more seats' : 'Tap − to reduce or + to add 4 seats',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStepperButton(
                  icon: Icons.remove,
                  onTap: widget.maxSeats <= 4 ? null : widget.onCollapseSeats,
                  disabled: widget.maxSeats <= 4,
                ),
                Container(
                  width: 30,
                  alignment: Alignment.center,
                  child: Text(
                    widget.maxSeats.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                _buildStepperButton(
                  icon: Icons.add,
                  onTap: expandDisabled ? null : widget.onExpandSeats,
                  disabled: expandDisabled,
                ),
              ],
            ),
          ),

        // Edit Room Name
        if (widget.isHost)
          if (_isEditingName)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90E2).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, color: Color(0xFF4A90E2)),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Edit Room Name',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    maxLength: 100,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      hintText: 'Enter room name',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: const Color(0xFF4A90E2).withOpacity(0.4), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 1),
                      ),
                      counterStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                    ),
                    onSubmitted: (_) => _handleSaveName(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _handleCancelEdit,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: _nameController.text.trim().isEmpty || _nameController.text.trim() == widget.roomName || widget.saving ? null : _handleSaveName,
                        style: TextButton.styleFrom(
                          backgroundColor: _nameController.text.trim().isEmpty || _nameController.text.trim() == widget.roomName || widget.saving 
                            ? Colors.white.withOpacity(0.14) 
                            : const Color(0xFF4A90E2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: _nameController.text.trim().isEmpty || _nameController.text.trim() == widget.roomName || widget.saving
                                ? Colors.white.withOpacity(0.28)
                                : Colors.transparent,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          widget.saving ? 'Saving...' : 'Save',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            _buildSettingOption(
              icon: Icons.edit,
              iconColor: const Color(0xFF4A90E2),
              title: 'Edit Room Name',
              description: widget.roomName,
              onTap: () => setState(() => _isEditingName = true),
              trailing: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.4)),
            ),
      ],
    );
  }

  Widget _buildSettingOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final content = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: content,
        ),
      );
    }
    return content;
  }

  Widget _buildStepperButton({required IconData icon, required VoidCallback? onTap, bool disabled = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: disabled ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: disabled ? Colors.white.withOpacity(0.2) : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAdminsTab() {
    if (widget.admins.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No Admins Yet',
        subtitle: 'Promote participants to admin from their profile',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Manage who can moderate this adda',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ),
        ...widget.admins.map((admin) => _buildMemberCard(
              member: admin,
              actionIcon: Icons.close,
              actionColor: const Color(0xFFEF4444),
              onAction: () => widget.onRemoveAdmin?.call(admin['uid'] ?? ''),
              avatarBg: const Color(0xFF4A90E2).withOpacity(0.3),
            )),
      ],
    );
  }

  Widget _buildBannedTab() {
    if (widget.bannedLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
        ),
      );
    }

    if (widget.bannedUsers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.block,
        title: 'No Banned Users',
        subtitle: 'Users you ban will appear here',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Users banned from this adda',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ),
        ...widget.bannedUsers.map((ban) => _buildMemberCard(
              member: ban,
              actionIcon: Icons.lock_open,
              actionColor: const Color(0xFF4CAF50),
              onAction: () => widget.onUnbanUser?.call(ban['banned_uid'] ?? ''),
              avatarBg: const Color(0xFFEF4444).withOpacity(0.2),
            )),
      ],
    );
  }

  Widget _buildMemberCard({
    required Map<String, dynamic> member,
    required IconData actionIcon,
    required Color actionColor,
    required VoidCallback onAction,
    required Color avatarBg,
  }) {
    final name = member['name'] ?? 'User';
    final username = member['username'] ?? 'unknown';
    final profilePic = member['profile_pic'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: avatarBg,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.center,
            child: profilePic != null
                ? CachedNetworkImage(
                    imageUrl: profilePic,
                    fit: BoxFit.cover,
                    width: 40,
                    height: 40,
                  )
                : Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@$username',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.isHost)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    actionIcon,
                    color: actionColor,
                    size: 18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 52, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.35),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_reviewsLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)));
    }

    if (_reviews.isEmpty) {
      return _buildEmptyState(
        icon: Icons.stars,
        title: 'No Reviews Yet',
        subtitle: 'Reviews will appear here once people rate your Adda',
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: MediaQuery.of(context).padding.bottom + 20),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        // Implement review card here if needed
        return const SizedBox.shrink();
      },
    );
  }
}

Future<void> showRoomSettingsBottomSheet({
  required BuildContext context,
  required String roomName,
  required String channelName,
  required String roomId,
  required bool stageRequestEnabled,
  required ValueChanged<bool> onToggleStageRequest,
  required Function(String) onSaveRoomName,
  bool saving = false,
  bool isCommunityAdda = false,
  bool coolDownMode = false,
  ValueChanged<bool>? onToggleCoolDownMode,
  bool isHost = false,
  bool isAdmin = false,
  List<Map<String, dynamic>> admins = const [],
  List<Map<String, dynamic>> bannedUsers = const [],
  bool bannedLoading = false,
  Function(String)? onRemoveAdmin,
  Function(String)? onUnbanUser,
  VoidCallback? onLoadBannedUsers,
  int maxSeats = 4,
  VoidCallback? onExpandSeats,
  VoidCallback? onCollapseSeats,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => RoomSettingsBottomSheet(
      roomName: roomName,
      channelName: channelName,
      roomId: roomId,
      stageRequestEnabled: stageRequestEnabled,
      onToggleStageRequest: onToggleStageRequest,
      onSaveRoomName: onSaveRoomName,
      saving: saving,
      isCommunityAdda: isCommunityAdda,
      coolDownMode: coolDownMode,
      onToggleCoolDownMode: onToggleCoolDownMode,
      isHost: isHost,
      isAdmin: isAdmin,
      admins: admins,
      bannedUsers: bannedUsers,
      bannedLoading: bannedLoading,
      onRemoveAdmin: onRemoveAdmin,
      onUnbanUser: onUnbanUser,
      onLoadBannedUsers: onLoadBannedUsers,
      maxSeats: maxSeats,
      onExpandSeats: onExpandSeats,
      onCollapseSeats: onCollapseSeats,
    ),
  );
}
