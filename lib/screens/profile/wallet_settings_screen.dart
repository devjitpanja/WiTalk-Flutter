import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/dio_client.dart';
import '../../theme/theme_colors.dart';

// ─── Alert model ─────────────────────────────────────────────────────────────

class _AlertButton {
  final String text;
  final VoidCallback onPress;
  const _AlertButton({required this.text, required this.onPress});
}

class _AlertConfig {
  final bool visible;
  final String title;
  final String message;
  final String iconColor;
  final List<_AlertButton> buttons;
  const _AlertConfig({
    this.visible = false,
    this.title = '',
    this.message = '',
    this.iconColor = '#EF4444',
    this.buttons = const [],
  });
  _AlertConfig copyWith({bool? visible, String? title, String? message, String? iconColor, List<_AlertButton>? buttons}) =>
      _AlertConfig(
        visible: visible ?? this.visible,
        title: title ?? this.title,
        message: message ?? this.message,
        iconColor: iconColor ?? this.iconColor,
        buttons: buttons ?? this.buttons,
      );
}

// ─── Simple dropdown ─────────────────────────────────────────────────────────

class _SimpleDropdown extends StatefulWidget {
  final List<Map<String, dynamic>> options;
  final dynamic selectedValue;
  final ValueChanged<dynamic> onValueChange;
  final String placeholder;
  final ThemeColors colors;

  const _SimpleDropdown({
    required this.options,
    required this.selectedValue,
    required this.onValueChange,
    required this.placeholder,
    required this.colors,
  });

  @override
  State<_SimpleDropdown> createState() => _SimpleDropdownState();
}

