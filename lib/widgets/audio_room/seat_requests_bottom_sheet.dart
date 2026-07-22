import 'package:flutter/material.dart';

class SeatRequestsBottomSheet extends StatelessWidget {
  final List<dynamic> requests;
  final Function(dynamic)? onAccept;
  final Function(dynamic)? onReject;

  const SeatRequestsBottomSheet({
    super.key,
    this.requests = const [],
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2A3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle Indicator
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Seat Requests',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (requests.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          requests.length.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  requests.isEmpty
                      ? 'No pending requests'
                      : 'Accept or reject audience requests to take a seat',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: requests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_seat, size: 48, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'No pending seat requests',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 15,
                      bottom: MediaQuery.of(context).padding.bottom + 20,
                    ),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request['userName'] ?? 'User',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Requesting Seat #${(request['seatIndex'] ?? 0) + 1}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildActionButton(
                                  icon: Icons.check,
                                  color: const Color(0xFF4CAF50),
                                  onTap: () => onAccept?.call(request),
                                ),
                                const SizedBox(width: 8),
                                _buildActionButton(
                                  icon: Icons.close,
                                  color: const Color(0xFFFF6B6B),
                                  onTap: () => onReject?.call(request),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            border: Border.all(color: color),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

Future<void> showSeatRequestsBottomSheet({
  required BuildContext context,
  List<dynamic> requests = const [],
  Function(dynamic)? onAccept,
  Function(dynamic)? onReject,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => SeatRequestsBottomSheet(
      requests: requests,
      onAccept: onAccept,
      onReject: onReject,
    ),
  );
}
