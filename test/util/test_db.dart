import 'package:drift/native.dart';
import 'package:noteflow/data/local/database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Whether a usable sqlite3 native library is present on the current host.
///
/// `sqlite3_flutter_libs` bundles the native library for Android/iOS devices,
/// but desktop test runners (e.g. `flutter test` on Windows/Linux/macOS CI)
/// only have it when the OS or CI image provides `sqlite3`. Where it is
/// missing, database-backed tests are skipped with a clear reason instead of
/// failing, and still run in full on-device / on CI images that ship sqlite3.
final bool sqlite3Available = () {
  try {
    // Touching `version` forces the dynamic library to load.
    sqlite3.version;
    return true;
  } catch (_) {
    return false;
  }
}();

const String sqlite3MissingReason =
    'sqlite3 native library not available on this host; '
    'runs on-device and on CI images that ship sqlite3.';

/// Opens a fresh in-memory [AppDatabase] for a test.
AppDatabase openTestDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());
