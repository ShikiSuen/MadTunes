# v26.04.10 (macOS AppKit)

// en

- **Sandbox bookmark validity UX**: Improved the UX to help users get noticed about possible Sandbox bookmark validity issues. Users can use the "Reapprove Sandbox Privileges" menu command to select a folder to re-grant MadTunes access to it. The app will cross-check its contents with your library and all folder playlists, then renew any expired bookmarks found within.
- **CoreAudio concurrency fix**: Fixed concurrency priority issues with CoreAudio APIs.
- **UI details improvements**: Ameliorated UI details across the app.
- **Horizontal Album Grid**: Introducing the 3rd content layout for MacBook users. All albums are listed in a horizontal scroll view. When an album is expanded, the expanded contents are placed to the right of the current vertical row of albums and show the track list of the album in an embedded vertical scroll view. This reduces the total amount of swipe gestures needed when you just want to swipe around the albums from the beginning to the end. When toggling between the horizontal and vertical album grid layouts, the expanded album will automatically get scrolled to, ensuring its visibility. This new content layout will be the default layout since this release, but the app will remember your preferred content layout on the device.
- **Album Grid UI improvements**: Improved the track list view of the expanded album when the content layout is Album Grid.
- **Column Browser appearance fix**: Fixed weird appearance of Column Browser when system accessibility settings turned the transparency off or the current UI theme is not Liquid Glass.
- **Keyboard hotkey improvements**: Stopped considering CapsLock state while handling keyboard hotkeys. This fixes certain issues when CapsLock is on. Also fixed an issue where the app might have misunderstood the current modifier key state in some situations.
- **Album Grid hotkeys**: Added `Option+↑↓←→` hotkeys to Album Grid layouts for switching the current expanded album. This hotkey is effective regardless of the content scroll orientation.

// zh-Hans

- **沙箱书签有效性 UX**：改善了用户体验，帮助用户了解可能的沙箱书签有效性问题。使用者可以使用「重新核准沙箱权限」菜单命令来选择资料夹以重新授予 MadTunes 访问权限。App 会将其内容与媒体柜和所有资料夹播放清单进行比对，然后更新任何已过期的书签。
- **CoreAudio 并发修复**：修复了 CoreAudio API 的并发优先级问题。
- **UI 细节改善**：改善了 App 各处的 UI 细节。
- **横向专辑网格**：为 MacBook 用户推出第 3 种内容布局。所有专辑在横向滚动视图中排列。当专辑展开时，展开的内容会放置在当前专辑垂直列的右侧，并在内嵌的垂直滚动视图中显示专辑的曲目列表。当您只需要从头到尾滑动浏览专辑时，这减少了所需的总滑动次数。在横向和纵向专辑网格布局之间切换时，展开的专辑会自动滚动到可见位置。此新内容布局将从本版本开始成为默认布局，但 App 会记住您偏好的内容布局。
- **专辑网格 UI 改善**：改善了专辑网格布局下展开专辑的曲目列表视图。
- **直栏浏览器外观修复**：当系统辅助使用设置关闭了透明度，或当前 UI 主题不是 Liquid Glass 时，直栏浏览器的显示异常问题已修复。
- **键盘快捷键改善**：在处理键盘快捷键时不再考虑 CapsLock 状态。这解决了 CapsLock 开启时的某些问题。同时修复了 App 在某些情况下可能误解当前修饰键状态的问题。
- **专辑网格快捷键**：为专辑网格布局新增 `Option+↑↓←→` 快捷键，用于切换当前展开的专辑。无论内容滚动方向为何，此快捷键均有效。

// zh-Hant

