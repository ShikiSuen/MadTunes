# v26.03.25 (iOS)

// en

- **Dynamic playlists**: Added comprehensive support for dynamic playlists driven by hierarchical user-defined predicates. Users can create complex nested rules with AND/OR grouping to automatically filter library contents. Also added predicate editor for dynamic playlists with nested group support (AND/OR sub-groups), visual depth indicators, and improved cross-platform usability between desktop and mobile UIs.
- **Sidebar state**: Sidebar interactability is now disabled during library imports to prevent accidental modifications while the library is being populated.
- **Track metadata display**: Fixed incorrect bitrate display in the Track Info dialog. Improved fallback logic for missing metadata fields.
- **FLAC/OGG/OPUS metadata support**: Fixed an issue where FLAC, OGG Vorbis, and Opus files had all metadata fields (title, artist, album, artwork, etc.) unrecognized. Added a native parser for Vorbis Comment and PICTURE/METADATA_BLOCK_PICTURE metadata blocks as a fallback when AVFoundation fails to extract them.
- **Track sorting in a playlist**: Table view and Phone UI now support customizable sorting. Dynamic playlists use persistent hierarchical compound sort criteria per playlist; static playlists allow users to physically reorder tracks and persist the new sequence.
- **File extension column**: Added new "File Extension" column to track view for better file extension visibility.
- **Playlist reordering**: Playlists can now have their track order customized.
- **Phone UI enhancements**: Added multi-select support to playlist detail views in Phone UI. Implemented sort-by-field functionality within the Metro-style interface.
- **Column Browser**: Fixed layout issues on iPad.
- **Performance improvements**: Applied per-row drawing groups to reduce unnecessary view recomputations in grid layout. Eliminated duplicate image decoding tasks to improve overall responsiveness across devices. The app maintains smooth performance on modern devices (iPhone 16, etc.). For legacy iOS devices, some UI lag may still be noticeable due to SwiftUI's AttributeGraph overhead.

// zh-Hans

- **动态播放清单**：添加了对由用户定义的分层谓词驱动的动态播放清单的全面支持。用户可以创建具有 AND/OR 分组的复杂嵌套规则，以自动筛选媒体柜的内容。同时为动态播放清单添加了谓词编辑器，支持嵌套规则组（AND/OR 子组）、视觉深度指标，以及改进的桌面和移动 UI 之间的跨平台可用性。
- **侧边栏状态**：媒体柜在正在接收文件导入期间禁用侧边栏交互，防止填充期间误操作。
- **曲目中继资料显示**：修复了曲目资讯对话框中不正确的比特率显示。改善了缺失中继资料栏位的回退逻辑。
- **FLAC/OGG/OPUS 中继资料支持**：修复了 FLAC、OGG Vorbis、Opus 文件所有中继资料栏位（标题、艺术家、专辑、封面等）无法识别的问题。新增原生解析器用于解析 Vorbis Comment 和 PICTURE/METADATA_BLOCK_PICTURE 中继资料块，当 AVFoundation 无法提取时作为后备。
- **播放清单排序**：表格视图和 Phone UI 现在支持可自订排序。动态播放清单使用每个播放清单的持久分层复合排序标准；静态播放清单允许用户物理重新排序曲目并保留新序列。
- **文件扩展名栏**：在曲目视图中新增「扩展名」栏，提高扩展名可见性。
- **播放清单重新排序**：播放清单现可自订曲目显示顺序。
- **Phone UI 增强功能**：在 Phone UI 中的播放清单详细资讯视图中添加了多选支持。在 Metro 风格界面内实现了按栏位排序功能。
- **Column Browser 优化**：修复了 iPad 上的布局问题。
- **性能改进**：为网格布局应用了分行绘制组，减少不必要的视图重新计算。消除了重复的图像解码任务以改进整体响应性。应用在现代设备（iPhone 16 等）上保持流畅效能。对于旧版 iOS 设备，由于 SwiftUI 的 AttributeGraph 开销，可能仍会出现 UI 延迟。

