# v26.04.01 (macOS AppKit)

// en

- **Folder Playlists**: Added a new playlist type that syncs with a specified folder on your device. Tracks are loaded from the folder and kept separate from your main library. Supports manual rescan to refresh contents. On macOS, you can right-click a Folder Playlist and select "Show in Finder" to open the corresponding folder. Folder playlists are ideal for users who prefer folder-based music organization.
- **Audio output device selection**: Added the ability to select audio output devices directly from the app. Users can now route audio to other available audio devices in the system, including virtual audio cable drivers like Soundflower. This allows users to wrap the audio output to Apple MainStage to use DSP plugins.
- **Dynamic playlist data sources**: Dynamic playlists can now specify one or more Folder Playlists as data sources. This allows predicates to filter within a specific folder scope instead of the entire library. The matched results count in Predicate Editor now respects the selected data sources.
- **Playlist duplication**: Added the ability to duplicate any playlist (except Folder Playlists). Duplicated playlists get a new ID and a timestamp suffix in the name. Useful for reusing predicate configurations from dynamic playlists.
- **Empty state improvements**: Empty playlist descriptions now vary by playlist type—static playlists, folder playlists, and dynamic playlists each show contextually appropriate messages.
- **Restrictions on Manual Track Reordering**: Manual track reordering in static playlists and Favorites is now automatically disabled when Column Browser filters are active or when the search bar has content.
- **Album artwork fallback**: Improved album artwork extraction to search all tracks in an album when the initial sample track lacks embedded artwork.
- **Rubber-band selection fix**: Fixed an issue where rubber-band selection in Album Grid could not be triggered in the empty area below the last row when the album count was insufficient to fill the viewport.
- **Album grid state management**: Fixed playlist-scoped album identity issues that caused incorrect track counts when switching between playlists with albums of the same name. Albums now have playlist-scoped IDs to prevent cross-playlist data pollution.
- **ID3 encoding fix**: Fixed garbled text when reading legacy non-UTF-8 MP3 ID3 tags. The app now automatically detects and corrects encoding issues for GBK, Big5, Shift-JIS, EUC-KR, and Cyrillic encodings. Locale-aware detection prioritizes the most likely encoding based on system preferred language fallback sequence.
- **Audio format display fix**: Fixed MP3 audio format showing as `.MP3` instead of `MP3` in Track Details.

// zh-Hans

- **资料夹播放清单**：新增一种与设备上指定资料夹同步的播放清单类型。曲目从资料夹载入，与主媒体柜保持隔离。支持手动重新扫描以更新内容。在 macOS 上，您可以右键点击资料夹播放清单并选择「在 Finder 中显示」来开启对应的资料夹。适合偏好以资料夹组织音乐的使用者。
- **音频输出设备选择**：新增直接从 App 内选择音频输出设备的功能。使用者可将音频路由至系统中的其他可用音频设备，包括 Soundflower 等虚拟音频线驱动程序。这让使用者可以将音频输出路由至 Apple MainStage 以使用 DSP 插件。
- **动态播放清单数据源**：动态播放清单现在可以指定一个或多个资料夹播放清单作为数据源。这让述词可以在特定的资料夹范围内进行筛选，而非整个媒体柜。述词编辑器中的匹配结果计数现在会反映所选的数据源。
- **创建播放清单副本**：新增创建任意播放清单副本的功能（资料夹播放清单除外）。创建的播放清单副本会获得新的 ID，名称会附加时间戳后缀。便于复用动态播放清单的述词配置。
- **空状态提示改善**：空播放清单描述现在会根据播放清单类型显示不同的提示——静态播放清单、资料夹播放清单和动态播放清单各有适合的说明文字。
- **手动曲目重排限制**：当直栏筛选条件生效或搜寻栏有内容时，静态播放清单和我的收藏的曲目重新排序功能会自动禁用。
- **专辑封面递补**：改善专辑封面提取逻辑，当初始取样曲目没有内嵌封面时，会搜寻专辑中的所有曲目。
- **拖曳框选修复**：修复当专辑数量不足以填满可视区域时，专辑网格底部的空白区域无法触发拖曳框选的问题。
- **专辑网格状态管理**：修复了播放清单范围的专辑身份问题，该问题导致在切换包含同名专辑的播放清单时显示错误的曲目数。专辑现在具有播放清单范围的 ID，以防止跨播放清单数据污染。
- **ID3 编码修复**：修复读取旧式非 UTF-8 MP3 ID3 标签时出现的乱码问题。App 现在会自动侦测并修正 GBK、Big5、Shift-JIS、EUC-KR 和 Cyrillic 编码的问题。基于系统偏好语言回退序列的侦测会优先选择最可能的编码。
- **音讯格式显示修复**：修复 MP3 音讯格式在曲目详情中显示为 `.MP3` 而非 `MP3` 的问题。

// zh-Hant

