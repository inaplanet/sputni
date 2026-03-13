#include "native_windows_recorder.h"

#include <algorithm>
#include <filesystem>
#include <future>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.Capture.h>
#include <winrt/Windows.Media.Editing.h>
#include <winrt/Windows.Media.MediaProperties.h>
#include <winrt/Windows.Media.Transcoding.h>
#include <winrt/Windows.Storage.FileProperties.h>
#include <winrt/Windows.Storage.h>

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResult;
using winrt::Windows::Media::Capture::MediaCapture;
using winrt::Windows::Media::Capture::MediaCaptureInitializationSettings;
using winrt::Windows::Media::Capture::MediaCaptureSharingMode;
using winrt::Windows::Media::Capture::StreamingCaptureMode;
using winrt::Windows::Media::Editing::MediaClip;
using winrt::Windows::Media::Editing::MediaComposition;
using winrt::Windows::Media::Editing::MediaTrimmingPreference;
using winrt::Windows::Media::MediaProperties::MediaEncodingProfile;
using winrt::Windows::Media::MediaProperties::VideoEncodingQuality;
using winrt::Windows::Media::Transcoding::TranscodeFailureReason;
using winrt::Windows::Storage::CreationCollisionOption;
using winrt::Windows::Storage::StorageFile;
using winrt::Windows::Storage::StorageFolder;

