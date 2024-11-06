import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ServiceState()),
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
      title: 'Translation Circuit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueGrey, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: '🗣 Translation Circuit'),
    );
  }
}

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

  String get data => _data;

  String get id => _id;

  String get subjectLanguage => _subjectLanguage;
  set subjectLanguage(String value) {
    _subjectLanguage = value;
    notifyListeners();
  }

  String get objectLanguage => _objectLanguage;
  set objectLanguage(String value) {
    _objectLanguage = value;
    notifyListeners();
  }

  void updateData(String newData) {
    _data = newData;
    notifyListeners();
  }
}

class PartnerTranscription extends TranscriptionState {
  PartnerTranscription()
      : super(
            data: 'Their words',
            id: 'P',
            subjectLanguage: 'German',
            objectLanguage: 'English');
}

class UserTranscription extends TranscriptionState {
  UserTranscription()
      : super(
            data: 'Your words',
            id: 'U',
            subjectLanguage: 'English',
            objectLanguage: 'German');
}

enum ConnectionState { connected, connecting, disconnected }

class ServiceState extends ChangeNotifier {
  ConnectionState _state = ConnectionState.disconnected;

  ConnectionState get state => _state;

  void toggleConnection() {
    _state = _state == ConnectionState.connected
        ? ConnectionState.disconnected
        : _state == ConnectionState.disconnected
            ? ConnectionState.connecting
            : ConnectionState.connected;

    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    final theme = Theme.of(context);
    final serviceState = context.watch<ServiceState>();

    MaterialColor connectionColor =
        serviceState.state == ConnectionState.connected
            ? Colors.green
            : serviceState.state == ConnectionState.connecting
                ? Colors.yellow
                : Colors.grey;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title,
            style: theme.textTheme.titleLarge!
                .copyWith(color: theme.colorScheme.secondary)),
      ),
      body: const Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(20.0),
              child: BigCard(stateId: 'P'),
            ),
            Padding(
              padding: EdgeInsets.all(20.0),
              child: BigCard(stateId: 'U'),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        onPressed: serviceState.toggleConnection,
        tooltip: 'Increment',
        child: Icon(Icons.connect_without_contact, color: connectionColor),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
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
            '${transcriptionState.objectLanguage} ➜ ${transcriptionState.subjectLanguage}',
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
                  height: 200,
                  child: Text(
                    transcriptionState.data,
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
