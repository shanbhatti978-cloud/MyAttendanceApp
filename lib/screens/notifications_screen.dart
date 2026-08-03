import 'package:flutter/material.dart';

import '../db/db_helper.dart';
import '../utils/constants.dart';
import '../utils/data_bus.dart';
import '../utils/time_ago.dart';
import '../widgets/app_drawer.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _all = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    DataBus.instance.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await DBHelper.instance.getNotifications();
    if (!mounted) return;
    setState(() {
      _all = all;
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    await DBHelper.instance.markAllNotificationsRead();
    DataBus.instance.notifyChanged();
  }

  Future<void> _markRead(int id) async {
    await DBHelper.instance.markNotificationRead(id);
    DataBus.instance.notifyChanged();
  }

  Future<void> _delete(int id) async {
    await DBHelper.instance.deleteNotification(id);
    DataBus.instance.notifyChanged();
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'leave_request':
        return Icons.event_note;
      case 'leave_decision':
        return Icons.fact_check;
      case 'manpower_alert':
        return Icons.warning_amber;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.trim().isEmpty
        ? _all
        : _all.where((n) => (n['message'] as String).toLowerCase().contains(_query.toLowerCase())).toList();
    final unreadCount = _all.where((n) => n['is_read'] == 0).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search notifications', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('No notifications.'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final n = filtered[i];
                          final isRead = n['is_read'] == 1;
                          final time = DateTime.parse(n['created_at'] as String);
                          return Dismissible(
                            key: ValueKey(n['id']),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: AppColors.danger,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) => _delete(n['id'] as int),
                            child: ListTile(
                              tileColor: isRead ? null : AppColors.primary.withValues(alpha: 0.05),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(alpha: isRead ? 0.08 : 0.16),
                                child: Icon(_iconFor(n['type'] as String), color: AppColors.primary, size: 18),
                              ),
                              title: Text(
                                n['message'] as String,
                                style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                              ),
                              subtitle: Text(timeAgo(time), style: const TextStyle(fontSize: 11)),
                              trailing: isRead
                                  ? null
                                  : Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                    ),
                              onTap: () => _markRead(n['id'] as int),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