namespace {

std::string GetStringArgument(const EncodableMap& arguments,
                              const char* key) {
  const auto iterator = arguments.find(EncodableValue(key));
  if (iterator == arguments.end()) {
    throw std::runtime_error("Missing required argument.");
  }

  const auto* value = std::get_if<std::string>(&iterator->second);
  if (value == nullptr || value->empty()) {
    throw std::runtime_error("Recording path is invalid.");
  }

  return *value;
}

bool GetBoolArgument(const EncodableMap& arguments,
                     const char* key,
                     bool default_value) {
  const auto iterator = arguments.find(EncodableValue(key));
  if (iterator == arguments.end()) {
    return default_value;
  }

  const auto* value = std::get_if<bool>(&iterator->second);
  return value == nullptr ? default_value : *value;
}

int32_t GetIntArgument(const EncodableMap& arguments,
                       const char* key,
                       int32_t default_value) {
  const auto iterator = arguments.find(EncodableValue(key));
  if (iterator == arguments.end()) {
    return default_value;
  }

  if (const auto* value = std::get_if<int32_t>(&iterator->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int64_t>(&iterator->second)) {
    return static_cast<int32_t>(*value);
  }
  return default_value;
}

StorageFile CreateOutputFile(const std::string& path) {
  const auto utf16_path = winrt::to_hstring(path);
  const std::filesystem::path file_path(utf16_path.c_str());
  const auto parent_path = file_path.parent_path();
  const auto file_name = file_path.filename().wstring();

  if (parent_path.empty() || file_name.empty()) {
    throw std::runtime_error("Recording path is invalid.");
  }

  const auto folder =
      StorageFolder::GetFolderFromPathAsync(parent_path.wstring()).get();
  return folder
      .CreateFileAsync(file_name, CreationCollisionOption::ReplaceExisting)
      .get();
}

std::string DescribeException(const winrt::hresult_error& error) {
  const auto message = winrt::to_string(error.message());
  return message.empty() ? "Windows recorder failed." : message;
}

}  // namespace

NativeWindowsRecorder::~NativeWindowsRecorder() {
  Reset();
}

void NativeWindowsRecorder::HandleMethodCall(
    const MethodCall<EncodableValue>& call,
    std::unique_ptr<MethodResult<EncodableValue>> result) {
  const auto& method_name = call.method_name();

  if (method_name == "isSupported") {
    result->Success(EncodableValue(true));
    return;
  }

  if (method_name == "startRecording") {
    const auto* arguments = std::get_if<EncodableMap>(call.arguments());
    if (arguments == nullptr) {
      result->Error("invalid_arguments", "Recording arguments are missing.");
      return;
    }

    try {
      const auto path = GetStringArgument(*arguments, "path");
      const auto include_audio =
          GetBoolArgument(*arguments, "includeAudio", false);
      StartRecording(path, include_audio);
      result->Success();
    } catch (const winrt::hresult_error& error) {
      result->Error("start_failed", DescribeException(error));
    } catch (const std::exception& error) {
      result->Error("start_failed", error.what());
    }
    return;
  }

  if (method_name == "stopRecording") {
    try {
      result->Success(EncodableValue(StopRecording()));
    } catch (const winrt::hresult_error& error) {
      result->Error("stop_failed", DescribeException(error));
    } catch (const std::exception& error) {
      result->Error("stop_failed", error.what());
    }
    return;
  }

  if (method_name == "composeFrameSequence") {
    const auto* arguments = std::get_if<EncodableMap>(call.arguments());
    if (arguments == nullptr) {
      result->Error("invalid_arguments",
                    "Frame composition arguments are missing.");
      return;
    }

    try {
      const auto input_directory =
          GetStringArgument(*arguments, "inputDirectory");
      const auto output_path = GetStringArgument(*arguments, "outputPath");
      const auto frame_rate = GetIntArgument(*arguments, "frameRate", 5);
      ComposeFrameSequence(input_directory, output_path, frame_rate);
      result->Success();
    } catch (const winrt::hresult_error& error) {
      result->Error("compose_failed", DescribeException(error));
    } catch (const std::exception& error) {
      result->Error("compose_failed", error.what());
    }
    return;
  }

  result->NotImplemented();
}

void NativeWindowsRecorder::StartRecording(const std::string& path,
                                           bool include_audio) {
  if (is_recording_) {
    throw std::runtime_error("Native recorder is already active.");
  }

  try {
    StartRecordingAttempt(path, include_audio);
  } catch (...) {
    Reset();
    if (!include_audio) {
      throw;
    }

    // Windows camera capture is more tolerant than shared mic capture.
    // Retry without audio so recording still works when microphone sharing
    // fails under the active WebRTC session.
    StartRecordingAttempt(path, false);
  }
}

void NativeWindowsRecorder::StartRecordingAttempt(const std::string& path,
                                                  bool include_audio) {
  output_file_ = CreateOutputFile(path);

  MediaCaptureInitializationSettings settings;
  settings.StreamingCaptureMode(include_audio
                                    ? StreamingCaptureMode::AudioAndVideo
                                    : StreamingCaptureMode::Video);
  settings.SharingMode(MediaCaptureSharingMode::SharedReadOnly);

  media_capture_ = MediaCapture();
  media_capture_.InitializeAsync(settings).get();

  auto profile = MediaEncodingProfile::CreateMp4(VideoEncodingQuality::Auto);
  media_capture_.StartRecordToStorageFileAsync(profile, output_file_).get();
  is_recording_ = true;
}

std::string NativeWindowsRecorder::StopRecording() {
  if (!is_recording_) {
    return "";
  }

  try {
    media_capture_.StopRecordAsync().get();
    const auto output_path = winrt::to_string(output_file_.Path());
    Reset();
    return output_path;
  } catch (...) {
    Reset();
    throw;
  }
}

void NativeWindowsRecorder::Reset() {
  if (media_capture_ != nullptr) {
    try {
      media_capture_.Close();
    } catch (...) {
    }
  }

  media_capture_ = nullptr;
  output_file_ = nullptr;
  is_recording_ = false;
}

void NativeWindowsRecorder::ComposeFrameSequence(
    const std::string& input_directory,
    const std::string& output_path,
    int32_t frame_rate) {
  std::promise<void> completion;
  auto future = completion.get_future();

  std::thread worker([&completion, input_directory, output_path, frame_rate]() {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    try {
      const auto folder =
          StorageFolder::GetFolderFromPathAsync(
              winrt::to_hstring(input_directory))
              .get();
      const auto files = folder.GetFilesAsync().get();

      std::vector<StorageFile> frame_files;
      const uint32_t file_count = files.Size();
      frame_files.reserve(file_count);
      for (uint32_t index = 0; index < file_count; ++index) {
        const auto file = files.GetAt(index);
        const auto name = winrt::to_string(file.Name());
        if (name.size() >= 4 && name.substr(name.size() - 4) == ".png") {
          frame_files.push_back(file);
        }
      }

      if (frame_files.empty()) {
        throw std::runtime_error("No PNG frames were captured.");
      }

      std::sort(frame_files.begin(), frame_files.end(),
                [](const StorageFile& a, const StorageFile& b) {
                  return a.Name() < b.Name();
                });

      MediaComposition composition;
      const int32_t safe_frame_rate = frame_rate <= 0 ? 5 : frame_rate;
      const auto frame_duration =
          std::chrono::milliseconds(1000 / safe_frame_rate);

      for (const auto& file : frame_files) {
        composition.Clips().Append(
            MediaClip::CreateFromImageFileAsync(file, frame_duration).get());
      }

      const auto output_file = CreateOutputFile(output_path);
      const auto first_frame_properties =
          frame_files.front().Properties().GetImagePropertiesAsync().get();
      auto profile = MediaEncodingProfile::CreateMp4(VideoEncodingQuality::HD720p);
      profile.Video().Width(first_frame_properties.Width());
      profile.Video().Height(first_frame_properties.Height());
      profile.Video().FrameRate().Numerator(safe_frame_rate);
      profile.Video().FrameRate().Denominator(1);
      profile.Video().PixelAspectRatio().Numerator(1);
      profile.Video().PixelAspectRatio().Denominator(1);

      const auto render_result = composition
                                     .RenderToFileAsync(
                                         output_file,
                                         MediaTrimmingPreference::Precise,
                                         profile)
                                     .get();
      if (render_result != TranscodeFailureReason::None) {
        throw std::runtime_error("Unable to encode Windows recording to MP4.");
      }

      const auto output_properties = output_file.GetBasicPropertiesAsync().get();
      if (output_properties.Size() == 0) {
        throw std::runtime_error("Windows recording encoder produced an empty MP4 file.");
      }

      completion.set_value();
    } catch (...) {
      completion.set_exception(std::current_exception());
    }
    winrt::uninit_apartment();
  });

  worker.join();
  future.get();
}
