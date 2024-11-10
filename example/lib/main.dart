import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:gal/gal.dart';
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
  String recordingPath = "";

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
    final tempDir = await Directory.systemTemp.createTemp();
    recordingPath =
        '${tempDir.path}/screen_record_${DateTime.now().millisecondsSinceEpoch}.mp4';
    print("Recording path: $recordingPath");
    if (audio) {
      start = await FlutterScreenRecording.startRecordScreenAndAudio(
        recordingPath,
        titleNotification: "titleNotification",
        messageNotification: "messageNotification",
      );
    } else {
      start = await FlutterScreenRecording.startRecordScreen(
        recordingPath,
        titleNotification: "titleNotification",
        messageNotification: "messageNotification",
      );
    }

    setState(() => _recordingState = RecordingState.recording);

    return start;
  }

  stopScreenRecord() async {
    await FlutterScreenRecording.stopRecordScreen;
    setState(() {
      _recordingState = RecordingState.initial;
    });
    // check for permission and save video to gallery
    final isGranted = await Gal.hasAccess();
    if (!isGranted) {
      final grantResult = await Gal.requestAccess();
      print("Grant result: $grantResult");
    }
    await Gal.putVideo(recordingPath);
    print("Saved video to gallery");
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
