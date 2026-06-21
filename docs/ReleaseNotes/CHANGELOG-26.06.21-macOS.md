# v26.06.21 (macOS AppKit)

// en

- **MP3 "Album Artist" metadata fix**: Fixed the inability of reading "Album Artist" field from MP3 metadata.
- **SwiftUI canvas measurement patch**: Patched some SwiftUI-related canvas measurement methods to make sure the UI behaves sane on future OS releases.
- **Concurrency fixes**: Fixed some concurrency issues detected thanks to the Swift 6.4 beta compiler. These issues were not discoverable by the Swift 6.3 toolchain (as of Xcode 26.5).
- **ESC key behavior fix**: Fixed some behavioral chaotic issues with ESC key when the metadata sheet presents.
- **Audio playback jitter fix (metadata sheet)**: Fixed the audio playback jitter issue happened on the first time calling the metadata sheet after starting the app.
- **Audio playback jitter fix (predicate config)**: Fixed the audio playback jitter issue happened when calling the predicate configuration sheet of a playlist.

// zh-Hans

- **MP3「专辑艺人」中继资料修复**：修复了无法从 MP3 中继资料中读取「专辑艺人」字段的问题。
- **SwiftUI 画布测量修补**：修补了一些与 SwiftUI 相关的画布测量方法，确保 UI 在未来的操作系统版本上行为正常。
- **并发修复**：修复了一些并发问题（借助 Swift 6.4 beta 编译器的增强检测能力才得以发现，Swift 6.3 工具链（截至 Xcode 26.5）无法侦测到这些问题）。
- **ESC 键行为修复**：修复了中继资料工作表显示时 ESC 键的一些行为混乱问题。
- **音频播放抖动修复（中继资料工作表）**：修复了启动 App 后首次调用中继资料工作表时出现的音频播放抖动问题。
- **音频播放抖动修复（谓词配置）**：修复了调用播放列表的谓词配置工作表时出现的音频播放抖动问题。

// zh-Hant

- **MP3「專輯藝人」中繼資料修正**：修正了無法從 MP3 中繼資料中讀取「專輯藝人」欄位的問題。
- **SwiftUI 畫布測量修補**：修補了一些與 SwiftUI 相關的畫布測量方法，確保 UI 在未來的作業系統版本上行為正常。
- **並行修正**：修正了一些並行問題（借助 Swift 6.4 beta 編譯器的增強偵測能力才得以發現，Swift 6.3 工具鏈（截至 Xcode 26.5）無法偵測到這些問題）。
- **ESC 鍵行為修正**：修正了中繼資料工作表顯示時 ESC 鍵的一些行為混亂問題。
- **音訊播放抖動修正（中繼資料工作表）**：修正了啟動 App 後首次呼叫中繼資料工作表時出現的音訊播放抖動問題。
- **音訊播放抖動修正（述詞配置）**：修正了呼叫播放清單的述詞配置工作表時出現的音訊播放抖動問題。

// ja

- **MP3「アルバムアーティスト」メタデータ修正**：MP3 メタデータから「アルバムアーティスト」フィールドを読み取れない問題を修正しました。
- **SwiftUI キャンバス測定パッチ**：将来の OS リリースで UI が正常に動作するように、SwiftUI 関連のキャンバス測定メソッドにパッチを適用しました。
- **並行処理修正**：並行処理の問題を修正しました（Swift 6.4 beta コンパイラの強化された検出機能によって発見されたもので、Swift 6.3 ツールチェーン（Xcode 26.5 時点）では検出できませんでした）。
- **ESC キー動作修正**：メタデータシート表示時の ESC キーの動作が不安定な問題を修正しました。
- **オーディオ再生ジッター修正（メタデータシート）**：アプリ起動後、初めてメタデータシートを呼び出した際に発生するオーディオ再生のジッター問題を修正しました。
- **オーディオ再生ジッター修正（述語設定）**：プレイリストの述語設定シートを呼び出した際に発生するオーディオ再生のジッター問題を修正しました。

// ko

- **MP3 "앨범 아티스트" 메타데이터 수정**: MP3 메타데이터에서 "앨범 아티스트" 필드를 읽을 수 없는 문제를 수정했습니다.
- **SwiftUI 캔버스 측정 패치**: 향후 OS 릴리스에서 UI가 정상적으로 동작하도록 SwiftUI 관련 캔버스 측정 메서드를 패치했습니다.
- **동시성 수정**: 동시성 문제를 수정했습니다（Swift 6.4 beta 컴파일러의 향상된 감지 기능 덕분에 발견되었으며, Swift 6.3 툴체인（Xcode 26.5 기준）에서는 감지할 수 없었습니다）.
- **ESC 키 동작 수정**: 메타데이터 시트가 표시될 때 ESC 키의 동작이 혼란스러운 문제를 수정했습니다.
- **오디오 재생 지터 수정 (메타데이터 시트)**: 앱 시작 후 처음으로 메타데이터 시트를 호출할 때 발생하는 오디오 재생 지터 문제를 수정했습니다.
- **오디오 재생 지터 수정 (술어 구성)**: 플레이리스트의 술어 구성 시트를 호출할 때 발생하는 오디오 재생 지터 문제를 수정했습니다.

