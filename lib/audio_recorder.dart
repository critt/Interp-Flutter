import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class AudioRecorder extends ChangeNotifier {
  FlutterSoundRecorder? _mRecorder = FlutterSoundRecorder();
  bool isInit = false;
  String? _mPath;
  StreamSubscription? _mRecordingDataSubscription;
  static const int sampleRate = 16000;
  static const int bufferSize = 2048;
  late IO.Socket _socket;

  AudioRecorder() {
    _socket = IO.io('http://192.168.1.251:10000/', <String, dynamic>{
      'transports': ['websocket'],
    });
  }

  Future<void> init() async {
    await _openRecorder();

    _socket.onConnect((_) {
      print("Connection established");
      isInit = true;
      notifyListeners();
    });

    _socket.connect();
  }

  @override
  void dispose() {
    stopRecorder();
    _mRecorder!.closeRecorder();
    _mRecorder = null;
    _socket.dispose();
    super.dispose();
  }

  Future<void> _openRecorder() async {
    print('_openRecorder');

    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    await _mRecorder!.openRecorder();

    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
    //sampleRate = await _mRecorder!.getSampleRate();
  }

  Future<void> record() async {
    print('record');

    assert(isInit);

    _socket.on('speechData', (response) {
      final speechData = response['data'];
      final isFinal = response['isFinal'];

      print('speechData: $speechData, isFinal: $isFinal');
    });

    _socket.emit('startGoogleCloudStream', _getTranscriptionConfig());

    var recordingDataController = StreamController<Uint8List>();
    _mRecordingDataSubscription =
        recordingDataController.stream.listen((buffer) {
      _socket.emit('binaryAudioData', buffer);
    });

    await _mRecorder!.startRecorder(
      toStream: recordingDataController.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: sampleRate,
      bufferSize: bufferSize,
    );
  }

  Future<void> stopRecorder() async {
    print('stopRecorder');

    _socket.emit('endGoogleCloudStream');
    _socket.off('speechData');

    await _mRecorder!.stopRecorder();

    if (_mRecordingDataSubscription != null) {
      await _mRecordingDataSubscription!.cancel();
      _mRecordingDataSubscription = null;
    }
  }

  dynamic _getTranscriptionConfig() {
    return {
      'audio': {
        'encoding': 'LINEAR16',
        'sampleRateHertz': sampleRate,
        'languageCode': 'en-US',
      },
      'interimResults': true
    };
  }
}
