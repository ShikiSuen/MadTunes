# v26.03.25 (macOS AppKit)

// en

- **Added localization**: French, German, Spanish, Brazilian Portuguese, Russian, Turkish, Korean, Italian.
- **System media controls**: Added compatibility with the system MediaPlayer framework and system media controls, allowing users to manage playback from the menu bar and Control Center.
- **Dynamic playlists**: Added comprehensive support for dynamic playlists driven by hierarchical user-defined predicates. Users can create complex nested rules with AND/OR grouping to automatically filter library contents. Also added predicate editor for dynamic playlists with nested group support (AND/OR sub-groups), visual depth indicators, and improved usability.
- **Sidebar state**: Sidebar interactability is now disabled during library imports to prevent accidental modifications while the library is being populated.
- **Track metadata display**: Fixed incorrect bitrate display in the Track Info dialog. Improved fallback logic for missing metadata fields.
- **FLAC/OGG/OPUS metadata support**: Fixed an issue where FLAC, OGG Vorbis, and Opus files had all metadata fields (title, artist, album, artwork, etc.) unrecognized. Added a native parser for Vorbis Comment and PICTURE/METADATA_BLOCK_PICTURE metadata blocks as a fallback when AVFoundation fails to extract them.
- **Track sorting in a playlist**: Table view now supports customizable sorting. Dynamic playlists use persistent hierarchical compound sort criteria per playlist; static playlists allow users to physically reorder tracks and persist the new sequence.
- **File extension column**: Added new "File Extension" column to track view for better file extension visibility.
- **Playlist reordering**: Playlists can now be dragged up and down in the sidebar to customize their display order.
- **Album artwork caching**: Offloaded album artwork cache data to the hard disk (managed by SwiftData).
- **Performance improvements**: Applied per-row drawing groups to reduce unnecessary view recomputations in grid layout. Eliminated duplicate image decoding tasks to improve overall responsiveness on macOS. The app maintains smooth performance on modern hardware (Mac mini M4, Apple Silicon, etc.). For Intel-based Macs, some UI lag may still be noticeable due to SwiftUI's AttributeGraph overhead. Extensive benchmarking with Xcode Instruments on an Intel Mac 13-inch 2020 with 4 Thunderbolt ports and quad-core i5 processor (running under macOS 26) confirms that all practical optimizations have been implemented from a developer's perspective.

// zh-Hans

- **新增本地化**：法语、德语、西班牙语、巴西葡萄牙语、俄语、土耳其语、韩语、意大利语。
- **系统媒体控制**：添加了对系统 MediaPlayer 框架和系统媒体控制（菜单栏/控制中心）的兼容性，让用户可以在菜单栏和控制中心管理播放。
- **动态播放清单**：添加了对由用户定义的分层谓词驱动的动态播放清单的全面支持。用户可以创建具有 AND/OR 分组的复杂嵌套规则，以自动筛选媒体柜的内容。同时为动态播放清单添加了谓词编辑器，支持嵌套规则组（AND/OR 子组）、视觉深度指标，以及改进的可用性。
- **侧边栏状态**：媒体柜在正在接收文件导入期间禁用侧边栏交互，防止填充期间误操作。
- **曲目中继资料显示**：修复了曲目资讯对话框中不正确的比特率显示。改善了缺失中继资料栏位的回退逻辑。
- **FLAC/OGG/OPUS 中继资料支持**：修复了 FLAC、OGG Vorbis、Opus 文件所有中继资料栏位（标题、艺术家、专辑、封面等）无法识别的问题。新增原生解析器用于解析 Vorbis Comment 和 PICTURE/METADATA_BLOCK_PICTURE 中继资料块，当 AVFoundation 无法提取时作为后备。
- **播放清单排序**：表格视图现在支持可自定义排序。动态播放清单使用每个清单的持久层次复合排序标准；静态播放清单允许用户手动重新排序并保存新顺序。
- **文件扩展名栏**：在曲目视图中新增「扩展名」栏，提高扩展名可见性。
- **播放清单重新排序**：播放清单可在侧边栏中上下拖动，自定义显示顺序。
- **专辑封面缓存**：将专辑封面缓存数据卸载到硬盘（由 SwiftData 管理）。
- **性能改进**：为网格布局应用了分行绘制组，减少不必要的视图重新计算。消除了重复的图像解码任务以改进 macOS 上的整体响应性。应用在现代硬件（Mac mini M4、Apple Silicon 等）上保持流畅性能。对于基于 Intel 的 Mac，仍可能因为 SwiftUI AttributeGraph 开销出现少量 UI 延迟。在配备 4 个 Thunderbolt 端口和四核 i5 处理器的 Intel Mac 13 英寸 2020 款机型上进行的广泛基准测试（运行 macOS 26）确认，从开发者角度出发，已实现所有可行的优化。

