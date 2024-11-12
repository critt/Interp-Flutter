import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transcription_client/speaker_switch.dart';
import 'audio_recorder.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'constants.dart' as constants;
import 'language.dart';

class TranscriptionState extends ChangeNotifier {
  TranscriptionState(
      {required String id,
      required Language subjectLanguage,
      required Language objectLanguage,
      required String data})
      : _id = id,
        _subjectLanguage = subjectLanguage,
        _objectLanguage = objectLanguage,
        _data = data;

  final String _id;
  Language _subjectLanguage;
  Language _objectLanguage;
  String _data;
  String _nextPhrase = '';

  String get data => _data;

  String get nextPhrase => _nextPhrase;

  String get id => _id;

  Language get subjectLanguage => _subjectLanguage;

  void setSubjectLanguage(Language language) {
    _subjectLanguage = language;
    notifyListeners();
  }

  Language get objectLanguage => _objectLanguage;

  void setObjectLanguage(Language language) {
    _objectLanguage = language;
    notifyListeners();
  }

  void updateData(String newData, bool isFinal) {
    if (isFinal) {
      _data += newData;
      _nextPhrase = '';
    } else {
      _nextPhrase = newData;
    }

    notifyListeners();
  }

  void clearData() {
    _data = '';
  }
}

class ObjectTranscription extends TranscriptionState {
  ObjectTranscription()
      : super(
          data: 'Their words',
          id: 'O',
          subjectLanguage: const Language(code: 'de', name: 'German'),
          objectLanguage: const Language(code: 'en', name: 'English'),
        );
}

class SubjectTranscription extends TranscriptionState {
  SubjectTranscription()
      : super(
          data: 'Their words',
          id: 'S',
          subjectLanguage: const Language(code: 'en', name: 'English'),
          objectLanguage: const Language(code: 'de', name: 'German'),
        );
}

class ServiceState extends ChangeNotifier {
  ConnectionStatus _state = ConnectionStatus.disconnected;

  ConnectionStatus get state => _state;

  void toggleConnection() {
    _state = _state == ConnectionStatus.disconnected
        ? ConnectionStatus.connecting
        : ConnectionStatus.disconnected;

    notifyListeners();
  }

  void connectionEstablished() {
    _state = ConnectionStatus.connected;
    notifyListeners();
  }
}

enum ConnectionStatus { connected, connecting, disconnected }

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ServiceState()),
        ChangeNotifierProvider(create: (_) => AudioRecorder()),
        ChangeNotifierProvider(create: (_) => SubjectTranscription()),
        ChangeNotifierProvider(create: (_) => ObjectTranscription()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: constants.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueGrey, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: constants.appBarTitle),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<List<Language>?> _supportedLanguages;
  final SpeakerSwitch _speakerSwitch = SpeakerSwitch();

  @override
  void initState() {
    super.initState();
    _supportedLanguages = fetchSupportedLanguages();
  }

  Future<List<Language>?> fetchSupportedLanguages() async {
    final response =
        await http.get(Uri.parse(constants.supportedLanguagesPath));

    if (response.statusCode == 200) {
      List<dynamic> jsonList = jsonDecode(response.body);
      List<Language> result =
          jsonList.map((item) => Language.fromJson(item)).toList();
      return result;
    } else {
      print('Failed to load supported languages');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final serviceState = context.watch<ServiceState>();
    final audioState = context.watch<AudioRecorder>();
    final subjectState = context.watch<SubjectTranscription>();
    final objectState = context.watch<ObjectTranscription>();

    if (serviceState.state == ConnectionStatus.connected &&
        audioState.isInit &&
        !audioState.isRecording) {
      audioState.record(subjectState.updateData, objectState.updateData,
          subjectState.objectLanguage.code, objectState.objectLanguage.code, _speakerSwitch);
    } else if (serviceState.state == ConnectionStatus.connecting &&
        !audioState.isInit) {
      subjectState.clearData();
      objectState.clearData();
      audioState.init(serviceState.connectionEstablished);
    } else if (serviceState.state == ConnectionStatus.disconnected) {
      audioState.stopRecorder();
    }

    MaterialColor connectionColor =
        serviceState.state == ConnectionStatus.connected
            ? Colors.green
            : serviceState.state == ConnectionStatus.connecting
                ? Colors.yellow
                : Colors.grey;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            const RotatedBox (
              quarterTurns: 2,
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: BigCard(stateId: 'S'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: BigCard(stateId: 'O'),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: FutureBuilder(
                  future: _supportedLanguages,
                  builder: (context, snapshot) => Row(
                        children: [
                          Expanded(
                            child: DropdownButton<Language>(
                              items: snapshot.data
                                  ?.map<DropdownMenuItem<Language>>(
                                      (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e.name),
                                          ))
                                  .toList(),
                              value: subjectState.subjectLanguage,
                              onChanged: (Language? value) {
                                if (value != null) {
                                  subjectState.setSubjectLanguage(value);
                                  objectState.setObjectLanguage(value);
                                }
                              },
                              iconEnabledColor: theme.colorScheme.primary,
                              iconDisabledColor: Colors.grey,
                              isExpanded: true, // Make the dropdown take up available space
                            ),
                          ),
                          const Text(' ⇌ '),
                          Expanded(
                            child: DropdownButton<Language>(
                              items: snapshot.data
                                  ?.map<DropdownMenuItem<Language>>(
                                      (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e.name),
                                          ))
                                  .toList(),
                              value: subjectState.objectLanguage,
                              onChanged: (Language? value) {
                                if (value != null) {
                                  subjectState.setObjectLanguage(value);
                                  objectState.setSubjectLanguage(value);
                                }
                              },
                              iconEnabledColor: theme.colorScheme.primary,
                              iconDisabledColor: Colors.grey,
                              isExpanded: true, // Make the dropdown take up available space
                            ),
                          ),
                        ],
                      )),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        onPressed: () {
          serviceState.toggleConnection();
        },
        tooltip: 'Increment',
        child: Icon(Icons.connect_without_contact, color: connectionColor),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  @override
  void dispose() {
    // can i access the AudioRecorder instance from here?
    // can i call dispose() on it?
    // is context available in StatefulWidgets dispose() method?
    Provider.of<AudioRecorder>(context, listen: false).dispose();
    super.dispose();
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.stateId,
  });

  final String stateId;

  @override
  Widget build(BuildContext context) {
    var transcriptionState = stateId == 'S'
        ? context.watch<SubjectTranscription>()
        : context.watch<ObjectTranscription>();

    final theme = Theme.of(context);

    return Column(
      children: [
        FractionallySizedBox(
          widthFactor: 1,
          child: Text(
            '${transcriptionState.subjectLanguage.name} ➜ ${transcriptionState.objectLanguage.name}',
            style: theme.textTheme.titleMedium!
                .copyWith(color: theme.colorScheme.secondary),
            textAlign: TextAlign.start,
          ),
        ),
        FractionallySizedBox(
          widthFactor: 1,
          child: Padding(
            padding: const EdgeInsets.only(top: 14.0, bottom: 14.0),
            child: Card( //TODO make scrollable, or otherwise handle content overflow behavior
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  height: 150,
                  child: Text(
                    transcriptionState.data + transcriptionState.nextPhrase,
                    style: theme.textTheme.bodyMedium!
                        .copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