- **資料夾播放清單**：新增一種與裝置上指定資料夾同步的播放清單類型。曲目從資料夾載入，與主媒體櫃保持隔離。支援手動重新掃描以更新內容。在 macOS 上，您可以右鍵點擊資料夾播放清單並選擇「在 Finder 中顯示」來開啟對應的資料夾。適合偏好以資料夾組織音樂的使用者。
- **音訊輸出裝置選擇**：新增直接從 App 內選擇音訊輸出裝置的功能。使用者可將音訊路由至系統中的其他可用音訊裝置，包括 Soundflower 等虛擬音訊線驅動程式。這讓使用者可以將音訊輸出路由至 Apple MainStage 以使用 DSP 插件。
- **動態播放清單資料來源**：動態播放清單現在可以指定一個或多個資料夾播放清單作為資料來源。這讓述詞可以在特定的資料夾範圍內進行篩選，而非整個媒體櫃。述詞編輯器中的匹配結果計數現在會反映所選的資料來源。
- **新增播放清單副本**：新增為任意播放清單建立副本的功能（資料夾播放清單除外）。新增的播放清單副本會獲得新的 ID，名稱會附加時間戳後綴。便於複用動態播放清單的述詞配置。
- **空狀態提示改善**：空播放清單描述現在會根據播放清單類型顯示不同的提示——靜態播放清單、資料夾播放清單和動態播放清單各有適合的說明文字。
- **手動曲目重排限制**：當直欄篩選條件生效或搜尋欄有內容時，靜態播放清單和我的收藏的曲目重新排序功能會自動禁用。
- **專輯封面遞補**：改善專輯封面提取邏輯，當初始取樣曲目沒有內嵌封面時，會搜尋專輯中的所有曲目。
- **拖曳框選修復**：修復當專輯數量不足以填滿可視區域時，專輯網格底部的空白區域無法觸發拖曳框選的問題。
- **專輯網格狀態管理**：修復了播放清單範圍的專輯身份問題，該問題導致在切換包含同名專輯的播放清單時顯示錯誤的曲目數。專輯現在具有播放清單範圍的 ID，以防止跨播放清單資料污染。
- **ID3 編碼修復**：修復讀取舊式非 UTF-8 MP3 ID3 標籤時出現的亂碼問題。App 現在會自動偵測並修正 GBK、Big5、Shift-JIS、EUC-KR 和 Cyrillic 編碼的問題。基於系統偏好語言回退序列的偵測會優先選擇最可能的編碼。
- **音訊格式顯示修復**：修復 MP3 音訊格式在曲目詳情中顯示為 `.MP3` 而非 `MP3` 的問題。

// ja

- **フォルダプレイリスト**：デバイス上の指定フォルダと同期する新しいプレイリストタイプを追加。トラックはフォルダから読み込まれ、メインライブラリとは分離されます。手動再スキャンでコンテンツを更新可能。macOSでは、フォルダプレイリストを右クリックして「Finderで開く」を選択すると、対応するフォルダを開けます。フォルダベースの音楽整理を好むユーザーに最適です。
- **オーディオ出力デバイス選択**：アプリ内から直接オーディオ出力デバイスを選択する機能を追加。システム内の他の利用可能なオーディオデバイスに音声をルーティングできるようになりました。Soundflower などの仮想オーディオケーブルドライバも含まれます。これにより、Apple MainStage に音声出力をルーティングして DSP プラグインを使用できるようになります。
- **ダイナミックプレイリストのデータソース**：ダイナミックプレイリストは、1つ以上のフォルダプレイリストをデータソースとして指定できるようになりました。これにより、ライブラリ全体ではなく特定のフォルダ範囲内で述語によるフィルタリングが可能に。述語エディタのマッチ件数は、選択したデータソースを反映するようになりました。
- **プレイリストの複製**：任意のプレイリストを複製する機能を追加（フォルダプレイリストを除く）。複製されたプレイリストは新しい ID を取得し、名前にタイムスタンプのサフィックスが付きます。ダイナミックプレイリストの述語設定を再利用するのに便利です。
- **空状態の改善**：空のプレイリストの説明がプレイリストタイプ別に変化するようになりました——静的プレイリスト、フォルダプレイリスト、ダイナミックプレイリストそれぞれに適切なメッセージを表示。
- **手動トラック並べ替えの制限**：Column Browser のフィルタがアクティブな場合、または検索バーに内容がある場合、静的プレイリストとお気に入りのトラック並べ替えが自動的に無効になります。
- **アルバムアートワークのフォールバック**：アルバムアートワーク抽出ロジックを改善し、最初のサンプルトラックに埋め込みアートワークがない場合、アルバム内のすべてのトラックを検索するようになりました。
- **ラバーバンド選択の修正**：アルバム数がビューポートを埋めるのに十分でない場合、アルバムグリッドの最後の行の下の空領域でラバーバンド選択をトリガーできない問題を修正。
- **アルバムグリッド状態管理**：同じ名前のアルバムを含むプレイリスト間を切り替える際にトラック数が正しく表示されない原因となっていたプレイリストスコープのアルバムID問題を修正。アルバムはプレイリストスコープの ID を持ち、プレイリスト間のデータ汚染を防ぐようになりました。
- **ID3 エンコーディング修正**：レガシー非 UTF-8 MP3 ID3 タグ読み込み時の文字化けを修正。GBK、Big5、Shift-JIS、EUC-KR、Cyrillic エンコーディングの問題を自動検出・修正。システム優先言語フォールバック順序に基づく優先エンコーディング検出を実装。
- **オーディオフォーマット表示修正**：トラック詳細で MP3 オーディオフォーマットが `MP3` ではなく `.MP3` と表示される問題を修正。

