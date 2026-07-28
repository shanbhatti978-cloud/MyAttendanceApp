package com.reliance.rams

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (instead of plain FlutterActivity) is required
// by the local_auth plugin so it can display the native Android
// fingerprint/face biometric prompt. All actual app logic (Login,
// Dashboard, Employee Master, Attendance, Reports, Backup, Settings)
// still lives in the Dart code under lib/.
class MainActivity : FlutterFragmentActivity()
