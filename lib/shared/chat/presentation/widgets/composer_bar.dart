import 'package:flutter/material.dart';

class ComposerBar extends StatefulWidget {
  final Color accentColor;
  final bool enabled;
  final ValueChanged<String> onSend;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onAttachTap;

  const ComposerBar({
    super.key,
    required this.accentColor,
    required this.onSend,
    this.enabled = true,
    this.onChanged,
    this.onAttachTap,
  });

  @override
  State<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<ComposerBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: Colors.grey[100],
        child: const Center(
          child: Text('انتهت المحادثة — لا يمكن إرسال رسائل جديدة', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.attach_file, color: widget.accentColor),
              onPressed: widget.onAttachTap,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: widget.onChanged,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة...',
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 4),
            CircleAvatar(
              backgroundColor: widget.accentColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
