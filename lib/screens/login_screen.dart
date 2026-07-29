import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/db_helper.dart';
import '../utils/constants.dart';
import '../utils/page_transitions.dart';
import '../utils/session.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late final AnimationController _animController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = await DBHelper.instance.login(_userCtrl.text.trim(), _passCtrl.text);

    if (!mounted) return;
    setState(() => _loading = false);

    if (user == null) {
      setState(() => _error = 'Invalid username or password.');
      return;
    }

    context.read<Session>().login(user['username'] as String, user['role'] as String);
    Navigator.pushReplacement(context, fadeSlideRoute(const DashboardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryLight],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.factory, size: 48, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        const Text('Offline Employee Attendance & Weekly Rest System',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 12)),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _userCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Username',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter username' : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passCtrl,
                                  obscureText: _obscure,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: _obscure ? 'Show password' : 'Hide password',
                                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _error == null
                                      ? const SizedBox(height: 0)
                                      : Padding(
                                          padding: const EdgeInsets.only(top: 12),
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: AppColors.danger.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(_error!,
                                                      style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 22),
                                ElevatedButton(
                                  onPressed: _loading ? null : _submit,
                                  child: _loading
                                      ? const SizedBox(
                                          height: 22, width: 22,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Text('LOGIN'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Default logins:\nAdmin → admin / admin123\nSupervisor → supervisor / super123',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
