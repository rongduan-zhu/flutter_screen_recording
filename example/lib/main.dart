import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quiver/async.dart';

void main() => runApp(MyApp());

enum RecordingState {
  initial,
  recording,
  paused,
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _time = 0;
  RecordingState _recordingState = RecordingState.initial;

  requestPermissions() async {
    if (!kIsWeb) {
      if (await Permission.storage.request().isDenied) {
        await Permission.storage.request();
      }
      if (await Permission.photos.request().isDenied) {
        await Permission.photos.request();
      }
      if (await Permission.microphone.request().isDenied) {
        await Permission.microphone.request();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    requestPermissions();
    startTimer();
  }

  void startTimer() {
    CountdownTimer countDownTimer = new CountdownTimer(
      new Duration(seconds: 1000),
      new Duration(seconds: 1),
    );

    var sub = countDownTimer.listen(null);
    sub.onData((duration) {
      setState(() => _time++);
    });

    sub.onDone(() {
      print("Done");
      sub.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Screen Recording'),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Time: $_time\n'),
            if (_recordingState == RecordingState.initial)
              Center(
                child: ElevatedButton(
                  child: Text("Record Screen"),
                  onPressed: () => startScreenRecord(false),
                ),
              ),
            if (_recordingState == RecordingState.initial)
              Center(
                child: ElevatedButton(
                  child: Text("Record Screen & audio"),
                  onPressed: () => startScreenRecord(true),
                ),
              ),
            if (_recordingState == RecordingState.recording)
              Center(
                child: ElevatedButton(
                  child: Text("Pause Record"),
                  onPressed: () => pauseScreenRecord(),
                ),
              ),
            if (_recordingState == RecordingState.recording)
              Center(
                child: ElevatedButton(
                  child: Text("Stop Record"),
                  onPressed: () => stopScreenRecord(),
                ),
              ),
            if (_recordingState == RecordingState.paused)
              Center(
                child: ElevatedButton(
                  child: Text("Resume Record"),
                  onPressed: () => resumeScreenRecord(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  startScreenRecord(bool audio) async {
    bool start = false;

    if (audio) {
      start = await FlutterScreenRecording.startRecordScreenAndAudio(
        "Title",
        titleNotification: "titleNotification",
        messageNotification: "messageNotification",
      );
    } else {
      start = await FlutterScreenRecording.startRecordScreen(
        "Title",
        titleNotification: "titleNotification",
        messageNotification: "messageNotification",
      );
    }

    if (start) {
      setState(() => _recordingState = RecordingState.recording);
    }

    return start;
  }

  stopScreenRecord() async {
    String path = await FlutterScreenRecording.stopRecordScreen;
    setState(() {
      _recordingState = RecordingState.initial;
    });
    print("Opening video");
    print(path);
    OpenFile.open(path);
  }

  pauseScreenRecord() async {
    await FlutterScreenRecording.pauseRecordScreen();
    setState(() => _recordingState = RecordingState.paused);
  }

  resumeScreenRecord() async {
    await FlutterScreenRecording.resumeRecordScreen();
    setState(() => _recordingState = RecordingState.recording);
  }
}
