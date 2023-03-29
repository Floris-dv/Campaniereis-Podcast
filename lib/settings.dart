import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:campaniereis/events.dart';

class SettingsWidget extends StatelessWidget {
  final AudioPlayer _audioPlayer;

  final controller = StreamController<bool>();

  SettingsWidget(this._audioPlayer, bool _autoPause, {super.key}) {
    controller.add(_autoPause);
  }

  Widget _speedWidget(BuildContext context, double? speed) {
    if (speed == null) return const SizedBox.shrink();
    return Row(children: [
      const Text('Snelheid'),
      SizedBox(
        width: MediaQuery.of(context).size.width - 120.0,
        child: Slider(
          value: speed,
          min: 0.5,
          max: 2.0,
          onChanged: (speed) => _audioPlayer.setSpeed(speed),
        ),
      )
    ]);
  }

  Widget _volumeWidget(BuildContext context, double? volume) {
    if (volume == null) return const SizedBox.shrink();
    return Row(children: [
      const Text('Volume'),
      SizedBox(
        width: MediaQuery.of(context).size.width - 115.0,
        child: Slider(
          value: volume,
          onChanged: (volume) => _audioPlayer.setVolume(volume),
        ),
      )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      StreamBuilder(
          stream: _audioPlayer.speedStream,
          builder: (context, snapshot) => _speedWidget(context, snapshot.data)),
      StreamBuilder(
          stream: _audioPlayer.volumeStream,
          builder: (context, snapshot) =>
              _volumeWidget(context, snapshot.data)),
      Row(children: [
        const Tooltip(
            message:
                "Met auto pauzeer wordt de volgende podcast in de lijst automatisch gepauzeerd wanneer het begint",
            child: Text("Auto pauzeer")),
        StreamBuilder(
          builder: (_, snapshot) {
            if (snapshot.data == null) return const SizedBox.shrink();
            return Switch(
              value: snapshot.data!,
              onChanged: (value) {
                ButtonEvents.broadcast(ButtonAction(ButtonActions.setAutoPause,
                    value ? "true" : "false", Duration.zero));
                controller.add(value);
              },
            );
          },
          stream: controller.stream,
        )
      ]),
      TextButton(
        onPressed: () {
          _audioPlayer.setVolume(1.0);
          _audioPlayer.setSpeed(1.0);
          controller.add(true);
          ButtonEvents.broadcast(
              ButtonAction(ButtonActions.setAutoPause, "true", Duration.zero));
        },
        style: ButtonStyle(
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.0),
                    side: const BorderSide(color: Colors.blue)))),
        child: const Text("Reset", textAlign: TextAlign.center),
      )
    ]);
  }
}