// zh-Hant

- **動態播放清單**：新增了由使用者定義的分層述詞驅動的動態播放清單的完整支援。使用者可以建立具有 AND/OR 分組的複雜嵌套規則，以自動篩選媒體櫃內容。同時為動態播放清單新增了述詞編輯器，支援嵌套式規則群組（AND/OR 子群組）、視覺深度指標，以及改進的桌面與行動介面間的跨平台易用性。
- **側邊欄狀態**：媒體櫃在正在接收檔案匯入期間禁用側邊欄互動，避免填充期間誤操作。
- **曲目中繼資料顯示**：修復曲目資訊對話框的位元率顯示錯誤。改善了缺少中繼資料欄位的遞補邏輯。
- **FLAC/OGG/OPUS 中繼資料支援**：修復 FLAC、OGG Vorbis、Opus 檔案中所有中繼資料欄位（標題、藝人、專輯、封面等）無法識別的問題。新增原生解析器解析 Vorbis Comment 和 PICTURE/METADATA_BLOCK_PICTURE 中繼資料區塊，當 AVFoundation 無法擷取時作為後備。
- **播放清單排序**：表格檢視及 Phone 介面現在支援可自訂的排序。動態播放清單使用每個清單的持續型分層複合排序條件；靜態播放清單允許使用者手動調整曲目順序並保存新序列。
- **副檔名欄**：在曲目檢視新增了「副檔名」欄，提升副檔名可見性。
- **播放清單重新排序**：播放清單現可自訂曲目顯示順序。
- **Phone 介面增強功能**：在 Phone 介面的播放清單詳細資訊檢視中新增了多選支援。在 Metro 風格介面內實作了按欄位排序功能。
- **Column Browser 最適化**：修復了 iPad 上的佈局問題。
- **效能最佳化**：為網格介面佈局應用了按列繪製群組，以減少不必要的視圖重新計算。消除重複的影像解碼工作，改善整體回應速度。應用程式在現代裝置（iPhone 16 等）上保持流暢效能。對於舊版 iOS 裝置，由於 SwiftUI 的 AttributeGraph 負荷，仍可能出現 UI 反應遲緩。

// ja

- **ダイナミックプレイリスト**：ユーザー定義の階層型述語によるダイナミックプレイリストの包括的なサポートを追加。ユーザーは AND/OR グループで複雑なネストされたルールを作成して、ライブラリの内容を自動的にフィルタリングできます。同時にダイナミックプレイリスト向け述語エディタを追加し、ネストされたルールグループ（AND/OR サブグループ）、視覚的な奥行き表示、デスクトップとモバイル UI 間の改善されたクロスプラットフォーム使いやすさをサポートしています。
- **サイドバー状態**：ライブラリ読み込み中、サイドバーのインタラクティブ操作が無効になり、ライブラリの設定中に誤った変更が加えられるのを防ぎます。
- **トラックメタデータ表示**：トラック情報ダイアログでの不正確なビットレート表示を修正。不足しているメタデータフィールドのフォールバック ロジックを改善。
- **FLAC/OGG/OPUS メタデータサポート**：FLAC、OGG Vorbis、および Opus ファイルのすべてのメタデータフィールド（タイトル、アーティスト、アルバム、アートワークなど）が認識されない問題を修正。Vorbis Comment と PICTURE/METADATA_BLOCK_PICTURE メタデータブロックを解析するネイティブパーサーを追加し、AVFoundation が抽出に失敗した場合のフォールバックとしています。
- **プレイリストソート**：テーブルビューと Phone UI は、カスタマイズ可能なソート機能をサポート。ダイナミックプレイリストはプレイリスト単位で永続化された階層型複合ソート基準を使用、静的プレイリストはトラックの物理的な並べ替えと新しいシーケンスの永続化が可能。
- **ファイル拡張子欄**：トラックビューに新しい「拡張子」欄を追加し、拡張子の視認性を向上。
- **プレイリスト並べ替え**：プレイリスト内のトラック順序をカスタマイズできるようになりました。
- **Phone UI の機能強化**：Phone UI のプレイリスト詳細ビューに複数選択サポートを追加。Metro スタイル インターフェース内でフィールド別ソート機能を実装。
- **Column Browser の改善**：iPad 上のレイアウト問題を修正。
- **パフォーマンス向上**：グリッドUI組版レイアウトに行単位の描画グループを適用し、不要なビュー再計算を削減。重複した画像デコードタスクを排除し、全体的な応答性を改善。アプリは最新デバイス（iPhone 16 など）で継続的に快適に動作します。旧式 iOS デバイスでは、SwiftUI の AttributeGraph オーバーヘッドにより UI ラグが生じる可能性があります。