// ko

- **폴더 재생 목록**: 장치의 지정된 폴더와 동기화되는 새로운 재생 목록 유형을 추가했습니다. 트랙은 폴더에서 로드되며 메인 라이브러리와 분리됩니다. 수동 재스캔으로 콘텐츠를 새로고침할 수 있습니다. macOS에서 폴더 재생 목록을 우클릭하고 "Finder에서 보기"를 선택하면 해당 폴더를 열 수 있습니다. 폴더 기반 음악 정리를 선호하는 사용자에게 적합합니다.
- **오디오 출력 장치 선택**: 앱 내에서 직접 오디오 출력 장치를 선택하는 기능을 추가했습니다. 시스템의 다른 사용 가능한 오디오 장치로 오디오를 라우팅할 수 있습니다. Soundflower와 같은 가상 오디오 케이블 드라이버도 포함됩니다. 이를 통해 Apple MainStage로 오디오 출력을 라우팅하여 DSP 플러그인을 사용할 수 있습니다.
- **동적 재생 목록 데이터 소스**: 동적 재생 목록이 이제 하나 이상의 폴더 재생 목록을 데이터 소스로 지정할 수 있습니다. 이를 통해 전체 라이브러리가 아닌 특정 폴더 범위 내에서 술어로 필터링할 수 있습니다. 술어 편집기의 일치 항목 수가 이제 선택한 데이터 소스를 반영합니다.
- **재생 목록 복제**: 모든 재생 목록을 복제하는 기능을 추가했습니다(폴더 재생 목록 제외). 복제된 재생 목록은 새 ID를 받고 이름에 타임스탬프 접미사가 추가됩니다. 동적 재생 목록의 술어 구성을 재사용하는 데 유용합니다.
- **빈 상태 개선**: 빈 재생 목록 설명이 이제 재생 목록 유형에 따라 다르게 표시됩니다——정적 재생 목록, 폴더 재생 목록, 동적 재생 목록 각각에 적절한 메시지를 표시합니다.
- **수동 트랙 재정렬 제한**: Column Browser 필터가 활성화되어 있거나 검색창에 내용이 있을 때 정적 재생 목록과 즐겨찾기의 트랙 재정렬이 자동으로 비활성화됩니다.
- **앨범 아트워크 폴백**: 앨범 아트워크 추출 로직을 개선하여 초기 샘플 트랙에 임베디드 아트워크가 없을 경우 앨범의 모든 트랙을 검색하도록 했습니다.
- **고무줄 선택 수정**: 앨범 수가 뷰포트를 채우기에 부족할 때 앨범 그리드 하단 빈 영역에서 고무줄 선택을 트리거할 수 없던 문제를 수정했습니다.
- **앨범 그리드 상태 관리**: 같은 이름의 앨범이 있는 재생 목록 간 전환 시 트랙 수가 잘못 표시되던 재생 목록 범위 앨범 ID 문제를 수정했습니다. 앨범은 이제 재생 목록 범위 ID를 가지며 재생 목록 간 데이터 오염을 방지합니다.
- **ID3 인코딩 수정**: 레거시 비 UTF-8 MP3 ID3 태그 읽기 시 깨진 문자 문제를 수정했습니다. GBK, Big5, Shift-JIS, EUC-KR, Cyrillic 인코딩 문제를 자동으로 감지하고 수정합니다. 시스템 선호 언어 폴백 시퀀스 기반 우선 인코딩 감지를 구현했습니다.
- **오디오 포맷 표시 수정**: 트랙 세부 정보에서 MP3 오디오 포맷이 `MP3` 대신 `.MP3`로 표시되던 문제를 수정했습니다.

// es