- **沙箱書籤有效性 UX**：改善了使用者體驗，幫助使用者了解可能的沙箱書籤有效性問題。使用者可以使用「重新核准沙箱權限」選單指令來選擇資料夾以重新授予 MadTunes 存取權限。App 會將其內容與媒體櫃和所有資料夾播放清單進行比對，然後更新任何已過期的書籤。
- **CoreAudio 並發修復**：修復了 CoreAudio API 的並發優先級問題。
- **UI 細節改善**：改善了 App 各處的 UI 細節。
- **橫向專輯網格**：為 MacBook 使用者推出第 3 種內容佈局。所有專輯在橫向滾動視圖中排列。當專輯展開時，展開的內容會放置在當前專輯垂直列的右側，並在內嵌的垂直滾動視圖中顯示專輯的曲目列表。當您只需要從頭到尾滑動瀏覽專輯時，這減少了所需的總滑動次數。在橫向和縱向專輯網格佈局之間切換時，展開的專輯會自動滾動到可見位置。此新內容佈局將從本版本開始成為預設佈局，但 App 會記住您偏好的內容佈局。
- **專輯網格 UI 改善**：改善了專輯網格佈局下展開專輯的曲目列表視圖。
- **直欄瀏覽器外觀修復**：當系統輔助使用設定關閉了透明度，或當前 UI 主題不是 Liquid Glass 時，直欄瀏覽器的顯示異常問題已修復。
- **鍵盤快捷鍵改善**：在處理鍵盤快捷鍵時不再考慮 CapsLock 狀態。這解決了 CapsLock 開啟時的某些問題。同時修復了 App 在某些情況下可能誤解當前修飾鍵狀態的問題。
- **專輯網格快捷鍵**：為專輯網格佈局新增 `Option+↑↓←→` 快捷鍵，用於切換當前展開的專輯。無論內容滾動方向為何，此快捷鍵均有效。

// ja

- **サンドボックスブックマーク有効性 UX**：サンドボックスブックマークの有効性に関する問題をユーザーに通知する UX を改善しました。「Sandbox 権限を再承認」メニューコマンドを使用して、MadTunes がアクセスするフォルダーを選択できます。App はその内容をライブラリおよびすべてのフォルダプレイリストと照合し、期限切れのブックマークを更新します。
- **CoreAudio 同時実行修正**：CoreAudio API の同時実行優先順位の問題を修正しました。
- **UI ディテールの改善**：アプリ全体の UI ディテールを改善しました。
- **Horizontal アルバムグリッド**：MacBook ユーザー向けの3番目のコンテンツレイアウトを導入します。すべてのアルバムは横スクロールビューにリストされます。アルバムを展開すると、展開したコンテンツは現在のアルバム垂直列の右側に配置され、アルバムトラックリストが埋め込みの垂直スクロールビューに表示されます。これにより、最初から最後までアルバムをスワイプするだけで済み、スワイプの回数が減ります。横向きと縦向きのアルバムグリッドレイアウトを切り替えるとき、展開したアルバムは自動的にスクロールして可視状態が確保されます。この新しいコンテンツレイアウトは、このリリースからデフォルトレイアウトになりますが、App はお好みのコンテンツレイアウトをデバイスに記憶します。
- **アルバムグリッド UI の改善**：アルバムグリッドレイアウトでの展開アルバムトラックリストビューを改善しました。
- **カラムブラウザの表示修正**：システムのアクセシビリティ設定で透明度をオフにしている場合、または現在の UI テーマが Liquid Glass でない場合のカラムブラウザの表示崩れを修正しました。
- **キーボードホットキーの改善**：キーボードホットキーを処理する際に CapsLock 状態を考慮しないようにしました。これにより、CapsLock がオンのときに発生する特定の問題が解決されます。また、状況によって現在の修飾子キーの状態を誤解していた可能性がある問題も修正しました。
- **アルバムグリッドホットキー**：アルバムグリッドレイアウトで現在展開しているアルバムを切り替えるための `Option+↑↓←→` ホットキーを追加しました。このホットキーはコンテンツのスクロール方向に関係なく有効です。

// ko

