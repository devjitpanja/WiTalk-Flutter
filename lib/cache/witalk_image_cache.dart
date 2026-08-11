import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom image cache manager used by every CachedNetworkImage in the app.
///
/// Centralises config: max-age 30 days, max 4 000 objects, named key so the
/// cache directory is predictable for storage accounting.
class WiTalkImageCache extends CacheManager with ImageCacheManager {
  static const key = 'witalkImageCache';

  static final WiTalkImageCache _instance = WiTalkImageCache._();
  factory WiTalkImageCache() => _instance;

  WiTalkImageCache._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 4000,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ));
}
