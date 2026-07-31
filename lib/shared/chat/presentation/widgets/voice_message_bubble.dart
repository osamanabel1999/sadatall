import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String url;
  final Color color;

  const VoiceMessageBubble({super.key, required this.url, required this.color});

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
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
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: widget.color, size: 32),
            onPressed: _toggle,
          ),
          Expanded(
            child: Slider(
              value: _position.inMilliseconds.clamp(0, _duration.inMilliseconds == 0 ? 1 : _duration.inMilliseconds).toDouble(),
              max: (_duration.inMilliseconds == 0 ? 1 : _duration.inMilliseconds).toDouble(),
              activeColor: widget.color,
              onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
            ),
          ),
          Text(_fmt(_duration - _position < Duration.zero ? Duration.zero : _duration - _position),
              style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