// zh-Hant

- **新增本地化**：法語、德語、西班牙語、巴西葡萄牙語、俄語、土耳其語、韓語、義大利語。
- **系統媒體控制**：新增系統 MediaPlayer 框架與系統媒體控制（菜單欄/控制中心）相容性，讓使用者可在菜單欄和控制中心管理播放。
- **動態播放清單**：新增了由使用者定義的分層述詞驅動的動態播放清單的完整支援。使用者可以建立具有 AND/OR 分組的複雜嵌套規則，以自動篩選媒體櫃內容。同時為動態播放清單新增了述詞編輯器，支援嵌套式規則群組（AND/OR 子群組）、視覺深度指標，以及改進的易用性。
- **側邊欄狀態**：媒體櫃在正在接收檔案匯入期間禁用側邊欄互動，避免填充期間誤操作。
- **曲目中繼資料顯示**：修復曲目資訊對話框的位元率顯示錯誤。改善了缺少中繼資料欄位的遞補邏輯。
- **FLAC/OGG/OPUS 中繼資料支援**：修復 FLAC、OGG Vorbis、Opus 檔案中所有中繼資料欄位（標題、藝人、專輯、封面等）無法識別的問題。新增原生解析器解析 Vorbis Comment 和 PICTURE/METADATA_BLOCK_PICTURE 中繼資料區塊，當 AVFoundation 無法擷取時作為後備。
- **播放清單排序**：表格檢視現在支持可自訂排序。動態播放清單使用每個清單的持續型分層複合排序條件；靜態播放清單允許使用者手動調整曲目順序並保存新序列。
- **副檔名欄**：在曲目檢視新增了「副檔名」欄，提升副檔名可見性。
- **播放清單重新排序**：播放清單現可在側欄中上下拖曳以自訂其顯示順序。
- **專輯封面快取**：將專輯封面快取資料卸載到硬碟（由 SwiftData 管理）。
- **效能最佳化**：為網格介面佈局應用了按列繪製群組，以減少不必要的視圖重新計算。消除重複的影像解碼工作，改善 macOS 整體回應速度。應用程式在現代硬體（Mac mini M4、Apple Silicon 等）上保持流暢效能。對於 Intel 架構的 Mac，仍可能因為 SwiftUI AttributeGraph 負荷出現少量 UI 延遲。在配備 4 個 Thunderbolt 連接埠和四核心 i5 處理器的 Intel Mac 13 英寸 2020 型號上進行的廣泛基準測試（運作於 macOS 26）確認，從開發者角度出發，已實現所有可行的最佳化。

// ja

