import 'package:flutter/material.dart';

class CloseAddaBottomSheet extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onCloseAdda;
  final Function(Map<String, dynamic>) onHandover;
  final VoidCallback onLeaveNoAdmin;
  final List<Map<String, dynamic>> eligibleAdmins;
  final bool isLoading;

  const CloseAddaBottomSheet({
    super.key,
    required this.onClose,
    required this.onCloseAdda,
    required this.onHandover,
    required this.onLeaveNoAdmin,
    this.eligibleAdmins = const [],
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasEligibleAdmins = eligibleAdmins.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: const Color(0xFF0751DF).withOpacity(0.25),
          width: 1,
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 4,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF0751DF).withOpacity(0.15),
                  width: 1,
                ),
              ),
            ),
            child: const Column(
              children: [
                Text(
                  'Leave Adda',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEBEBF5),
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose what happens when you leave',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white60,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0751DF)),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Please wait…',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Leave Adda Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: hasEligibleAdmins
                    ? () => onHandover(eligibleAdmins.first)
                    : onLeaveNoAdmin,
                borderRadius: BorderRadius.circular(12),
                splashColor: const Color(0xFF0751DF).withOpacity(0.15),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0751DF).withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0751DF).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0751DF).withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0751DF).withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: Color(0xFF0751DF),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Leave Adda',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF7AA3F5),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              hasEligibleAdmins
                                  ? 'Admins will keep the room running'
                                  : 'Make someone an admin first',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF7AA3F5).withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: const Color(0xFF0751DF).withOpacity(0.5),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Container(
              height: 1,
              color: const Color(0xFF0751DF).withOpacity(0.15),
              margin: const EdgeInsets.symmetric(vertical: 14),
            ),

            // End Adda Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onCloseAdda,
                borderRadius: BorderRadius.circular(12),
                splashColor: const Color(0xFFFF4444).withOpacity(0.15),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4444).withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF4444).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4444).withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF4444).withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.cancel,
                          color: Color(0xFFFF4444),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'End Adda for Everyone',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFFF6B6B),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'All participants will be removed',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFFFF6B6B).withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: const Color(0xFFFF4444).withOpacity(0.5),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showCloseAddaBottomSheet({
  required BuildContext context,
  required VoidCallback onClose,
  required VoidCallback onCloseAdda,
  required Function(Map<String, dynamic>) onHandover,
  required VoidCallback onLeaveNoAdmin,
  List<Map<String, dynamic>> eligibleAdmins = const [],
  bool isLoading = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CloseAddaBottomSheet(
      onClose: onClose,
      onCloseAdda: onCloseAdda,
      onHandover: onHandover,
      onLeaveNoAdmin: onLeaveNoAdmin,
      eligibleAdmins: eligibleAdmins,
      isLoading: isLoading,
    ),
  ).whenComplete(onClose);
}
