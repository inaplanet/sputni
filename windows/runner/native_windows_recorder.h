#ifndef RUNNER_NATIVE_WINDOWS_RECORDER_H_
#define RUNNER_NATIVE_WINDOWS_RECORDER_H_

#include <flutter/encodable_value.h>
#include <flutter/method_call.h>
#include <flutter/method_result.h>

#include <memory>
#include <string>
#include <vector>

#include <winrt/Windows.Media.Capture.h>
#include <winrt/Windows.Storage.h>

class NativeWindowsRecorder {
 public:
  NativeWindowsRecorder() = default;
  ~NativeWindowsRecorder();

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  void ComposeFrameSequence(const std::string& input_directory,
                            const std::string& output_path,
                            int32_t frame_rate);
  void StartRecordingAttempt(const std::string& path, bool include_audio);
  void StartRecording(const std::string& path, bool include_audio);
  std::string StopRecording();
  void Reset();

  winrt::Windows::Media::Capture::MediaCapture media_capture_{nullptr};
  winrt::Windows::Storage::StorageFile output_file_{nullptr};
  bool is_recording_ = false;
};

#endif  // RUNNER_NATIVE_WINDOWS_RECORDER_H_
