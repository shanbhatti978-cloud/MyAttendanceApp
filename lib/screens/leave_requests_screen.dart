import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../models/employee.dart';
import '../utils/constants.dart';
import '../utils/data_bus.dart';
import '../utils/page_transitions.dart';
import '../utils/session.dart';
import '../widgets/access_guard.dart';
import '../widgets/app_drawer.dart';
import 'apply_leave_screen.dart';

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({super.key});

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen> {
  String _statusFilter = 'Pending';
  List<Map<String, dynamic>> _requests = [];
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
    final requests = await DBHelper.instance.getLeaveRequests(statusFilter: _statusFilter);
    if (!mounted) return;
    setState(() {
      _requests = requests;
      _loading = false;
    });
  }

  Future<void> _decide(Map<String, dynamic> request, bool approve) async {
    final remarksCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'Approve Leave' : 'Reject Leave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(approve
                ? 'This will mark attendance as Leave for the requested dates.'
                : 'This request will be marked as rejected.'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              decoration: const InputDecoration(labelText: 'Remarks (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final session = context.read<Session>();
    await DBHelper.instance.decideLeaveRequest(
      requestId: request['id'] as int,
      approve: approve,
      decidedBy: session.username ?? '',
      remarks: remarksCtrl.text.trim(),
    );
    _load();
  }

  Color _statusColorFor(String status) {
    switch (status) {
      case 'Approved':
        return AppColors.success;
      case 'Rejected':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManageLeave = context.watch<Session>().permissions.canManageLeave;

    return Scaffold(
      appBar: AppBar(title: const Text('Leave Requests')),
      drawer: const AppDrawer(),
      floatingActionButton: canManageLeave
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Apply Leave'),
              onPressed: () async {
                await Navigator.push(context, fadeSlideRoute(const ApplyLeaveScreen()));
                _load();
              },
            )
          : null,
      body: AccessGuard(
        allowed: canManageLeave,
        message: 'Viewer accounts cannot manage leave requests.',
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                children: ['Pending', 'Approved', 'Rejected', 'All'].map((s) {
                  return ChoiceChip(
                    label: Text(s),
                    selected: _statusFilter == s,
                    onSelected: (_) {
                      setState(() => _statusFilter = s);
                      _load();
                    },
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _requests.isEmpty
                      ? const Center(child: Text('No leave requests here.'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: _requests.length,
                          itemBuilder: (context, i) {
                            final r = _requests[i];
                            final Employee? emp = r['employee'];
                            final status = r['status'] as String;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(emp?.name ?? 'Unknown employee',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: _statusColorFor(status).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(status,
                                              style: TextStyle(
                                                  color: _statusColorFor(status),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${r['leave_type']} • ${r['from_date']} to ${r['to_date']}',
                                        style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                    if ((r['reason'] as String).isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('Reason: ${r['reason']}', style: const TextStyle(fontSize: 13)),
                                    ],
                                    const SizedBox(height: 4),
                                    Text('Applied by ${r['applied_by']} on '
                                        '${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(r['applied_at'] as String))}',
                                        style: const TextStyle(fontSize: 11, color: Colors.black45)),
                                    if (status != 'Pending' && r['decided_by'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text('$status by ${r['decided_by']}'
                                          '${(r['remarks'] as String).isNotEmpty ? ' — ${r['remarks']}' : ''}',
                                          style: const TextStyle(fontSize: 11, color: Colors.black45)),
                                    ],
                                    if (status == 'Pending') ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _decide(r, false),
                                              icon: const Icon(Icons.close, color: AppColors.danger),
                                              label: const Text('Reject', style: TextStyle(color: AppColors.danger)),
                                              style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(color: AppColors.danger)),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _decide(r, true),
                                              icon: const Icon(Icons.check),
                                              label: const Text('Approve'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
