# MadTunes，一款 macOS 上用於檔案響度測量的工具。 #

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/madtunes/id6760667980)

MadTunes 是一款面向發燒友與音樂製作人的本地音樂播放器，採用經典 iTunes 11 風格的格狀瀏覽體驗，提供準確、純淨的高保真音訊播放。

> 請見下方「Description」章節。

![MadTunes](./Screenshots/Screenshot-Grid.avif)

MadTunes 程式碼以 GNU Affero General Public License 第 3 版（AGPLv3）授權釋出，請參閱 `LICENSE`。

**由專案維護者發行的預編譯二進位檔與建置產物採非商業授權。** 未經明確書面許可，不得將這些預編譯二進位檔用於商業用途；詳見 `LICENSE-BINARY`。

另有一項僅適用於 Apple Inc. 的有限例外，僅涵蓋本倉庫內「可以縱向捲動的 Album Grid View Implementation」；詳見 `LICENSES/APPLE-EXCEPTION.md`。任何「可以橫向捲動的 Album Grid View Implementation」均不在此豁免範圍內。

## 二進位檔 ##

本專案不提供任何版本的二進位檔。

你需自行編譯二進位檔或於 Mac App Store 購買。

收費並非強制，因為你始終可以自行編譯；不過若你能購買 App Store 版本，將有助於支援開發與維護。

### 如何編譯 ###

建議使用 Xcode 26 與 Swift 6.2 進行編譯。Apple 常將最新工具鏈視為編譯現代 Xcode 專案的硬性需求。

## Description ##

**為何是 MadTunes？**

身為音樂創作者，你需要能夠準確呈現混音細節的播放工具。經過 100 多次嚴苛測試驗證，唯有系統內建的 AVPlayer 能在 macOS 上確保最佳音質。MadTunes 建構在此基礎上，忠實還原原始音訊，不添加額外音效處理，讓你聽見真正的錄音室級音色。

**主要特色：**

• **廣泛格式支援** — MP3、FLAC、AAC、WAV、AIFF、Ogg Vorbis、Opus，以及更多主流音訊格式（僅限音訊檔案）；
• **無縫循環播放** — 專為可循環音訊設計，銜接處無縫過渡；
• **精準立體聲** — 忠實還原原始混音，無 HRTF 干擾；
• **強大鍵盤導航** — 完整鍵盤支援，從格狀瀏覽到播放佇列管理皆可無滑鼠操作；
• **智慧搜尋與篩選** — 關鍵字搜尋 + 三欄級聯篩選（類型/演出者/專輯）；
• **彈性播放佇列** — 拖曳調整順序、播放下一首、洗牌、完整播放控制；
• **播放清單管理** — 建立個人播放清單，整理你的音樂收藏；
• **經典格狀佈局** — 2012 年末 iTunes 11 風格專輯格狀介面，自 macOS 10.15 Catalina 後你一直懷念的：點擊展開、雙擊播放，直覺又高效。

**針對 macOS 最佳化：**

• 內建系統原生 Apple AVPlayer 核心 — 經過 100 多次測試驗證以確保 macOS 上最佳音質；
• 自適應 HAL 緩衝以消除音訊抖動；
• 安全範圍書籤（Security-scoped bookmarks）確保檔案存取持久性；
• 原生 SwiftUI 介面，具流暢動畫與 Liquid Glass 特效；
• 完整支援 macOS 15 Sequoia 及以上版本。

MadTunes 不蒐集任何使用者資料。所有音樂檔案均在本機處理—你的隱私受到完全保護。

**支援格式：** MP3、FLAC、AAC、M4A、WAV、AIFF、Ogg Vorbis、Opus、CAF

> CoreAudio 可能會隨 macOS 版本支援新增格式。若有可在 MadTunes 中實作的新格式，歡迎提出 issue。

## 安裝 ##
你可以從 Xcode 專案自行編譯執行檔，或於 Mac App Store 購買。

## 開發動機

