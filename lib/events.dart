import 'dart:async';
import 'package:event/event.dart';

enum ButtonActions {
  pauseButtonPressed,
  skip,
  previous,
  setTime,
  setCurrentlyPlaying,
  setAutoPause, // Uses asset as a true/false value
}

class ButtonAction extends EventArgs {
  ButtonActions action;
  String asset;
  Duration time;
  ButtonAction(this.action, this.asset, this.time);
}

// Messages from the buttons to the player
class ButtonEvents {
  static final _event = Event<ButtonAction>();

  static void stream(StreamSink<ButtonAction?> sink) =>
      _event.subscribeStream(sink);

  static void unsubAll() => _event.unsubscribeAll();

  static void subscribe(EventHandler<ButtonAction> f) => _event.subscribe(f);

  static void broadcast(ButtonAction action) => _event.broadcast(action);

  static void subscribeStream(StreamSink sink) => _event.subscribeStream(sink);
}

enum WidgetActions {
  setTime, // For animation
  pause,
  play,
}

class WidgetAction extends EventArgs {
  WidgetActions action;
  String asset;
  Duration time;
  WidgetAction(this.action, this.asset, this.time);
}

// Messages from the player to the widgets
class WidgetEvents {
  static final _event = Event<WidgetAction>();

  static void unsubAll() => _event.unsubscribeAll();

  static void subscribe(EventHandler<WidgetAction> f) => _event.subscribe(f);

  static void broadcast(WidgetAction action) => _event.broadcast(action);

  static void subscribeStream(StreamSink sink) => _event.subscribeStream(sink);
}

class Messaging {
  static final _event = Event<Value<String>>();

  static void unsubAll() => _event.unsubscribeAll();

  static void subscribe(EventHandler<Value<String>> f) => _event.subscribe(f);

  static void broadcast(Value<String> action) => _event.broadcast(action);

  static void subscribeStream(StreamSink sink) => _event.subscribeStream(sink);
}
