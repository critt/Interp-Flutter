import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
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
  late IO.Socket _socketSubject;
  late IO.Socket _socketObject;

  AudioRecorder() {
    //This looks like we are opening two sockets, but its actually just a magic multiplexing feature in socket_io_client
    //It allows us to multiplex multiple bidirectional streams over a single socket, identified by namespaces ('/subject' and '/object' in this case)
    _socketSubject = IO.io('${constants.servicePath}subject', <String, dynamic>{
      'transports': ['websocket'],
    });

    _socketObject = IO.io('${constants.servicePath}object', <String, dynamic>{
      'transports': ['websocket'],
    });
  }

  Future<void> init(Function() f) async {
    print('AudioRecorder.init()');
    await _openRecorder();

    if (_socketSubject.connected && _socketObject.connected) {
      print("AudioRecorder.init() - Already connected");
      isInit = true;
      f();
      return;
    }

    _socketSubject.onConnect((_) {
      _socketObject.connect();
    });

    _socketObject.onConnect((_) {
      print("AudioRecorder.init() - Connection established");
      isInit = true;
      f();
    });

    _socketSubject.connect();
  }

  @override
  void dispose() {
    stopRecorder();
    _mRecorder!.closeRecorder();
    _mRecorder = null;

    _socketSubject.dispose();
    _socketObject.dispose();

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

  Future<void> record(
      Function(String, bool) handlerSubject,
      Function(String, bool) handlerObject,
      String languageObject,
      String languageSubject,
      SpeakerSwitch speakerSwitch) async {
    print('record');

    assert(isInit);
    assert(!isRecording);

    isRecording = true;

    _socketSubject.on('speechData', (response) {
      print('_socketSubject.on speechData');
      handlerSubject(response['data'], response['isFinal']);
    });
    _socketSubject.emit('startGoogleCloudStream',
        _getTranscriptionConfig(languageObject, languageSubject));

    _socketObject.on('speechData', (response) {
      print('_socketObject.on speechData');
      handlerObject(response['data'], response['isFinal']);
    });
    _socketObject.emit('startGoogleCloudStream',
        _getTranscriptionConfig(languageSubject, languageObject));

    var recordingDataController = StreamController<Uint8List>();
    _mRecordingDataSubscription =
        recordingDataController.stream.listen((buffer) {
      if (speakerSwitch.currentSpeaker == Speaker.subject) {
        _socketSubject.emit('binaryAudioData', buffer);
        _socketObject.emit('binaryAudioData', Uint8List(0));
      } else {
        _socketObject.emit('binaryAudioData', buffer);
        _socketSubject.emit('binaryAudioData', Uint8List(0));
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

    _socketSubject.emit('endGoogleCloudStream');
    _socketSubject.off('speechData');
    _socketObject.emit('endGoogleCloudStream');
    _socketObject.off('speechData');

    await _mRecorder!.stopRecorder();

    if (_mRecordingDataSubscription != null) {
      await _mRecordingDataSubscription!.cancel();
      _mRecordingDataSubscription = null;
    }

    isRecording = false;
  }

  String _getTranscriptionConfig(String languageObject, String languageSubject) {
    var config = {
      'audio': {
        'encoding': 'LINEAR16',
        'sampleRateHertz': sampleRate,
        'languageCode': languageSubject,
      },
      'interimResults': true,
      'targetLanguage': languageObject
    };
    return jsonEncode(config);
  }
}
