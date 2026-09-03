#include "flutter_window.h"

#include <shellapi.h>
#include <wininet.h>

#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {

constexpr wchar_t kInternetSettingsKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings";
constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kRunValue[] = L"MobileTinaVPN";
constexpr UINT kTrayMessage = WM_APP + 42;
constexpr UINT kTrayShow = 41001;
constexpr UINT kTrayExit = 41002;

std::wstring Utf16FromUtf8(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                       value.data(),
                                       static_cast<int>(value.size()), nullptr, 0);
  if (size <= 0) {
    return std::wstring();
  }
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), result.data(), size);
  return result;
}

std::string Utf8FromUtf16Value(const std::wstring& value) {
  if (value.empty()) {
    return std::string();
  }
  const int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
                                       value.data(),
                                       static_cast<int>(value.size()), nullptr, 0,
                                       nullptr, nullptr);
  if (size <= 0) {
    return std::string();
  }
  std::string result(size, '\0');
  WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), result.data(), size,
                      nullptr, nullptr);
  return result;
}

std::wstring ReadRegistryString(HKEY key, const wchar_t* name) {
  DWORD type = 0;
  DWORD byte_count = 0;
  if (RegQueryValueExW(key, name, nullptr, &type, nullptr, &byte_count) !=
          ERROR_SUCCESS ||
      (type != REG_SZ && type != REG_EXPAND_SZ) || byte_count == 0) {
    return std::wstring();
  }
  std::vector<wchar_t> buffer((byte_count / sizeof(wchar_t)) + 1, L'\0');
  if (RegQueryValueExW(key, name, nullptr, nullptr,
                       reinterpret_cast<LPBYTE>(buffer.data()),
                       &byte_count) != ERROR_SUCCESS) {
    return std::wstring();
  }
  return std::wstring(buffer.data());
}

bool WriteRegistryString(HKEY key, const wchar_t* name,
                         const std::wstring& value) {
  if (value.empty()) {
    const LONG status = RegDeleteValueW(key, name);
    return status == ERROR_SUCCESS || status == ERROR_FILE_NOT_FOUND;
  }
  const DWORD bytes = static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t));
  return RegSetValueExW(key, name, 0, REG_SZ,
                        reinterpret_cast<const BYTE*>(value.c_str()), bytes) ==
         ERROR_SUCCESS;
}