- **本地化対応言語の追加**：フランス語、ドイツ語、スペイン語、ブラジルポルトガル語、ロシア語、トルコ語、韓国語、イタリア語。
- **システムメディアコントロール**：システムの MediaPlayer フレームワークおよびシステムメディアコントロール（メニューバー/コントロールセンター）との互換性を追加し、macOS での再生管理を改善しました。
- **ダイナミックプレイリスト**：ユーザー定義の階層型述語によるダイナミックプレイリストの包括的なサポートを追加。ユーザーは AND/OR グループで複雑なネストされたルールを作成して、ライブラリの内容を自動的にフィルタリングできます。同時にダイナミックプレイリスト向け述語エディタを追加し、ネストされたルールグループ（AND/OR サブグループ）、視覚的な奥行き表示をサポートしています。
- **サイドバー状態**：ライブラリ読み込み中、サイドバーのインタラクティブ操作が無効になり、ライブラリの設定中に誤った変更が加えられるのを防ぎます。
- **トラックメタデータ表示**：トラック情報ダイアログでの不正確なビットレート表示を修正。不足しているメタデータフィールドのフォールバック ロジックを改善。
- **FLAC/OGG/OPUSメタデータサポート**：FLAC/OGG Vorbis/Opusファイルのすべてのメタデータフィールドが認識されない問題を修正。Vorbis CommentおよびPICTURE/METADATA_BLOCK_PICTUREメタデータブロックのネイティブパーサを追加し、AVFoundationが抽出できない場合のフォールバックとする。
- **プレイリストソート**：テーブルビューでカスタマイズ可能なソートをサポート。ダイナミックプレイリストはプレイリスト単位で永続化された階層型複合ソート基準を使用、静的プレイリストはトラックの物理的な並べ替えと新しいシーケンスの永続化が可能。
- **ファイル拡張子列**：トラックビューに「拡張子」列を追加し、拡張子の視認性を向上。
- **プレイリスト並べ替え**：プレイリストをサイドバーで上下ドラッグして表示順をカスタマイズ可能に。
- **アルバムアートワークキャッシュ**：アルバムアートワークキャッシュをハードディスクにオフロード（SwiftData 管理）。
- **パフォーマンス向上**：グリッドUI組版レイアウトに行単位の描画グループを適用し、不要なビュー再計算を削減。重複した画像デコードタスクを排除し、macOS 全体の応答性を改善。アプリは最新ハードウェア（Mac mini M4、Apple Silicon など）で継続的に快適に動作します。Intel ベースの Mac では、SwiftUI の AttributeGraph オーバーヘッドにより UI ラグが生じる可能性があります。4 個の Thunderbolt ポートと 4 コア i5 プロセッサを搭載した Intel Mac 13 インチ 2020 年モデル（macOS 26 で動作）での徹底的なベンチマーク測定により、アプリケーション開発者の観点からすべての実用的な最適化が実装されていることが確認されています。

// ko

- **로컬라이제이션 추가**: 프랑스어, 독일어, 스페인어, 브라질 포르투갈어, 러시아어, 터키어, 한국어, 이탈리아어.
- **시스템 미디어 컨트롤**: 시스템 MediaPlayer 프레임워크 및 시스템 미디어 컨트롤(메뉴 막대/제어 센터)과의 호환성을 추가하여 메뉴 막대와 제어 센터에서 재생을 관리할 수 있습니다.
- **동적 재생 목록**: 계층형 사용자 정의 술어로 구동되는 동적 재생 목록을 포괄적으로 지원합니다. 사용자는 AND/OR 그룹으로 복잡한 중첩 규칙을 만들어 라이브러리 내용을 자동으로 필터링할 수 있습니다. 중첩된 규칙 그룹(AND/OR 하위 그룹), 시각적 깊이 표시기, 그리고 향상된 사용성을 제공하는 술어 편집기도 추가했습니다.
- **사이드바 상태**: 라이브러리 가져오기 중 사이드바 상호작용이 비활성화되어 라이브러리가 채워지는 동안 실수로 인한 수정을 방지합니다.
- **트랙 메타데이터 표시**: 트랙 정보 대화 상자의 잘못된 비트레이트 표시를 수정했습니다. 누락된 메타데이터 필드에 대한 대체 로직을 개선했습니다.
- **FLAC/OGG/OPUS 메타데이터 지원**: FLAC, OGG Vorbis 및 Opus 파일의 제목, 아티스트, 앨범, 아트워크 등 모든 메타데이터 필드가 인식되지 않던 문제를 수정했습니다. AVFoundation이 추출하지 못할 때 사용하는 Vorbis Comment 및 PICTURE/METADATA_BLOCK_PICTURE 메타데이터 블록용 네이티브 파서를 추가했습니다.
- **재생 목록 정렬**: 테이블 보기는 이제 사용자 정의 가능한 정렬을 지원합니다. 동적 재생 목록은 재생 목록별 지속형 계층형 복합 정렬 기준을 사용하고, 정적 재생 목록은 사용자가 트랙을 물리적으로 재정렬하고 새 순서를 유지할 수 있습니다.
- **파일 확장자 열**: 트랙 보기에 새 "파일 확장자" 열을 추가하여 파일 확장자 가시성을 높였습니다.
- **재생 목록 재정렬**: 사이드바에서 재생 목록을 위아래로 끌어 표시 순서를 사용자화할 수 있습니다.
- **앨범 아트워크 캐싱**: 앨범 아트워크 캐시 데이터를 디스크로 오프로드했습니다(SwiftData 관리).
- **성능 개선**: 그리드 레이아웃에 행별 드로잉 그룹을 적용하여 불필요한 보기 재계산을 줄였습니다. 중복 이미지 디코딩 작업을 제거하여 macOS 전반의 응답성을 개선했습니다. 앱은 최신 하드웨어(Mac mini M4, Apple Silicon 등)에서 안정적으로 부드러운 성능을 유지합니다. Intel Mac에서는 SwiftUI AttributeGraph 오버헤드로 인해 일부 UI 지연이 발생할 수 있습니다. macOS 26에서 실행되는 Intel Mac 13인치 2020 모델(4 Thunderbolt 포트, 쿼드코어 i5)에 대한 광범위한 Xcode Instruments 벤치마크 결과, 개발자 관점에서 적용 가능한 최적화는 모두 반영된 것으로 확인되었습니다.

