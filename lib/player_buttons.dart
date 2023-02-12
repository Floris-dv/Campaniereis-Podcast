import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:campaniereis/events.dart';

const double playerIconSize = 24.0;

class PlayerButtons extends StatelessWidget {
  const PlayerButtons(this._audioPlayer, this.asset, {Key? key})
      : super(key: key);

  final AudioPlayer _audioPlayer;

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(asset),
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
          builder: (_, __) {
            return _nextButton();
          },
        ),
      ],
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
        onPressed: () => ButtonEvents.broadcast(
            ButtonAction(ButtonActions.previous, asset, Duration.zero)));
  }

  Widget _nextButton() {
    return IconButton(
        icon: const Icon(Icons.skip_next),
        onPressed: () => ButtonEvents.broadcast(
            ButtonAction(ButtonActions.skip, asset, Duration.zero)));
  }
}