- **Listas de reproducción de carpetas**: Se ha añadido un nuevo tipo de lista de reproducción que se sincroniza con una carpeta especificada en el dispositivo. Las pistas se cargan desde la carpeta y se mantienen separadas de la biblioteca principal. Admite reescaneo manual para actualizar el contenido. En macOS, puede hacer clic derecho en una Lista de Carpeta y seleccionar «Mostrar en Finder» para abrir la carpeta correspondiente. Ideal para usuarios que prefieren organizar su música por carpetas.
- **Selección de dispositivo de salida de audio**: Se ha añadido la capacidad de seleccionar dispositivos de salida de audio directamente desde la aplicación. Los usuarios ahora pueden dirigir el audio a otros dispositivos de audio disponibles en el sistema, incluyendo controladores de cable de audio virtual como Soundflower. Esto permite a los usuarios enrutar la salida de audio a Apple MainStage para usar plugins DSP.
- **Fuentes de datos para listas dinámicas**: Las listas de reproducción dinámicas ahora pueden especificar una o más Listas de Carpeta como fuentes de datos. Esto permite que los predicados filtren dentro de un ámbito de carpeta específico en lugar de toda la biblioteca. El conteo de resultados coincidentes en el Editor de Predicados ahora respeta las fuentes de datos seleccionadas.
- **Duplicación de listas de reproducción**: Se ha añadido la capacidad de duplicar cualquier lista de reproducción (excepto Listas de Carpeta). Las listas duplicadas obtienen un nuevo ID y un sufijo de marca de tiempo en el nombre. Útil para reutilizar configuraciones de predicados de listas dinámicas.
- **Mejoras de estado vacío**: Las descripciones de listas vacías ahora varían según el tipo de lista—listas estáticas, listas de carpeta y listas dinámicas muestran mensajes apropiados al contexto.
- **Restricciones en el reordenamiento manual de pistas**: La reordenación manual de pistas en listas estáticas y Favoritos ahora se desactiva automáticamente cuando los filtros de Column Browser están activos o cuando la barra de búsqueda tiene contenido.
- **Respaldo de carátulas de álbum**: Se ha mejorado la lógica de extracción de carátulas para buscar en todas las pistas de un álbum cuando la pista de muestra inicial carece de carátula incrustada.
- **Corrección de selección por banda elástica**: Se ha corregido un problema donde la selección por banda elástica en la cuadrícula de álbumes no podía activarse en el área vacía debajo de la última fila cuando la cantidad de álbumes era insuficiente para llenar la ventana gráfica.
- **Gestión de estado de cuadrícula de álbumes**: Se han corregido problemas de identidad de álbum con ámbito de lista que causaban recuentos de pistas incorrectos al cambiar entre listas con álbumes del mismo nombre. Los álbumes ahora tienen IDs con ámbito de lista para evitar la contaminación de datos entre listas.
- **Corrección de codificación ID3**: Se han corregido los caracteres ilegibles al leer etiquetas ID3 de MP3 heredadas no UTF-8. La app ahora detecta y corrige automáticamente problemas de codificación GBK, Big5, Shift-JIS, EUC-KR y Cyrillic. La detección basada en la secuencia de reserva de idiomas preferidos del sistema prioriza la codificación más probable.
- **Corrección de visualización de formato de audio**: Se ha corregido el formato de audio MP3 que se mostraba como `.MP3` en lugar de `MP3` en los detalles de la pista.

// fr

- **Listes de lecture de dossier** : Ajout d'un nouveau type de liste de lecture qui se synchronise avec un dossier spécifié sur l'appareil. Les pistes sont chargées depuis le dossier et restent séparées de la bibliothèque principale. Supporte le rescan manuel pour actualiser le contenu. Sur macOS, vous pouvez cliquer droit sur une Liste de Dossier et sélectionner « Afficher dans le Finder » pour ouvrir le dossier correspondant. Idéal pour les utilisateurs qui préfèrent organiser leur musique par dossiers.
- **Sélection du périphérique de sortie audio** : Ajout de la possibilité de sélectionner les périphériques de sortie audio directement depuis l'application. Les utilisateurs peuvent maintenant router l'audio vers d'autres périphériques audio disponibles dans le système, y compris les pilotes de câble audio virtuel comme Soundflower. Cela permet aux utilisateurs de router la sortie audio vers Apple MainStage pour utiliser des plugins DSP.
- **Sources de données pour listes dynamiques** : Les listes de lecture dynamiques peuvent maintenant spécifier une ou plusieurs Listes de Dossier comme sources de données. Cela permet aux prédicats de filtrer dans une portée de dossier spécifique au lieu de toute la bibliothèque. Le comptage des résultats correspondants dans l'Éditeur de Prédicats respecte maintenant les sources de données sélectionnées.
- **Duplication de listes de lecture** : Ajout de la possibilité de dupliquer n'importe quelle liste de lecture (sauf les Listes de Dossier). Les listes dupliquées obtiennent un nouvel ID et un suffixe d'horodatage dans le nom. Utile pour réutiliser les configurations de prédicats des listes dynamiques.
- **Améliorations de l'état vide** : Les descriptions de listes vides varient maintenant selon le type de liste—listes statiques, listes de dossier et listes dynamiques affichent des messages appropriés au contexte.
- **Restrictions sur la réorganisation manuelle des pistes** : La réorganisation manuelle des pistes dans les listes statiques et Favoris est maintenant automatiquement désactivée lorsque les filtres Column Browser sont actifs ou lorsque la barre de recherche contient du texte.
- **Solution de repli pour pochettes d'album** : Amélioration de la logique d'extraction des pochettes pour rechercher dans toutes les pistes d'un album lorsque la piste échantillon initiale manque de pochette intégrée.
- **Correction de la sélection par bande élastique** : Correction d'un problème où la sélection par bande élastique dans la grille d'albums ne pouvait pas être déclenchée dans la zone vide sous la dernière rangée lorsque le nombre d'albums était insuffisant pour remplir la fenêtre d'affichage.
- **Gestion d'état de la grille d'albums** : Correction des problèmes d'identité d'album à portée de liste qui causaient des comptages de pistes incorrects lors du basculement entre des listes contenant des albums du même nom. Les albums ont maintenant des IDs à portée de liste pour éviter la contamination de données entre listes.
- **Correction de l'encodage ID3** : Correction des caractères illisibles lors de la lecture des balises ID3 MP3 héritées non UTF-8. L'application détecte et corrige désormais automatiquement les problèmes d'encodage GBK, Big5, Shift-JIS, EUC-KR et Cyrillic. La détection basée sur la séquence de repli des langues préférées du système privilégie l'encodage le plus probable.
- **Correction de l'affichage du format audio** : Correction du format audio MP3 affiché comme `.MP3` au lieu de `MP3` dans les détails de la piste.