// es

- **Localización añadida**: Francés, alemán, español, portugués de Brasil, ruso, turco, coreano, italiano.
- **Controles de medios del sistema**: Se añadió compatibilidad con el framework MediaPlayer del sistema y con los controles de medios del sistema, lo que permite gestionar la reproducción desde la barra de menús y el Centro de control.
- **Listas de reproducción dinámicas**: Compatibilidad integral con listas dinámicas impulsadas por predicados jerárquicos definidos por el usuario. Se pueden crear reglas anidadas complejas con agrupación AND/OR para filtrar automáticamente el contenido de la biblioteca. También se añadió un editor de predicados para listas dinámicas con grupos de reglas anidados, indicadores visuales de profundidad y mejor usabilidad multiplataforma.
- **Estado de la barra lateral**: La interactividad de la barra lateral ahora está desactivada durante las importaciones de la biblioteca para evitar cambios accidentales mientras se llena la biblioteca.
- **Visualización de metadatos de pista**: Se corrigió el bitrate incorrecto y la lógica de reserva para campos faltantes.
- **Compatibilidad con metadatos FLAC/OGG/OPUS**: Se corrigió el reconocimiento fallido de metadatos en FLAC, OGG Vorbis y Opus. Se añadió un analizador nativo para Vorbis Comment y PICTURE/METADATA_BLOCK_PICTURE como respaldo cuando AVFoundation no puede extraerlos.
- **Ordenación de listas**: La vista de tabla admite orden personalizado. Las listas dinámicas usan criterios jerárquicos persistentes; las estáticas permiten reordenación física.
- **Columna de extensión de archivo**: Nueva columna "Extensión de archivo" para mejorar la visibilidad de las extensiones.
- **Reordenamiento de listas**: Arrastra listas en la barra lateral para personalizar el orden.
- **Caché de carátulas de álbum**: Descarga de datos de la caché de carátulas al disco duro (gestionado por SwiftData).
- **Mejoras de rendimiento**: Se aplicaron grupos de dibujo por fila en el diseño de cuadrícula para reducir recomputaciones. Se eliminaron decodificaciones de imagen duplicadas para mejorar la capacidad de respuesta en macOS. La aplicación ofrece un rendimiento fluido en hardware moderno (Mac mini M4, Apple Silicon, etc.). En Macs Intel puede haber algo de latencia debido a AttributeGraph de SwiftUI. Los benchmarks con Xcode Instruments en un Intel Mac de 13 pulgadas de 2020 (4 Thunderbolt, i5) con macOS 26 confirman las optimizaciones.

// fr

