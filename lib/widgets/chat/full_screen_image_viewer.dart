import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../../cache/witalk_image_cache.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? caption;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.caption,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  bool _showControls = true;
  bool _downloading = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1,
    );
    _fadeAnim = _fadeCtrl;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _fadeCtrl.forward();
    } else {
      _fadeCtrl.reverse();
    }
  }

  Future<void> _downloadImage() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: false);
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gallery permission denied')),
            );
          }
          return;
        }
      }

      final dir = await getTemporaryDirectory();
      final fileName = 'witalk_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${dir.path}/$fileName';

      await Dio().download(widget.imageUrl, filePath);
      await Gal.putImage(filePath);

      // Clean up temp file
      final tmp = File(filePath);
      if (tmp.existsSync()) tmp.deleteSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to gallery'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save image')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Zoomable image
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: Center(
                child: CachedNetworkImage(
                  cacheManager: WiTalkImageCache(),
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (ctx, url) => const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white54,
                      strokeWidth: 2,
                    ),
                  ),
                  errorWidget: (ctx, url, err) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  ),
                ),
              ),
            ),

            // Top bar — close button
            FadeTransition(
              opacity: _fadeAnim,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _CircleButton(
                      icon: Icons.close,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom bar — caption + download
            FadeTransition(
              opacity: _fadeAnim,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 24,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Caption (if any)
                      if (widget.caption != null && widget.caption!.isNotEmpty)
                        Expanded(
                          child: Text(
                            widget.caption!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Outfit',
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        const Spacer(),

                      // Download button
                      _CircleButton(
                        icon: _downloading ? null : Icons.download_outlined,
                        onTap: _downloading ? null : _downloadImage,
                        child: _downloading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? child;

  const _CircleButton({this.icon, this.onTap, this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: child ?? Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
