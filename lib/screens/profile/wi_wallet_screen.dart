import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api/dio_client.dart';
import '../../providers/theme_provider.dart';

class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
  Color get surface => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get border => dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  Color get text => dark ? Colors.white : Colors.black;
  Color get textSecondary => dark ? const Color(0xFFEBEBF5) : const Color(0xFF3C3C43);
  Color get textTertiary => const Color(0xFF8E8E93);
  Color get accent => const Color(0xFF0751DF);
  Color get primary => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
}

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
  Map<String, dynamic>? _alertConfig;
  final _amountCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _fetch(); }

  @override
  void dispose() { _amountCtrl.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await dioClient.get('/v1/wallet');
      if (res.data['success'] == true) {
        setState(() {
          _wallet = Map<String, dynamic>.from(res.data['data']['wallet'] as Map);
          _transactions = List<Map<String, dynamic>>.from((res.data['data']['transactions'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
        });
      }
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _requestPayout() async {
    final amount = double.tryParse(_payoutAmount);
    if (amount == null || amount <= 0) { _showAlert('Invalid Amount', 'Please enter a valid payout amount.'); return; }
    final balance = double.tryParse(_wallet['balance'].toString()) ?? 0;
    if (amount > balance) { _showAlert('Insufficient Balance', 'You cannot request more than your current balance.'); return; }
    setState(() => _submitting = true);
    try {
      final res = await dioClient.post('/v1/wallet/payout', data: {'amount': amount});
      if (res.data['success'] == true) {
        _showAlert('Success', 'Payout requested successfully. Your transaction is pending approval.', onOk: () {
          setState(() { _alertConfig = null; _payoutAmount = ''; _amountCtrl.clear(); _activeTab = 'history'; });
          _fetch();
        });
      }
    } catch (e) {
      final status = (e as dynamic).response?.statusCode;
      if (status == 403) _showAlert('Verification Required', 'Your profile must be verified before you can request a payout.');
      else _showAlert('Request Failed', 'Failed to request payout. Please try again.');
    } finally { if (mounted) setState(() => _submitting = false); }
  }

  void _showAlert(String title, String msg, {VoidCallback? onOk}) {
    setState(() => _alertConfig = {'title': title, 'message': msg, 'onOk': onOk ?? () => setState(() => _alertConfig = null)});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);
    final balance = double.tryParse(_wallet['balance'].toString()) ?? 0;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: Stack(children: [
        Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            decoration: BoxDecoration(color: t.bg, border: Border(bottom: BorderSide(color: t.surface, width: 1))),
            child: Row(children: [
              GestureDetector(onTap: () => context.pop(), child: Icon(Icons.arrow_back, color: t.text, size: 24)),
              const SizedBox(width: 8),
              Text('Wi-Wallet', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20, color: t.text)),
            ]),
          ),
          if (_loading)
            Expanded(child: Center(child: CircularProgressIndicator(color: t.accent)))
          else ...[
            // Balance card
            Container(
              margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              padding: const EdgeInsets.symmetric(vertical: 35),
              decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 4))]),
              child: Column(children: [
                const Text('Current Balance', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 16, color: Color(0xCCFFFFFF))),
                const SizedBox(height: 8),
                Text('₹${balance.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 42, color: Colors.white)),
              ]),
            ),
            // Tabs
            Container(
              margin: const EdgeInsets.fromLTRB(20, 25, 20, 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                _tabBtn('history', 'History', t),
                _tabBtn('payout', 'Request Payout', t),
              ]),
            ),
            // Content
            Expanded(child: _activeTab == 'history' ? _history(t) : _payout(t, balance)),
          ],
        ]),
        if (_alertConfig != null) _dialog(t),
      ])),
    );
  }

  Widget _tabBtn(String id, String label, _T t) => Expanded(child: GestureDetector(
    onTap: () => setState(() => _activeTab = id),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: _activeTab == id ? t.bg : Colors.transparent, borderRadius: BorderRadius.circular(10), boxShadow: _activeTab == id ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 3, offset: Offset(0, 2))] : null),
      child: Center(child: Text(label, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14, color: _activeTab == id ? t.text : t.textSecondary))),
    ),
  ));

  Widget _history(_T t) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
    itemCount: _transactions.isEmpty ? 1 : _transactions.length,
    itemBuilder: (_, i) {
      if (_transactions.isEmpty) return Padding(padding: const EdgeInsets.only(top: 60), child: Column(children: [Icon(Icons.receipt_long, size: 48, color: t.textTertiary), const SizedBox(height: 10), Text('No transactions yet', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 16, color: t.textSecondary))]));
      final tx = _transactions[i];
      final isCredit = tx['type'] == 'credit';
      final status = tx['status']?.toString() ?? '';
      final statusColor = status == 'completed' ? const Color(0xFF4CAF50) : status == 'pending' ? const Color(0xFFFFC107) : const Color(0xFFF44336);
      final amt = double.tryParse(tx['amount'].toString()) ?? 0;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.surface, width: 1))),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: t.surface, shape: BoxShape.circle), child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, size: 24, color: isCredit ? const Color(0xFF4CAF50) : const Color(0xFFFF9800))),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isCredit ? 'Reward Credited' : 'Payout Requested', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: t.text)),
            const SizedBox(height: 3),
            Text(tx['timestamp']?.toString() ?? '', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${isCredit ? '+' : '-'}₹${amt.toStringAsFixed(2)}', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16, color: isCredit ? const Color(0xFF4CAF50) : t.text)),
            const SizedBox(height: 4),
            Text(status.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 11, color: statusColor)),
          ]),
        ]),
      );
    },
  );

  Widget _payout(_T t, double balance) => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 30, 24, 40), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Withdraw Funds', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 22, color: t.text)),
    const SizedBox(height: 10),
    Text('Minimum payout request limit applies. Your profile must be verified to process the request.', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary, height: 1.4)),
    const SizedBox(height: 30),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
      child: Row(children: [
        Text('₹', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 24, color: t.text)),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 28, color: t.text),
          decoration: InputDecoration(hintText: '0.00', hintStyle: TextStyle(color: t.textTertiary), border: InputBorder.none),
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
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(12)),
          child: Center(child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Request', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white))),
        ),
      ),
    ),
  ]));

  Widget _dialog(_T t) => GestureDetector(
    onTap: () {},
    child: Container(color: Colors.black.withValues(alpha: 0.5), child: Center(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_alertConfig!['title'].toString(), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 17, color: t.text)),
        const SizedBox(height: 8),
        Text(_alertConfig!['message'].toString(), style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textTertiary)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: _alertConfig!['onOk'] as VoidCallback, child: Text('OK', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: t.primary))),
        ]),
      ]),
    ))),
  );
}