// it

- **Playlist cartella**: Aggiunto un nuovo tipo di playlist che si sincronizza con una cartella specificata sul dispositivo. Le tracce vengono caricate dalla cartella e mantenute separate dalla libreria principale. Supporta la risincronizzazione manuale per aggiornare i contenuti. Su macOS, puoi fare clic destro su una Playlist Cartella e selezionare «Mostra nel Finder» per aprire la cartella corrispondente. Ideale per utenti che preferiscono organizzare la musica per cartelle.
- **Selezione dispositivo uscita audio**: Aggiunta la possibilità di selezionare i dispositivi di uscita audio direttamente dall'app. Gli utenti possono ora instradare l'audio verso altri dispositivi audio disponibili nel sistema, inclusi driver di cavo audio virtuale come Soundflower. Questo permette agli utenti di instradare l'uscita audio verso Apple MainStage per utilizzare plugin DSP.
- **Fonti dati per playlist dinamiche**: Le playlist dinamiche possono ora specificare una o più Playlist Cartella come fonti dati. Questo permette ai predicati di filtrare all'interno di un ambito di cartella specifico invece dell'intera libreria. Il conteggio dei risultati corrispondenti nell'Editor Predicati ora rispetta le fonti dati selezionate.
- **Duplicazione playlist**: Aggiunta la possibilità di duplicare qualsiasi playlist (eccetto Playlist Cartella). Le playlist duplicate ottengono un nuovo ID e un suffisso timestamp nel nome. Utile per riutilizzare le configurazioni di predicati dalle playlist dinamiche.
- **Miglioramenti stato vuoto**: Le descrizioni delle playlist vuote ora variano in base al tipo di playlist—playlist statiche, playlist cartella e playlist dinamiche mostrano messaggi appropriati al contesto.
- **Restrizioni sul riordinamento manuale delle tracce**: Il riordinamento manuale delle tracce nelle playlist statiche e Preferiti è ora automaticamente disabilitato quando i filtri Column Browser sono attivi o quando la barra di ricerca contiene testo.
- **Fallback copertine album**: Migliorata la logica di estrazione delle copertine per cercare in tutte le tracce di un album quando la traccia campione iniziale manca di copertina incorporata.
- **Correzione selezione a elastico**: Corretto un problema per cui la selezione a elastico nella griglia album non poteva essere attivata nell'area vuota sotto l'ultima riga quando il numero di album era insufficiente a riempire la viewport.
- **Gestione stato griglia album**: Corretti problemi di identità album con ambito playlist che causavano conteggi di tracce errati durante il passaggio tra playlist con album con lo stesso nome. Gli album ora hanno ID con ambito playlist per prevenire la contaminazione di dati tra playlist.
- **Correzione codifica ID3**: Corretti i caratteri illeggibili durante la lettura di tag ID3 MP3 legacy non UTF-8. L'app ora rileva e corregge automaticamente i problemi di codifica GBK, Big5, Shift-JIS, EUC-KR e Cyrillic. Il rilevamento basato sulla sequenza di riserva delle lingue preferite di sistema privilegia la codifica più probabile.
- **Correzione visualizzazione formato audio**: Corretto il formato audio MP3 visualizzato come `.MP3` invece di `MP3` nei dettagli della traccia.