- **Localisation ajoutée** : Français, allemand, espagnol, portugais brésilien, russe, turc, coréen, italien.
- **Contrôles médias système** : Compatibilité ajoutée avec le framework MediaPlayer système et les contrôles médias système, permettant de gérer la lecture depuis la barre de menu et le Centre de contrôle.
- **Listes de lecture dynamiques** : Prise en charge complète des listes de lecture dynamiques basées sur des prédicats hiérarchiques définis par l'utilisateur. Les utilisateurs peuvent créer des règles imbriquées complexes avec regroupement AND/OR pour filtrer automatiquement le contenu de la bibliothèque. Un éditeur de prédicats a également été ajouté pour les listes dynamiques, avec support des groupes de règles imbriquées, indicateurs visuels de profondeur et meilleure ergonomie multiplateforme.
- **État de la barre latérale** : L'interactivité de la barre latérale est maintenant désactivée lors des importations de bibliothèque pour éviter les modifications accidentelles pendant le remplissage de la bibliothèque.
- **Affichage des métadonnées de piste** : Correction du débit binaire incorrect et amélioration de la logique de repli pour les champs manquants.
- **Support des métadonnées FLAC/OGG/OPUS** : Correction d'un problème de non-reconnaissance des métadonnées. Ajout d'un analyseur natif pour Vorbis Comment et PICTURE/METADATA_BLOCK_PICTURE comme solution de secours quand AVFoundation ne peut pas les extraire.
- **Tri des listes** : La vue tableau prend en charge le tri personnalisé. Les listes dynamiques utilisent des critères persistants ; les listes statiques permettent une réorganisation physique.
- **Colonne extension de fichier** : Nouvelle colonne « Extension de fichier » pour améliorer la visibilité des extensions.
- **Réorganisation des listes** : Glisser les listes dans la barre latérale pour personnaliser l'ordre.
- **Mise en cache des pochettes d'album** : Déchargement du cache d'illustrations d'album vers le disque (géré par SwiftData).
- **Améliorations de performance** : Application de groupes de dessin par ligne pour la mise en page en grille. Suppression des décodages d'images en double pour une meilleure réactivité sur macOS. Performances fluides sur matériel moderne (Mac mini M4, Apple Silicon). Sur les Mac Intel, quelques ralentissements peuvent subsister à cause de SwiftUI AttributeGraph. Les benchmarks Xcode Instruments sur un Intel Mac 13 pouces 2020 (4 Thunderbolt, i5) sous macOS 26 confirment les optimisations.

// it

- **Localizzazione aggiunta**: Francese, tedesco, spagnolo, portoghese brasiliano, russo, turco, coreano, italiano.
- **Controlli multimediali di sistema**: Compatibilità aggiunta con MediaPlayer di sistema e con i controlli multimediali di sistema (barra dei menu/Control Center) per gestire la riproduzione.
- **Playlist dinamiche**: Supporto completo per playlist dinamiche basate su predicati gerarchici definiti dall'utente. È possibile creare regole nidificate complesse con raggruppamento AND/OR per filtrare automaticamente il contenuto della libreria. È stato aggiunto anche un editor di predicati con gruppi di regole nidificate, indicatori di profondità visivi e usabilità multipiattaforma migliorata.
- **Stato barra laterale**: L'interattività della barra laterale è ora disabilitata durante l'importazione della libreria per evitare modifiche accidentali mentre la libreria viene popolata.
- **Visualizzazione metadati traccia**: Corretto il bitrate errato e migliorata la logica di fallback per i campi mancanti.
- **Supporto metadati FLAC/OGG/OPUS**: Risolto un problema di mancato riconoscimento dei metadati. Aggiunto un parser nativo per Vorbis Comment e PICTURE/METADATA_BLOCK_PICTURE come soluzione di fallback quando AVFoundation non riesce a estrarli.
- **Ordinamento playlist**: La vista tabella supporta ora l'ordinamento personalizzato. Le playlist dinamiche usano criteri persistenti; le playlist statiche supportano il riordinamento fisico.
- **Colonna estensione file**: Aggiunta una nuova colonna "Estensione file" per migliorare la visibilità delle estensioni.
- **Riordino playlist**: Trascina le playlist nella barra laterale per personalizzare l'ordine.
- **Cache copertine album**: Scaricamento dei dati della cache delle copertine su disco rigido (gestito da SwiftData).
- **Miglioramenti prestazioni**: Gruppi di disegno per riga nel layout a griglia. Eliminazione della decodifica immagini duplicata per migliorare la reattività su macOS. Prestazioni fluide su hardware moderno (Mac mini M4, Apple Silicon). Su Mac Intel è possibile qualche ritardo dovuto ad AttributeGraph. I benchmark di Xcode Instruments su un Intel Mac 13” 2020 (4 Thunderbolt, i5) con macOS 26 confermano le ottimizzazioni.

