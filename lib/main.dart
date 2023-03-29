import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;

import 'package:campaniereis/player_buttons.dart';
import 'package:campaniereis/events.dart';
import 'package:campaniereis/settings.dart';
import 'package:campaniereis/track_widget.dart';
import 'package:event/event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AudioSession.instance.then((session) => // Audio session
      session.configure(const AudioSessionConfiguration.speech()));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const Player(),
    );
  }
}

class Player extends StatefulWidget {
  const Player({super.key});

  @override
  State<Player> createState() => _Player();
}

class _Player extends State<Player> {
  late AudioPlayer _audioPlayer;

  List<TrackWidget> trackWidgets = [const EmptyTrackWidget()].toList();

  final StreamController<int> _currentIndexController =
      StreamController<int>.broadcast();
  int currentIndex = 0;

  List<String> logging = List.filled(1, "", growable: true);

  bool _autoPause = true;

  List<String> shortNames = List.empty();

  PlayerButtons? _buttons;

  void loadTracks() async {
    var lines = await rootBundle
        .loadString('assets/Tracks.txt')
        .then<List<List<String>>>(
          (value) =>
              List.from(value.split('\n').map((e) => e.trim().split(' '))),
        );

    var names = [for (var line in lines) line[0].replaceAll(RegExp(r'_'), ' ')];

    setState(() {
      trackWidgets = [
        const EmptyTrackWidget(),
        for (int i = 0; i < lines.length; i++)
          TrackWidget(
            names[i].substring(0, names[i].lastIndexOf('.')),
            Duration(seconds: int.tryParse(lines[i][1]) ?? 0),
            lines[i][2],
          )
      ];
      currentIndex = 0;
      shortNames = List.from(lines.map(
        (e) => e[2].toUpperCase(),
      ));
    });
  }

  void addListeners() {
    Messaging.subscribe((args) {
      if (args == null) return;
      if (kDebugMode) {
        print(args.value);
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => setState(() => logging.add(args.value)));
      }
    });