- **샌드박스 북마크 유효성 UX**: 샌드박스 북마크 유효성 문제를 사용자가 인식할 수 있도록 UX를 개선했습니다. 사용자는 "Sandbox 권한 다시 승인" 메뉴 명령을 사용하여 MadTunes가 액세스할 폴더를 선택할 수 있습니다. App은 해당 내용을 라이브러리 및 모든 폴더 재생목록과 비교한 다음 찾은 만료된 북마크를 갱신합니다.
- **CoreAudio 동시성 수정**: CoreAudio API의 동시성 우선순위 문제를 수정했습니다.
- **UI 디테일 개선**: 앱 전체의 UI 디테일을 개선했습니다.
- **Horizontal 앨범 그리드**: MacBook 사용자를 위한 세 번째 콘텐츠 레이아웃을 소개합니다. 모든 앨범은 가로 스크롤 뷰에 나열됩니다. 앨범을 펼치면 펼쳐진 콘텐츠가 현재 앨범 수직 행의 오른쪽에 배치되고 앨범의 트랙 목록이 내장된 수직 스크롤 뷰에 표시됩니다. 이를 통해 처음부터 끝까지 앨범을 스와이프하기만 할 때 필요한 총 스와이프 횟수가 줄어듭니다. 가로 및 세로 앨범 그리드 레이아웃 사이를 전환할 때 펼쳐진 앨범이 자동으로 스크롤되어 가시성이 확보됩니다. 이 새로운 콘텐츠 레이아웃은 이번 릴리스부터 기본 레이아웃이 되지만 App은 선호하는 콘텐츠 레이아웃을 기기에 기억합니다.
- **앨범 그리드 UI 개선**: 앨범 그리드 레이아웃에서 펼쳐진 앨범의 트랙 목록 보기를 개선했습니다.
- **컬럼 브라우저 모양 수정**: 시스템 접근성 설정에서 투명도를 끄거나 현재 UI 테마가 Liquid Glass가 아닌 경우의 컬럼 브라우저 이상 현상을 수정했습니다.
- **키보드 단축키 개선**: 키보드 단축키 처리 시 CapsLock 상태를 고려하지 않도록 했습니다. 이를 통해 CapsLock이 켜져 있을 때 발생하는 특정 문제가 해결됩니다. 또한 특정 상황에서 현재 수식자 키 상태를 오해했을 수 있는 문제도 수정했습니다.
- **앨범 그리드 단축키**: 현재 확장된 앨범을 전환하는 데 `Option+↑↓←→` 단축키를 앨범 그리드 레이아웃에 추가했습니다. 이 단축키는 콘텐츠 스크롤 방향에 관계없이 유효합니다.

// es

- **Usabilidad de marcadores de Sandbox**: Se ha mejorado la usabilidad para ayudar a los usuarios a conocer posibles problemas de validez de marcadores de Sandbox. Los usuarios pueden usar el comando de menú "Reaprobar privilegios de Sandbox" para seleccionar una carpeta y volver a otorgar a MadTunes acceso a ella. La app cruzará su contenido con tu biblioteca y todas las listas de reproducción de carpeta, y luego renovará cualquier marcador caducado encontrado.
- **Corrección de prioridad de simultaneidad de CoreAudio**: Se han corregido problemas de prioridad de simultaneidad con las API de CoreAudio.
- **Mejoras en detalles de UI**: Se han mejorado los detalles de la UI en toda la app.
- **Cuadrícula de álbumes horizontal**: Presentamos el tercer diseño de contenido para usuarios de MacBook. Todos los álbumes se muestran en una vista de desplazamiento horizontal. Cuando se expande un álbum, los contenidos expandidos se colocan a la derecha de la fila vertical actual de álbumes y muestran la lista de canciones del álbum en una vista de desplazamiento vertical integrada. Esto reduce la cantidad total de gestos de deslizador necesarios cuando solo deseas desplazarte por los álbumes de principio a fin. Al alternar entre los diseños de cuadrícula de álbumes horizontal y vertical, el álbum expandido se desplazará automáticamente para garantizar su visibilidad. Este nuevo diseño de contenido será el predeterminado desde este lanzamiento, pero la app recordará tu diseño de contenido preferido en el dispositivo.
- **Mejoras de UI de cuadrícula de álbumes**: Se ha mejorado la vista de lista de canciones del álbum expandido cuando el diseño de contenido es cuadrícula de álbumes.
- **Corrección de apariencia del navegador de columnas**: Se ha corregido la apariencia extraña del navegador de columnas cuando la configuración de accesibilidad del sistema desactivaba la transparencia o el tema UI actual no era Liquid Glass.
- **Mejoras en teclas de acceso rápido**: Se ha dejado de considerar el estado de CapsLock al manejar las teclas de acceso rápido. Esto soluciona ciertos problemas cuando CapsLock está activado. También se ha corregido un problema donde la app podría haber malinterpretado el estado actual de la tecla modificadora en algunas situaciones.
- **Teclas de acceso rápido de cuadrícula de álbumes**: Se han añadido teclas de acceso rápido `Option+↑↓←→` a los diseños de cuadrícula de álbumes para cambiar el álbum expandido actual. Estas teclas son efectivas independientemente de la orientación del desplazamiento del contenido.