// ko

- **동적 재생 목록**: 계층형 사용자 정의 술어로 구동되는 동적 재생 목록을 포괄적으로 지원합니다. 사용자는 AND/OR 그룹으로 복잡한 중첩 규칙을 만들어 라이브러리 내용을 자동으로 필터링할 수 있습니다. 중첩된 규칙 그룹(AND/OR 하위 그룹), 시각적 깊이 표시기, 그리고 데스크톱과 모바일 UI 간의 향상된 크로스 플랫폼 사용성을 지원하는 술어 편집기도 추가했습니다.
- **사이드바 상태**: 라이브러리 가져오기 중 사이드바 상호작용이 비활성화되어 라이브러리가 채워지는 동안 실수로 인한 수정을 방지합니다.
- **트랙 메타데이터 표시**: 트랙 정보 대화 상자의 잘못된 비트레이트 표시를 수정했습니다. 누락된 메타데이터 필드에 대한 대체 로직을 개선했습니다.
- **FLAC/OGG/OPUS 메타데이터 지원**: FLAC, OGG Vorbis 및 Opus 파일의 제목, 아티스트, 앨범, 아트워크 등 모든 메타데이터 필드가 인식되지 않던 문제를 수정했습니다. AVFoundation이 추출하지 못할 때 사용하는 Vorbis Comment 및 PICTURE/METADATA_BLOCK_PICTURE 메타데이터 블록용 네이티브 파서를 추가했습니다.
- **재생 목록 정렬**: 테이블 보기와 Phone UI는 이제 사용자 정의 가능한 정렬을 지원합니다. 동적 재생 목록은 재생 목록별 지속형 계층형 복합 정렬 기준을 사용하고, 정적 재생 목록은 사용자가 트랙을 물리적으로 재정렬하고 새 순서를 유지할 수 있습니다.
- **파일 확장자 열**: 트랙 보기에 새 "파일 확장자" 열을 추가하여 파일 확장자 가시성을 높였습니다.
- **재생 목록 재정렬**: 재생 목록의 트랙 순서를 사용자화할 수 있습니다.
- **Phone UI 개선 사항**: Phone UI의 재생 목록 세부 정보 보기에서 다중 선택 지원을 추가했습니다. Metro 스타일 인터페이스 내에 필드별 정렬 기능을 구현했습니다.
- **Column Browser 개선**: iPad의 레이아웃 문제를 수정했습니다.
- **성능 개선**: 그리드 레이아웃에 행별 드로잉 그룹을 적용하여 불필요한 보기 재계산을 줄였습니다. 중복 이미지 디코딩 작업을 제거하여 전반적인 응답성을 개선했습니다. 앱은 최신 장치(iPhone 16 등)에서 매끄럽게 실행됩니다. 구형 iOS 장치에서는 SwiftUI의 AttributeGraph 오버헤드로 UI 지연이 발생할 수 있습니다.

// es