class _SimpleDropdownState extends State<_SimpleDropdown> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final selected = widget.selectedValue != null
        ? widget.options.firstWhere(
            (o) => o['id'].toString() == widget.selectedValue.toString(),
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    final hasSelected = selected.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isOpen = !_isOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hasSelected ? (selected['name']?.toString() ?? '') : widget.placeholder,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    color: hasSelected ? c.text : c.placeholder,
                  ),
                ),
                Icon(
                  _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 22,
                  color: c.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_isOpen)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
              boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: Column(
              children: widget.options.asMap().entries.map((entry) {
                final i = entry.key;
                final opt = entry.value;
                final isLast = i == widget.options.length - 1;
                final isSelected = widget.selectedValue != null &&
                    widget.selectedValue.toString() == opt['id'].toString();
                return GestureDetector(
                  onTap: () {
                    widget.onValueChange(opt['id']);
                    setState(() => _isOpen = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: isLast ? null : Border(bottom: BorderSide(color: c.border, width: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(opt['name']?.toString() ?? '', style: TextStyle(fontFamily: 'Outfit', fontSize: 15, color: c.text)),
                        if (isSelected) const Icon(Icons.check, size: 18, color: Color(0xFF4F46E5)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class WalletSettingsScreen extends ConsumerStatefulWidget {
  const WalletSettingsScreen({super.key});
  @override
  ConsumerState<WalletSettingsScreen> createState() => _WalletSettingsScreenState();
}

class _WalletSettingsScreenState extends ConsumerState<WalletSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _methods = [];
  dynamic _selectedMethodId;
  String _paymentAccount = '';
  String _profileName = '';
  _AlertConfig _alertConfig = const _AlertConfig();
  final _accountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _accountCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid != null) {
        final userRes = await dioClient.get('/v1/user/$uid');
        if (userRes.data['data'] != null) {
          final d = userRes.data['data'] as Map;
          setState(() => _profileName = (d['name'] ?? d['username'] ?? '').toString());
        }
      }

      final methodsRes = await dioClient.get('/v1/wallet/payment-methods');
      if (methodsRes.data['success'] == true) {
        setState(() {
          _methods = List<Map<String, dynamic>>.from(
            (methodsRes.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        });
      }

      final settingsRes = await dioClient.get('/v1/wallet/settings');
      if (settingsRes.data['success'] == true && settingsRes.data['data'] != null) {
        final s = settingsRes.data['data'] as Map;
        final account = s['payment_account']?.toString() ?? '';
        setState(() {
          _selectedMethodId = s['payment_method_id'];
          _paymentAccount = account;
        });
        _accountCtrl.text = account;
      }
    } catch (e) {
      _showAlert(
        title: 'Error',
        message: 'Could not load your payment settings. Please try again.',
        iconColor: '#EF4444',
        buttons: [_AlertButton(text: 'OK', onPress: _dismissAlert)],
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSave() async {
    if (_selectedMethodId == null) {
      _showAlert(
        title: 'Required',
        message: 'Please select a payment method.',
        iconColor: '#EF4444',
        buttons: [_AlertButton(text: 'OK', onPress: _dismissAlert)],
      );
      return;
    }
    if (_paymentAccount.trim().isEmpty) {
      _showAlert(
        title: 'Required',
        message: 'Please enter your payment account details.',
        iconColor: '#EF4444',
        buttons: [_AlertButton(text: 'OK', onPress: _dismissAlert)],
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await dioClient.put('/v1/wallet/settings', data: {
        'payment_method_id': _selectedMethodId,
        'payment_account': _paymentAccount.trim(),
      });
      if (res.data['success'] == true) {
        _showAlert(
          title: 'Settings Saved',
          message: 'Your payment settings have been updated successfully.',
          iconColor: '#10B981',
          buttons: [
            _AlertButton(text: 'Done', onPress: () {
              _dismissAlert();
              context.pop();
            }),
          ],
        );
      }
    } catch (e) {
      final msg = ((e as dynamic).response?.data as Map?)?['message']?.toString()
          ?? 'Failed to save settings. Please try again.';
      _showAlert(
        title: 'Error',
        message: msg,
        iconColor: '#EF4444',
        buttons: [_AlertButton(text: 'OK', onPress: _dismissAlert)],
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showAlert({
    required String title,
    required String message,
    required String iconColor,
    required List<_AlertButton> buttons,
  }) {
    setState(() => _alertConfig = _AlertConfig(
      visible: true,
      title: title,
      message: message,
      iconColor: iconColor,
      buttons: buttons,
    ));
  }

  void _dismissAlert() => setState(() => _alertConfig = _alertConfig.copyWith(visible: false));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_loading) {
      return Scaffold(
        backgroundColor: c.background,
        body: SafeArea(child: Column(children: [
          _buildHeader(c),
          Expanded(child: Center(child: CircularProgressIndicator(color: c.accent))),
        ])),
      );
    }

    final activeMethod = _selectedMethodId != null
        ? _methods.firstWhere(
            (m) => m['id'].toString() == _selectedMethodId.toString(),
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};

    final isFormValid = _selectedMethodId != null && _paymentAccount.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(child: Stack(children: [
        Positioned.fill(child: Column(children: [
          _buildHeader(c),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Card
              Container(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border, width: 0.5),
                  boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Payout Configuration', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 18, color: c.text)),
                  const SizedBox(height: 6),
                  Text(
                    'Set up how you want to receive your contributor rewards and earnings.',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: c.textSecondary, height: 1.46),
                  ),
                  const SizedBox(height: 20),

                  // Account Name (read-only)
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Account Name', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: c.text)),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: 0.75,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border),
                        ),
                        child: Row(children: [
                          Icon(Icons.person_outline, size: 18, color: c.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            _profileName.isNotEmpty ? _profileName : '—',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w500, color: c.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.verified_user, size: 14, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 6),
                      Expanded(child: Text.rich(
                        TextSpan(
                          text: 'Your payout account name must match your profile name to verify your identity and ensure secure, trusted transactions. ',
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: c.textSecondary, height: 1.42),
                          children: [
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => context.push('/edit-profile'),
                                child: const Text(
                                  'Update your profile',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 12,
                                    color: Color(0xFF4F46E5),
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ]),
                  ]),
                  const SizedBox(height: 20),

                  // Payment methods or empty notice
                  if (_methods.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.info_outline, size: 20, color: Color(0xFF92400E)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'No payment methods are currently active on the platform. Please contact support.',
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF92400E), height: 1.38),
                        )),
                      ]),
                    )
                  else ...[
                    // Method selector
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('Payment Method ', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: c.text)),
                        const Text('*', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                      ]),
                      const SizedBox(height: 8),
                      _SimpleDropdown(
                        options: _methods,
                        selectedValue: _selectedMethodId,
                        onValueChange: (v) => setState(() => _selectedMethodId = v),
                        placeholder: 'Select a method',
                        colors: c,
                      ),
                      if (activeMethod.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text(
                            'Minimum withdrawal: ₹${double.tryParse(activeMethod['min_withdrawal_amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: c.textSecondary),
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 20),

                    // Account input
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('Payment Account / Email / UPI ID ', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: c.text)),
                        const Text('*', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                      ]),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _accountCtrl,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.none,
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 15, color: c.text),
                        decoration: InputDecoration(
                          hintText: 'e.g. username@upi or example@paypal.com',
                          hintStyle: TextStyle(fontFamily: 'Outfit', fontSize: 15, color: c.placeholder),
                          filled: true,
                          fillColor: c.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: c.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: c.border),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: c.border),
                          ),
                        ),
                        onChanged: (v) => setState(() => _paymentAccount = v),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          'Please ensure this information is accurate to avoid failed transfers.',
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: c.textSecondary),
                        ),
                      ),
                    ]),
                  ],
                ]),
              ),

              // Save button
              const SizedBox(height: 24),
              GestureDetector(
                onTap: (!isFormValid || _saving) ? null : _handleSave,
                child: Opacity(
                  opacity: (!isFormValid || _saving) ? 0.5 : 1,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: isFormValid && !_saving
                          ? [BoxShadow(color: c.accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
                          : null,
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (_saving)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      else ...[
                        const Icon(Icons.save, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text('Save Settings', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
                      ],
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ]),
          )),
        ])),
        if (_alertConfig.visible) Positioned.fill(child: _buildAlertDialog(c)),
      ])),
    );
  }

  Widget _buildHeader(ThemeColors c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: c.headerBackground,
      border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
    ),
    child: Row(children: [
      GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
          child: Icon(Icons.arrow_back, color: c.text, size: 24),
        ),
      ),
      const SizedBox(width: 2),
      Text('Wallet Settings', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20, color: c.headerText)),
    ]),
  );

  Widget _buildAlertDialog(ThemeColors c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {},
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xCC1C1C1E) : const Color(0xF5FFFFFF),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.3), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_alertConfig.title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20, color: c.text)),
              const SizedBox(height: 8),
              Text(_alertConfig.message, style: TextStyle(fontFamily: 'Outfit', fontSize: 15, color: c.textSecondary, height: 1.47)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _alertConfig.buttons.map((btn) {
                  Color textColor;
                  switch (_alertConfig.iconColor) {
                    case '#10B981': textColor = const Color(0xFF10B981); break;
                    case '#F59E0B': textColor = const Color(0xFFF59E0B); break;
                    case '#4F46E5': textColor = const Color(0xFF4F46E5); break;
                    default: textColor = const Color(0xFF3B82F6);
                  }
                  return TextButton(
                    onPressed: btn.onPress,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      minimumSize: const Size(70, 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(btn.text, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 12, color: textColor)),
                  );
                }).toList(),
              ),
            ]),
          ),
        )),
      ),
    );
  }
}