// fr

- **UX de validité des signets Sandbox** : Amélioration de l'UX pour aider les utilisateurs à détecter les problèmes de validité possibles des signets Sandbox. Les utilisateurs peuvent utiliser la commande de menu "Réapprouver les privilèges sandbox" pour sélectionner un dossier et réattribuer à MadTunes l'accès à celui-ci. L'application croise son contenu avec votre bibliothèque et toutes les listes de lecture de dossier, puis renouvelle les signets expirés trouvés.
- **Correctif de priorité de concurrence CoreAudio** : Correction des problèmes de priorité de concurrence avec les API CoreAudio.
- **Améliorations des détails de l'UI** : Amélioration des détails de l'UI dans toute l'application.
- **Grille d'albums horizontale** : Présentation de la 3ème disposition de contenu pour les utilisateurs de MacBook. Tous les albums sont listés dans une vue de défilement horizontal. Lorsqu'un album est déployé, les contenus déployés sont placés à droite de la rangée verticale actuelle d'albums et affichent la liste des pistes de l'album dans une vue de défilement vertical intégrée. Cela réduit le nombre total de gestes de balayage nécessaires lorsque vous souhaitez simplement balayer les albums du début à la fin. Lors de la commutation entre les dispositions de grille d'albums horizontale et verticale, l'album déployé défile automatiquement pour garantir sa visibilité. Cette nouvelle disposition de contenu sera la disposition par défaut depuis cette version, mais l'application se souviendra de votre disposition de contenu préférée sur l'appareil.
- **Améliorations de l'UI de la grille d'albums** : Amélioration de la vue de liste des pistes de l'album déployé lorsque la disposition du contenu est la grille d'albums.
- **Correction de l'apparence du navigateur de colonnes** : Correction de l'apparence étrange du navigateur de colonnes lorsque les paramètres d'accessibilité du système désactivaient la transparence ou que le thème UI actuel n'était pas Liquid Glass.
- **Améliorations des raccourcis clavier** : L'état CapsLock n'est plus pris en compte lors du traitement des raccourcis clavier. Cela résout certains problèmes lorsque CapsLock est activé. Correction également d'un problème où l'application aurait pu mal comprendre l'état actuel de la touche modificatrice dans certaines situations.
- **Raccourcis de la grille d'albums** : Ajout de raccourcis `Option+↑↓←→` aux dispositions de grille d'albums pour basculer vers l'album actuellement déployé. Ce raccourci est efficace quelle que soit l'orientation du défilement du contenu.

// de