const flutter::EncodableValue* FindArgument(
    const flutter::EncodableMap& arguments, const char* key) {
  const auto iterator = arguments.find(flutter::EncodableValue(key));
  return iterator == arguments.end() ? nullptr : &iterator->second;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  ConfigurePlatformChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  CreateTrayIcon();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveTrayIcon();
  platform_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_CLOSE:
      if (!quit_requested_) {
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
      break;
    case kTrayMessage:
      if (lparam == WM_LBUTTONDBLCLK) {
        ShowMainWindow();
        return 0;
      }
      if (lparam == WM_RBUTTONUP || lparam == WM_CONTEXTMENU) {
        POINT cursor{};
        GetCursorPos(&cursor);
        HMENU menu = CreatePopupMenu();
        AppendMenuW(menu, MF_STRING, kTrayShow, L"Show MobileTinaVPN");
        AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(menu, MF_STRING, kTrayExit, L"Exit");
        SetForegroundWindow(hwnd);
        TrackPopupMenu(menu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN | TPM_LEFTALIGN,
                       cursor.x, cursor.y, 0, hwnd, nullptr);
        DestroyMenu(menu);
        return 0;
      }
      break;
    case WM_COMMAND:
      if (LOWORD(wparam) == kTrayShow) {
        ShowMainWindow();
        return 0;
      }
      if (LOWORD(wparam) == kTrayExit) {
        RequestDartExit();
        return 0;
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::ConfigurePlatformChannel() {
  platform_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.mobiletina.vpn/windows",
          &flutter::StandardMethodCodec::GetInstance());

  platform_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "getSystemProxy") {
          HKEY key = nullptr;
          DWORD enabled = 0;
          DWORD size = sizeof(enabled);
          if (RegOpenKeyExW(HKEY_CURRENT_USER, kInternetSettingsKey, 0,
                            KEY_QUERY_VALUE, &key) != ERROR_SUCCESS) {
            result->Error("registry", "Unable to read Windows proxy settings");
            return;
          }
          RegQueryValueExW(key, L"ProxyEnable", nullptr, nullptr,
                           reinterpret_cast<LPBYTE>(&enabled), &size);
          const std::string server =
              Utf8FromUtf16Value(ReadRegistryString(key, L"ProxyServer"));
          const std::string override_value =
              Utf8FromUtf16Value(ReadRegistryString(key, L"ProxyOverride"));
          RegCloseKey(key);
          flutter::EncodableMap response;
          response[flutter::EncodableValue("enabled")] =
              flutter::EncodableValue(enabled != 0);
          response[flutter::EncodableValue("server")] =
              flutter::EncodableValue(server);
          response[flutter::EncodableValue("override")] =
              flutter::EncodableValue(override_value);
          result->Success(flutter::EncodableValue(response));
          return;
        }

        if (call.method_name() == "setSystemProxy") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(
              call.arguments());
          if (arguments == nullptr) {
            result->Error("arguments", "Missing proxy settings");
            return;
          }
          const auto* enabled_value = FindArgument(*arguments, "enabled");
          const auto* server_value = FindArgument(*arguments, "server");
          const auto* override_value = FindArgument(*arguments, "override");
          const auto* enabled = enabled_value == nullptr
                                    ? nullptr
                                    : std::get_if<bool>(enabled_value);
          const auto* server = server_value == nullptr
                                   ? nullptr
                                   : std::get_if<std::string>(server_value);
          const auto* bypass = override_value == nullptr
                                   ? nullptr
                                   : std::get_if<std::string>(override_value);
          if (enabled == nullptr || server == nullptr || bypass == nullptr) {
            result->Error("arguments", "Invalid proxy settings");
            return;
          }
          HKEY key = nullptr;
          if (RegOpenKeyExW(HKEY_CURRENT_USER, kInternetSettingsKey, 0,
                            KEY_SET_VALUE, &key) != ERROR_SUCCESS) {
            result->Error("registry", "Unable to update Windows proxy settings");
            return;
          }
          const DWORD proxy_enabled = *enabled ? 1 : 0;
          const bool ok =
              RegSetValueExW(key, L"ProxyEnable", 0, REG_DWORD,
                              reinterpret_cast<const BYTE*>(&proxy_enabled),
                              sizeof(proxy_enabled)) == ERROR_SUCCESS &&
              WriteRegistryString(key, L"ProxyServer", Utf16FromUtf8(*server)) &&
              WriteRegistryString(key, L"ProxyOverride", Utf16FromUtf8(*bypass));
          RegCloseKey(key);
          InternetSetOptionW(nullptr, INTERNET_OPTION_SETTINGS_CHANGED, nullptr,
                             0);
          InternetSetOptionW(nullptr, INTERNET_OPTION_REFRESH, nullptr, 0);
          if (!ok) {
            result->Error("registry", "Windows rejected the proxy settings");
          } else {
            result->Success();
          }
          return;
        }

        if (call.method_name() == "setAutoStart") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(
              call.arguments());
          const auto* enabled_value =
              arguments == nullptr ? nullptr : FindArgument(*arguments, "enabled");
          const auto* path_value = arguments == nullptr
                                       ? nullptr
                                       : FindArgument(*arguments, "executable");
          const auto* enabled = enabled_value == nullptr
                                    ? nullptr
                                    : std::get_if<bool>(enabled_value);
          const auto* executable = path_value == nullptr
                                       ? nullptr
                                       : std::get_if<std::string>(path_value);
          if (enabled == nullptr || executable == nullptr) {
            result->Error("arguments", "Invalid auto-start settings");
            return;
          }
          HKEY key = nullptr;
          if (RegCreateKeyExW(HKEY_CURRENT_USER, kRunKey, 0, nullptr, 0,
                              KEY_SET_VALUE, nullptr, &key, nullptr) !=
              ERROR_SUCCESS) {
            result->Error("registry", "Unable to update Windows startup");
            return;
          }
          LONG status = ERROR_SUCCESS;
          if (*enabled) {
            const std::wstring command = L"\"" + Utf16FromUtf8(*executable) +
                                         L"\" --startup";
            status = RegSetValueExW(
                key, kRunValue, 0, REG_SZ,
                reinterpret_cast<const BYTE*>(command.c_str()),
                static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
          } else {
            status = RegDeleteValueW(key, kRunValue);
            if (status == ERROR_FILE_NOT_FOUND) {
              status = ERROR_SUCCESS;
            }
          }
          RegCloseKey(key);
          if (status == ERROR_SUCCESS) {
            result->Success();
          } else {
            result->Error("registry", "Windows rejected the startup setting");
          }
          return;
        }

        if (call.method_name() == "showWindow") {
          ShowMainWindow();
          result->Success();
          return;
        }

        if (call.method_name() == "openUrl") {
          const auto* value =
              std::get_if<std::string>(call.arguments());
          if (value == nullptr || value->rfind("https://", 0) != 0) {
            result->Error("arguments", "Only HTTPS links are supported");
            return;
          }
          const std::wstring target = Utf16FromUtf8(*value);
          const auto status = reinterpret_cast<INT_PTR>(ShellExecuteW(
              GetHandle(), L"open", target.c_str(), nullptr, nullptr,
              SW_SHOWNORMAL));
          if (status <= 32) {
            result->Error("shell", "Windows could not open the link");
          } else {
            result->Success();
          }
          return;
        }

        if (call.method_name() == "quitApplication") {
          quit_requested_ = true;
          RemoveTrayIcon();
          result->Success();
          PostMessageW(GetHandle(), WM_CLOSE, 0, 0);
          return;
        }

        result->NotImplemented();
      });
}

void FlutterWindow::CreateTrayIcon() {
  NOTIFYICONDATAW data{};
  data.cbSize = sizeof(data);
  data.hWnd = GetHandle();
  data.uID = 1;
  data.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  data.uCallbackMessage = kTrayMessage;
  data.hIcon = static_cast<HICON>(
      LoadImageW(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON),
                 IMAGE_ICON, 0, 0, LR_DEFAULTSIZE | LR_SHARED));
  wcscpy_s(data.szTip, L"MobileTinaVPN");
  tray_icon_created_ = Shell_NotifyIconW(NIM_ADD, &data) == TRUE;
}

void FlutterWindow::RemoveTrayIcon() {
  if (!tray_icon_created_) {
    return;
  }
  NOTIFYICONDATAW data{};
  data.cbSize = sizeof(data);
  data.hWnd = GetHandle();
  data.uID = 1;
  Shell_NotifyIconW(NIM_DELETE, &data);
  tray_icon_created_ = false;
}

void FlutterWindow::ShowMainWindow() {
  ShowWindow(GetHandle(), SW_RESTORE);
  SetForegroundWindow(GetHandle());
}

void FlutterWindow::RequestDartExit() {
  if (platform_channel_) {
    platform_channel_->InvokeMethod(
        "trayExit", std::make_unique<flutter::EncodableValue>());
  }
}