- **Listas de reproducción dinámicas**: Se ha añadido compatibilidad integral con listas de reproducción dinámicas impulsadas por predicados jerárquicos definidos por el usuario. Los usuarios pueden crear reglas anidadas complejas con agrupación AND/OR para filtrar automáticamente el contenido de la biblioteca. Se ha añadido también un editor de predicados para listas dinámicas con soporte de grupos de reglas anidadas (subgrupos AND/OR), indicadores visuales de profundidad y usabilidad multiplataforma mejorada entre interfaces de escritorio y móvil.
- **Estado de la barra lateral**: La interactividad de la barra lateral ahora está deshabilitada durante las importaciones de biblioteca para evitar modificaciones accidentales mientras se populan la biblioteca.
- **Visualización de metadatos de pistas**: Se ha corregido la visualización incorrecta de velocidad de bits en el diálogo Información de la pista. Se ha mejorado la lógica de respaldo para campos de metadatos faltantes.
- **Soporte de metadatos FLAC/OGG/OPUS**: Se ha corregido un problema donde los archivos FLAC, OGG Vorbis y Opus tenían todos los campos de metadatos (título, artista, álbum, carátula, etc.) no reconocidos. Se ha añadido un analizador nativo para los bloques de metadatos Vorbis Comment y PICTURE/METADATA_BLOCK_PICTURE como respaldo cuando AVFoundation no puede extraerlos.
- **Ordenamiento de listas de reproducción**: Vista de tabla y Phone UI ahora soportan ordenamiento personalizable. Las listas de reproducción dinámicas utilizan criterios de ordenamiento compuesto jerárquico persistentes por lista; las listas de reproducción estáticas permiten a los usuarios reordenar físicamente pistas y mantener la nueva secuencia.
- **Columna de extensión de archivo**: Se ha añadido una nueva columna de "Extensión de archivo" a la vista de pistas para mejorar la visibilidad de las extensiones.
- **Reordenamiento de listas de reproducción**: Ahora se puede personalizar el orden de las pistas en las listas de reproducción.
- **Mejoras de Phone UI**: Se ha añadido compatibilidad de selección múltiple a vistas detalladas de listas de reproducción en Phone UI. Se ha implementado funcionalidad de ordenamiento por campo dentro de la interfaz de estilo Metro.
- **Mejoras de Column Browser**: Se han corregido problemas de diseño en iPad.
- **Mejoras de rendimiento**: Aplicadas capas de dibujo por fila para reducir recomputaciones innecesarias en vistas de cuadrícula. Eliminadas tareas de decodificación de imágenes duplicadas para mejorar la capacidad de respuesta general. La aplicación mantiene un rendimiento suave en dispositivos modernos (iPhone 16, etc.). Para dispositivos iOS antiguos, aún pueden experimentarse ralentizaciones de UI debido al overhead de AttributeGraph de SwiftUI.

// fr

- **Listes de lecture dynamiques** : Ajout d'une prise en charge complète des listes de lecture dynamiques basées sur des prédicats hiérarchiques définis par l'utilisateur. Les utilisateurs peuvent créer des règles imbriquées complexes avec regroupement AND/OR pour filtrer automatiquement le contenu de la bibliothèque. Un éditeur de prédicats a également été ajouté pour les listes dynamiques, avec support des groupes de règles imbriquées (sous-groupes AND/OR), indicateurs visuels de profondeur et ergonomie multiplateforme améliorée entre les interfaces de bureau et mobiles.
- **État de la barre latérale** : L'interactivité de la barre latérale est maintenant désactivée lors des importations de bibliothèque pour éviter les modifications accidentelles pendant le remplissage de la bibliothèque.
- **Affichage des métadonnées de piste** : Correction de l'affichage incorrect du débit binaire dans la boîte de dialogue Informations de piste. Amélioration de la logique de secours pour les champs de métadonnées manquants.
- **Support des métadonnées FLAC/OGG/OPUS** : Correction d'un problème où les fichiers FLAC, OGG Vorbis et Opus avaient tous les champs de métadonnées (titre, artiste, album, pochette, etc.) non reconnus. Ajout d'un analyseur natif pour les blocs de métadonnées Vorbis Comment et PICTURE/METADATA_BLOCK_PICTURE comme secours lorsque AVFoundation échoue à les extraire.
- **Tri des listes de lecture** : Les vues tableau et Phone UI prennent maintenant en charge le tri personnalisable. Les listes de lecture dynamiques utilisent des critères de tri composé hiérarchique persistants par liste ; les listes de lecture statique permettent aux utilisateurs de réorganiser physiquement les pistes et de conserver la nouvelle séquence.
- **Colonne d'extension de fichier** : Ajout d'une nouvelle colonne « Extension de fichier » à la vue des pistes pour une meilleure visibilité des extensions.
- **Réorganisation des listes de lecture** : Il est maintenant possible de personnaliser l'ordre des pistes dans les listes de lecture.
- **Améliorations de Phone UI** : Ajout de la prise en charge de la sélection multiple aux vues détaillées de listes de lecture dans Phone UI. Implémentation de la fonctionnalité de tri par champ dans l'interface de style Metro.
- **Améliorations du Column Browser** : Correction des problèmes de mise en page sur iPad.
- **Améliorations des performances** : Application de groupes de dessin par ligne pour réduire les recalculs de vue inutiles dans la mise en page grille. Élimination des tâches de décodage d'images en double pour améliorer la réactivité globale. L'application maintient des performances fluides sur les appareils modernes (iPhone 16, etc.). Pour les appareils iOS hérités, certains ralentissements d'UI peuvent toujours se produire en raison de la surcharge d'AttributeGraph de SwiftUI.