筆者曾長期使用 Foobar 2000 for macOS。然而，在使用超過四年後，才意識到其音訊表現存在明顯問題。作為一名樂曲創作者，筆者也嘗試為自己的作品進行混音。然而，自己的混音經常被批評「很糟」，但在該播放器中聆聽時，卻始終難以分辨自己作品與市售配樂專輯在混音品質上的差距。長期以來，這種錯誤的聽覺參考讓筆者無法準確理解專業混音的聲音特徵，也因此難以吸引客戶，不得不一邊維持創作，一邊兼職學習編程、以此作為第二條收入途徑。直到後來接手 R128x 這款音訊響度分析工具的維護，在為其新增聆聽功能時，筆者才第一次意識到：原來一台普通的 Mac，其音質竟然可以如此優秀。也正是在那一刻，筆者才意識到自己多年來被那款播放器誤導，因而震怒。MadTunes 這個名字既是 Mad + Tunes，也帶有「媽的Tunes」的諧音，正是為了表達這種情緒。

> 閉源免費軟體是最讓我覺得不舒服的：開發者免費提供了，證明開發者沒有任何義務及時地修正任何可能的軟體缺陷與體驗不良。其他人想給意見的話，哪怕自己會寫程式，也只能給出小白一樣的功能請求或故障提報，然後事態的發展就只能看臉，完全沒有任何主觀能動性可期。稍微急切一點的話，就會被認為是伸手黨、可能會因此而在社群被群訐。所以我只能重寫一個同類軟體來開源。然後這樣重寫出來反而可能會被視為敵意、從而招來敵意。

## 理念

MadTunes 的音訊播放功能仰仗於 AVPlayer 這個系統元件來實施，且自身不具備 DSP 處理功能。這可以讓整個 pipeline 的失真做到最小。但使用者仍可以使用 audio routing driver 將音聲輸出訊號駁接到諸如 Apple MainStage 這樣的專業 DSP Rack App 上。

雖然 MadTunes 的 UI 操作體驗（限 macOS 以及滿版顯示的 iPad）在某些方面與 2012 年推出的 iTunes 11 有些相似，但其設計目標與 Apple Music / iTunes 面向的消費市場完全不同。經 BlackHole 回錄互消測試實測：在播放電平一致的前提下，Apple Music 對同一立體聲檔案的播放輸出與 MadTunes 互消至 -96.9dBFS——兩者走的是同一條 CoreAudio 路徑，都不對訊號染色。實際差異在行為而非音質：MadTunes 不施加任何 DSP、也不內建音量正規化，因此需要分析專輯混音特徵的學習者聽到的即是混音原貌。此外，一些音訊素材（例如遊戲或環境音樂）在設計時本身就可以首尾無縫 loop。但在許多播放器中，單曲循環播放時往往會在銜接點出現不到一秒的延時中斷，打斷整個樂曲的 Loop 節拍。MadTunes 在開發時也針對這類情況進行了專門處理，以確保真正的「不會被打斷節奏的」循環播放。

至於 iPhone 版面以及 iPad 小型視窗顯示的版面的 UI 設計，則是致敬 Windows Phone 7 / 8 的 UI 設計語言（也是 2012 年流行的事物）。

## 技術註腳

mac 寫 audiophile audio player 只能用 AVPlayer (源自系統內建的 AVFoundation Framework)。AVAudioEngine 無法達到同樣的播放傳真品質。這是筆者這邊在開發過程中經過超過百次的 trial and error 之後得出的結論。測試用樂曲或專輯包括：

- Brian Tyler《Call of Duty: Modern Warfare 3 (2011) Soundtrack》
- 加藤達也《食戟創真OST》
- 梁靜如《勇氣》
- FLOW《Go!!! & Sign》
- Zutomayo《勘ぐれい》
- 方順吉（所有由張翊華負責混音的專輯）

另：請避免在 1 倍速播放時將 `AVPlayerItem.audioTimePitchAlgorithm` 設為 `.spectral`。雖然文件指出該演算法僅在 `rate != 1.0` 時「啟用」，但強制指定 `.spectral` 會讓額外的 DSP 處理環節留在訊號鏈中，使 `rate == 1.0` 時本應生效的直通 (bypass) 失效。開發期間的 A/B 聽測確認：此設定會可聞地削弱瞬態還原——樂器在高音量下失去瞬態的「呼吸感」。建議維持 macOS 12+ 預設的 `.timeDomain` 設定以確保音質。

> 上述註記與 Foobar2000 for macOS **無關**。

$ EOF.