// pt-BR

- **Localização adicionada**: Francês, alemão, espanhol, português do Brasil, russo, turco, coreano, italiano.
- **Controles de mídia do sistema**: Compatibilidade adicionada com o framework MediaPlayer do sistema e com os controles de mídia do sistema (barra de menus/Control Center) para controle de reprodução.
- **Playlists dinâmicas**: Suporte completo para playlists dinâmicas baseadas em predicados hierárquicos definidos pelo usuário. É possível criar regras aninhadas complexas com agrupamento AND/OR para filtrar automaticamente o conteúdo da biblioteca. Também foi adicionado um editor de predicados com grupos de regras aninhadas, indicadores visuais de profundidade e usabilidade multiplataforma melhorada.
- **Estado da barra lateral**: A interatividade da barra lateral agora está desativada durante importações de biblioteca para evitar alterações acidentais enquanto a biblioteca é preenchida.
- **Exibição de metadados de faixa**: Corrigido o bitrate incorreto e melhorada a lógica de fallback para campos ausentes.
- **Suporte a metadados FLAC/OGG/OPUS**: Corrigido um problema de reconhecimento de metadados. Adicionado um parser nativo para Vorbis Comment e PICTURE/METADATA_BLOCK_PICTURE como fallback quando o AVFoundation não consegue extraí-los.
- **Ordenação de playlists**: A visualização em tabela agora suporta ordenação personalizável. Playlists dinâmicas usam critérios persistentes; playlists estáticas permitem reordenação física.
- **Coluna de extensão de arquivo**: Adicionada uma nova coluna "Extensão de arquivo" para melhorar a visibilidade das extensões.
- **Reordenamento de playlists**: Arraste as playlists na barra lateral para personalizar a ordem.
- **Cache de capas de álbum**: Descarregamento dos dados do cache de capas de álbum para o disco (gerenciado por SwiftData).
- **Melhorias de desempenho**: Grupos de desenho por linha no layout em grade. Remoção da decodificação de imagem duplicada para melhor responsividade no macOS. Desempenho suave em hardware moderno (Mac mini M4, Apple Silicon). Macs Intel podem notar alguma lentidão devido ao AttributeGraph. Benchmarks do Xcode Instruments em um Intel Mac 13" 2020 (4 Thunderbolt, i5) com macOS 26 confirmam as otimizações.

// ru

- **Добавлены локализации**: Французский, немецкий, испанский, португальский (Бразилия), русский, турецкий, корейский, итальянский.
- **Системные медиа-контролы**: Добавлена совместимость с системным MediaPlayer и системными медиа-контролами, что позволяет управлять воспроизведением из строки меню и Control Center.
- **Динамические плейлисты**: Полная поддержка динамических плейлистов, основанных на иерархических пользовательских предикатах. Можно создавать сложные вложенные правила с группировкой AND/OR для автоматической фильтрации содержимого библиотеки. Также добавлен редактор предикатов с вложенными группами правил, визуальными индикаторами глубины и улучшенным кроссплатформенным удобством использования.
- **Состояние боковой панели**: Интерактивность боковой панели теперь отключена во время импорта библиотеки, чтобы предотвратить случайные изменения во время заполнения библиотеки.
- **Отображение метаданных трека**: Исправлено неверное отображение битрейта и улучшена логика резервного варианта для отсутствующих полей метаданных.
- **Поддержка метаданных FLAC/OGG/OPUS**: Исправлена проблема, при которой поля метаданных файлов FLAC, OGG Vorbis и Opus не распознавались. Добавлен нативный парсер для блоков метаданных Vorbis Comment и PICTURE/METADATA_BLOCK_PICTURE, который используется как резервный вариант, когда AVFoundation не может их извлечь.
- **Сортировка плейлистов**: Теперь таблица поддерживает настраиваемую сортировку. Динамические плейлисты используют постоянные иерархические составные критерии сортировки на плейлист; статические плейлисты позволяют физически переупорядочивать треки и сохранять новую последовательность.
- **Колонка расширения файла**: Добавлена новая колонка «Расширение файла» для лучшей видимости расширений.
- **Переупорядочивание плейлистов**: Теперь можно перетаскивать плейлисты в боковой панели, чтобы настраивать порядок отображения.
- **Кэш обложек альбомов**: Данные кэша обложек альбомов выгружены на жесткий диск (управляется SwiftData).
- **Улучшения производительности**: Применены группы рисования по строкам в сеточной компоновке, чтобы уменьшить ненужные пересчеты представлений. Удалены дублирующиеся задачи декодирования изображений для повышения общей отзывчивости. Приложение сохраняет плавную работу на современном оборудовании (Mac mini M4, Apple Silicon и т.д.). На Intel Mac возможны небольшие задержки из-за AttributeGraph. Обширные бенчмарки Xcode Instruments на Intel Mac 13” 2020 (4 Thunderbolt, i5) под macOS 26 подтверждают выполненные оптимизации.

