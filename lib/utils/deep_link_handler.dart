import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'mic_permission_utils.dart';

class DeepLinkHandler {
  static Future<void> handleUri(BuildContext context, Uri uri) async {
    if (uri.host == 'witalk.in' || uri.host == 'www.witalk.in') {
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 2 && pathSegments[0] == 'adda') {
        final roomId = pathSegments[1];
        if (!await checkMicPermission(context)) return;
        if (context.mounted) context.push('/live-audio/$roomId');
      }
    }
  }
}
