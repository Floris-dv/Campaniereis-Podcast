import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:campaniereis/events.dart';

const double playerIconSize = 24.0;
const TextStyle _style = TextStyle(fontFamily: "Comic Sans");

const int phoneScreenWidth = 500;

// ignore: must_be_immutable
class PlayerButtons extends StatelessWidget {
  PlayerButtons(this._audioPlayer, this.asset, Duration length, {Key? key})
      : microSeconds = length.inMicroseconds,
        super(key: key) {
    dynamic seconds = length.inSeconds % 60;
    if (seconds < 10) seconds = '0$seconds';
    lengthTrack = '${length.inMinutes}:$seconds';
  }

  final AudioPlayer _audioPlayer;

  late String lengthTrack;

  final int microSeconds;

  final String asset;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width < phoneScreenWidth) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Text(
                  asset,
                  style: _style,
                ),
                StreamBuilder<SequenceState?>(
                  stream: _audioPlayer.sequenceStateStream,
                  builder: (_, __) => _previousButton(),
                ),
                StreamBuilder<PlayerState>(
                  stream: _audioPlayer.playerStateStream,
                  builder: (_, snapshot) {
                    final PlayerState? playerState = snapshot.data;
                    return _playerPauseButton(playerState);
                  },
                ),
                StreamBuilder<SequenceState?>(
                  stream: _audioPlayer.sequenceStateStream,
                  builder: (_, __) => _nextButton(),
                ),
              ],
            ),
            Center(
              child: Row(
                children: [
                  StreamBuilder<Duration>(
                      stream: _audioPlayer.positionStream,
                      builder: (context, snapshot) =>
                          _slider(context, snapshot.data ?? Duration.zero)),
                  Text(lengthTrack, style: _style)
                ],
              ),
            )
          ],
        ),
      );
    }
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            asset,
            style: _style,
          ),
          StreamBuilder<Duration>(
              stream: _audioPlayer.positionStream,
              builder: (context, snapshot) =>
                  _slider(context, snapshot.data ?? Duration.zero)),
          StreamBuilder<SequenceState?>(
            stream: _audioPlayer.sequenceStateStream,
            builder: (_, __) => _previousButton(),
          ),
          StreamBuilder<PlayerState>(
            stream: _audioPlayer.playerStateStream,
            builder: (_, snapshot) {
              final PlayerState? playerState = snapshot.data;
              return _playerPauseButton(playerState);
            },
          ),
          StreamBuilder<SequenceState?>(
            stream: _audioPlayer.sequenceStateStream,
            builder: (_, __) => _nextButton(),
          ),
          Text(lengthTrack, style: _style)
        ],
      ),
    );
  }

  Widget _playerPauseButton(PlayerState? playerState) {
    final processingState = playerState?.processingState;
    if (processingState == ProcessingState.loading ||
        processingState == ProcessingState.buffering) {
      return Container(
        margin: const EdgeInsets.all(8.0),
        width: playerIconSize,
        height: playerIconSize,
        child: const CircularProgressIndicator(),
      );
    } else if (_audioPlayer.playing != true) {
      return IconButton(
          icon: const Icon(Icons.play_arrow),
          iconSize: playerIconSize,
          onPressed: () => ButtonEvents.broadcast(ButtonAction(
              ButtonActions.pauseButtonPressed, asset, _audioPlayer.position)));
    } else if (processingState != ProcessingState.completed) {
      return IconButton(
          icon: const Icon(Icons.pause),
          iconSize: playerIconSize,
          onPressed: () => ButtonEvents.broadcast(ButtonAction(
              ButtonActions.pauseButtonPressed, asset, _audioPlayer.position)));
    } else {
      return IconButton(
        icon: const Icon(Icons.replay),
        iconSize: playerIconSize,
        onPressed: () => _audioPlayer.seek(Duration.zero,
            index: _audioPlayer.effectiveIndices?.first),
      );
    }
  }

  Widget _previousButton() {
    return IconButton(
        icon: const Icon(Icons.skip_previous),
        iconSize: playerIconSize,
        onPressed: () => ButtonEvents.broadcast(
            ButtonAction(ButtonActions.previous, asset, Duration.zero)));
  }

  Widget _nextButton() {
    return IconButton(
        icon: const Icon(Icons.skip_next),
        iconSize: playerIconSize,
        onPressed: () => ButtonEvents.broadcast(
            ButtonAction(ButtonActions.skip, asset, Duration.zero)));
  }

  Size _textSize(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  Widget _slider(BuildContext context, Duration position) {
    double width = MediaQuery.of(context).size.width;
    if (width < phoneScreenWidth) {
      width -= _textSize(lengthTrack, _style).width;
    } else {
      width -= 3 * playerIconSize +
          _textSize(asset, _style).width +
          _textSize(lengthTrack, _style).width +
          70.0;
    }
    return SliderTheme(
        data: SliderTheme.of(context),
        child: SizedBox(
            width: width,
            child: Slider(
                value: position.inMicroseconds / 1000000,
                max: microSeconds / 1000000,
                onChanged: (value) => ButtonEvents.broadcast(ButtonAction(
                    ButtonActions.setTime,
                    asset,
                    Duration(microseconds: (value * 1000000).round()))))));
  }
}