// it

- **Playlist dinamiche**: Aggiunto supporto completo per playlist dinamiche basate su predicati gerarchici definiti dall'utente. Gli utenti possono creare regole nidificate complesse con raggruppamento AND/OR per filtrare automaticamente il contenuto della libreria. È stato aggiunto anche un editor di predicati per le playlist dinamiche con supporto di gruppi di regole nidificate (sottogruppi AND/OR), indicatori di profondità visivi e usabilità multipiattaforma migliorata tra UI desktop e mobile.
- **Stato della barra laterale**: L'interattività della barra laterale è ora disabilitata durante le importazioni di libreria per evitare modifiche accidentali mentre la libreria viene popolata.
- **Visualizzazione metadati traccia**: Corretto il display errato del bitrate nella finestra di dialogo Informazioni traccia. Migliorata la logica di fallback per i campi metadati mancanti.
- **Supporto metadati FLAC/OGG/OPUS**: Corretto un problema per cui i file FLAC, OGG Vorbis e Opus avevano tutti i campi metadati (titolo, artista, album, copertina, ecc.) non riconosciuti. Aggiunto un parser nativo per i blocchi di metadati Vorbis Comment e PICTURE/METADATA_BLOCK_PICTURE come fallback quando AVFoundation non riesce a estrarli.
- **Ordinamento playlist**: La visualizzazione tabella e Phone UI supportano ora l'ordinamento personalizzabile. Le playlist dinamiche utilizzano criteri di ordinamento composito gerarchico persistenti per playlist; le playlist statiche consentono agli utenti di riordinare fisicamente i brani e mantenere la nuova sequenza.
- **Colonna estensione file**: Aggiunta una nuova colonna "Estensione file" alla vista dei brani per migliorare la visibilità delle estensioni.
- **Riordinamento playlist**: È ora possibile personalizzare l'ordine dei brani nelle playlist.
- **Miglioramenti Phone UI**: Aggiunto supporto di selezione multipla alle visualizzazioni dettagliate della playlist in Phone UI. Implementata la funzionalità di ordinamento per campo all'interno dell'interfaccia in stile Metro.
- **Miglioramenti Column Browser**: Corretti i problemi di layout su iPad.
- **Miglioramenti delle prestazioni**: Applicati gruppi di disegno per riga per ridurre i ricalcoli di visualizzazione non necessari nel layout griglia. Eliminate le attività di decodifica immagine duplicate per migliorare la reattività complessiva. L'app mantiene prestazioni fluide sui dispositivi moderni (iPhone 16, ecc.). Per i dispositivi iOS legacy, potrebbe comunque verificarsi qualche rallentamento dell'UI dovuto all'overhead di AttributeGraph di SwiftUI.