- **Sandbox-Lesezeichen-Validitäts-UX**: Verbesserte UX, um Benutzern bei möglichen Problemen mit der Gültigkeit von Sandbox-Lesezeichen zu helfen. Benutzer können den Menübefehl "Sandbox-Berechtigungen erneut genehmigen" verwenden, um einen Ordner auszuwählen, dem MadTunes erneut Zugriff gewähren soll. Die App gleicht deren Inhalte mit Ihrer Bibliothek und allen Ordner-Playlists ab und erneuert dann alle vorhandenen abgelaufenen Lesezeichen.
- **CoreAudio-Gleichzeitigkeitsprioritätsfix**: Behebung von Prioritätsproblemen bei CoreAudio-APIs.
- **UI-Detailverbesserungen**: Verbesserung der UI-Details in der gesamten App.
- **Horizontales Albumraster**: Einführung des 3. Inhaltslayouts für MacBook-Benutzer. Alle Alben werden in einer horizontalen Scrollansicht aufgelistet. Wenn ein Album erweitert wird, werden die erweiterten Inhalte rechts von der aktuellen vertikalen Albumzeile platziert und die Titeliste des Albums in einer eingebetteten vertikalen Scrollansicht angezeigt. Dies reduziert die Gesamtzahl der Swipe-Gesten, die Sie benötigen, wenn Sie einfach die Alben vom Anfang bis zum Ende durchsuchen möchten. Beim Umschalten zwischen dem horizontalen und vertikalen Albumraster-Layout wird das erweiterte Album automatisch gescrollt, um seine Sichtbarkeit zu gewährleisten. Dieses neue Inhaltslayout wird seit diesem Release das Standard-Layout sein, aber die App merkt sich Ihr bevorzugtes Inhaltslayout auf dem Gerät.
- **Albumraster-UI-Verbesserungen**: Verbesserung der Titelistenansicht des erweiterten Albums, wenn das Inhaltslayout Albumraster ist.
- **Spaltenbrowser-Erscheinungsbildfix**: Behebung des seltsamen Erscheinungsbilds des Spaltenbrowsers, wenn die System-Barrierefreiheitseinstellungen die Transparenz deaktiviert haben oder das aktuelle UI-Theme nicht Liquid Glass ist.
- **Tastenkürzelverbesserungen**: Keine Berücksichtigung des CapsLock-Status mehr bei der Behandlung von Tastenkürzeln. Dies behebt bestimmte Probleme, wenn CapsLock aktiviert ist. Ebenfalls behoben: ein Problem, bei dem die App möglicherweise den aktuellen Status der Modifikator-Taste in manchen Situationen missverstanden hat.
- **Albumraster-Tastenkürzel**: Hinzufügen von `Option+↑↓←→`-Tastenkürzeln zu Albumraster-Layouts zum Umschalten des aktuell erweiterten Albums. Dieses Tastenkürzel ist unabhängig von der Scrollrichtung des Inhalts wirksam.

// it

- **UX validità segnalibri Sandbox**: UX migliorata per aiutare gli utenti a rilevare possibili problemi di validità dei segnalibri Sandbox. Gli utenti possono utilizzare il comando di menu "Riapprova i privilegi sandbox" per selezionare una cartella a cui riassegnare l'accesso MadTunes. L'app intersecherà i suoi contenuti con la libreria e tutte le playlist di cartelle, quindi rinnoverà eventuali segnalibri scaduti trovati.
- **Correzione priorità concorrenza CoreAudio**: Correzione dei problemi di priorità di concorrenza con le API CoreAudio.
- **Miglioramenti dettagli UI**: Miglioramento dei dettagli dell'UI in tutta l'app.
- **Griglia album orizzontale**: Introduzione del terzo layout di contenuto per gli utenti di MacBook. Tutti gli album sono elencati in una vista di scorrimento orizzontale. Quando un album viene espanso, i contenuti espansi vengono posizionati a destra dell'attuale riga verticale di album e mostrano l'elenco dei brani dell'album in una vista di scorrimento verticale incorporata. Questo riduce la quantità totale di gesti di scorrimento necessari quando desideri semplicemente scorrere gli album dall'inizio alla fine. Quando si commuta tra i layout di griglia album orizzontale e verticale, l'album espanso verrà automaticamente fatto scorrere per garantire la sua visibilità. Questo nuovo layout di contenuto sarà il layout predefinito da questa release, ma l'app ricorderà il tuo layout di contenuto preferito sul dispositivo.
- **Miglioramenti UI griglia album**: Miglioramento della vista elenco brani dell'album espanso quando il layout di contenuto è griglia album.
- **Correzione aspetto browser colonne**: Correzione dell'aspetto anomalo del browser colonne quando le impostazioni di accessibilità del sistema hanno disattivato la trasparenza o il tema UI corrente non è Liquid Glass.
- **Miglioramenti scorciatoie tastiera**: Non viene più considerato lo stato CapsLock durante la gestione delle scorciatoie da tastiera. Ciò risolve alcuni problemi quando CapsLock è attivo. Corretto anche un problema per cui l'app potrebbe aver frainteso lo stato corrente del tasto modificatore in alcune situazioni.
- **Scorciatoie griglia album**: Aggiunta delle scorciatoie `Option+↑↓←→` ai layout della griglia album per passare all'album attualmente espanso. Questa scorciatoia è efficace indipendentemente dall'orientamento di scorrimento del contenuto.