// tr

- **Yerelleştirme eklendi**: Fransızca, Almanca, İspanyolca, Brezilya Portekizcesi, Rusça, Türkçe, Korece, İtalyanca.
- **Sistem medya kontrolleri**: Sistem MediaPlayer çerçevesi ve sistem medya kontrolleri (menü çubuğu/Denetim Merkezi) desteği eklendi; artık menü çubuğu ve Denetim Merkezi'nden oynatma yönetilebilir.
- **Dinamik çalma listeleri**: Hiyerarşik kullanıcı tanımlı yüklemler tarafından desteklenen dinamik çalma listeleri için kapsamlı destek eklendi. AND/OR gruplarıyla karmaşık iç içe kurallar oluşturup kitaplık içeriğini otomatik olarak filtreleyebilirsiniz. İç içe kural grupları, görsel derinlik göstergeleri ve geliştirilmiş çapraz platform kullanılabilirliği sunan bir yüklem düzenleyicisi de eklendi.
- **Kenar çubuğu durumu**: Kitaplık içe aktarımı sırasında kenar çubuğu etkileşimi devre dışı bırakılır; böylece yanlışlıkla değişiklik yapılması önlenir.
- **Parça meta verisi gösterimi**: Parça Bilgisi iletişim kutusundaki yanlış bit hızı gösterimi düzeltildi. Eksik meta veri alanları için geri dönüş mantığı iyileştirildi.
- **FLAC/OGG/OPUS meta veri desteği**: FLAC, OGG Vorbis ve Opus dosyalarındaki tüm meta veri alanlarının tanınmaması sorunu giderildi. AVFoundation çıkaramazsa yedek olarak kullanılan Vorbis Comment ve PICTURE/METADATA_BLOCK_PICTURE meta veri blokları için yerel ayrıştırıcı eklendi.
- **Çalma listesi sıralaması**: Tablo görünümü artık özelleştirilebilir sıralamayı destekler. Dinamik çalma listeleri çalma listesi başına kalıcı hiyerarşik bileşik sıralama ölçütlerini kullanır; statik çalma listeleri kullanıcıların parçaları fiziksel olarak yeniden sıralamasına ve yeni diziyi korumasına izin verir.
- **Dosya uzantısı sütunu**: Parça görünümüne uzantıların görünürlüğünü artırmak için yeni bir "Dosya Uzantısı" sütunu eklendi.
- **Çalma listesi yeniden sıralama**: Çalma listelerini yan çubukta yukarı ve aşağı sürükleyerek görüntü sırasını özelleştirebilirsiniz.
- **Albüm kapak önbelleği**: Albüm kapak önbellek verileri diske aktarıldı (SwiftData tarafından yönetilir).
- **Performans iyileştirmeleri**: Izgara düzenlerinde satır başına çizim grupları uygulanarak gereksiz görünüm yeniden hesaplamaları azaltıldı. Tekrarlanan görüntü kod çözme görevleri kaldırılarak macOS'ta genel yanıt verme hızı iyileştirildi. Uygulama modern donanımda (Mac mini M4, Apple Silicon, vb.) akıcı performansı korur. Intel Mac'lerde SwiftUI AttributeGraph yükü nedeniyle bazı arayüz gecikmeleri görülebilir. macOS 26 altında çalışan Intel Mac 13" 2020 modelinde (4 Thunderbolt, dört çekirdekli i5) yapılan kapsamlı Xcode Instruments benchmarkları, yapılan optimizasyonları doğrulamaktadır.