// pt-BR

- **Playlists dinâmicas**: Adicionado suporte abrangente para playlists dinâmicas impulsionadas por predicados hierárquicos definidos pelo usuário. Os usuários podem criar regras aninhadas complexas com agrupamento AND/OR para filtrar automaticamente o conteúdo da biblioteca. Um editor de predicados também foi adicionado para playlists dinâmicas, com suporte a grupos de regras aninhadas (subgrupos AND/OR), indicadores de profundidade visual e usabilidade multiplataforma melhorada entre interfaces de desktop e móvel.
- **Estado da barra lateral**: A interatividade da barra lateral agora está desativada durante importações de biblioteca para evitar modificações acidentais enquanto a biblioteca é preenchida.
- **Exibição de metadados de faixa**: Corrigida a exibição incorreta de taxa de bits no diálogo Informações da Faixa. Melhorada a lógica de fallback para campos de metadados ausentes.
- **Suporte a metadados FLAC/OGG/OPUS**: Corrigido um problema em que arquivos FLAC, OGG Vorbis e Opus tinham todos os campos de metadados (título, artista, álbum, capa, etc.) não reconhecidos. Adicionado um analisador nativo para blocos de metadados Vorbis Comment e PICTURE/METADATA_BLOCK_PICTURE como fallback quando o AVFoundation não consegue extraí-los.
- **Classificação de playlists**: A visualização de tabela e Phone UI agora suportam classificação personalizável. Playlists dinâmicas usam critérios de classificação composta hierárquica persistente por playlist; playlists estáticas permitem que os usuários reorganizem fisicamente faixas e persistam a nova sequência.
- **Coluna de extensão de arquivo**: Adicionada nova coluna "Extensão de arquivo" à visualização de faixas para melhor visibilidade das extensões.
- **Reordenação de playlists**: Agora é possível personalizar a ordem das faixas nas playlists.
- **Aprimoramentos da Phone UI**: Adicionado suporte de seleção múltipla às visualizações de detalhes de playlist em Phone UI. Implementada funcionalidade de classificação por campo dentro da interface ao estilo Metro.
- **Aprimoramentos do Column Browser**: Corrigidos problemas de layout no iPad.
- **Melhorias de desempenho**: Aplicados grupos de desenho por linha para reduzir recomputações desnecessárias de visualizações em layout de grade. Eliminadas tarefas de decodificação de imagem duplicadas para melhorar a responsividade geral. O app mantém desempenho suave em dispositivos modernos (iPhone 16, etc.). Para dispositivos iOS legados, ainda pode haver alguma demora de UI devido à sobrecarga de AttributeGraph do SwiftUI.

// ru