// es

- **Corrección de metadatos "Artista del álbum" MP3**: Se ha corregido la incapacidad de leer el campo "Artista del álbum" de los metadatos MP3.
- **Parche de medición de lienzo SwiftUI**: Se han parcheado algunos métodos de medición del lienzo relacionados con SwiftUI para garantizar que la UI se comporte correctamente en futuras versiones del sistema operativo.
- **Correcciones de concurrencia**: Se han corregido algunos problemas de concurrencia detectados gracias al compilador de Swift 6.4 beta. Estos problemas no eran detectables por la cadena de herramientas Swift 6.3 (a partir de Xcode 26.5).
- **Corrección de comportamiento de tecla ESC**: Se han corregido algunos problemas de comportamiento caótico con la tecla ESC cuando se presenta la hoja de metadatos.
- **Corrección de fluctuación de audio (hoja de metadatos)**: Se ha corregido el problema de fluctuación en la reproducción de audio que ocurría al llamar a la hoja de metadatos por primera vez después de iniciar la app.
- **Corrección de fluctuación de audio (configuración de predicados)**: Se ha corregido el problema de fluctuación en la reproducción de audio que ocurría al llamar a la hoja de configuración de predicados de una lista de reproducción.

// fr

- **Correction métadonnées « Artiste de l'album » MP3** : Correction de l'incapacité à lire le champ « Artiste de l'album » des métadonnées MP3.
- **Correctif de mesure de canevas SwiftUI** : Correction de certaines méthodes de mesure du canevas liées à SwiftUI pour garantir que l'UI se comporte correctement sur les futures versions du système d'exploitation.
- **Correctifs de concurrence** : Correction de certains problèmes de concurrence détectés grâce au compilateur de Swift 6.4 beta. Ces problèmes n'étaient pas détectables par la chaîne d'outils Swift 6.3 (à partir de Xcode 26.5).
- **Correction du comportement de la touche Échap** : Correction de certains problèmes de comportement chaotique avec la touche Échap lorsque la fiche de métadonnées est affichée.
- **Correction de gigue audio (fiche de métadonnées)** : Correction du problème de gigue de lecture audio survenant lors du premier appel de la fiche de métadonnées après le lancement de l'application.
- **Correction de gigue audio (configuration de prédicats)** : Correction du problème de gigue de lecture audio survenant lors de l'appel de la fiche de configuration des prédicats d'une liste de lecture.

// de

- **MP3-"Albumkünstler"-Metadaten-Fix**: Behebung des Problems, dass das Feld "Albumkünstler" aus MP3-Metadaten nicht gelesen werden konnte.
- **SwiftUI-Canvas-Messungs-Patch**: Einige SwiftUI-bezogene Canvas-Messmethoden wurden gepatcht, um sicherzustellen, dass die UI auf zukünftigen Betriebssystemversionen korrekt funktioniert.
- **Gleichzeitigkeitskorrekturen**: Behebung einiger Gleichzeitigkeitsprobleme, die dank des verbesserten Swift 6.4-Beta-Compilers erkannt wurden. Diese Probleme waren mit der Swift 6.3-Toolchain (Stand Xcode 26.5) nicht erkennbar.
- **ESC-Taste Verhaltenskorrektur**: Behebung einiger Verhaltensprobleme mit der ESC-Taste beim Anzeigen des Metadatenblatts.
- **Audio-Wiedergabe-Jitter-Fix (Metadatenblatt)**: Behebung des Audio-Wiedergabeproblems (Jitter), das beim ersten Aufruf des Metadatenblatts nach dem Starten der App auftrat.
- **Audio-Wiedergabe-Jitter-Fix (Prädikatkonfiguration)**: Behebung des Audio-Wiedergabeproblems (Jitter), das beim Aufruf des Prädikatkonfigurationsblatts einer Playlist auftrat.

// it

