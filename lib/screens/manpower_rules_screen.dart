import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../utils/constants.dart';
import '../utils/session.dart';
import '../widgets/access_guard.dart';
import '../widgets/app_drawer.dart';

/// Admin-only screen for defining minimum/maximum manpower requirements
/// per designation (e.g. "Sizing Operator: min 4, max 6"). These rules
/// power the shortage alerts shown on the Shift Planning report.
class ManpowerRulesScreen extends StatefulWidget {
  const ManpowerRulesScreen({super.key});

  @override
  State<ManpowerRulesScreen> createState() => _ManpowerRulesScreenState();
}

class _ManpowerRulesScreenState extends State<ManpowerRulesScreen> {
  List<Map<String, dynamic>> _rules = [];
  List<String> _designations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rules = await DBHelper.instance.getManpowerRules();
    final designations = await DBHelper.instance.getDistinctDesignations();
    setState(() {
      _rules = rules;
      _designations = designations;
      _loading = false;
    });
  }

  Future<void> _showRuleDialog({Map<String, dynamic>? existing}) async {
    String? designation = existing?['designation'] as String?;
    final minCtrl = TextEditingController(text: existing != null ? '${existing['min_required']}' : '0');
    final maxCtrl = TextEditingController(text: existing != null ? '${existing['max_required']}' : '0');
    final formKey = GlobalKey<FormState>();

    final availableDesignations = existing != null
        ? [existing['designation'] as String]
        : _designations.where((d) => !_rules.any((r) => r['designation'] == d)).toList();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit Rule' : 'Add Manpower Rule'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existing == null)
                  DropdownButtonFormField<String>(
                    initialValue: designation,
                    decoration: const InputDecoration(labelText: 'Designation'),
                    items: availableDesignations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setDialogState(() => designation = v),
                    validator: (v) => v == null ? 'Required' : null,
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Designation'),
                    child: Text(designation ?? ''),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minimum Required'),
                  validator: (v) => (v == null || int.tryParse(v) == null) ? 'Enter a number' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Maximum Required'),
                  validator: (v) => (v == null || int.tryParse(v) == null) ? 'Enter a number' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate() || designation == null) return;
                await DBHelper.instance.setManpowerRule(
                  designation!,
                  int.parse(minCtrl.text),
                  int.parse(maxCtrl.text),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    _load();
  }

  Future<void> _delete(String designation) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Rule'),
        content: Text('Remove the manpower rule for "$designation"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DBHelper.instance.deleteManpowerRule(designation);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<Session>().permissions.isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('Manpower Rules')),
      drawer: const AppDrawer(),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add Rule'),
              onPressed: () => _showRuleDialog(),
            )
          : null,
      body: AccessGuard(
        allowed: isAdmin,
        message: 'Manpower rules are managed by Admin accounts only.',
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _rules.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No manpower rules set yet. Tap "Add Rule" to define minimum/maximum staffing per designation.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90, top: 8),
                    itemCount: _rules.length,
                    itemBuilder: (context, i) {
                      final r = _rules[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.groups, color: AppColors.primary),
                          title: Text(r['designation'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('Min: ${r['min_required']}   Max: ${r['max_required']}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _showRuleDialog(existing: r);
                              if (v == 'delete') _delete(r['designation'] as String);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