// pt-BR

- **Listas de reprodução de pasta**: Adicionado um novo tipo de lista de reprodução que sincroniza com uma pasta especificada no dispositivo. As faixas são carregadas da pasta e mantidas separadas da biblioteca principal. Suporta ressincronização manual para atualizar o conteúdo. No macOS, você pode clicar com o botão direito em uma Lista de Pasta e selecionar «Mostrar no Finder» para abrir a pasta correspondente. Ideal para usuários que preferem organizar a música por pastas.
- **Seleção de dispositivo de saída de áudio**: Adicionada a capacidade de selecionar dispositivos de saída de áudio diretamente do aplicativo. Os usuários agora podem rotear o áudio para outros dispositivos de áudio disponíveis no sistema, incluindo drivers de cabo de áudio virtual como Soundflower. Isso permite aos usuários rotear a saída de áudio para o Apple MainStage para usar plugins DSP.
- **Fontes de dados para listas dinâmicas**: As listas de reprodução dinâmicas agora podem especificar uma ou mais Listas de Pasta como fontes de dados. Isso permite que os predicados filtrem dentro de um escopo de pasta específico em vez de toda a biblioteca. A contagem de resultados correspondentes no Editor de Predicados agora respeita as fontes de dados selecionadas.
- **Duplicação de listas de reprodução**: Adicionada a capacidade de duplicar qualquer lista de reprodução (exceto Listas de Pasta). As listas duplicadas obtêm um novo ID e um sufixo de timestamp no nome. Útil para reutilizar configurações de predicados de listas dinâmicas.
- **Melhorias de estado vazio**: As descrições de listas vazias agora variam de acordo com o tipo de lista—listas estáticas, listas de pasta e listas dinâmicas mostram mensagens apropriadas ao contexto.
- **Restrições no reordenamento manual de faixas**: O reordenamento manual de faixas em listas estáticas e Favoritos agora é automaticamente desativado quando os filtros do Column Browser estão ativos ou quando a barra de pesquisa tem conteúdo.
- **Fallback de capas de álbum**: Melhorada a lógica de extração de capas para pesquisar em todas as faixas de um álbum quando a faixa de amostra inicial não tem capa incorporada.
- **Correção de seleção por elástico**: Corrigido um problema onde a seleção por elástico na grade de álbuns não podia ser acionada na área vazia abaixo da última linha quando a quantidade de álbuns era insuficiente para preencher a viewport.
- **Gerenciamento de estado da grade de álbuns**: Corrigidos problemas de identidade de álbum com escopo de lista que causavam contagens de faixas incorretas ao alternar entre listas com álbuns de mesmo nome. Os álbuns agora têm IDs com escopo de lista para evitar contaminação de dados entre listas.
- **Correção de codificação ID3**: Corrigidos caracteres ilegíveis ao ler tags ID3 de MP3 legados não UTF-8. O app agora detecta e corrige automaticamente problemas de codificação GBK, Big5, Shift-JIS, EUC-KR e Cyrillic. A detecção baseada na sequência de fallback de idiomas preferidos do sistema prioriza a codificação mais provável.
- **Correção de exibição de formato de áudio**: Corrigido o formato de áudio MP3 exibido como `.MP3` em vez de `MP3` nos detalhes da faixa.

// de

