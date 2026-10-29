import 'dart:async';

import 'package:flutter/material.dart';

import 'media_controller.dart';
import 'media_models.dart';

class MediaPanel extends StatelessWidget {
  const MediaPanel({
    super.key,
    this.controller,
    this.onOpen,
    this.fontScale = 1,
  });
  final MediaController? controller;
  final VoidCallback? onOpen;
  final double fontScale;
  @override
  Widget build(BuildContext context) => controller == null
      ? content(context, const MediaSnapshot())
      : ListenableBuilder(
          listenable: controller!,
          builder: (context, _) => content(context, controller!.state),
        );
  Widget content(BuildContext context, MediaSnapshot state) => LayoutBuilder(
    builder: (context, bounds) {
      if (bounds.maxHeight < 60) {
        return Padding(
          padding: const EdgeInsets.all(4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: MediaControls(controller: controller, state: state),
          ),
        );
      }
      final factor = fontScale.clamp(.8, 1.6);
      final titleSize = (18 * factor).clamp(16.0, 28.8);
      final artistSize = (16 * factor).clamp(16.0, 25.6);
      final scaler = MediaQuery.textScalerOf(context);
      final titleHeight = scaler.scale(titleSize) * 1.2;
      final artistHeight = scaler.scale(artistSize) * 1.2;
      final title = bounds.maxHeight >= 8 + 52 + titleHeight;
      final tall =
          bounds.maxHeight >=
          12 + 52 + titleHeight + artistHeight + 24 + scaler.scale(16) * 1.5;
      final art = tall && bounds.maxHeight >= 230
          ? controller?.artwork ?? state.artwork
          : null;
      return Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (title)
              InkWell(
                onTap: onOpen,
                child: Row(
                  children: [
                    if (art != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Image.memory(
                          art,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.music_note),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: titleSize,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (tall)
                            Text(
                              state.displayArtist.isEmpty
                                  ? state.app
                                  : state.displayArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: artistSize,
                                height: 1.2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            MediaControls(controller: controller, state: state),
            if (tall) MediaProgress(controller: controller, state: state),
          ],
        ),
      );
    },
  );
}

class MediaControls extends StatelessWidget {
  const MediaControls({
    super.key,
    required this.controller,
    required this.state,
  });
  final MediaController? controller;
  final MediaSnapshot state;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Bài trước',
          icon: const Icon(Icons.skip_previous),
          onPressed: controller != null && state.canPrevious
              ? () => unawaited(controller!.command('previous'))
              : null,
        ),
        IconButton(
          tooltip: state.isPlaying ? 'Tạm dừng' : 'Phát',
          icon: Icon(
            state.isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_fill,
          ),
          iconSize: 36,
          onPressed: controller != null && state.canPlay
              ? () => unawaited(
                  controller!.command(state.isPlaying ? 'pause' : 'play'),
                )
              : null,
        ),
        IconButton(
          tooltip: 'Bài tiếp',
          icon: const Icon(Icons.skip_next),
          onPressed: controller != null && state.canNext
              ? () => unawaited(controller!.command('next'))
              : null,
        ),
      ],
    ),
  );
}

class MediaProgress extends StatefulWidget {
  const MediaProgress({
    super.key,
    required this.controller,
    required this.state,
  });
  final MediaController? controller;
  final MediaSnapshot state;
  @override
  State<MediaProgress> createState() => _MediaProgressState();
}

class _MediaProgressState extends State<MediaProgress> {
  double? drag;
  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final duration = s.durationMs.clamp(1, 864000000).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          child: Slider(
            value: (drag ?? s.positionMs.toDouble()).clamp(0, duration),
            max: duration,
            onChanged: widget.controller != null && s.canSeek
                ? (v) => setState(() => drag = v)
                : null,
            onChangeEnd: widget.controller != null && s.canSeek
                ? (v) {
                    unawaited(widget.controller!.command('seek', v.round()));
                    setState(() => drag = null);
                  }
                : null,
          ),
        ),
        Text(
          '${mediaTime(s.positionMs)} / ${mediaTime(s.durationMs)}',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
