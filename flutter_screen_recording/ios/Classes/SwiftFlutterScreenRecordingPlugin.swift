import Flutter
import Photos
import ReplayKit
import UIKit

public class SwiftFlutterScreenRecordingPlugin: NSObject, FlutterPlugin {

  let recorder = RPScreenRecorder.shared()

  var videoOutputURL: URL?
  var videoWriter: AVAssetWriter?

  var audioInput: AVAssetWriterInput!
  var videoWriterInput: AVAssetWriterInput?
  var nameVideo: String = ""
  var recordAudio: Bool = false
  var myResult: FlutterResult?
  let screenSize = UIScreen.main.bounds

  private var recordingCount: Int = 0
  private var currentRecordingPath: String?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_screen_recording", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterScreenRecordingPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    myResult = result
    if call.method == "startRecordScreen" {
      let args = call.arguments as? [String: Any]

      self.nameVideo = (args?["name"] as? String)!
      startRecording()
      result(true)
    } else if call.method == "pauseRecordScreen" {
      pauseRecording()
    } else if call.method == "resumeRecordScreen" {
      resumeRecording()
      result(true)
    } else if call.method == "stopRecordScreen" {
        stopRecording(isPause: false)
    }
  }

  @objc func startRecording() {
    let temporaryPath = URL(
      fileURLWithPath: (nameVideo as NSString).deletingLastPathComponent, isDirectory: true)
    try! FileManager.default.createDirectory(
      at: temporaryPath, withIntermediateDirectories: true,
      attributes: nil)

    var videoOutputURL: URL?
    if #available(iOS 14.0, *) {
      videoOutputURL = temporaryPath.appendingPathComponent(
        "\(recordingCount).mp4", conformingTo: .movie)
    } else {
      // Fallback on earlier versions
    }
    recordingCount += 1

    //Check the file does not already exist by deleting it if it does
    do {
      try FileManager.default.removeItem(at: videoOutputURL!)
    } catch {}

    do {
      try videoWriter = AVAssetWriter(outputURL: videoOutputURL!, fileType: AVFileType.mp4)
    } catch let writerError as NSError {
      print("Error opening video file", writerError)
      videoWriter = nil
      return
    }

    //Create the video settings

    let codec = AVVideoCodecType.h264
    let compressionProperties: [String: Any] = [
      AVVideoAverageBitRateKey: 6_000_000,  // 6 Mbps
      AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
      AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
      AVVideoExpectedSourceFrameRateKey: 30,  // or 30 based on your needs
      AVVideoMaxKeyFrameIntervalKey: 30,  // 1 keyframe per second
    ]
    let videoSettings: [String: Any] = [
      AVVideoCodecKey: codec,
      AVVideoWidthKey: screenSize.width,
      AVVideoHeightKey: screenSize.height,
      AVVideoCompressionPropertiesKey: compressionProperties,
    ]

    let audioOutputSettings: [String: Any] = [
      AVNumberOfChannelsKey: 2,
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: 44100,
    ]

    audioInput = AVAssetWriterInput(
      mediaType: AVMediaType.audio, outputSettings: audioOutputSettings)
    audioInput?.expectsMediaDataInRealTime = true
    videoWriter?.add(audioInput)

    //Create the asset writer input object whihc is actually used to write out the video
    videoWriterInput = AVAssetWriterInput(
      mediaType: AVMediaType.video, outputSettings: videoSettings)
    videoWriterInput?.expectsMediaDataInRealTime = true
    videoWriter?.add(videoWriterInput!)

    //Tell the screen recorder to start capturing and to call the handler
    RPScreenRecorder.shared().isMicrophoneEnabled = true

    RPScreenRecorder.shared().startCapture(
      handler: { (cmSampleBuffer, rpSampleType, error) in
        guard error == nil else {
          //Handle error
          print("Error starting capture")
          self.myResult!(false)
          return
        }

        let currentTimestamp = CMSampleBufferGetPresentationTimeStamp(cmSampleBuffer)

        switch rpSampleType {
        case RPSampleBufferType.video:
          if self.videoWriter?.status == AVAssetWriter.Status.unknown {

            if (self.videoWriter?.startWriting) != nil {
              print("Starting videoWriter")
              self.videoWriter?.startWriting()
              self.videoWriter?.startSession(
                atSourceTime: CMSampleBufferGetPresentationTimeStamp(cmSampleBuffer))
            }
          }

          if self.videoWriter?.status == AVAssetWriter.Status.writing {
            if self.videoWriterInput?.isReadyForMoreMediaData == true {
              if self.videoWriterInput?.append(cmSampleBuffer) == false {
                print("Failed to append video sample buffer")
              }
            }
          }
        case RPSampleBufferType.audioMic:
          if self.audioInput?.isReadyForMoreMediaData == true
            && self.videoWriter?.status == AVAssetWriter.Status.writing
          {
            if self.audioInput?.append(cmSampleBuffer) == false {
              print("Failed to append audio sample buffer")
            }
          }
        case RPSampleBufferType.audioApp:
          return
        default:
          print("Unknown sample \(rpSampleType), skip")
        }
      }) { (error) in
        guard error == nil else {
          //Handle error
          print("Screen record not allowed")
          self.myResult!(false)
          return
        }
      }
  }

  @objc func stopRecording(isPause: Bool) {
    //Stop Recording the screen
    RPScreenRecorder.shared().stopCapture(handler: { (error) in
      print("Stopping recording")
    })

    self.videoWriterInput?.markAsFinished()
    self.audioInput?.markAsFinished()

    self.videoWriter?.finishWriting {
      print("Finished writing video")
      if isPause {
        self.myResult?(true)
      } else {
        self.myResult?("")
      }
    }
  }

  @objc func pauseRecording() {
      stopRecording(isPause: true)
  }

  @objc func resumeRecording() {
    startRecording()
  }

  private func adjustBufferTimestamp(_ buffer: CMSampleBuffer, withOffset offset: CMTime)
    -> CMSampleBuffer
  {
    // Create a new timing info array with adjusted timestamps
    var timingInfo = CMSampleTimingInfo()
    CMSampleBufferGetSampleTimingInfo(buffer, 0, &timingInfo)

    timingInfo.presentationTimeStamp = CMTimeAdd(timingInfo.presentationTimeStamp, offset)
    timingInfo.decodeTimeStamp = CMTimeAdd(timingInfo.decodeTimeStamp, offset)

    // Create a new sample buffer with adjusted timing
    var adjustedBuffer: CMSampleBuffer?
    CMSampleBufferCreateCopyWithNewTiming(
      kCFAllocatorDefault,
      buffer,
      1,
      &timingInfo,
      &adjustedBuffer
    )

    return adjustedBuffer ?? buffer
  }
}
