import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../utils/sync_service.dart';

/// Watches for connectivity changes and kicks off a background sync
/// the moment internet becomes available — this is what makes sync
/// "automatic" per the requirement, on top of the manual "Sync Now"
/// button in Settings. Sync failures here are silent by design (see
/// SyncService) so a flaky connection never disrupts the UI.
class ConnectivitySyncListener extends StatefulWidget {
  final Widget child;
  const ConnectivitySyncListener({super.key, required this.child});

  @override
  State<ConnectivitySyncListener> createState() => _ConnectivitySyncListenerState();
}

class _ConnectivitySyncListenerState extends State<ConnectivitySyncListener> {
  bool _wasOffline = true;

  @override
  void initState() {
    super.initState();
    SyncService.instance.loadLastSyncTime();
    Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    // Also attempt a sync shortly after a cold start, in case the app
    // was already online when it opened (onConnectivityChanged only
    // fires on a *change*, not on the initial state).
    Future.delayed(const Duration(seconds: 2), () => SyncService.instance.syncNow());
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (isOnline && _wasOffline) {
      SyncService.instance.syncNow();
    }
    _wasOffline = !isOnline;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