- **Динамические плейлисты**: Добавлена всесторонняя поддержка динамических плейлистов, управляемых иерархическими пользовательскими предикатами. Пользователи могут создавать сложные вложенные правила с группировкой AND/OR для автоматической фильтрации содержимого библиотеки. Также добавлен редактор предикатов для динамических плейлистов с поддержкой вложенных групп правил (подгруппы AND/OR), визуальными индикаторами глубины и улучшенным кроссплатформенным удобством использования между настольными и мобильными интерфейсами.
- **Состояние боковой панели**: Интерактивность боковой панели теперь отключена во время импорта библиотеки, чтобы предотвратить случайные изменения во время заполнения библиотеки.
- **Отображение метаданных трека**: Исправлено неправильное отображение битрейта в диалоговом окне "Информация о дорожке". Улучшена логика резерва для отсутствующих полей метаданных.
- **Поддержка метаданных FLAC/OGG/OPUS**: Исправлена проблема, при которой все поля метаданных файлов FLAC, OGG Vorbis и Opus (название, исполнитель, альбом, обложка и т.д.) не распознавались. Добавлен нативный парсер для блоков метаданных Vorbis Comment и PICTURE/METADATA_BLOCK_PICTURE для резервного варианта, когда AVFoundation не может их извлечь.
- **Сортировка плейлистов**: Представление таблицы и Phone UI теперь поддерживают настраиваемую сортировку. Динамические плейлисты используют постоянные иерархические составные критерии сортировки на плейлист; статические плейлисты позволяют пользователям физически переупорядочивать треки и сохранять новую последовательность.
- **Колонка расширения файла**: в представление треков добавлен новый столбец «Расширение файла» для лучшей видимости расширений.
- **Переупорядочение плейлистов**: Теперь можно настраивать порядок треков в плейлистах.
- **Улучшения Phone UI**: Добавлена поддержка множественного выбора в представления деталей плейлиста в Phone UI. Реализована функциональность сортировки по полям в интерфейсе стиля Metro.
- **Улучшения Column Browser**: Исправлены проблемы с макетом на iPad.
- **Оптимизация производительности**: Применены группы отрисовки по строкам для снижения ненужных пересчётов представлений в макете сетки. Исключены повторяющиеся задачи декодирования изображений для повышения общей отзывчивости. Приложение сохраняет плавную производительность на современных устройствах (iPhone 16 и т.д.). Для унаследованных устройств iOS все еще может наблюдаться задержка UI из-за нагрузки AttributeGraph в SwiftUI.

// tr

- **Dinamik çalma listeleri**: Kullanıcı tanımlı hiyerarşik yüklemler tarafından yönlendirilen dinamik çalma listeleri için kapsamlı destek eklendi. Kullanıcılar kütüphanenin içeriğini otomatik olarak filtrelemek için AND/OR gruplandırması ile karmaşık iç içe kurallar oluşturabilir. Dinamik çalma listeleri için bir yüklem düzenleyicisi de eklenmiş olup, iç içe kural grupları (AND/OR alt grupları), görsel derinlik göstergeleri ve masaüstü ile mobil kullanıcı arayüzleri arasında iyileştirilmiş çapraz platform kullanılabilirliğini desteklemektedir.
- **Kenar çubuğu durumu**: Kütüphane güncellemelerinin doldurulması sırasında yanlışlıkla yapılan değişiklikleri önlemek için kütüphane içe aktarma sırasında kenar çubuğu etkileşimi şimdi devre dışı bırakılmıştır.
- **İz meta verisi görüntüsü**: İz Bilgisi iletişim kutusunda yanlış bit hızı görüntüsü düzeltildi. Eksik meta veri alanları için geri dönüş mantığı iyileştirildi.
- **FLAC/OGG/OPUS meta veri desteği**: FLAC, OGG Vorbis ve Opus dosyalarının tüm meta veri alanlarının (başlık, sanatçı, albüm, kapağı, vb.) tanınmadığı bir sorun düzeltildi. Vorbis Comment ve PICTURE/METADATA_BLOCK_PICTURE meta veri blokları için yerel bir ayrıştırıcı eklendi; AVFoundation çıkaramıyorsa yedek olarak kullanılır.
- **Çalma listesi sıralaması**: Tablo görünümü ve Phone UI artık özelleştirilebilir sıralamayı destekler. Dinamik çalma listeleri çalma listesi başına kalıcı hiyerarşik bileşik sıralama kriterlerini kullanır; statik çalma listeleri, kullanıcıların izleri fiziksel olarak yeniden sıralamasına ve yeni diziyi sürdürmesine izin verir.
- **Dosya uzantısı sütunu**: Parça görünümüne uzantıların görünürlüğünü artırmak için yeni bir "Dosya Uzantısı" sütunu eklendi.
- **Çalma listesi yeniden sıralaması**: Çalma listelerindeki şarkı sırası artık özelleştirilebilir.
- **Phone UI iyileştirmeleri**: Phone UI'deki çalma listesi ayrıntı görünümlerine çoklu seçim desteği eklendi. Metro stil arayüzü içinde alana göre sıralama işlevi uygulandı.
- **Column Browser iyileştirmeleri**: iPad'te Sütun Tarayıcı düzeni sorunları düzeltildi.
- **Performans iyileştirmeleri**: Izgara düzenlerindeki gereksiz görünüm yeniden hesaplamalarını azaltmak için satır başına çizim grupları uygulanmıştır. Genel yanıt verme yeteneğini iyileştirmek için yinelenen görüntü kod çözme görevleri ortadan kaldırılmıştır. Uygulama modern cihazlarda (iPhone 16, vb.) sorunsuz performansı korur. Eski iOS cihazlarında UI gecikmeleri, SwiftUI'nun AttributeGraph ek yükü nedeniyle hala beklenebilir.