- **Ordner-Wiedergabelisten**: Ein neuer Wiedergabelistentyp wurde hinzugefügt, der mit einem angegebenen Ordner auf dem Gerät synchronisiert wird. Titel werden aus dem Ordner geladen und separat von der Hauptbibliothek gehalten. Unterstützt manuelles erneutes Scannen zur Aktualisierung des Inhalts. Unter macOS können Sie mit Rechtsklick auf eine Ordner-Wiedergabeliste «Im Finder anzeigen» wählen, um den entsprechenden Ordner zu öffnen. Ideal für Benutzer, die ihre Musik lieber nach Ordnern organisieren.
- **Audio-Ausgabegeräteauswahl**: Die Möglichkeit wurde hinzugefügt, Audio-Ausgabegeräte direkt aus der App auszuwählen. Benutzer können Audio jetzt an andere verfügbare Audiogeräte im System weiterleiten, einschließlich virtueller Audiokabel-Treiber wie Soundflower. Dies ermöglicht es Benutzern, die Audioausgabe an Apple MainStage weiterzuleiten, um DSP-Plugins zu verwenden.
- **Datenquellen für dynamische Wiedergabelisten**: Dynamische Wiedergabelisten können jetzt eine oder mehrere Ordner-Wiedergabelisten als Datenquellen angeben. Dies ermöglicht es Prädikaten, innerhalb eines bestimmten Ordnerbereichs statt der gesamten Bibliothek zu filtern. Die Anzahl der übereinstimmenden Ergebnisse im Prädikats-Editor berücksichtigt jetzt die ausgewählten Datenquellen.
- **Wiedergabelisten-Duplizierung**: Die Möglichkeit wurde hinzugefügt, jede Wiedergabeliste zu duplizieren (außer Ordner-Wiedergabelisten). Duplizierte Wiedergabelisten erhalten eine neue ID und ein Zeitstempel-Suffix im Namen. Nützlich zur Wiederverwendung von Prädikatskonfigurationen aus dynamischen Wiedergabelisten.
- **Verbesserungen des leeren Zustands**: Beschreibungen leerer Wiedergabelisten variieren jetzt nach Wiedergabelistentyp—statische Wiedergabelisten, Ordner-Wiedergabelisten und dynamische Wiedergabelisten zeigen kontextgerechte Nachrichten.
- **Einschränkungen bei der manuellen Titelneuanordnung**: Die manuelle Neuanordnung von Titeln in statischen Wiedergabelisten und Favoriten wird jetzt automatisch deaktiviert, wenn Column Browser-Filter aktiv sind oder wenn die Suchleiste Inhalt hat.
- **Album-Cover-Fallback**: Die Extraktionslogik für Album-Cover wurde verbessert, um alle Titel eines Albums zu durchsuchen, wenn der anfängliche Beispiel-Titel kein eingebettetes Cover hat.
- **Korrektur der Gummiband-Auswahl**: Ein Problem wurde behoben, bei dem die Gummiband-Auswahl im Album-Raster nicht im leeren Bereich unter der letzten Zeile ausgelöst werden konnte, wenn die Albumanzahl nicht ausreichte, um den Ansichtsbereich zu füllen.
- **Album-Raster-Zustandsverwaltung**: Probleme mit der Wiedergabelisten-bezogenen Album-Identität wurden behoben, die falsche Titelzahlen verursachten, wenn zwischen Wiedergabelisten mit gleichnamigen Alben gewechselt wurde. Alben haben jetzt Wiedergabelisten-bezogene IDs, um Datenverschmutzung zwischen Wiedergabelisten zu verhindern.
- **ID3-Kodierungskorrektur**: Korrigiert verstümmelten Text beim Lesen von Legacy-Nicht-UTF-8-MP3-ID3-Tags. Die App erkennt und korrigiert automatisch Kodierungsprobleme für GBK, Big5, Shift-JIS, EUC-KR und Cyrillic. Die auf der System-Bevorzugte-Sprache-Fallback-Sequenz basierende Erkennung priorisiert die wahrscheinlichste Kodierung.
- **Audioformat-Anzeigekorrektur**: Korrigiert das MP3-Audioformat, das als `.MP3` statt `MP3` in den Track-Details angezeigt wurde.

// ru

- **Плейлисты папок**: Добавлен новый тип плейлиста, синхронизируемый с указанной папкой на устройстве. Треки загружаются из папки и хранятся отдельно от основной библиотеки. Поддерживает ручное повторное сканирование для обновления содержимого. В macOS можно щёлкнуть правой кнопкой по Плейлисту Папки и выбрать «Показать в Finder», чтобы открыть соответствующую папку. Идеально для пользователей, предпочитающих организовывать музыку по папкам.
- **Выбор устройства вывода звука**: Добавлена возможность выбора устройств вывода звука прямо из приложения. Пользователи теперь могут направлять звук на другие доступные аудиоустройства в системе, включая драйверы виртуальных аудиокабелей, такие как Soundflower. Это позволяет пользователям направлять аудиовыход в Apple MainStage для использования DSP-плагинов.
- **Источники данных для динамических плейлистов**: Динамические плейлисты теперь могут указывать один или несколько Плейлистов Папок в качестве источников данных. Это позволяет предикатам фильтровать в пределах конкретной папки вместо всей библиотеки. Счётчик совпадающих результатов в Редакторе Предикатов теперь учитывает выбранные источники данных.
- **Дублирование плейлистов**: Добавлена возможность дублировать любой плейлист (кроме Плейлистов Папок). Дубликаты получают новый ID и суффикс с временной меткой в названии. Полезно для повторного использования конфигураций предикатов из динамических плейлистов.
- **Улучшения пустого состояния**: Описания пустых плейлистов теперь различаются в зависимости от типа—статические плейлисты, плейлисты папок и динамические плейлисты показывают контекстно-уместные сообщения.
- **Ограничения ручного перемещения треков**: Ручное перемещение треков в статических плейлистах и Избранном теперь автоматически отключается, когда фильтры Column Browser активны или когда в строке поиска есть содержимое.
- **Резерв для обложек альбомов**: Улучшена логика извлечения обложек для поиска по всем трекам альбома, когда начальный образец не имеет встроенной обложки.
- **Исправление выбора резиновой лентой**: Исправлена проблема, при которой выбор резиновой лентой в сетке альбомов не мог быть активирован в пустой области под последней строкой, когда количество альбомов было недостаточно для заполнения области просмотра.
- **Управление состоянием сетки альбомов**: Исправлены проблемы идентичности альбомов с областью видимости плейлиста, которые вызывали неверные подсчёты треков при переключении между плейлистами с одноимёнными альбомами. Альбомы теперь имеют ID с областью видимости плейлиста для предотвращения загрязнения данных между плейлистами.
- **Исправление кодировки ID3**: Исправлены искажённые символы при чтении устаревших не-UTF-8 MP3 ID3 тегов. Приложение теперь автоматически обнаруживает и исправляет проблемы кодировки GBK, Big5, Shift-JIS, EUC-KR и Cyrillic. Обнаружение на основе последовательности резервных предпочтительных языков системы приоритизирует наиболее вероятную кодировку.
- **Исправление отображения аудиоформата**: Исправлено отображение аудиоформата MP3 как `.MP3` вместо `MP3` в деталях трека.

