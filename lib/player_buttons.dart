import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:campaniereis/events.dart';

const double playerIconSize = 24.0;
const TextStyle _style = TextStyle(fontFamily: "Comic Sans");

class PlayerButtons extends StatelessWidget {
  const PlayerButtons(this._audioPlayer, this.asset, this.lengthTrack,
      {Key? key})
      : super(key: key);

  final AudioPlayer _audioPlayer;

  final Duration lengthTrack;

  final String asset;

  @override
  Widget build(BuildContext context) {
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
          Text('${lengthTrack.inMinutes}:${lengthTrack.inSeconds % 60}',
              style: _style)
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
    return SliderTheme(
        data: SliderTheme.of(context),
        child: SizedBox(
            width: MediaQuery.of(context).size.width -
                3 * playerIconSize -
                _textSize(asset, _style).width -
                _textSize(
                        '${lengthTrack.inMinutes}:${lengthTrack.inSeconds % 60}',
                        _style)
                    .width -
                50.0,
            child: Slider(
                value: position.inMicroseconds / 1000000,
                max: lengthTrack.inMicroseconds / 1000000,
                onChanged: (value) => ButtonEvents.broadcast(ButtonAction(
                    ButtonActions.setTime,
                    asset,
                    Duration(microseconds: (value * 1000000).round()))))));
  }
}
