import 'package:flutter/material.dart';

enum ChatAttachmentChoice { camera, gallery, voice, location }

Future<ChatAttachmentChoice?> showChatAttachmentSheet(BuildContext context, {required Color accentColor}) {
  return showModalBottomSheet<ChatAttachmentChoice>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: Icon(Icons.camera_alt, color: accentColor),
            title: const Text('التقاط صورة'),
            onTap: () => Navigator.pop(ctx, ChatAttachmentChoice.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library, color: accentColor),
            title: const Text('اختيار من المعرض'),
            onTap: () => Navigator.pop(ctx, ChatAttachmentChoice.gallery),
          ),
          ListTile(
            leading: Icon(Icons.mic, color: accentColor),
            title: const Text('رسالة صوتية'),
            onTap: () => Navigator.pop(ctx, ChatAttachmentChoice.voice),
          ),
          ListTile(
            leading: Icon(Icons.location_on, color: accentColor),
            title: const Text('مشاركة الموقع'),
            onTap: () => Navigator.pop(ctx, ChatAttachmentChoice.location),
          ),
        ],
      ),
    ),
  );
}
