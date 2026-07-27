import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../db/db_helper.dart';
import '../utils/constants.dart';
import '../widgets/app_drawer.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _working = false;
  String? _message;

  Future<void> _backup() async {
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final path = await DBHelper.instance.prepareBackupFile();
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await Share.shareXFiles(
        [XFile(path)],
        text: 'RAMS Database Backup - $stamp',
      );
      setState(() => _message = 'Backup ready. Choose where to save it (Drive, USB, WhatsApp, etc).');
    } catch (e) {
      setState(() => _message = 'Backup failed: $e');
    } finally {
      // Reopens the database connection (it was closed to safely copy the file)
      await DBHelper.instance.database;
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
            'This will REPLACE all current data (employees, attendance, settings) with the '
            'contents of the backup file you choose. This cannot be undone. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: 'Select RAMS backup (.db) file',
    );
    if (result == null || result.files.single.path == null) return;

    setState(() {
      _working = true;
      _message = null;
    });
    try {
      await DBHelper.instance.restoreFromFile(result.files.single.path!);
      setState(() => _message = 'Restore complete. Please restart the app.');
    } catch (e) {
      setState(() => _message = 'Restore failed: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup / Restore')),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All your data lives only on this phone. Back it up regularly '
                        '(e.g. weekly) to Google Drive or another safe place in case the '
                        'phone is lost, damaged, or replaced.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _working ? null : _backup,
              icon: const Icon(Icons.backup),
              label: const Text('BACKUP DATABASE'),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _working ? null : _restore,
              icon: const Icon(Icons.restore, color: AppColors.danger),
              label: const Text('RESTORE FROM BACKUP', style: TextStyle(color: AppColors.danger)),
            ),
            if (_working) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_message != null) ...[
              const SizedBox(height: 20),
              Text(_message!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
