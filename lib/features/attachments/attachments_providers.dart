import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/local/database.dart';
import '../../data/repositories/attachments_repository.dart';

final attachmentsRepositoryProvider = Provider<AttachmentsRepository>((ref) {
  return AttachmentsRepository(ref.watch(databaseProvider));
});

final attachmentsForNoteProvider =
    StreamProvider.autoDispose.family<List<Attachment>, String>((ref, noteId) {
  return ref.watch(attachmentsRepositoryProvider).watchForNote(noteId);
});
