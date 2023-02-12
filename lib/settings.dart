import 'package:campaniereis/track_widget.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:campaniereis/events.dart';

class SettingsWidget extends StatelessWidget {
  const SettingsWidget(this._audioPlayer, this.trackWidgets, this._autoPause,
      {super.key});

  final AudioPlayer _audioPlayer;

  final List<TrackWidget> trackWidgets;

  final bool _autoPause;

  Widget _speedWidget(BuildContext context, double? speed) {
    if (speed == null) return const SizedBox.shrink();
    return Row(children: [
      const Text('Snelheid'),
      SizedBox(
        width: MediaQuery.of(context).size.width - 120.0,
        child: Slider(
          value: speed,
          max: 5.0,
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
                "Met auto pauzeer wordt alles de volgende podcast in de lijst automatisch gepauzeerd wanneer het begint",
            child: Text("Auto pauzeer")),
        StatefulSwitch(_autoPause),
      ]),
    ]);
  }
}

class StatefulSwitch extends StatefulWidget {
  const StatefulSwitch(this.autoPause, {super.key});

  final bool autoPause;

  @override
  // ignore: no_logic_in_create_state
  State<StatefulSwitch> createState() => _StatefulSwitchState(autoPause);
}

class _StatefulSwitchState extends State<StatefulSwitch> {
  _StatefulSwitchState(this.state);

  bool state;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: state,
      onChanged: (value) {
        setState(() {
          state = !state;
        });
        ButtonEvents.broadcast(ButtonAction(ButtonActions.setAutoPause,
            value ? "true" : "false", Duration.zero));
      },
    );
  }
}
