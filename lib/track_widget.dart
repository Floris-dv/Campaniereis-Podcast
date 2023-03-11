import 'package:event/event.dart';
import 'package:flutter/material.dart';
import 'package:campaniereis/events.dart';

const double trackIconSize = 24.0;

class TrackWidget extends StatefulWidget {
  const TrackWidget(this.asset, this.length, this.shortName, {Key? key})
      : super(key: key);

  final String asset;
  final String shortName;
  final Duration length;

  @override
  // ignore: no_logic_in_create_state
  State<TrackWidget> createState() => _TrackWidget(shortName, asset, length);
}

const TextStyle _style = TextStyle(fontFamily: "Comic Sans");
const TextStyle _smallStyle =
    TextStyle(fontFamily: "Comic Sans", fontSize: 7.0);

class _TrackWidget extends State<TrackWidget> {
  _TrackWidget(this._shortName, this._asset, this.lengthTrack);

  final String _asset;
  final String _shortName;

  Duration timeStamp = Duration.zero;
  double _time = 0.0;
  bool playing = false;
  bool end = false;
  Duration lengthTrack;

  void setTime(double seconds) {
    setState(() {
      _time = seconds;
      timeStamp = Duration(microseconds: (seconds * 1000000).round());
    });
  }

  @override
  void initState() {
    super.initState();

    Messaging.broadcast(Value('TrackWidget of $_asset being loaded'));

    WidgetEvents.subscribe((WidgetAction? args) {
      if (args == null) return;
      if (args.asset != _asset) return;

      double time = args.time.inMicroseconds.toDouble();
      time /= 1000000;

      switch (args.action) {
        case WidgetActions.pause:
          setState(() {
            playing = false;
            end = false;
          });

          break;

        case WidgetActions.play:
          setState(() {
            playing = true;
            end = false;
          });
          setTime(time);
          break;

        case WidgetActions.setTime:
          setTime(time);
          break;

        case WidgetActions.end:
          setState(() {
            end = true;
            playing = false;
          });
          break;
        default:
          break;
      }
    });
  }

  Size _textSize(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  @override
  Widget build(BuildContext context) {
    int minutes = lengthTrack.inMinutes;
    dynamic seconds = lengthTrack.inSeconds % 60;
    if (seconds < 10) {
      seconds = '0$seconds';
    }
    return Row(
      children: [
        SizedBox.fromSize(
            size: Size(
          5.0,
          _textSize(_asset, _style).height,
        )),
        Text(_shortName, style: _smallStyle),
        Text(_asset, style: _style),
        SliderTheme(
            data: SliderTheme.of(context),
            child: SizedBox(
                width: MediaQuery.of(context).size.width -
                    _textSize(_shortName, _smallStyle).width -
                    _textSize(_asset, _style).width -
                    _textSize('$minutes:$seconds', _style).width -
                    trackIconSize -
                    30.0,
                child: Slider(
                    value: _time,
                    max: lengthTrack.inMicroseconds / 1000000,
                    onChanged: (value) => ButtonEvents.broadcast(ButtonAction(
                        ButtonActions.setTime,
                        _asset,
                        Duration(microseconds: (value * 1000000).round())))))),
        Text('$minutes:$seconds', style: _style),
        _pauseButton(),
      ],
    );
  }

  Widget _pauseButton() {
    if (lengthTrack.inMicroseconds == 0) {
      return Container(
          margin: const EdgeInsets.all(8.0),
          width: trackIconSize,
          height: trackIconSize,
          child: const CircularProgressIndicator());
    }
    if (playing) {
      return IconButton(
          icon: const Icon(Icons.pause),
          iconSize: trackIconSize,
          onPressed: () => ButtonEvents.broadcast(ButtonAction(
              ButtonActions.pauseButtonPressed, _asset, timeStamp)));
    }
    if (end) {
      return IconButton(
          icon: const Icon(Icons.replay),
          iconSize: trackIconSize,
          onPressed: () => ButtonEvents.broadcast(ButtonAction(
              ButtonActions.pauseButtonPressed, _asset, Duration.zero)));
    }
    return IconButton(
        icon: const Icon(Icons.play_arrow),
        iconSize: trackIconSize,
        onPressed: () => ButtonEvents.broadcast(
            ButtonAction(ButtonActions.pauseButtonPressed, _asset, timeStamp)));
  }
}

class EmptyTrackWidget extends TrackWidget {
  const EmptyTrackWidget({Key? key})
      : super("Aan het laden", const Duration(seconds: 1),
            "<<<INTERNAL DATA TESTING>>>",
            key: key);

  @override
  // ignore: no_logic_in_create_state
  State<EmptyTrackWidget> createState() => _EmptyTrackWidget();
}

class _EmptyTrackWidget extends State<EmptyTrackWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Text("Aan het laden!", style: _style),
      SliderTheme(
          data: SliderTheme.of(context),
          child: SizedBox(
              width: MediaQuery.of(context).size.width -
                  200.0 -
                  trackIconSize -
                  20.0,
              child: Slider(value: 0.0, onChanged: (value) {}))),
      const Text('0:00'),
      Container(
          margin: const EdgeInsets.all(8.0),
          width: trackIconSize,
          height: trackIconSize,
          child: const CircularProgressIndicator())
    ]);
  }
}
