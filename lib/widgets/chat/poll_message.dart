import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../api/dio_client.dart';

// Mirrors PollMessage.jsx
class PollMessageWidget extends ConsumerStatefulWidget {
  final Map<String, dynamic> pollData;
  final String messageId;
  final bool isMyMessage;
  final String conversationId;

  const PollMessageWidget({
    super.key,
    required this.pollData,
    required this.messageId,
    required this.isMyMessage,
    required this.conversationId,
  });

  @override
  ConsumerState<PollMessageWidget> createState() =>
      _PollMessageWidgetState();
}

class _PollMessageWidgetState extends ConsumerState<PollMessageWidget> {
  bool _isVoting = false;
  late Map<String, dynamic> _pollData;

  @override
  void initState() {
    super.initState();
    _pollData = Map<String, dynamic>.from(widget.pollData);
  }

  Future<void> _vote(String optionId) async {
    final uid = ref.read(authProvider).uid;
    if (uid == null || _isVoting) return;

    setState(() => _isVoting = true);
    try {
      final res = await dioClient.post(
        '/v1/chat/conversations/${widget.conversationId}/messages/${widget.messageId}/poll/vote',
        data: {'option_id': optionId, 'user_id': uid},
      );
      if (res.data['success'] == true && res.data['data'] != null) {
        setState(() {
          _pollData = Map<String, dynamic>.from(
              res.data['data'] as Map<String, dynamic>);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isVoting = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final uid = ref.watch(authProvider).uid ?? '';
    final question = (_pollData['question'] as String?) ?? 'Poll';
    final options = (_pollData['options'] as List?) ?? [];
    final totalVotes = (_pollData['total_votes'] as num?)?.toInt() ?? 0;
    final isExpired = _pollData['is_expired'] == true;
    final isClosed = _pollData['is_closed'] == true;
    final canVote = !isExpired && !isClosed;

    final textColor = widget.isMyMessage ? Colors.white : c.text;
    final subColor = widget.isMyMessage
        ? Colors.white.withOpacity(0.7)
        : c.textSecondary;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.poll,
                size: 16,
                color: widget.isMyMessage ? Colors.white70 : c.primary),
            const SizedBox(width: 6),
            Text('POLL',
                style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: widget.isMyMessage
                        ? Colors.white70
                        : c.primary)),
          ]),
          const SizedBox(height: 8),
          Text(question,
              style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  color: textColor)),
          const SizedBox(height: 10),
          ...options.map((opt) {
            final optMap = Map<String, dynamic>.from(opt as Map);
            final optId = (optMap['id'] ?? optMap['_id'] ?? '')
                .toString();
            final optText =
                (optMap['text'] ?? optMap['option'] ?? '')
                    .toString();
            final votes =
                (optMap['votes'] as num?)?.toInt() ?? 0;
            final hasVoted =
                (optMap['voted_by'] as List?)?.contains(uid) == true;
            final pct = totalVotes > 0
                ? votes / totalVotes
                : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: canVote ? () => _vote(optId) : null,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: hasVoted
                          ? (widget.isMyMessage
                              ? Colors.white
                              : c.primary)
                          : (widget.isMyMessage
                              ? Colors.white38
                              : c.border),
                      width: hasVoted ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(children: [
                    // Progress fill
                    FractionallySizedBox(
                      widthFactor: pct.clamp(0.0, 1.0),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: (widget.isMyMessage
                                  ? Colors.white
                                  : c.primary)
                              .withOpacity(hasVoted ? 0.2 : 0.08),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                    // Option text
                    SizedBox(
                      height: 40,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                              optText,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'Outfit',
                                fontWeight: hasVoted
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: textColor,
                              ),
                            ),
                          ),
                          if (totalVotes > 0)
                            Text(
                              '${(pct * 100).round()}%',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                  color: hasVoted
                                      ? (widget.isMyMessage
                                          ? Colors.white
                                          : c.primary)
                                      : subColor),
                            ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            );
          }),
          Row(children: [
            Text(
              '$totalVotes vote${totalVotes != 1 ? 's' : ''}',
              style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Outfit',
                  color: subColor),
            ),
            if (isExpired || isClosed) ...[
              const SizedBox(width: 8),
              Text('• Closed',
                  style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Outfit',
                      color: subColor)),
            ],
          ]),
        ],
      ),
    );
  }
}
