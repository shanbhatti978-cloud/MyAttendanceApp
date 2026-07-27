import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../utils/constants.dart';
import '../utils/session.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _companyNameCtrl = TextEditingController();
  final _companyAddressCtrl = TextEditingController();
  final _companyPhoneCtrl = TextEditingController();
  bool _loading = true;
  bool _savingCompany = false;

  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _passFormKey = GlobalKey<FormState>();
  bool _changingPassword = false;
  String? _passMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await DBHelper.instance.getSetting('company_name', fallback: 'My Company');
    final address = await DBHelper.instance.getSetting('company_address');
    final phone = await DBHelper.instance.getSetting('company_phone');
    setState(() {
      _companyNameCtrl.text = name;
      _companyAddressCtrl.text = address;
      _companyPhoneCtrl.text = phone;
      _loading = false;
    });
  }

  Future<void> _saveCompany() async {
    setState(() => _savingCompany = true);
    await DBHelper.instance.setSetting('company_name', _companyNameCtrl.text.trim());
    await DBHelper.instance.setSetting('company_address', _companyAddressCtrl.text.trim());
    await DBHelper.instance.setSetting('company_phone', _companyPhoneCtrl.text.trim());
    setState(() => _savingCompany = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company information saved.')));
  }

  Future<void> _changePassword() async {
    if (!_passFormKey.currentState!.validate()) return;
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      setState(() => _passMessage = 'New password and confirmation do not match.');
      return;
    }
    setState(() {
      _changingPassword = true;
      _passMessage = null;
    });

    final session = context.read<Session>();
    final ok = await DBHelper.instance.changePassword(
      session.username!,
      _oldPassCtrl.text,
      _newPassCtrl.text,
    );

    setState(() {
      _changingPassword = false;
      _passMessage = ok ? 'Password changed successfully.' : 'Current password is incorrect.';
    });
    if (ok) {
      _oldPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      drawer: const AppDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Company Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _companyNameCtrl,
                  decoration: const InputDecoration(labelText: 'Company Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _companyAddressCtrl,
                  decoration: const InputDecoration(labelText: 'Address'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _companyPhoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _savingCompany ? null : _saveCompany,
                  child: _savingCompany
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('SAVE COMPANY INFO'),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Form(
                  key: _passFormKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _oldPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Current Password'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'New Password'),
                        validator: (v) => (v == null || v.length < 4) ? 'Minimum 4 characters' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Confirm New Password'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      if (_passMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(_passMessage!,
                            style: TextStyle(
                                color: _passMessage!.contains('success') ? AppColors.success : AppColors.danger)),
                      ],
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _changingPassword ? null : _changePassword,
                        child: _changingPassword
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('CHANGE PASSWORD'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