- **Fix metadati "Artista album" MP3**: Risolto il problema dell'impossibilità di leggere il campo "Artista album" dai metadati MP3.
- **Patch misurazione canvas SwiftUI**: Corretti alcuni metodi di misurazione della canvas relativi a SwiftUI per garantire che l'UI si comporti correttamente nelle future versioni del sistema operativo.
- **Correzioni concorrenza**: Risolti alcuni problemi di concorrenza rilevati grazie al compilatore di Swift 6.4 beta. Questi problemi non erano rilevabili dalla toolchain Swift 6.3 (a partire da Xcode 26.5).
- **Correzione comportamento tasto ESC**: Risolti alcuni problemi di comportamento caotico con il tasto ESC quando viene visualizzata la scheda dei metadati.
- **Correzione jitter audio (scheda metadati)**: Risolto il problema di jitter nella riproduzione audio che si verificava alla prima chiamata della scheda dei metadati dopo l'avvio dell'app.
- **Correzione jitter audio (configurazione predicati)**: Risolto il problema di jitter nella riproduzione audio che si verificava quando si chiamava la scheda di configurazione dei predicati di una playlist.

// pt-BR

- **Correção de metadados "Artista do Álbum" MP3**: Corrigida a incapacidade de ler o campo "Artista do Álbum" dos metadados MP3.
- **Patch de medição de canvas SwiftUI**: Corrigidos alguns métodos de medição de canvas relacionados ao SwiftUI para garantir que a UI se comporte corretamente em futuras versões do sistema operacional.
- **Correções de concorrência**: Corrigidos alguns problemas de concorrência detectados graças ao compilador do Swift 6.4 beta. Esses problemas não eram detectáveis pela toolchain Swift 6.3 (a partir do Xcode 26.5).
- **Correção de comportamento da tecla ESC**: Corrigidos alguns problemas de comportamento caótico com a tecla ESC quando a folha de metadados é exibida.
- **Correção de tremulação de áudio (folha de metadados)**: Corrigido o problema de tremulação na reprodução de áudio que ocorria na primeira chamada da folha de metadados após iniciar o app.
- **Correção de tremulação de áudio (configuração de predicados)**: Corrigido o problema de tremulação na reprodução de áudio que ocorria ao chamar a folha de configuração de predicados de uma playlist.

// ru

- **Исправление метаданных MP3 «Исполнитель альбома»**: Исправлена невозможность чтения поля «Исполнитель альбома» из метаданных MP3.
- **Патч измерения холста SwiftUI**: Исправлены некоторые методы измерения холста, связанные с SwiftUI, для обеспечения корректного поведения UI в будущих версиях ОС.
- **Исправления конкурентности**: Исправлены некоторые проблемы параллелизма, обнаруженные благодаря улучшенному компилятору Swift 6.4 beta. Эти проблемы не обнаруживались инструментарием Swift 6.3 (по состоянию на Xcode 26.5).
- **Исправление поведения клавиши ESC**: Исправлены некоторые проблемы с хаотичным поведением клавиши ESC при отображении листа метаданных.
- **Исправление дрожания аудио (лист метаданных)**: Исправлена проблема дрожания воспроизведения аудио, возникавшая при первом вызове листа метаданных после запуска приложения.
- **Исправление дрожания аудио (конфигурация предикатов)**: Исправлена проблема дрожания воспроизведения аудио, возникавшая при вызове листа конфигурации предикатов плейлиста.

// tr

- **MP3 "Albüm Sanatçısı" meta veri düzeltmesi**: MP3 meta verilerinden "Albüm Sanatçısı" alanının okunamaması sorunu düzeltildi.
- **SwiftUI canvas ölçüm yaması**: Gelecekteki işletim sistemi sürümlerinde UI'ın düzgün çalışmasını sağlamak için SwiftUI ile ilgili bazı canvas ölçüm yöntemleri yamalandı.
- **Eşzamanlılık düzeltmeleri**: Swift 6.4 beta derleyicisinin gelişmiş tespit yeteneği sayesinde bulunan bazı eşzamanlılık sorunları düzeltildi. Bu sorunlar Swift 6.3 araç zinciri (Xcode 26.5 itibarıyla) tarafından tespit edilemezdi.
- **ESC tuşu davranış düzeltmesi**: Meta veri sayfası görüntülendiğinde ESC tuşunun bazı davranışsal kaotik sorunları düzeltildi.
- **Ses çalma titreme düzeltmesi (meta veri sayfası)**: Uygulama başlatıldıktan sonra meta veri sayfasının ilk kez çağrılmasında meydana gelen ses çalma titreme sorunu düzeltildi.
- **Ses çalma titreme düzeltmesi (yüklem yapılandırması)**: Bir çalma listesinin yüklem yapılandırma sayfası çağrıldığında meydana gelen ses çalma titreme sorunu düzeltildi.
