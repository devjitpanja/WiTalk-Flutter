import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../utils/logger.dart';

class CreateActionFlags {
  final bool createPost;
  final bool createCommunity;
  final bool createChannel;

  const CreateActionFlags({
    this.createPost = true,
    this.createCommunity = false,
    this.createChannel = false,
  });

  factory CreateActionFlags.fromJson(Map<String, dynamic> j) => CreateActionFlags(
        createPost: j['create_post_enabled'] ?? true,
        createCommunity: j['create_community_enabled'] ?? false,
        createChannel: j['create_channel_enabled'] ?? false,
      );
}

class CreateActionNotifier extends StateNotifier<CreateActionFlags> {
  CreateActionNotifier() : super(const CreateActionFlags());

  /// Fetch flags from API. Called at app startup so the sheet never shows a
  /// loader — by the time the user taps the button, flags are already loaded.
  Future<void> load() async {
    try {
      final res = await dioClient.get('/v1/config/create-actions');
      final data = res.data?['data'];
      if (data != null) {
        state = CreateActionFlags.fromJson(data as Map<String, dynamic>);
        AppLogger.log('[CreateActionFlags] loaded: createPost=${state.createPost} createCommunity=${state.createCommunity} createChannel=${state.createChannel}');
      }
    } catch (e) {
      AppLogger.error('[CreateActionFlags] load error — using defaults', e);
    }
  }
}

final createActionProvider =
    StateNotifierProvider<CreateActionNotifier, CreateActionFlags>(
        (ref) => CreateActionNotifier());
