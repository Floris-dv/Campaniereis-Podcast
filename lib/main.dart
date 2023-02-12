import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:campaniereis/binary_audio_source.dart';
import 'package:campaniereis/player_buttons.dart';
import 'package:campaniereis/events.dart';
import 'package:campaniereis/settings.dart';
import 'package:campaniereis/track_widget.dart';
import 'package:event/event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    AudioSession.instance.then((session) => // Audio session
        session.configure(const AudioSessionConfiguration.speech())),
    Settings.init() // Flutter settings screen
  ]);

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

  int currentIndex = 0;

  List<String> logging = List.filled(1, "Initializing logging", growable: true);

  bool _autoPause = true;

  void saveFiles(String text, List<List<int>> bytes) async {
    final directory = await getApplicationSupportDirectory()
        .then((value) => value.create(recursive: true));

    await Future.wait([
      File("${directory.absolute.path}/Tracks.txt").writeAsString(text),
      for (int i = 0; i < bytes.length; i++)
        File('${directory.absolute.path}/${trackWidgets[i].asset}')
            .writeAsBytes(bytes[i])
    ]);
    Messaging.broadcast(Value("Saved files to $directory"));
  }

  Future<void> loadFile() async {
    FilePickerResult? result = await FilePicker.platform
        .pickFiles(allowMultiple: false, withData: true);
    if (result == null || result.files.isEmpty) return; // canceled

    await _audioPlayer.dispose();
    Messaging.broadcast(Value("Result: ${result.files.first.name}"));

    final decoder = ZipDecoder();

    Archive archive = decoder.decodeBytes(result.files.first.bytes!);
    Messaging.broadcast(Value("decoded"));
    var file = archive.findFile("Tracks.txt");
    if (file == null) return; // Couldn't find file
    var text = utf8.decode(file.content! as List<int>);
    var files = List.from(text.split('\n').map((e) => e.trim()));
    List<BinaryAudioSource> audioSources = List.empty(growable: true);
    List<String> loadedFiles = List.empty(growable: true);
    for (var fileName in files) {
      ArchiveFile? file = archive.findFile(fileName);
      if (file == null) {
        Messaging.broadcast(Value("Couldn't find $fileName"));
        continue;
      }
      audioSources.add(
          BinaryAudioSource(file.content as List<int>, getMIMEType(fileName)));
      loadedFiles.add(fileName);
    }

    try {
      var durations = await Future.wait(
          Iterable<Future<Duration?>>.generate(loadedFiles.length, (index) {
        final AudioPlayer player = AudioPlayer();

        return player.setAudioSource(audioSources[index]).catchError((error) {
          Messaging.broadcast(
              Value("Couldn't load ${loadedFiles[index]}: $error"));
          return const Duration(seconds: 1);
        });
      }));

      setState(() {
        trackWidgets.clear();
        trackWidgets = [
          for (int i = 0; i < loadedFiles.length; i++)
            TrackWidget(
                loadedFiles[i], durations[i] ?? const Duration(seconds: 1))
        ].toList();
      });
    } on PlayerException catch (e) {
      Messaging.broadcast(Value("Player exception ${e.code}: ${e.message}"));
    } on PlayerInterruptedException catch (e) {
      Messaging.broadcast(Value("Player interrupted: ${e.message}"));
    }
    if (!kIsWeb) saveFiles(text, List.from(audioSources.map((e) => e.bytes)));
    ButtonEvents.unsubAll();
    WidgetEvents.unsubAll();
    addListeners();
    setState(() {
      setAudioPlayer();
    });
    await _audioPlayer
        .setAudioSource(ConcatenatingAudioSource(children: audioSources));
    return;
  }

  void loadTracks() async {
    if (kIsWeb) {
      await loadFile();
      return;
    }
    final directory = await getApplicationSupportDirectory()
        .then((value) => value.create(recursive: true))
        .catchError((error) {
      Messaging.broadcast(Value("Couldn't find the support directory"));
      return Directory.systemTemp;
    });

    Messaging.broadcast(Value(directory.path));

    var trackFile = File("${directory.absolute.path}/Tracks.txt");

    if (!await trackFile.exists()) {
      await loadFile();
      return;
    }

    var lines = await trackFile.readAsLines();

    List<Uint8List> data = await Future.wait([
      for (var line in lines)
        File('${directory.absolute.path}/$line').readAsBytes()
    ]);

    var durations = await Future.wait(
        Iterable<Future<Duration?>>.generate(data.length, (index) {
      final AudioPlayer player = AudioPlayer();
      return player.setAudioSource(
          BinaryAudioSource(data[index], getMIMEType(lines[index])));
    }));

    setState(() {
      trackWidgets = [
        for (int i = 0; i < lines.length; i++)
          TrackWidget(lines[i], durations[i] ?? const Duration(seconds: 1))
      ];
      currentIndex = 0;
    });

    await _audioPlayer.setAudioSource(ConcatenatingAudioSource(children: [
      for (int i = 0; i < data.length; i++)
        BinaryAudioSource(data[i], getMIMEType(lines[i]))
    ]));
  }

  void addListeners() {
    Messaging.subscribe((args) {
      if (args == null) return;
      if (kDebugMode) print(args.value);
      WidgetsBinding.instance
          .addPostFrameCallback((_) => setState(() => logging.add(args.value)));
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
              await _audioPlayer.pause();
            } else {
              WidgetEvents.broadcast(WidgetAction(WidgetActions.play,
                  trackWidgets[currentIndex].asset, args.time));
              await _audioPlayer.play();
            }
          }

          break;
        case ButtonActions.previous:
          if (_audioPlayer.hasPrevious) {
            ButtonEvents.broadcast(ButtonAction(
                ButtonActions.setCurrentlyPlaying,
                trackWidgets[_audioPlayer.previousIndex!].asset,
                args.time));
          }
          break;
        case ButtonActions.skip:
          if (_audioPlayer.hasNext) {
            ButtonEvents.broadcast(ButtonAction(
                ButtonActions.setCurrentlyPlaying,
                trackWidgets[_audioPlayer.nextIndex!].asset,
                args.time));
          }
          break;
        case ButtonActions.setTime:
          if (args.asset == trackWidgets[currentIndex].asset) {
            await _audioPlayer.seek(args.time);
          }
          WidgetEvents.broadcast(
              WidgetAction(WidgetActions.setTime, args.asset, args.time));
          break;
        case ButtonActions.setCurrentlyPlaying:
          // Need to stop the previous song
          if (_audioPlayer.playing) {
            WidgetEvents.broadcast(WidgetAction(WidgetActions.pause,
                trackWidgets[currentIndex].asset, _audioPlayer.position));
          }
          for (int i = 0; i < trackWidgets.length; i++) {
            if (trackWidgets[i].asset == args.asset) {
              setState(() => currentIndex = i);
              break;
            }
          }

          WidgetEvents.broadcast(WidgetAction(
              WidgetActions.play, trackWidgets[currentIndex].asset, args.time));
          await _audioPlayer.seek(args.time, index: currentIndex);
          await _audioPlayer.play();
          break;
        case ButtonActions.setAutoPause:
          setState(() {
            _autoPause = !_autoPause;
          });

          break;
        default:
          break;
      }
    });
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

    _audioPlayer.sequenceStateStream.listen((event) {
      if (event == null) return;
      if (!_audioPlayer.playing) return;
      if (_autoPause) _audioPlayer.pause();
    });

    _audioPlayer.currentIndexStream.listen((event) {
      if (event == null) return;
      if (currentIndex == event) return;
      setState(() {
        currentIndex = event;
      });
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
                    SettingsWidget(_audioPlayer, trackWidgets, _autoPause),
                    StreamBuilder(
                        stream: _audioPlayer.currentIndexStream,
                        builder: (_, snapshot) {
                          if (snapshot.data == null) {
                            return const SizedBox.shrink();
                          }
                          return PlayerButtons(
                              _audioPlayer, trackWidgets[snapshot.data!].asset);
                        })
                  ]),
                ),
              )),
        ),
      ]),
      body: Center(
          child: Column(children: [
        for (var track in trackWidgets) track,
        PlayerButtons(_audioPlayer, trackWidgets[currentIndex].asset)
      ])),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            loadFile();
          },
          child: const Icon(Icons.download)),
    );
  }
}
