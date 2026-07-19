import 'dart:async';
import 'package:flutter/material.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../theme/theme_colors.dart';

class CityInput extends StatefulWidget {
  final String value;
  final ValueChanged<String> onCitySelect;
  final void Function(String cityName, String fullDescription, String? country)? onCitySelectFull;
  final String placeholder;
  final bool disabled;
  final Widget? rightAction;

  const CityInput({
    super.key,
    required this.value,
    required this.onCitySelect,
    this.onCitySelectFull,
    this.placeholder = 'Search and select your city',
    this.disabled = false,
    this.rightAction,
  });

  @override
  State<CityInput> createState() => _CityInputState();
}

class _CityInputState extends State<CityInput> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  bool _loading = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.value;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(CityInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _removeOverlay();
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      _removeOverlay();
      setState(() { _suggestions = []; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetch(value));
  }

  Future<void> _fetch(String query) async {
    try {
      final res = await dioClient.get(
        AppEndpoints.locationAutocomplete,
        queryParameters: {'input': query},
      );
      final predictions = (res.data['data']?['predictions'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _suggestions = predictions.cast<Map<String, dynamic>>();
          _loading = false;
        });
        if (_suggestions.isNotEmpty && _focusNode.hasFocus) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _overlay = OverlayEntry(builder: (_) => Positioned(
      width: _getBoxWidth(),
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 52),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                final main = s['structured_formatting']?['main_text'] as String? ?? s['description'] as String? ?? '';
                final secondary = s['structured_formatting']?['secondary_text'] as String? ?? '';
                return InkWell(
                  onTap: () => _select(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      Icon(Icons.location_on_outlined, size: 16, color: colors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(main, style: TextStyle(color: colors.text, fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
                        if (secondary.isNotEmpty)
                          Text(secondary, style: TextStyle(color: colors.textTertiary, fontSize: 12, fontFamily: 'Outfit')),
                      ])),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ));
    Overlay.of(context).insert(_overlay!);
  }

  double _getBoxWidth() {
    final box = context.findRenderObject() as RenderBox?;
    return box?.size.width ?? 300;
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _select(Map<String, dynamic> suggestion) {
    final main = suggestion['structured_formatting']?['main_text'] as String? ?? suggestion['description'] as String? ?? '';
    final desc = suggestion['description'] as String? ?? main;
    // Try to extract country from secondary text
    final secondary = suggestion['structured_formatting']?['secondary_text'] as String? ?? '';
    final parts = secondary.split(', ');
    final country = parts.isNotEmpty ? parts.last : null;

    _ctrl.text = main;
    _removeOverlay();
    _focusNode.unfocus();
    widget.onCitySelect(main);
    widget.onCitySelectFull?.call(main, desc, country);
    setState(() { _suggestions = []; });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const SizedBox(width: 12),
          Expanded(child: TextField(
            controller: _ctrl,
            focusNode: _focusNode,
            enabled: !widget.disabled,
            style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontSize: 16),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: TextStyle(color: colors.placeholder, fontFamily: 'Outfit'),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: _onChanged,
          )),
          if (_loading)
            Padding(padding: const EdgeInsets.only(right: 8), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))),
          if (widget.rightAction != null) widget.rightAction!,
          const SizedBox(width: 8),
        ]),
      ),
    );
  }
}
