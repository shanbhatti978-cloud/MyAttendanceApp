import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../utils/constants.dart';
import '../utils/session.dart';
import '../widgets/access_guard.dart';
import '../widgets/app_drawer.dart';

/// Admin-only screen for managing user accounts: create new users,
/// change roles, reset passwords, and remove accounts. Protected both
/// by hiding its entry point in Settings for non-Admins, and by this
/// screen's own AccessGuard as a second line of defense.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final users = await DBHelper.instance.getUsers();
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  Future<void> _showAddUserDialog() async {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String role = AppConstants.roleViewer;
    String? error;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add User'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) => (v == null || v.length < 4) ? 'Minimum 4 characters' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: AppConstants.allRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setDialogState(() => role = v!),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final result = await DBHelper.instance.createUser(usernameCtrl.text.trim(), passwordCtrl.text, role);
                if (result != null) {
                  setDialogState(() => error = result);
                } else if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    _load();
  }

  Future<void> _showChangeRoleDialog(Map<String, dynamic> user) async {
    String role = user['role'] as String;
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Change Role — ${user['username']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: AppConstants.allRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setDialogState(() => role = v!),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final result = await DBHelper.instance.updateUserRole(user['id'] as int, role);
                if (result != null) {
                  setDialogState(() => error = result);
                } else if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    _load();
  }

  Future<void> _showResetPasswordDialog(Map<String, dynamic> user) async {
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reset Password — ${user['username']}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New Password'),
            validator: (v) => (v == null || v.length < 4) ? 'Minimum 4 characters' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await DBHelper.instance.resetUserPassword(user['id'] as int, passwordCtrl.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    final session = context.read<Session>();
    if (user['username'] == session.username) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('You cannot delete your own currently logged-in account.')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete user "${user['username']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final result = await DBHelper.instance.deleteUser(user['id'] as int);
    if (!mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    } else {
      _load();
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case AppConstants.roleAdmin:
        return AppColors.primary;
      case AppConstants.roleSupervisor:
        return AppColors.accent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<Session>().permissions.isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      drawer: const AppDrawer(),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add),
              label: const Text('Add User'),
              onPressed: _showAddUserDialog,
            )
          : null,
      body: AccessGuard(
        allowed: isAdmin,
        message: 'User management is restricted to Admin accounts.',
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90, top: 8),
                  itemCount: _users.length,
                  itemBuilder: (context, i) {
                    final user = _users[i];
                    final role = user['role'] as String;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _roleColor(role).withValues(alpha: 0.12),
                          child: Icon(Icons.person, color: _roleColor(role)),
                        ),
                        title: Text(user['username'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _roleColor(role).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(role,
                              style: TextStyle(color: _roleColor(role), fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'More actions',
                          onSelected: (v) {
                            if (v == 'role') _showChangeRoleDialog(user);
                            if (v == 'password') _showResetPasswordDialog(user);
                            if (v == 'delete') _confirmDelete(user);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'role', child: Text('Change Role')),
                            PopupMenuItem(value: 'password', child: Text('Reset Password')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