// de

- **Dynamische Wiedergabelisten**: Umfassende Unterstützung für dynamische Wiedergabelisten hinzugefügt, die durch benutzerdefinierte hierarchische Prädikate betrieben werden. Benutzer können komplexe verschachtelte Regeln mit AND/OR-Gruppierung erstellen, um Bibliotheksinhalte automatisch zu filtern. Ein Prädikatseditor für dynamische Wiedergabelisten wurde ebenfalls hinzugefügt und unterstützt verschachtelte Regelgruppen (AND/OR-Untergruppen), visuelle Tiefenmarkierungen und verbesserte plattformübergreifende Benutzerfreundlichkeit zwischen Desktop- und Mobil-UI.
- **Seitenleisten-Status**: Die Seitenleisteninteraktion ist jetzt während des Bibliotheksimports deaktiviert, um versehentliche Änderungen während der Befüllung der Bibliothek zu verhindern.
- **Anzeige von Track-Metadaten**: Fehlerhafte Bitrate-Anzeige im Trackinfo-Dialog behoben. Verbesserte Fallback-Logik für fehlende Metadatenfelder.
- **FLAC/OGG/OPUS-Metadaten-Unterstützung**: Ein Problem wurde behoben, bei dem alle Metadatenfelder von FLAC, OGG Vorbis und Opus-Dateien (Titel, Künstler, Album, Cover usw.) nicht erkannt wurden. Ein nativer Parser für Vorbis Comment- und PICTURE/METADATA_BLOCK_PICTURE-Metadatenblöcke wurde hinzugefügt, der als Fallback dient, wenn AVFoundation sie nicht extrahiert.
- **Wiedergabelisten-Sortierung**: In der Tabellenansicht und der Phone UI können Sie jetzt benutzerdefinierte Sortierung verwenden. Dynamische Wiedergabelisten verwenden persistente hierarchische zusammengesetzte Sortierkriterien pro Wiedergabeliste; statische Wiedergabelisten ermöglichen Benutzern das physische Neuanordnen von Titeln und das Beibehalten der neuen Reihenfolge.
- **Dateiendungs-Spalte**: Neue Spalte "Dateierweiterung" zur Titelansicht hinzugefügt, um die Sichtbarkeit der Erweiterungen zu verbessern.
- **Wiedergabelisten-Neuanordnung**: Die Titelreihenfolge in Wiedergabelisten kann nun angepasst werden.
- **Phone UI-Verbesserungen**: Unterstützung für Mehrfachauswahl zu Wiedergabelisten-Detailansichten in Phone UI hinzugefügt. Feldweise Sortierfunktionalität in der Metro-Oberfläche implementiert.
- **Column Browser-Verbesserungen**: Probleme mit dem Column Browser-Layout auf iPad behoben.
- **Leistungsverbesserungen**: Anwendung von zeilenweisen Zeichnungsgruppen, um unnötige Neuberechnungen von Ansichten im Rasterlayout zu reduzieren. Beseitigung doppelter Bilddekodierungsaufgaben zur Verbesserung der Gesamtreaktionsfähigkeit. Die App behält auf modernen Geräten (iPhone 16 usw.) reibungslose Leistung. Bei älteren iOS-Geräten können UI-Verzögerungen aufgrund des SwiftUI-AttributeGraph-Overheads auftreten.

$ EOF.
