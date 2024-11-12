import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:transcription_client/speaker_switch.dart';
import 'constants.dart' as constants;

class AudioRecorder extends ChangeNotifier {
  FlutterSoundRecorder? _mRecorder = FlutterSoundRecorder();
  bool isInit = false;
  bool isRecording = false;
  String? _mPath;
  StreamSubscription? _mRecordingDataSubscription;
  static const int sampleRate = 16000;
  static const int bufferSize = 2048;
  late IO.Socket _socket;

  AudioRecorder() {
    _socket = IO.io(constants.servicePath, <String, dynamic>{
      'transports': ['websocket'],
    });
  }

  Future<void> init(Function() f) async {
    print('AudioRecorder.init()');
    await _openRecorder();

    if (_socket.connected) {
      print("AudioRecorder.init() - Already connected");
      isInit = true;
      f();
    }

    _socket.onConnect((_) {
      print("AudioRecorder.init() - Connection established");
      isInit = true;
      f();
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

  Future<void> record(Function(String, bool) handlerSubject, Function(String, bool) handlerObject, String languageObject,
      String languageSubject, SpeakerSwitch speakerSwitch) async {
    print('record');

    assert(isInit);
    assert(!isRecording);

    isRecording = true;

    _socket.on('speechData', (response) {
      print('_socketSubject.on speechData');
      handlerSubject(response['data'], response['isFinal']);
    });

    _socket.emit('startGoogleCloudStream',
        _getTranscriptionConfig(languageObject, languageSubject));

    var recordingDataController = StreamController<Uint8List>();
    _mRecordingDataSubscription =
        recordingDataController.stream.listen((buffer) {
          if (speakerSwitch.currentSpeaker == Speaker.subject) {
            _socket.emit('binaryAudioData', buffer);
          } else {
            _socket.emit('binaryAudioData', buffer); // TODO: GET MULTIPLEXING WORKING SO BOTH SPEAKERS ARE SUPPORTED OVER THE SAME SOCKET
          }
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

    isInit = false;

    _socket.emit('endGoogleCloudStream');
    _socket.off('speechData');

    await _mRecorder!.stopRecorder();

    if (_mRecordingDataSubscription != null) {
      await _mRecordingDataSubscription!.cancel();
      _mRecordingDataSubscription = null;
    }

    isRecording = false;
  }

  dynamic _getTranscriptionConfig(
      String languageObject, String languageSubject) {
    return {
      'audio': {
        'encoding': 'LINEAR16',
        'sampleRateHertz': sampleRate,
        'languageCode': languageSubject,
      },
      'interimResults': true,
      'targetLanguage': languageObject
    };
  }
}
