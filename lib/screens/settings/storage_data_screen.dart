import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/theme_provider.dart';

const _prefWifi = 'media_auto_dl_wifi';
const _prefMobile = 'media_auto_dl_mobile';

class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
  Color get surface => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get border => dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  Color get text => dark ? Colors.white : Colors.black;
  Color get textTertiary => const Color(0xFF8E8E93);
  Color get primary => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  Color get barTrack => dark ? const Color(0xFF2a2f3e) : const Color(0xFFe8eaf0);
}

String _fmt(int bytes) {
  if (bytes == 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class StorageDataScreen extends ConsumerStatefulWidget {
  const StorageDataScreen({super.key});
  @override
  ConsumerState<StorageDataScreen> createState() => _StorageDataScreenState();
}

class _StorageDataScreenState extends ConsumerState<StorageDataScreen> {
  int? _cacheSize;
  int _imageCount = 0;
  bool _calculating = true;
  bool _clearing = false;
  bool _autoWifi = true;
  bool _autoMobile = false;

  @override
  void initState() { super.initState(); _loadPrefs(); _calcCache(); }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoWifi = prefs.getBool(_prefWifi) ?? true;
      _autoMobile = prefs.getBool(_prefMobile) ?? false;
    });
  }

  Future<void> _calcCache() async {
    setState(() => _calculating = true);
    try {
      final dir = await getTemporaryDirectory();
      final files = dir.listSync().whereType<File>().where((f) => f.path.contains('witalk_img_')).toList();
      int total = 0;
      for (final f in files) { try { total += f.lengthSync(); } catch (_) {} }
      if (mounted) setState(() { _cacheSize = total; _imageCount = files.length; });
    } catch (_) { if (mounted) setState(() { _cacheSize = 0; _imageCount = 0; }); }
    finally { if (mounted) setState(() => _calculating = false); }
  }

  Future<void> _clearCache() async {
    if (_imageCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No cached media to clear')));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Media Cache', style: TextStyle(fontFamily: 'Outfit')),
        content: Text('This will delete $_imageCount cached image${_imageCount != 1 ? 's' : ''} (${_fmt(_cacheSize ?? 0)}) from your device.', style: const TextStyle(fontFamily: 'Outfit')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear', style: TextStyle(color: Color(0xFFFF453A)))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _clearing = true);
    try {
      final dir = await getTemporaryDirectory();
      final files = dir.listSync().whereType<File>().where((f) => f.path.contains('witalk_img_')).toList();
      for (final f in files) { try { f.deleteSync(); } catch (_) {} }
      if (mounted) { setState(() { _cacheSize = 0; _imageCount = 0; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Media cache cleared'), backgroundColor: Color(0xFF34C759))); }
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to clear cache'), backgroundColor: Color(0xFFFF453A))); }
    finally { if (mounted) setState(() => _clearing = false); }
  }

  Future<void> _toggleWifi(bool v) async { setState(() => _autoWifi = v); final p = await SharedPreferences.getInstance(); p.setBool(_prefWifi, v); }
  Future<void> _toggleMobile(bool v) async { setState(() => _autoMobile = v); final p = await SharedPreferences.getInstance(); p.setBool(_prefMobile, v); }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);
    const maxBytes = 500 * 1024 * 1024;
    final fill = (_cacheSize != null && _cacheSize! > 0) ? (_cacheSize! / maxBytes).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border, width: 0.5))),
          child: Row(children: [
            GestureDetector(onTap: () => context.pop(), child: Icon(Icons.arrow_back, color: t.text, size: 24)),
            const SizedBox(width: 12),
            Text('Storage & Data', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text)),
          ]),
        ),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('STORAGE', t),
          _card(t, [
            // Bar
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Row(children: [
              Icon(Icons.photo_library, size: 20, color: t.primary),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 6, decoration: BoxDecoration(color: t.barTrack, borderRadius: BorderRadius.circular(3)), child: FractionallySizedBox(widthFactor: fill, alignment: Alignment.centerLeft, child: Container(decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(3)))))),
            ])),
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cached Images', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: t.text)),
                const SizedBox(height: 2),
                Text(_calculating ? 'Calculating…' : '$_imageCount file${_imageCount != 1 ? 's' : ''} · ${_fmt(_cacheSize ?? 0)}', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.textTertiary)),
              ])),
              if (_calculating) CircularProgressIndicator(strokeWidth: 2, color: t.primary),
            ])),
            Container(height: 0.5, color: t.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
            GestureDetector(
              onTap: (_clearing || _calculating) ? null : _clearCache,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [
                _clearing
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF453A)))
                    : const Icon(Icons.delete_outline, size: 22, color: Color(0xFFFF453A)),
                const SizedBox(width: 12),
                Text(_clearing ? 'Clearing…' : 'Clear Media Cache', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFFFF453A))),
              ])),
            ),
          ]),
          Padding(padding: const EdgeInsets.only(top: 8, left: 4), child: Text('Cached images are stored on your device for faster loading. Clearing them frees up space — images will re-download when opened.', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary, height: 1.5))),
          _sectionLabel('MEDIA AUTO-DOWNLOAD', t),
          _card(t, [
            _prefRow(Icons.wifi, t.primary, const Color(0x18007AFF), 'When on Wi-Fi', _autoWifi ? 'Images download automatically' : 'Tap image to download', _autoWifi, _toggleWifi, t),
            Container(height: 0.5, color: t.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
            _prefRow(Icons.signal_cellular_alt, const Color(0xFFFF9F0A), const Color(0x18FF9F0A), 'When on Mobile Data', _autoMobile ? 'Images download automatically' : 'Tap image to download', _autoMobile, _toggleMobile, t),
          ]),
          Padding(padding: const EdgeInsets.only(top: 8, left: 4), child: Text('When auto-download is off, images show a blurred preview. Tap to download and view them. This saves mobile data.', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary, height: 1.5))),
        ]))),
      ])),
    );
  }

  Widget _sectionLabel(String s, _T t) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4), child: Text(s, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 11, color: t.textTertiary, letterSpacing: 0.8)));

  Widget _card(_T t, List<Widget> children) => Container(decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.border, width: 0.5), boxShadow: const []), clipBehavior: Clip.hardEdge, child: Column(children: children));

  Widget _prefRow(IconData icon, Color iconColor, Color iconBg, String title, String subtitle, bool value, Future<void> Function(bool) onToggle, _T t) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 20, color: iconColor)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: t.text)),
          const SizedBox(height: 1),
          Text(subtitle, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary)),
        ])),
        Switch(value: value, onChanged: onToggle, activeTrackColor: iconColor, activeThumbColor: Colors.white, inactiveTrackColor: t.border),
      ]));
}