// pt-BR

- **UX de validade de marcadores Sandbox**: UX aprimorada para ajudar os usuários a perceberem possíveis problemas de validade de marcadores Sandbox. Os usuários podem usar o comando de menu "Reaprovar privilégios sandbox" para selecionar uma pasta para atribuir novamente à MadTunes acesso a ela. O app cruzará seu conteúdo com sua biblioteca e todas as listas de reprodução de pasta, e então renovará quaisquer marcadores expirados encontrados.
- **Correção de prioridade de concorrência CoreAudio**: Correção de problemas de prioridade de concorrência com APIs CoreAudio.
- **Melhorias nos detalhes da UI**: Melhoria nos detalhes da UI em todo o app.
- **Grade de álbuns horizontal**: Apresentando o terceiro layout de conteúdo para usuários de MacBook. Todos os álbuns são listados em uma visualização de rolagem horizontal. Quando um álbum é expandido, os conteúdos expandidos são colocados à direita da linha vertical atual de álbuns e mostram a lista de faixas do álbum em uma visualização de rolagem vertical incorporada. Isso reduz a quantidade total de gestos de deslize necessários quando você apenas deseja deslizar pelos álbuns do início ao fim. Ao alternar entre os layouts de grade de álbuns horizontal e vertical, o álbum expandido será automaticamente rolado para garantir sua visibilidade. Este novo layout de conteúdo será o layout padrão desde esta versão, mas o app lembrará seu layout de conteúdo preferido no dispositivo.
- **Melhorias na UI da grade de álbuns**: Melhoria na visualização da lista de faixas do álbum expandido quando o layout de conteúdo é grade de álbuns.
- **Correção de aparência do navegador de colunas**: Correção da aparência estranha do navegador de colunas quando as configurações de acessibilidade do sistema desativavam a transparência ou o tema de IU atual não era Liquid Glass.
- **Melhorias em teclas de atalho**: Interrompida a consideração do estado CapsLock ao processar teclas de atalho. Isso corrige certos problemas quando CapsLock está ativado. Também corrigido um problema onde o app poderia ter interpretado incorretamente o estado atual da tecla modificadora em algumas situações.
- **Teclas de atalho da grade de álbuns**: Adição de teclas de atalho `Option+↑↓←→` aos layouts de grade de álbuns para alternar o álbum expandido atual. Esta tecla de atalho é efetiva independentemente da orientação de rolagem do conteúdo.

// ru

