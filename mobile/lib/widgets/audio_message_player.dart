import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioMessagePlayer extends StatefulWidget {
  final String url;
  final bool isMine;

  const AudioMessagePlayer({super.key, required this.url, required this.isMine});

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  final _player = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _loaded = false;
  late final List<double> _waveform;

  @override
  void initState() {
    super.initState();
    _waveform = _generateWaveform(widget.url, 28);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _player.setSource(UrlSource(widget.url));
    final duration = await _player.getDuration();
    if (!mounted) return;
    setState(() {
      _duration = duration ?? Duration.zero;
      _loaded = true;
    });

    _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _player.onDurationChanged.listen((duration) {
      if (mounted && duration > Duration.zero) {
        setState(() => _duration = duration);
      }
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  List<double> _generateWaveform(String seed, int count) {
    final hash = seed.hashCode;
    return List.generate(count, (i) => 0.2 + ((hash + i * 31) % 80) / 100);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Duration get _displayDuration {
    if (_playing || _position > Duration.zero) return _position;
    return _duration;
  }

  double get _progress {
    if (_duration.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    if (_position == Duration.zero || _position >= _duration) {
      await _player.play(UrlSource(widget.url));
    } else {
      await _player.resume();
    }
    if (mounted) setState(() => _playing = true);
  }

  Future<void> _seekTo(double fraction) async {
    if (_duration == Duration.zero) return;
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * fraction).round(),
    );
    await _player.seek(target);
    if (mounted) setState(() => _position = target);
    if (!_playing) await _togglePlay();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.isMine ? scheme.onPrimaryContainer : scheme.primary;
    final barActive = accent;
    final barInactive = accent.withValues(alpha: 0.35);
    final playBg = widget.isMine ? scheme.primary : scheme.primaryContainer;
    final playIcon = widget.isMine ? scheme.onPrimary : scheme.onPrimaryContainer;

    return SizedBox(
      width: 240,
      child: Row(
        children: [
          Material(
            color: playBg,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _loaded ? _togglePlay : null,
              child: SizedBox(
                width: 40,
                height: 40,
                child: _loaded
                    ? Icon(
                        _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: playIcon,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2, color: playIcon),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (waveContext) => GestureDetector(
                    onTapDown: (details) {
                      final box = waveContext.findRenderObject() as RenderBox?;
                      if (box == null) return;
                      _seekTo((details.localPosition.dx / box.size.width).clamp(0.0, 1.0));
                    },
                    child: SizedBox(
                      height: 28,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _WaveformPainter(
                          heights: _waveform,
                          progress: _progress,
                          activeColor: barActive,
                          inactiveColor: barInactive,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _loaded ? _formatDuration(_displayDuration) : '--:--',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: accent.withValues(alpha: 0.85),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> heights;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _WaveformPainter({
    required this.heights,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty) return;
    final barWidth = size.width / heights.length;
    final gap = barWidth * 0.35;
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < heights.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final barH = heights[i] * size.height;
      final y1 = (size.height - barH) / 2;
      final y2 = y1 + barH;
      final played = (i + 1) / heights.length <= progress;
      paint.color = played ? activeColor : inactiveColor;
      paint.strokeWidth = barWidth - gap;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }

    if (progress > 0 && progress < 1) {
      final dotX = progress * size.width;
      final dotPaint = Paint()..color = activeColor;
      canvas.drawCircle(Offset(dotX, size.height / 2), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor;
}
