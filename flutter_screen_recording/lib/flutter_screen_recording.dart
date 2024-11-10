//import 'file:D:/Workspace/flutter_screen_recording/flutter_screen_recording_platform_interface/lib/flutter_screen_recording_platform_interface.dart';
import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_https_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_https_gpl/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_screen_recording_platform_interface/flutter_screen_recording_platform_interface.dart';
import 'package:path/path.dart';

class FlutterScreenRecording {
  static var recordingPath = "";

  static Future<bool> startRecordScreen(String name,
      {String? titleNotification, String? messageNotification}) async {
    try {
      if (titleNotification == null) {
        titleNotification = "";
      }
      if (messageNotification == null) {
        messageNotification = "";
      }
      recordingPath = name;
      await _maybeStartFGS(titleNotification, messageNotification);
      final bool start =
          await FlutterScreenRecordingPlatform.instance.startRecordScreen(
        name,
        notificationTitle: titleNotification,
        notificationMessage: messageNotification,
      );

      return start;
    } catch (err) {
      print("startRecordScreen err");
      print(err);
    }

    return false;
  }

  static Future<bool> startRecordScreenAndAudio(String name,
      {String? titleNotification, String? messageNotification}) async {
    try {
      if (titleNotification == null) {
        titleNotification = "";
      }
      if (messageNotification == null) {
        messageNotification = "";
      }
      recordingPath = name;
      await _maybeStartFGS(titleNotification, messageNotification);
      final bool start = await FlutterScreenRecordingPlatform.instance
          .startRecordScreenAndAudio(
        name,
        notificationTitle: titleNotification,
        notificationMessage: messageNotification,
      );
      return start;
    } catch (err) {
      print("startRecordScreenAndAudio err");
      print(err);
    }
    return false;
  }

  static Future<bool> pauseRecordScreen() async {
    return await FlutterScreenRecordingPlatform.instance.pauseRecordScreen();
  }

  static Future<bool> resumeRecordScreen() async {
    return await FlutterScreenRecordingPlatform.instance.resumeRecordScreen();
  }

  static Future<String> get stopRecordScreen async {
    try {
      await FlutterScreenRecordingPlatform.instance.stopRecordScreen;
      if (!kIsWeb && Platform.isAndroid) {
        FlutterForegroundTask.stopService();
      }
      if (Platform.isIOS) {
        final directory = Directory(recordingPath).parent;
        final files = await directory.list().toList();
        final getFileName = (FileSystemEntity path) =>
            int.tryParse(path.path.split('/').last.split('.').first) ??
            path.statSync().modified.millisecondsSinceEpoch;
        files.sort((a, b) => getFileName(a).compareTo(getFileName(b)));
        print("Files in recording directory ${recordingPath}: ${files}");

        final concatContent =
            files.map((file) => "file '${file.path}'").join('\n');
        final concatPath = join(directory.path, 'concat.txt');
        await File(concatPath).writeAsString(concatContent);
        final command =
            '-f concat -safe 0 -i $concatPath -c copy -y $recordingPath';
        print('Combining video segment with command $command');
        final result = await FFmpegKit.execute(command);
        final returnCode = await result.getReturnCode();
        if (returnCode == ReturnCode.success) {
          return recordingPath;
        } else {
          final output = await result.getOutput();
          print(output);
          return '';
        }
      }
      return '';
    } catch (err) {
      print("stopRecordScreen err");
      print(err);
    }
    return "";
  }

  static _maybeStartFGS(String titleNotification, String messageNotification) {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        FlutterForegroundTask.init(
          androidNotificationOptions: AndroidNotificationOptions(
            channelId: 'notification_channel_id',
            channelName: titleNotification,
            channelDescription: messageNotification,
            channelImportance: NotificationChannelImportance.LOW,
            priority: NotificationPriority.LOW,
            iconData: const NotificationIconData(
              resType: ResourceType.mipmap,
              resPrefix: ResourcePrefix.ic,
              name: 'launcher',
            ),
          ),
          iosNotificationOptions: const IOSNotificationOptions(
            showNotification: true,
            playSound: false,
          ),
          foregroundTaskOptions: const ForegroundTaskOptions(
            interval: 5000,
            autoRunOnBoot: true,
            allowWifiLock: true,
          ),
        );
      }
    } catch (err) {
      print("_maybeStartFGS err");
      print(err);
    }
  }
}
