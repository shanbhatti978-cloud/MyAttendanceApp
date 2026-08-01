import 'package:flutter/material.dart';

import 'constants.dart';

/// Wrap any screen's body with this. If [allowed] is false, it shows a
/// clear "not permitted" message instead of the real content — a
/// defense-in-depth guard so a restricted screen refuses to render even
/// if something ever navigates to it directly, not just when the menu
/// entry that normally leads there is hidden.
class AccessGuard extends StatelessWidget {
  final bool allowed;
  final Widget child;
  final String? message;

  const AccessGuard({super.key, required this.allowed, required this.child, this.message});

  @override
  Widget build(BuildContext context) {
    if (allowed) return child;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.10), shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline, size: 40, color: AppColors.danger),
            ),
            const SizedBox(height: 16),
            const Text('Access Restricted', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              message ?? 'Your account role does not have permission to view this section.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
