import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import '../config.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/avatar.dart';
import '../widgets/audio_message_player.dart';

class ChatScreen extends StatefulWidget {
  final ChatModel chat;
  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = AudioRecorder();
  final _picker = ImagePicker();
  bool _recording = false;
  String? _audioPath;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTyping);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadMessages(widget.chat.id);
    });
  }

  void _onTyping() {
    final state = context.read<AppState>();
    if (_controller.text.isNotEmpty) {
      state.socket.typingStart(widget.chat.id);
    } else {
      state.socket.typingStop(widget.chat.id);
    }
  }

  @override
  void dispose() {
    context.read<AppState>().socket.typingStop(widget.chat.id);
    _controller.dispose();
    _scroll.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final messages = state.messagesByChat[widget.chat.id] ?? [];
    final isTyping = state.isTypingInChat(widget.chat.id);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            AvatarWidget(
              url: widget.chat.otherUser.avatarUrl,
              radius: 18,
              fallbackLetter: widget.chat.otherUser.username,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.chat.otherUser.username),
                if (isTyping)
                  Text('typing...', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, i) => _MessageBubble(
                message: messages[i],
                onEdit: (m) => _editMessage(m),
                onDelete: (m) => state.deleteMessage(m.id),
                onRetry: (m) => _retryMessage(state, m),
                onVisible: (m) {
                  if (m.isLocal) return;
                  if (!m.isMine && m.status != 'read') {
                    state.markRead(m.id);
                  }
                },
              ),
            ),
          ),
          _inputBar(state),
        ],
      ),
    );
  }

  String _formatRecordDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _inputBar(AppState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_recording)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatRecordDuration(_recordDuration),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.red,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
              ),
            Row(
          children: [
            IconButton(
              icon: Icon(_recording ? Icons.stop_circle : Icons.mic),
              color: _recording ? Colors.red : null,
              onPressed: _toggleRecording,
            ),
            IconButton(icon: const Icon(Icons.image), onPressed: () => _pickMedia(state, true)),
            IconButton(icon: const Icon(Icons.videocam), onPressed: () => _pickMedia(state, false)),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onSubmitted: (t) => _sendText(state, t),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => _sendText(state, _controller.text),
            ),
          ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retryMessage(AppState state, MessageModel m) async {
    try {
      await state.retryMessage(m.id);
      _scrollToEnd();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _sendText(AppState state, String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();
    state.socket.typingStop(widget.chat.id);
    try {
      await state.sendText(widget.chat.id, text.trim());
      _scrollToEnd();
    } catch (_) {
      _scrollToEnd();
    }
  }

  Future<void> _pickMedia(AppState state, bool image) async {
    if (image) {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (file == null) return;
      var bytes = await FlutterImageCompress.compressWithFile(file.path, quality: 70) ??
          await file.readAsBytes();
      if (bytes.length > 20 * 1024 * 1024 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File exceeds 20MB limit')),
        );
        return;
      }
      try {
        await state.sendMedia(widget.chat.id, bytes, file.name, 'image');
        _scrollToEnd();
      } catch (_) {
        _scrollToEnd();
      }
    } else {
      final picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 20 * 1024 * 1024 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File exceeds 20MB limit')),
        );
        return;
      }
      try {
        await state.sendMedia(widget.chat.id, bytes, picked.name, 'video');
        _scrollToEnd();
      } catch (_) {
        _scrollToEnd();
      }
    }
  }

  Future<void> _toggleRecording() async {
    final state = context.read<AppState>();
    if (_recording) {
      _recordTimer?.cancel();
      _recordTimer = null;
      final path = await _recorder.stop();
      setState(() {
        _recording = false;
        _recordDuration = Duration.zero;
      });
      if (path != null) {
        final bytes = await File(path).readAsBytes();
        try {
          await state.sendMedia(widget.chat.id, bytes, 'audio.m4a', 'audio');
          _scrollToEnd();
        } catch (_) {
          _scrollToEnd();
        }
      }
    } else {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _audioPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(), path: _audioPath!);
        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _recordDuration += const Duration(seconds: 1));
          }
        });
        setState(() {
          _recording = true;
          _recordDuration = Duration.zero;
        });
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _editMessage(MessageModel m) {
    final ctrl = TextEditingController(text: m.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: ctrl, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<AppState>().editMessage(m.id, ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final MessageModel message;
  final void Function(MessageModel) onEdit;
  final void Function(MessageModel) onDelete;
  final void Function(MessageModel) onRetry;
  final void Function(MessageModel) onVisible;

  const _MessageBubble({
    required this.message,
    required this.onEdit,
    required this.onDelete,
    required this.onRetry,
    required this.onVisible,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onVisible(widget.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final align = m.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final isFailed = m.status == 'failed';
    final color = isFailed
        ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5)
        : m.isMine
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest;

    return Align(
      alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: m.isMine && !m.deleted && !m.isLocal
            ? () => showModalBottomSheet(
                  context: context,
                  builder: (ctx) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (m.type == 'text')
                        ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text('Edit'),
                          onTap: () {
                            Navigator.pop(ctx);
                            widget.onEdit(m);
                          },
                        ),
                      ListTile(
                        leading: const Icon(Icons.delete),
                        title: const Text('Delete'),
                        onTap: () {
                          Navigator.pop(ctx);
                          widget.onDelete(m);
                        },
                      ),
                    ],
                  ),
                )
            : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: isFailed
                ? Border.all(color: Theme.of(context).colorScheme.error, width: 1)
                : null,
          ),
          child: Column(
            crossAxisAlignment: align,
            children: [
              if (m.deleted)
                const Text('Message deleted', style: TextStyle(fontStyle: FontStyle.italic))
              else if (m.type == 'text')
                Text(m.content ?? '',
                    style: m.edited ? const TextStyle(fontStyle: FontStyle.italic) : null)
              else if (m.type == 'image')
                m.mediaUrl != null
                    ? Image.network(AppConfig.mediaUrl(m.mediaUrl!), height: 180, fit: BoxFit.cover)
                    : _MediaPlaceholder(label: m.content ?? 'Photo', icon: Icons.image)
              else if (m.type == 'video')
                m.mediaUrl != null
                    ? _VideoPreview(url: AppConfig.mediaUrl(m.mediaUrl!))
                    : _MediaPlaceholder(label: m.content ?? 'Video', icon: Icons.videocam)
              else if (m.type == 'audio')
                m.mediaUrl != null
                    ? AudioMessagePlayer(
                        url: AppConfig.mediaUrl(m.mediaUrl!),
                        isMine: m.isMine,
                      )
                    : _MediaPlaceholder(label: m.content ?? 'Voice message', icon: Icons.mic),
              if (isFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 16, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 4),
                      Text(
                        'Not delivered',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => widget.onRetry(m),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: () => widget.onDelete(m),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ),
              if (m.isMine) _StatusIcon(status: m.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final String status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'sending') {
      return const Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (status == 'failed') {
      return Align(
        alignment: Alignment.centerRight,
        child: Icon(Icons.error_outline, size: 14, color: Theme.of(context).colorScheme.error),
      );
    }

    IconData icon;
    Color? color;
    switch (status) {
      case 'read':
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      case 'delivered':
        icon = Icons.done_all;
        break;
      case 'sent':
        icon = Icons.check;
        break;
      default:
        icon = Icons.schedule;
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Icon(icon, size: 14, color: color),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MediaPlaceholder({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final String url;
  const _VideoPreview({required this.url});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl == null || !_ctrl!.value.isInitialized) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }
    return AspectRatio(
      aspectRatio: _ctrl!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_ctrl!),
          IconButton(
            icon: Icon(_ctrl!.value.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play();
              });
            },
          ),
        ],
      ),
    );
  }
}

