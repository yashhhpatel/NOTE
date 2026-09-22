import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:noteflow/data/local/database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

/// Whether a usable sqlite3 native library is present for the test run.
///
/// `sqlite3_flutter_libs` bundles the native library for Android/iOS devices,
/// but desktop test runners only have it when the OS/CI image provides it. To
/// keep database-backed tests runnable on developer machines, a locally cached
/// `sqlite3` library (see below) is loaded when present. Where none is found,
/// database tests skip with a clear reason instead of failing.
final bool sqlite3Available = _detect();

const String sqlite3MissingReason =
    'sqlite3 native library not available on this host; '
    'runs on-device, on CI images that ship sqlite3, and when a local library '
    'is cached under .dart_tool/sqlite3/.';

bool _detect() {
  _registerLocalLibraryIfPresent();
  try {
    sqlite3.version; // Forces the dynamic library to load.
    return true;
  } catch (_) {
    return false;
  }
}

/// If a developer has cached a platform sqlite3 library under
/// `.dart_tool/sqlite3/`, register it so `flutter test` can open databases
/// without a system-wide install. Silently ignored when absent.
void _registerLocalLibraryIfPresent() {
  final root = _projectRoot();
  final candidates = <OperatingSystem, String>{
    OperatingSystem.windows: 'sqlite3.dll',
    OperatingSystem.linux: 'libsqlite3.so',
    OperatingSystem.macOS: 'libsqlite3.dylib',
  };
  for (final entry in candidates.entries) {
    final file = File(p.join(root, '.dart_tool', 'sqlite3', entry.value));
    if (file.existsSync()) {
      open.overrideFor(
        entry.key,
        () => DynamicLibrary.open(file.absolute.path),
      );
    }
  }
}

/// Walks up from the test's working directory to the package root
/// (the directory containing pubspec.yaml).
String _projectRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current.path;
}

/// Opens a fresh in-memory [AppDatabase] for a test.
AppDatabase openTestDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());