    _currentIndexController.stream.listen((event) {
      if (currentIndex == event) return;

      setState(() {
        currentIndex = event;
        _buttons = PlayerButtons(_audioPlayer, trackWidgets[currentIndex].asset,
            trackWidgets[currentIndex].length);
      });
      _audioPlayer.setAsset('assets/${trackWidgets[currentIndex].asset}');
    });
    ButtonEvents.subscribe((ButtonAction? args) async {
      if (args == null) return;

      switch (args.action) {
        case ButtonActions.pauseButtonPressed:
          if (trackWidgets[currentIndex].asset != args.asset) {
            ButtonEvents.broadcast(ButtonAction(
                ButtonActions.setCurrentlyPlaying, args.asset, args.time));
          } else {
            if (_audioPlayer.playing) {
              WidgetEvents.broadcast(WidgetAction(WidgetActions.pause,
                  trackWidgets[currentIndex].asset, args.time));
              Messaging.broadcast(
                  Value("Pausing ${trackWidgets[currentIndex].asset}"));
              await _audioPlayer.pause();
            } else {
              WidgetEvents.broadcast(WidgetAction(WidgetActions.play,
                  trackWidgets[currentIndex].asset, args.time));
              await _audioPlayer.play();
            }
          }
          break;
        case ButtonActions.previous:
          _seek(currentIndex - 1);
          break;
        case ButtonActions.skip:
          _seek(currentIndex + 1);
          break;
        case ButtonActions.setTime:
          if (args.asset == trackWidgets[currentIndex].asset) {
            await _audioPlayer.seek(args.time);
          }
          WidgetEvents.broadcast(
              WidgetAction(WidgetActions.play, args.asset, args.time));
          WidgetEvents.broadcast(
              WidgetAction(WidgetActions.setTime, args.asset, args.time));
          break;
        case ButtonActions.setCurrentlyPlaying:
          Messaging.broadcast(Value("Setting ${args.asset} to play"));
          // Need to stop the previous song
          if (_audioPlayer.playing) {
            WidgetEvents.broadcast(WidgetAction(WidgetActions.pause,
                trackWidgets[currentIndex].asset, _audioPlayer.position));
          }
          for (int i = 0; i < trackWidgets.length; i++) {
            if (trackWidgets[i].asset == args.asset) {
              setState(() {
                currentIndex = i;
                _buttons = PlayerButtons(
                    _audioPlayer,
                    trackWidgets[currentIndex].asset,
                    trackWidgets[currentIndex].length);
              });
              break;
            }
          }

          WidgetEvents.broadcast(WidgetAction(
              WidgetActions.play, trackWidgets[currentIndex].asset, args.time));
          await _audioPlayer.setAudioSource(
              AudioSource.asset(
                  'assets/${trackWidgets[currentIndex].asset}.mp3'),
              initialPosition: args.time);
          await _audioPlayer.play();
          break;

        case ButtonActions.setAutoPause:
          setState(() {
            _autoPause = args.asset == "true";
          });
          break;
      }
    });
  }

  void _seek(int index) {
    if (index < 0 || index >= trackWidgets.length) {
      return;
    }

    _currentIndexController.add(index);
  }

  void setAudioPlayer() {
    _audioPlayer = AudioPlayer();

    _audioPlayer
        .createPositionStream(
            steps: 1000,
            minPeriod: const Duration(milliseconds: 1),
            maxPeriod: const Duration(milliseconds: 200))
        .listen((event) => WidgetEvents.broadcast(WidgetAction(
            WidgetActions.setTime, trackWidgets[currentIndex].asset, event)));

    _audioPlayer.playerStateStream.listen((event) {
      if (event.processingState == ProcessingState.completed) {
        WidgetEvents.broadcast(WidgetAction(WidgetActions.end,
            trackWidgets[currentIndex].asset, Duration.zero));
        if (_autoPause) {
          _audioPlayer.pause();
          setState(() {
            _currentIndexController.add(0);
            _buttons = null;
          });
        } else {
          _seek(currentIndex + 1);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    try {
      setAudioPlayer();
      loadTracks();
      addListeners();
    } catch (e) {
      Messaging.broadcast(Value(e.toString()));
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Campaniereis podcasts"), actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: const Text("Instellingen")),
                  body: Column(children: [
                    SettingsWidget(_audioPlayer, _autoPause),
                    StreamBuilder(
                        stream: _audioPlayer.currentIndexStream,
                        builder: (_, __) => Center(
                            child: _buttons != null
                                ? PlayerButtons(
                                    _audioPlayer,
                                    trackWidgets[currentIndex].asset,
                                    trackWidgets[currentIndex].length)
                                : const Text(
                                    'Selecteer iets of voer een nummer in'))),
                    for (var l in logging) Text(l)
                  ]),
                ),
              )),
        ),
      ]),
      body: Center(
          child: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height -
                160.0 -
                (MediaQuery.of(context).size.width < 500 ? 40.0 : 0),
            child: ListView(children: trackWidgets.sublist(1)),
          ),
          TextField(
            autocorrect: false,
            autofillHints: shortNames,
            decoration: InputDecoration(
                labelText: "Invoer",
                border: const OutlineInputBorder(),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width)),
            onSubmitted: (value) {
              int index = shortNames.indexOf(value.toUpperCase());
              if (index == -1) {
                Messaging.broadcast(Value("Can't find $value!"));
              } else {
                ButtonEvents.broadcast(ButtonAction(
                    ButtonActions.setCurrentlyPlaying,
                    trackWidgets[index +
                            1] // First trackwidget (empty) has no shortName
                        .asset,
                    Duration.zero));
              }
            },
          ),
          Center(
              child: _buttons != null
                  ? PlayerButtons(
                      _audioPlayer,
                      trackWidgets[currentIndex].asset,
                      trackWidgets[currentIndex].length)
                  : const Text('Selecteer iets of voer een nummer in')),
        ],
      )),
    );
  }
}
