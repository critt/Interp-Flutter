import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorder extends ChangeNotifier {
  FlutterSoundPlayer? _mPlayer = FlutterSoundPlayer();
  FlutterSoundRecorder? _mRecorder = FlutterSoundRecorder();
  bool _mPlayerIsInit = false;
  bool _mRecorderIsInit = false;
  String? _mPath;
  bool _mPlaybackReady = false;
  StreamSubscription? _mRecordingDataSubscription;
  int sampleRate = 44100;

  AudioRecorder();

  Future<void> init() async {
    _mPlayer!.openPlayer().then((value) {
      _mPlayerIsInit = true;
      notifyListeners();
    });

    await _openRecorder();
    notifyListeners();
  }

  @override
  void dispose() {
    stopPlayer();
    _mPlayer!.closePlayer();
    _mPlayer = null;

    stopRecorder();
    _mRecorder!.closeRecorder();
    _mRecorder = null;
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

    _mRecorderIsInit = true;
    notifyListeners();
  }

  Future<void> record() async {
    print('record'); 
    assert(_mRecorderIsInit && _mPlayer!.isStopped);
    var sink = await _createFile();
    var recordingDataController = StreamController<Uint8List>();
    _mRecordingDataSubscription =
        recordingDataController.stream.listen((buffer) {
      sink.add(buffer);
    });
    await _mRecorder!.startRecorder(
      toStream: recordingDataController.sink,
      codec: Codec.pcm16,
      numChannels: 2,
      sampleRate: 44100,
      bufferSize: 8192,
    );

  }

  Future<void> stopRecorder() async {
    print('stopRecorder'); 
    await _mRecorder!.stopRecorder();
    if (_mRecordingDataSubscription != null) {
      await _mRecordingDataSubscription!.cancel();
      _mRecordingDataSubscription = null;
    }

    _mPlaybackReady = true;
  }

  void play() async {
    print('play'); 
    assert(_mPlayerIsInit &&
        _mPlaybackReady &&
        _mRecorder!.isStopped &&
        _mPlayer!.isStopped);
    await _mPlayer!.startPlayer(
        fromURI: _mPath,
        sampleRate: sampleRate,
        codec: Codec.pcm16,
        numChannels: 2,
        whenFinished: () {
        });

  }

  Future<void> stopPlayer() async {
    print('stopPlayer'); 
    await _mPlayer!.stopPlayer();
  }

  Future<IOSink> _createFile() async {
    var tempDir = await getTemporaryDirectory();
    _mPath = '${tempDir.path}/flutter_audio_stream.pcm';
    var outputFile = File(_mPath!);
    if (outputFile.existsSync()) {
      await outputFile.delete();
    }
    return outputFile.openWrite();
  }
}