// de

- **Lokalisierung hinzugefügt**: Französisch, Deutsch, Spanisch, brasilianisches Portugiesisch, Russisch, Türkisch, Koreanisch, Italienisch.
- **Systemmediensteuerungen**: Kompatibilität mit dem systemeigenen MediaPlayer und den Systemmediensteuerungen (Menüleiste/Control Center) hinzugefügt, sodass die Wiedergabe über die Menüleiste und das Control Center verwaltet werden kann.
- **Dynamische Wiedergabelisten**: Umfassende Unterstützung für dynamische Wiedergabelisten auf Basis hierarchischer benutzerdefinierter Prädikate. Komplexe verschachtelte Regeln mit AND/OR-Gruppierung können erstellt werden, um Bibliotheksinhalte automatisch zu filtern. Ein Prädikatseditor wurde ebenfalls hinzugefügt, mit verschachtelten Regelgruppen, visuellen Tiefenindikatoren und verbesserter plattformübergreifender Benutzerfreundlichkeit.
- **Seitenleisten-Status**: Die Interaktivität der Seitenleiste ist während des Bibliotheksimports deaktiviert, um versehentliche Änderungen zu verhindern.
- **Track-Metadatenanzeige**: Fehlerhafte Bitratenanzeige korrigiert und Fallback-Logik für fehlende Felder verbessert.
- **FLAC/OGG/OPUS-Metadaten-Unterstützung**: Ein Problem wurde behoben, bei dem Metadatenfelder in FLAC-, OGG-Vorbis- und Opus-Dateien nicht erkannt wurden. Ein nativer Parser für Vorbis Comment- und PICTURE/METADATA_BLOCK_PICTURE-Metadatenblöcke wurde als Fallback hinzugefügt, wenn AVFoundation sie nicht extrahieren kann.
- **Wiedergabelisten-Sortierung**: Die Tabellenansicht unterstützt jetzt benutzerdefinierte Sortierung. Dynamische Wiedergabelisten verwenden pro Liste persistente hierarchische zusammengesetzte Sortierkriterien; statische Wiedergabelisten erlauben Benutzern das physische Neuanordnen von Titeln und das Beibehalten der neuen Reihenfolge.
- **Dateierweiterungs-Spalte**: Neue Spalte "Dateierweiterung" zur Titelansicht hinzugefügt, um die Sichtbarkeit der Erweiterungen zu verbessern.
- **Wiedergabelisten-Neuordnung**: Wiedergabelisten können in der Seitenleiste nach oben und unten gezogen werden, um die Anzeigereihenfolge anzupassen.
- **Albumcover-Cache**: Albumcover-Cache-Daten wurden auf die Festplatte ausgelagert (verwaltet von SwiftData).
- **Leistungsverbesserungen**: Zeilenweise Zeichnungsgruppen wurden auf das Grid-Layout angewendet, um unnötige Neuberechnungen von Ansichten zu reduzieren. Doppelte Bilddekodierungsaufgaben wurden entfernt, um die allgemeine Reaktionsfähigkeit auf macOS zu verbessern. Die App behält auf moderner Hardware (Mac mini M4, Apple Silicon usw.) eine flüssige Leistung. Auf Intel-Macs kann es aufgrund des SwiftUI-AttributeGraph-Overheads zu etwas UI-Lag kommen. Umfangreiche Xcode-Instruments-Benchmarks auf einem Intel Mac 13 Zoll 2020 (4 Thunderbolt, Quad-Core i5) unter macOS 26 bestätigen, dass die praktikablen Optimierungen umgesetzt wurden.
