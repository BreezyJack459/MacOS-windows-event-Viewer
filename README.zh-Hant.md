# 🪟 Windows Event Log Viewer

Windows Event Log Viewer 是一款原生 macOS 工具，讓你在無需啟動 Windows 虛擬機的情況下，直接開啟、搜尋與檢視 Windows 事件記錄檔。本程式使用 SwiftUI 打造，並內建輕量解析函式庫，可讀取 Windows EVTX 記錄檔、Windows Event XML 匯出檔，以及純文字記錄檔。

本應用程式專為 IT 支援人員、系統管理員、安全分析師與工程師設計，讓他們能夠在 Mac 上檢查 Windows 記錄檔。你可以開啟事件記錄檔、依嚴重性篩選、跨事件欄位搜尋，並在可讀的詳細資訊面板中檢視所選記錄。

## ✨ 功能特色

- 📂 直接在 macOS 上開啟 Windows `.evtx` 檔案
- 📄 解析 Windows Event XML 匯出檔
- 📃 讀取純文字、`.log` 與 `.json` 檔案作為簡易事件列
- 🔍 跨提供者（Provider）、事件 ID、頻道（Channel）、電腦名稱、訊息、記錄 ID 與原始文字進行搜尋
- 🔎 依嚴重性篩選事件，包括：重大（Critical）、錯誤（Error）、警告（Warning）、資訊（Information）、稽核成功（Audit Success）、稽核失敗（Audit Failure）、詳細資訊（Verbose）與未知（Unknown）
- 📋 檢視事件中繼資料，如提供者、事件 ID、記錄 ID、頻道、電腦名稱、時間戳記與來源偏移量
- 📝 檢視解碼後的訊息、擷取文字、原始 XML 與解析器備註
- 🖥️ 採用原生 macOS 分割介面，文字可選取以便複製調查細節

## 🛠️ 系統需求

- macOS 13 或以上版本
- Xcode 命令列工具
- Swift 5.9 或以上版本

## 🚀 從原始碼執行

克隆或開啟此儲存庫，然後執行：

```sh
swift test
./script/build_and_run.sh
```

建置腳本會編譯 Swift 套件、在 `dist/` 建立本機 `.app` 套件、視需要產生應用程式圖示，然後啟動應用程式。

你也可以直接建置 Swift 套件：

```sh
swift build --product WinEventLogViewer
```

## 📖 使用方式

1. 啟動 Windows Event Log Viewer 🪟
2. 點擊工具列的 `📂 Open` 按鈕，或使用 `Command-O` 快速鍵
3. 選取 Windows 事件記錄檔，例如 `.evtx` 或 `.xml`
4. 使用搜尋欄位尋找相關事件 🔍
5. 使用嚴重性選單縮小事件列表範圍 🔎
6. 選取事件以檢視其訊息、中繼資料、擷取文字與解析器備註

## 📦 封裝

建立發布用應用程式套件：

```sh
./script/build_and_run.sh --package
```

建立 DMG 安裝映像檔：

```sh
./script/create_dmg.sh
```

DMG 腳本會建置發布版應用程式、將應用程式與 Applications 捷徑一併安排、寫入 Finder 版面配置中繼資料，並驗證最終磁碟映像檔。

### macOS Gatekeeper 注意事項

此應用程式採用**臨時簽署**（未使用付費的 Apple Developer ID）。當你從 GitHub 下載 DMG 時，macOS 可能會顯示安全性警告。這對於在 App Store 外分發的開源應用程式來說是正常的。

**開啟應用程式的方法：**

1. 將 `WinEventLogViewer.app` 拖曳到**應用程式**資料夾。
2. **按右鍵**點擊應用程式圖示，選擇**開啟**。
3. 在對話框中點擊**開啟**。

或者，在安裝後於終端機執行：

```sh
xattr -cr /Applications/WinEventLogViewer.app
```

之後即可正常雙擊開啟。

## 📁 專案結構

```text
Sources/
  EventLogCore/          核心事件記錄模型與解析器
  WinEventLogViewer/     SwiftUI macOS 應用程式
Tests/
  EventLogCoreTests/     解析器測試
Assets/                  應用程式圖示與 DMG 美術素材
script/                  建置、執行、圖示與 DMG 腳本
```

## 📥 支援的輸入格式

| 格式 | 說明 |
| --- | --- |
| `.evtx` | Windows 事件記錄檔。在可行的情況下從 EVTX Binary XML 解碼記錄，無法解碼時則以可讀文字擷取作為備援 |
| `.xml` | Windows Event XML 匯出檔 |
| `.txt`, `.log`, `.json` | 以純文字事件列方式解析，供快速檢閱 |

## 🧑‍💻 開發

執行測試套件：

```sh
swift test
```

解析器測試涵蓋 Windows Event XML 欄位擷取、Windows FILETIME 轉換、純文字解析，以及基礎 EVTX 記錄偵測。

## 📝 備註

EVTX 是一種複雜的二進位格式。本應用程式專注於實用的本機檢視，當事件無法完整解碼時，會保留擷取的原始文字或解析器備註以便檢視。

---

[English Version](README.md)
