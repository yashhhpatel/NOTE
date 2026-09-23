import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../data/local/database.dart';
import '../../domain/entities/enums.dart';
import '../../shared/utils/snackbars.dart';
import 'attachments_providers.dart';
import 'audio_recorder_dialog.dart';

/// Displays a note's attachments (images, files, audio) with add/delete.
/// Permissions are requested only when the user invokes each feature.
class AttachmentsSection extends ConsumerWidget {
  const AttachmentsSection({super.key, required this.noteId});
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachmentsAsync = ref.watch(attachmentsForNoteProvider(noteId));
    final attachments = attachmentsAsync.valueOrNull ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attachments.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in attachments)
                _AttachmentChip(
                  attachment: a,
                  onDelete: () => ref
                      .read(attachmentsRepositoryProvider)
                      .delete(a),
                ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.attach_file, size: 18),
            label: const Text('Attach'),
            onPressed: () => _showAddMenu(context, ref),
          ),
        ),
      ],
    );
  }

  void _showAddMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(context, ref, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose image'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(context, ref, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Attach file'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFile(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_none),
              title: const Text('Record audio'),
              onTap: () {
                Navigator.pop(sheetContext);
                _recordAudio(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(
      BuildContext context, WidgetRef ref, ImageSource source) async {
    try {
      final picked =
          await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      await ref.read(attachmentsRepositoryProvider).addFromPath(
            noteId: noteId,
            type: AttachmentType.image,
            sourcePath: picked.path,
          );
    } catch (_) {
      if (context.mounted) {
        showInfoSnackBar(context, 'Could not add image (permission denied?).');
      }
    }
  }

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    try {
      final file = await openFile();
      if (file == null) return;
      await ref.read(attachmentsRepositoryProvider).addFromPath(
            noteId: noteId,
            type: AttachmentType.file,
            sourcePath: file.path,
          );
    } catch (_) {
      if (context.mounted) showInfoSnackBar(context, 'Could not attach file.');
    }
  }

  Future<void> _recordAudio(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(attachmentsRepositoryProvider);
    final path = await repo.newFilePath('.m4a');
    if (!context.mounted) return;
    final recorded = await showAudioRecorderDialog(context, targetPath: path);
    if (recorded == null) return;
    await repo.register(
      noteId: noteId,
      type: AttachmentType.audio,
      storedPath: recorded,
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment, required this.onDelete});
  final Attachment attachment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    switch (attachment.type) {
      case AttachmentType.image:
      case AttachmentType.drawing:
        return _ImageThumb(attachment: attachment, onDelete: onDelete);
      case AttachmentType.audio:
        return _AudioTile(attachment: attachment, onDelete: onDelete);
      case AttachmentType.file:
        return _FileChip(attachment: attachment, onDelete: onDelete);
    }
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.attachment, required this.onDelete});
  final Attachment attachment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => OpenFilex.open(attachment.path),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(attachment.path),
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _MissingFile(),
            ),
          ),
        ),
        _DeleteBadge(onDelete: onDelete),
      ],
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.attachment, required this.onDelete});
  final Attachment attachment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: const Icon(Icons.insert_drive_file_outlined, size: 18),
      label: Text(
        p.basename(attachment.path),
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: () => OpenFilex.open(attachment.path),
      onDeleted: onDelete,
    );
  }
}

class _AudioTile extends StatefulWidget {
  const _AudioTile({required this.attachment, required this.onDelete});
  final Attachment attachment;
  final VoidCallback onDelete;

  @override
  State<_AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<_AudioTile> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _player.play(DeviceFileSource(widget.attachment.path));
      setState(() => _playing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 18),
      label: const Text('Audio'),
      onPressed: _toggle,
      onDeleted: widget.onDelete,
    );
  }
}

class _DeleteBadge extends StatelessWidget {
  const _DeleteBadge({required this.onDelete});
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 2,
      right: 2,
      child: GestureDetector(
        onTap: onDelete,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(2),
          child: const Icon(Icons.close, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

class _MissingFile extends StatelessWidget {
  const _MissingFile();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}