- **UX действительности закладок Sandbox**: Улучшен UX, чтобы помочь пользователям узнать о возможных проблемах с действительностью закладок Sandbox. Пользователи могут использовать команду меню "Переутвердить права Sandbox", чтобы выбрать папку, для которой необходимо повторно предоставить MadTunes доступ. Приложение пересечет ее содержимое с вашей библиотекой и всеми плейлистами папок, а затем обновит все найденные просроченные закладки.
- **Исправление приоритета параллелизма CoreAudio**: Исправлены проблемы с приоритетом параллелизма в API CoreAudio.
- **Улучшения деталей UI**: Улучшены детали UI во всём приложении.
- **Горизонтальная сетка альбомов**: Представляем 3-й вариант раскладки контента для пользователей MacBook. Все альбомы перечислены в горизонтальной прокручиваемой области. Когда альбом развернут, развернутое содержимое помещается справа от текущей вертикальной строки альбомов и показывает список треков альбома во встроенной вертикальной прокручиваемой области. Это уменьшает общее количество свайп-жестов, необходимых, когда вы просто хотите пролистать альбомы от начала до конца. При переключении между горизонтальной и вертикальной раскладками сетки альбомов развернутый альбом автоматически прокручивается, обеспечивая его видимость. Эта новая раскладка контента будет раскладкой по умолчанию с этого выпуска, но приложение запомнит вашу предпочтительную раскладку контента на устройстве.
- **Улучшения UI сетки альбомов**: Улучшен вид списка треков развернутого альбома, когда раскладка контента — сетка альбомов.
- **Исправление внешнего вида браузера столбцов**: Исправлен странный внешний вид браузера столбцов, когда настройки специальных возможностей системы отключали прозрачность или текущая тема UI не была Liquid Glass.
- **Улучшения горячих клавиш**: Состояние CapsLock больше не учитывается при обработке горячих клавиш. Это устраняет определенные проблемы, когда CapsLock включен. Также исправлена проблема, когда приложение могло неправильно понимать текущее состояние клавиши-модификатора в некоторых ситуациях.
- **Горячие клавиши сетки альбомов**: Добавлены горячие клавиши `Option+↑↓←→` в макеты сетки альбомов для переключения текущего развернутого альбома. Эта горячая клавиша эффективна независимо от ориентации прокрутки контента.

// tr

- **Sandbox yer imi geçerliliği UX**: Kullanıcıların olası Sandbox yer imi geçerliliği sorunları hakkında bilgi edinmesine yardımcı olmak için UX iyileştirildi. Kullanıcılar, MadTunes'in erişimini yeniden vermek için bir klasör seçmek üzere "Sandbox Ayrıcalıklarını Yeniden Onayla" menü komutunu kullanabilir. Uygulama, içeriğini kitaplığınız ve tüm klasör çalma listeleriyle karşılaştıracak ve bulunan süresi dolmuş yer işaretlerini yenileyecektir.
- **CoreAudio eşzamanlılık önceliği düzeltmesi**: CoreAudio API'lerinde eşzamanlılık önceliği sorunları düzeltildi.
- **UI detay iyileştirmeleri**: Uygulama genelinde UI detayları iyileştirildi.
- **Yatay Albüm Izgara**: MacBook kullanıcıları için 3. içerik düzeni sunuluyor. Tüm albümler yatay kaydırma görünümünde listelenir. Bir albüm genişletildiğinde, genişletilmiş içerikler mevcut albüm dikey satırının sağına yerleştirilir ve albümün parça listesi gömülü bir dikey kaydırma görünümünde gösterilir. Bu, albümleri başından sonuna kadar sadece kaydırmak istediğinizde gereken toplam kaydırma hareketi sayısını azaltır. Yatay ve dikey albüm ızgara düzenleri arasında geçiş yaparken, genişletilmiş albüm otomatik olarak kaydırılarak görünürlüğü sağlanır. Bu yeni içerik düzeni bu sürümden itibaren varsayılan düzen olacak, ancak uygulama tercih ettiğiniz içerik düzenini cihazda hatırlayacaktır.
- **Albüm Izgara UI iyileştirmeleri**: İçerik düzeni albüm ızgarası olduğunda genişletilmiş albümün parça listesi görünümü iyileştirildi.
- **Sütun Tarayıcı görünüm düzeltmesi**: Sistem erişilebilirlik ayarları şeffaflığı kapattığında veya mevcut UI teması Liquid Glass olmadığında Sütun Tarayıcı'nın garip görünümü düzeltildi.
- **Klavye kısayol iyileştirmeleri**: Klavye kısayollarını işlerken CapsLock durumu artık dikkate alınmıyor. Bu, CapsLock açıkken belirli sorunları çözüyor. Ayrıca, uygulamanın bazı durumlarda mevcut değiştirici anahtar durumunu yanlış anlamış olabileceği bir sorun da düzeltildi.
- **Albüm Izgara kısayolları**: Mevcut genişletilmiş albümü değiştirmek için Albüm Izgara düzenlerine `Option+↑↓←→` kısayolları eklendi. Bu kısayol, içerik kaydırma yönünden bağımsız olarak etkilidir.
