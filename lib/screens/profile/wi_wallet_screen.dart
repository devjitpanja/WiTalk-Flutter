import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api/dio_client.dart';
import '../../theme/theme_colors.dart';

// ─── Alert model ────────────────────────────────────────────────────────────

class _AlertButton {
  final String text;
  final String style; // 'solid' | 'outline' | 'cancel'
  final VoidCallback onPress;
  const _AlertButton({required this.text, required this.style, required this.onPress});
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
    this.iconColor = '#3B82F6',
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

// ─── Timestamp formatting (matches RN parseDBDate → toLocaleString) ──────────

String _formatTimestamp(dynamic raw) {
  if (raw == null) return '';
  final s = raw.toString();
  if (s.isEmpty) return '';
  try {
    DateTime dt;
    // MySQL DATETIME has no timezone — treat as UTC (matches RN parseDBDate)
    if (RegExp('Z\$|[+-]\\d{2}:?\\d{2}\$').hasMatch(s)) {
      dt = DateTime.parse(s).toLocal();
    } else {
      dt = DateTime.parse(s.replaceFirst(' ', 'T') + 'Z').toLocal();
    }
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m $ampm';
  } catch (_) {
    return s;
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class WiWalletScreen extends ConsumerStatefulWidget {
  const WiWalletScreen({super.key});
  @override
  ConsumerState<WiWalletScreen> createState() => _WiWalletScreenState();
}

class _WiWalletScreenState extends ConsumerState<WiWalletScreen> {
  bool _loading = true;
  Map<String, dynamic> _wallet = {'balance': 0};
  List<Map<String, dynamic>> _transactions = [];
  String _activeTab = 'history';
  String _payoutAmount = '';
  bool _submitting = false;
  _AlertConfig _alertConfig = const _AlertConfig();
  final _amountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await dioClient.get('/v1/wallet');
      if (res.data['success'] == true) {
        setState(() {
          _wallet = Map<String, dynamic>.from(res.data['data']['wallet'] as Map);
          _transactions = List<Map<String, dynamic>>.from(
            (res.data['data']['transactions'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestPayout() async {
    final amount = double.tryParse(_payoutAmount);
    if (amount == null || amount <= 0) {
      _showAlert(
        title: 'Invalid Amount',
        message: 'Please enter a valid payout amount.',
        iconColor: '#EF4444',
        buttons: [_AlertButton(text: 'OK', style: 'solid', onPress: _dismissAlert)],
      );
      return;
    }
    final balance = double.tryParse(_wallet['balance'].toString()) ?? 0;
    if (amount > balance) {
      _showAlert(
        title: 'Insufficient Balance',
        message: 'You cannot request more than your current balance.',
        iconColor: '#EF4444',
        buttons: [_AlertButton(text: 'OK', style: 'solid', onPress: _dismissAlert)],
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await dioClient.post('/v1/wallet/payout', data: {'amount': amount});
      if (res.data['success'] == true) {
        _showAlert(
          title: 'Success',
          message: 'Payout requested successfully. Your transaction is pending approval.',
          iconColor: '#10B981',
          buttons: [
            _AlertButton(text: 'OK', style: 'solid', onPress: () {
              _dismissAlert();
              setState(() {
                _payoutAmount = '';
                _amountCtrl.clear();
                _activeTab = 'history';
              });
              _fetch();
            }),
          ],
        );
      }
    } catch (e) {
      final status = (e as dynamic).response?.statusCode;
      final data = (e as dynamic).response?.data;

      if (status == 403) {
        _showAlert(
          title: 'Verification Required',
          message: 'Your profile must be verified before you can request a payout.',
          iconColor: '#F59E0B',
          buttons: [
            _AlertButton(text: 'Cancel', style: 'outline', onPress: _dismissAlert),
            _AlertButton(text: 'Verify Now', style: 'solid', onPress: () {
              _dismissAlert();
              context.push('/id-verification');
            }),
          ],
        );
      } else if (status == 400 && data?['error'] == 'PAYMENT_INFO_MISSING') {
        _showAlert(
          title: 'Settings Incomplete',
          message: 'Please configure your payment method and account details first.',
          iconColor: '#4F46E5',
          buttons: [
            _AlertButton(text: 'Cancel', style: 'outline', onPress: _dismissAlert),
            _AlertButton(text: 'Go to Settings', style: 'solid', onPress: () {
              _dismissAlert();
              context.push('/wallet-settings');
            }),
          ],
        );
      } else {
        final errMsg = data?['message']?.toString() ?? 'Failed to request payout';
        _showAlert(
          title: 'Request Failed',
          message: errMsg,
          iconColor: '#EF4444',
          buttons: [_AlertButton(text: 'OK', style: 'solid', onPress: _dismissAlert)],
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
    final balance = double.tryParse(_wallet['balance'].toString()) ?? 0;

    if (_loading && _wallet['user_id'] == null) {
      return Scaffold(
        backgroundColor: c.background,
        body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildHeader(c),
          Expanded(child: Center(child: CircularProgressIndicator(color: c.accent))),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(child: Stack(children: [
        Positioned.fill(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildHeader(c),
          if (_loading)
            Expanded(child: Center(child: CircularProgressIndicator(color: c.accent)))
          else ...[
            _buildBalanceCard(c, balance),
            _buildTabs(c),
            Expanded(child: _activeTab == 'history' ? _buildHistory(c) : _buildPayout(c, balance)),
          ],
        ])),
        if (_alertConfig.visible) Positioned.fill(child: _buildAlertDialog(c)),
      ])),
    );
  }

  Widget _buildHeader(ThemeColors c) => Container(
    padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
    decoration: BoxDecoration(
      color: c.background,
      border: Border(bottom: BorderSide(color: c.surface, width: 1)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
              child: Icon(Icons.arrow_back, color: c.text, size: 24),
            ),
          ),
          Text('Wi-Wallet', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20, color: c.text)),
        ]),
        GestureDetector(
          onTap: () => context.push('/wallet-settings'),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.settings, color: c.text, size: 24),
          ),
        ),
      ],
    ),
  );

  Widget _buildBalanceCard(ThemeColors c, double balance) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    padding: const EdgeInsets.symmetric(vertical: 35),
    decoration: BoxDecoration(
      color: c.accent,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 4))],
    ),
    child: Column(children: [
      const Text('Current Balance', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 16, color: Color(0xCCFFFFFF))),
      const SizedBox(height: 8),
      Text('₹${balance.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 42, color: Colors.white)),
    ]),
  );

  Widget _buildTabs(ThemeColors c) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(20, 25, 20, 10),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      _tabBtn('history', 'History', c),
      _tabBtn('payout', 'Request Payout', c),
    ]),
  );

  Widget _tabBtn(String id, String label, ThemeColors c) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _activeTab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _activeTab == id ? c.background : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: _activeTab == id
              ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 3, offset: Offset(0, 2))]
              : null,
        ),
        child: Center(child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: _activeTab == id ? c.text : c.textSecondary,
          ),
        )),
      ),
    ),
  );

  Widget _buildHistory(ThemeColors c) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
    itemCount: _transactions.isEmpty ? 1 : _transactions.length,
    itemBuilder: (_, i) {
      if (_transactions.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(children: [
            Icon(Icons.receipt_long, size: 48, color: c.textTertiary),
            const SizedBox(height: 10),
            Text('No transactions yet', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 16, color: c.textSecondary)),
          ]),
        );
      }
      final tx = _transactions[i];
      final isCredit = tx['type'] == 'credit';
      final status = tx['status']?.toString() ?? '';
      final statusColor = status == 'completed'
          ? const Color(0xFF4CAF50)
          : status == 'pending'
              ? const Color(0xFFFFC107)
              : const Color(0xFFF44336);
      final amt = double.tryParse(tx['amount'].toString()) ?? 0;

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.surface, width: 1))),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              size: 24,
              color: isCredit ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isCredit ? 'Reward Credited' : 'Payout Requested',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: c.text),
            ),
            const SizedBox(height: 3),
            Text(
              _formatTimestamp(tx['timestamp']),
              style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: c.textTertiary),
            ),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              '${isCredit ? '+' : '-'}₹${amt.toStringAsFixed(2)}',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16, color: isCredit ? const Color(0xFF4CAF50) : c.text),
            ),
            const SizedBox(height: 4),
            Text(
              status.toUpperCase(),
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 11, color: statusColor),
            ),
          ]),
        ]),
      );
    },
  );

  Widget _buildPayout(ThemeColors c, double balance) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Withdraw Funds', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 22, color: c.text)),
      const SizedBox(height: 10),
      Text(
        'Minimum payout request limit applies. Your profile must be verified to process the request.',
        style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: c.textSecondary, height: 1.4),
      ),
      const SizedBox(height: 30),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Text('₹', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 24, color: c.text)),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 28, color: c.text),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(color: c.placeholder),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
            ),
            onChanged: (v) => setState(() => _payoutAmount = v),
          )),
        ]),
      ),
      const SizedBox(height: 30),
      GestureDetector(
        onTap: (_payoutAmount.isEmpty || _submitting) ? null : _requestPayout,
        child: Opacity(
          opacity: (_payoutAmount.isEmpty || _submitting) ? 0.6 : 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(12)),
            child: Center(child: _submitting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Submit Request', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white))),
          ),
        ),
      ),
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
              Text(
                _alertConfig.title,
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20, color: c.text),
              ),
              const SizedBox(height: 8),
              Text(
                _alertConfig.message,
                style: TextStyle(fontFamily: 'Outfit', fontSize: 15, color: c.textSecondary, height: 1.47),
              ),
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
                  if (btn.style == 'outline' || btn.style == 'cancel') {
                    textColor = c.textSecondary;
                  }
                  return TextButton(
                    onPressed: btn.onPress,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      minimumSize: const Size(70, 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      btn.text,
                      style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 12, color: textColor),
                    ),
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
