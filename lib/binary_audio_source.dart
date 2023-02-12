import 'package:just_audio/just_audio.dart';

String getMIMEType(String fileName) {
  var fileExtension = fileName.substring(fileName.lastIndexOf('.') + 1);
  if (fileExtension == 'mp3') fileExtension = 'mpeg';
  return 'audio/$fileExtension';
}

// From https://pub.dev/packages/just_audio, changed so it has a custom MIME types
// Feed your own stream of bytes into the player
class BinaryAudioSource extends StreamAudioSource {
  final List<int> bytes;
  // ignore: non_constant_identifier_names
  final String MIMEType;
  BinaryAudioSource(this.bytes, this.MIMEType);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: MIMEType,
    );
  }
}
