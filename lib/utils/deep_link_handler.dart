import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeepLinkHandler {
  static void handleUri(BuildContext context, Uri uri) {
    if (uri.host == 'witalk.in' || uri.host == 'www.witalk.in') {
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 2 && pathSegments[0] == 'adda') {
        final roomId = pathSegments[1];
        context.push('/live-audio/$roomId');
      }
    }
  }
}
