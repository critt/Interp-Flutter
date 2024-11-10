import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'audio_recorder.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'constants.dart' as constants;

class TranscriptionState extends ChangeNotifier {
  TranscriptionState(
      {required String id,
      required String subjectLanguage,
      required String objectLanguage,
      required String data})
      : _id = id,
        _subjectLanguage = subjectLanguage,
        _objectLanguage = objectLanguage,
        _data = data;

  final String _id;
  String _subjectLanguage;
  String _objectLanguage;
  String _data;
  String _nextPhrase = '';

  String get data => _data;

  String get nextPhrase => _nextPhrase;

  String get id => _id;

  String get subjectLanguage => _subjectLanguage;

  void setSubjectLanguage(String value) {
    _subjectLanguage = value;
    notifyListeners();
  }

  String get objectLanguage => _objectLanguage;

  void setObjectLanguage(String value) {
    _objectLanguage = value;
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

class PartnerTranscription extends TranscriptionState {
  PartnerTranscription()
      : super(
            data: 'Their words',
            id: 'P',
            subjectLanguage: 'de',
            objectLanguage: 'en');
}

class UserTranscription extends TranscriptionState {
  UserTranscription()
      : super(
            data: 'Your words',
            id: 'U',
            subjectLanguage: 'en',
            objectLanguage: 'de');
}

class ServiceState extends ChangeNotifier {
  ConnectionStatus _state = ConnectionStatus.disconnected;

  ConnectionStatus get state => _state;

  void toggleConnection() {
    _state = _state == ConnectionStatus.disconnected
        ? ConnectionStatus.connecting : ConnectionStatus.disconnected;

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
        ChangeNotifierProvider(create: (_) => UserTranscription()),
        ChangeNotifierProvider(create: (_) => PartnerTranscription()),
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
  late Future<List<String>> _supportedLanguages;

  @override
  void initState() {
    super.initState();
    _supportedLanguages = fetchSupportedLanguages();
  }

  //TODO: Fix mistake in implementing REST endpoint on backend.
  //TODO: It currently doesn't work, so this is hacked to return a hard-coded list.
  Future<List<String>> fetchSupportedLanguages() async {
    final response =
        await http.get(Uri.parse(constants.supportedLanguagesPath));

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      return jsonDecode(response.body) as List<String>;
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      print('Failed to load album');
      return ['en', 'de', 'es', 'fr', 'it', 'nl', 'pl', 'pt', 'ru', 'zh', 'ja'];
    }
  }

  @override
  Widget build(BuildContext context) {
    print('-------------------build-------------------');

    final theme = Theme.of(context);
    final serviceState = context.watch<ServiceState>();
    final audioState = context.watch<AudioRecorder>();
    final userState = context.watch<UserTranscription>();

    print('serviceState.state == ${serviceState.state}');

    if (serviceState.state == ConnectionStatus.connected &&
        audioState.isInit &&
        !audioState.isRecording) {
      audioState.record(userState.updateData, userState.objectLanguage);
    } else if (serviceState.state == ConnectionStatus.connecting &&
        !audioState.isInit) {
      userState.clearData();
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
        title: Text(widget.title,
            style: theme.textTheme.titleLarge!
                .copyWith(color: theme.colorScheme.secondary)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: BigCard(stateId: 'U'),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: FutureBuilder(
                  future: _supportedLanguages,
                  builder: (context, snapshot) => DropdownButton(
                        items: snapshot.data
                            ?.map<DropdownMenuItem<String>>(
                                (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ))
                            .toList(),
                        value: userState.objectLanguage,
                        onChanged: (String? value) {
                          userState.setObjectLanguage(value!);
                        },
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
    var transcriptionState = stateId == 'U'
        ? context.watch<UserTranscription>()
        : context.watch<PartnerTranscription>();

    final theme = Theme.of(context);

    return Column(
      children: [
        FractionallySizedBox(
          widthFactor: 1,
          child: Text(
            '${transcriptionState.subjectLanguage} ➜ ${transcriptionState.objectLanguage}',
            style: theme.textTheme.titleMedium!
                .copyWith(color: theme.colorScheme.secondary),
            textAlign: TextAlign.start,
          ),
        ),
        FractionallySizedBox(
          widthFactor: 1,
          child: Padding(
            padding: const EdgeInsets.only(top: 14.0, bottom: 14.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: theme.colorScheme.primaryContainer,
              ),
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