// tr

- **Klasör çalma listeleri**: Cihazdaki belirli bir klasörle senkronize edilen yeni bir çalma listesi türü eklendi. Parçalar klasörden yüklenir ve ana kitaplıktan ayrı tutulur. İçeriği yenilemek için manuel yeniden taramayı destekler. macOS'ta bir Klasör Çalma Listesine sağ tıklayıp «Finder'da Göster»i seçerek ilgili klasörü açabilirsiniz. Müziği klasörlere göre düzenlemeyi tercih eden kullanıcılar için idealdir.
- **Ses çıkış cihazı seçimi**: Doğrudan uygulamadan ses çıkış cihazlarını seçme yeteneği eklendi. Kullanıcılar artık sesi sistemdeki diğer kullanılabilir ses cihazlarına yönlendirebilir, Soundflower gibi sanal ses kablosu sürücülerini de içerebilir. Bu, kullanıcıların DSP eklentilerini kullanmak için ses çıkışını Apple MainStage'e yönlendirmesine olanak tanır.
- **Dinamik çalma listeleri için veri kaynakları**: Dinamik çalma listeleri artık bir veya daha fazla Klasör Çalma Listesini veri kaynağı olarak belirtebilir. Bu, koşulların tüm kitaplık yerine belirli bir klasör kapsamında filtrelenmesine olanak tanır. Koşul Düzenleyicideki eşleşen sonuç sayısı artık seçilen veri kaynaklarını yansıtır.
- **Çalma listesi çoğaltma**: Herhangi bir çalma listesini çoğaltma yeteneği eklendi (Klasör Çalma Listeleri hariç). Çoğaltılan çalma listeleri yeni bir ID ve adda zaman damgası soneki alır. Dinamik çalma listelerinden koşul yapılandırmalarını yeniden kullanmak için kullanışlıdır.
- **Boş durum iyileştirmeleri**: Boş çalma listesi açıklamaları artık çalma listesi türüne göre değişiyor—statik çalma listeleri, klasör çalma listeleri ve dinamik çalma listeleri bağlama uygun mesajlar gösteriyor.
- **Manuel parça yeniden sıralama kısıtlamaları**: Column Browser filtreleri aktifken veya arama çubuğunda içerik varken statik çalma listelerindeki ve Favorilerdeki manuel parça yeniden sıralama artık otomatik olarak devre dışı bırakılıyor.
- **Albüm kapağı yedeği**: İlk örnek parçada gömülü kapak olmadığında bir albümdeki tüm parçaları aramak için albüm kapağı çıkarma mantığı iyileştirildi.
- **Lastik bant seçimi düzeltmesi**: Albüm sayısı görüntü alanını doldurmak için yetersiz olduğunda, albüm ızgarasındaki son satırın altındaki boş alanda lastik bant seçiminin tetiklenemediği sorun düzeltildi.
- **Albüm ızgara durum yönetimi**: Aynı adda albümler içeren çalma listeleri arasında geçiş yaparken yanlış parça sayılarına neden olan çalma listesi kapsamlı albüm kimliği sorunları düzeltildi. Albümler artık çalma listeleri arası veri kirliliğini önlemek için çalma listesi kapsamlı ID'lere sahip.
- **ID3 kodlama düzeltmesi**: Eski UTF-8 olmayan MP3 ID3 etiketlerini okurken bozuk karakterler düzeltildi. Uygulama artık GBK, Big5, Shift-JIS, EUC-KR ve Cyrillic kodlama sorunlarını otomatik olarak algılar ve düzeltir. Sistem tercih edilen dil geri dönüş sırasına dayalı algılama, en olası kodlamayı önceliklendirir.
- **Ses formatı görüntüleme düzeltmesi**: Parça detaylarında MP3 ses formatının `MP3` yerine `.MP3` olarak görüntülenmesi düzeltildi.
