# MadTunes User Guide

## Introduction

MadTunes is a local music player designed for audiophiles and music producers, featuring a classic iTunes 11-style grid layout that delivers accurate, uncolored high-quality audio playback.

---

## System Requirements

- **macOS**: 15.0 or later
- **iOS/iPadOS**: 18.0 or later

---

## Supported Audio Formats

MadTunes supports playback of the following audio formats:

| Format | Extensions |
|--------|------------|
| MPEG Audio | `.mp3`, `.mp2` |
| AAC / M4A | `.m4a`, `.aac` |
| Apple Lossless | `.m4a` |
| FLAC | `.flac` |
| WAV | `.wav` |
| AIFF | `.aif`, `.aiff` |
| Ogg Vorbis | `.ogg` |
| Opus | `.opus` |
| Core Audio Format | `.caf` |
| Sound Designer II | `.sd2` |
| Dolby Digital | `.ac3` |

> **Note:** MadTunes only supports audio files. Video formats are not supported.

---

## Interface Layout

MadTunes uses a three-column navigation layout:

```
┌─────────────────┬─────────────────────────────────────┐
│                 │                                     │
│    Sidebar      │          Album Grid Area            │
│                 │        (Album Grid View)            │
│                 │                                     │
│ • All Music     │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐    │
│ • Favorites     │  │Album│ │Album│ │Album│ │Album│    │
│ • Playlists...  │  │Art  │ │Art  │ │Art  │ │Art  │    │
│                 │  └─────┘ └─────┘ └─────┘ └─────┘    │
│                 │       [Expanded Album Tracklist]    │
├─────────────────┤                                     │
│                 └─────────────────────────────────────┘
│  Player Controls                                      │
└───────────────────────────────────────────────────────┘
```

### 1. Sidebar

The sidebar is located on the left and contains the following sections:

**Library**
- **All Music**: Displays all tracks in the library
- **Favorites**: Displays tracks marked as favorites (click the heart icon to add)

**Dynamic Playlists**
- Hierarchical-Predicate-Driven playlists that automatically match tracks based on rules
- Supports complex nested condition combinations
- Configurable **Data Source**: Use "All Music" or one/multiple "Folder Playlists" as the filtering scope
- Right-click to rename, duplicate, or delete; use the "+" button to create
- On iPhone WPUI, tap the Gear-shaped button to open the dedicated Predicate editor

**Playlists**
- User-created static playlists
- Right-click to create, rename, duplicate, or delete playlists

**Folder Playlists**
- Folder-based playlists that scan a specified folder for audio files
- Tracks from folder playlists are isolated from the main library (All Music)
- Supports **Lazy Reload** — automatically detects folder changes when first switched to after app launch
- Right-click to rescan the folder, open in Finder (macOS), or delete the playlist
- Use the "+" button in the sidebar to create a folder playlist by selecting a folder

### 2. Album Grid Area

A toolbar button in the upper-right allows toggling between the standard grid layout and a list-style table view.
The album grid is the main browsing area:

- **Grid Layout**: Adaptive column count, minimum 160px width per album
- **Album Cards**: Display album artwork, album title, and artist name
- **Expand/Collapse**: Click an album to expand the tracklist; click again or press Esc to collapse
- **Close by clicking blank area**: When an album is expanded, you can also collapse it by clicking any empty portion of the grid outside the album card and the detail pane
- **Multi-selection**: Supports multi-selection with Shift and Command keys

**Expanded Album View**

When expanded, displays:
- Left: Multi-column tracklist (up to 7 rows per column)
- Right: Large album artwork (200×200px)
  - **Double-click artwork**: Play the album
  - **Right-click artwork**: Show album context menu
- Track information: Track number, title, artist, duration

### 3. Player Controls

Located at the bottom of the window, includes:

| Element | Function |
|---------|----------|
| Album Art Thumbnail | Double-click to jump to currently playing album; right-click for track options |
| Track Title/Artist | Display current playback information |
| Play/Pause | Toggle playback state |
| Previous/Next | Switch tracks |
| Progress Bar | Drag to seek; click time to toggle remaining time display |
| Volume Slider | Adjust volume (icon changes with volume level) |
| Loop Mode | Sequential / Repeat One / Shuffle |
| Playing Queue | Open playing queue panel |
| Column Browser | Open Genre/Artist/Album filter panel |

**Audio Output Device Selection (macOS only)**
- Click the volume icon or use the Control menu to select audio output device
- Supports selecting System Default or specific audio interfaces (e.g., external DAC, BlackHole, etc.)
- The currently selected device is marked with a checkmark in the menu

---

## Keyboard Shortcuts

### Global Shortcuts

| Shortcut | Function |
|----------|----------|
| `Space` | Expand album (when collapsed) / Play/Pause (when expanded) |
| `Shift + Space` | Play/Pause (when collapsed) / Play selected or collapse (when expanded) |

### Album Grid Navigation

When no album is expanded:

| Shortcut | Function |
|----------|----------|
| `←` `→` `↑` `↓` | Move selection in album grid |
| `Shift + Arrow Keys` | Range select multiple albums |
| `Page Up` / `Page Down` | Scroll up/down by one page |
| `Shift + Page Up/Down` | Range select to previous/next page |
| `Home` / `End` | Jump to first/last album |
| `Shift + Home/End` | Range select to first/last album |
| `Return` / `Enter` | Expand/collapse selected album |
| `⌘ + ↓` | Expand selected album |
| `⌘ + A` | Select all visible albums (affected by Column Browser and search filters) |

| Shortcut | Function |
|----------|----------|
| `⌘ + Click` | Multi-select/deselect albums |
| `Shift + Click` | Range select from anchor to clicked album |
| `Drag Selection` | Rubber-band select multiple albums (hold ⌘ to append) |

### Expanded Album Navigation

When an album is expanded:

| Shortcut | Function |
|----------|----------|
| `↑` `↓` | Move selection in tracklist |
| `←` `→` | Jump between track columns |
| `Return` / `Enter` | Play selected track |
| `Esc` / `⌘ + ↑` | Collapse album, return to grid view |
| `Space` | Play/Pause |
| `Shift + Space` | Play selected tracks; or collapse album |
| `⌘ + A` | Select all visible tracks in current album (affected by search filters) |
| `⌘ + C` | Copy selected tracks' metadata (TSV format) to clipboard |

| Shortcut | Function |
|----------|----------|
| `⌘ + Click` | Multi-select/deselect tracks |
| `Shift + Click` | Range select tracks |
| `Shift + Drag` | Drag to select multiple tracks |

### Playing Queue Shortcuts

In the playing queue panel:

| Shortcut | Function |
|----------|----------|
| `↑` `↓` | Move selection in queue |
| `Delete` / `⌫` | Remove selected track |
| `Return` / `Enter` | Jump to and play selected track |

---

## Mouse/Trackpad Operations

### Album Grid

| Operation | Function |
|-----------|----------|
| Click Album | Expand/collapse album |
| Double-click Album | Start playback from first track of album |
| Right-click Album | Show context menu |

### Track List

| Operation | Function |
|-----------|----------|
| Click Track | Select track |
| Double-click Track | Play track |
| Right-click Track | Show context menu |

### Table View

The table view displays all tracks as a flat list. Columns include Name, Length, Artist, Album Title, Album Artist, Genre, and Folder (the parent folder name – hover to see the full path).

### Player Controls

| Operation | Function |
|-----------|----------|
| Double-click Album Art | Locate current album in main view |
| Click Time Display | Toggle between elapsed time / remaining time |
| Drag Progress Bar | Seek to position |
| Right-click / Long-press Play/Pause Button | Switch playback engine (AVPlayer / AVAudioEngine) |

---

## Context Menu Features

### Album Right-Click Menu

- **Add to Playlist**: Add album to specified playlist
- **Play Album (Sequential)**: Play in track number order
- **Play Album (Shuffled)**: Play in random order
- **Play Next**: Insert album after current position and play immediately
- **Get Info**: View detailed information about tracks in album
- **Add to Favorites**: Mark all tracks in album as favorites
- **Show in Finder**: Open folder containing album in Finder
- **Remove from Library**: Remove from library (does not delete original files)

### Track Right-Click Menu

- **Add to Playlist**: Add track to specified playlist
- **Play Next**: Insert track after current position and play immediately
- **Get Info**: View detailed track metadata
- **Add to Favorites**: Mark track as favorite
- **Copy Metadata**: Copy TSV-formatted metadata to clipboard
- **Show in Finder**: Open folder containing track in Finder
- **Remove from Library**: Remove from library (does not delete original files)

---

## Table View

When the table view is active the library is displayed as a flat list of tracks.
Columns include Name, Length, Artist, Album Title, Album Artist, Genre, and Folder (the parent folder name – hover to see the full path).

### Table View Keyboard Shortcuts

| Shortcut | Function |
|----------|----------|
| `↑` `↓` | Move selection up/down |
| `Shift + ↑` `Shift + ↓` | Range select up/down |
| `Page Up` / `Page Down` | Scroll up/down by one page |
| `Shift + Page Up/Down` | Range select to previous/next page |
| `Home` / `End` | Jump to first/last track |
| `Shift + Home/End` | Range select to first/last track |
| `Return` / `Enter` | Play from selected track (like double-click) |
| `Shift + Space` | Play from selected track (like double-click) |
| `Space` | Toggle Play/Pause |
| `⌘ + ↓` | Play from selected track (like double-click) |
| `⌘ + A` | Select all visible tracks |
| `⌘ + C` | Copy selected tracks' metadata (TSV format) to clipboard |
| `⌥ + ↑` | Move selected tracks up in playlist (Favorites / static playlists only) |
| `⌥ + ↓` | Move selected tracks down in playlist (Favorites / static playlists only) |

### Column Customization & Sorting

- **Column Visibility**: Right-click the table header to show/hide columns via toggle menu.
- **Column Resizing**: Drag the dividers between column headers to adjust column widths. Widths are persisted across sessions.
- **Sorting**: Click column header to sort by that column (once for ascending ▲, again for descending ▼, third click to clear and restore album order)
- **Compound Sort** (All Music only): Click additional column headers to add secondary/tertiary sort criteria. Each header shows a subscript number indicating its priority (e.g. ▲₁ ▼₂).
- **Persistent Sort** (Favorites & static playlists): Clicking a column header permanently reorders the playlist's tracks by that column. Click the same column again to toggle between ascending and descending. The reordered sequence is saved automatically.

### Playlist Track Reordering

In Favorites and user-created static playlists (when no table sort, search or column browser filter is active), you can reorder tracks:

- **Drag & Drop**: Drag a track (or multi-selected tracks) to a different row to reorder.
- **Keyboard**: Select tracks and press `⌥ + ↑` / `⌥ + ↓` to move them up/down.

> **Note**: When Column Browser filter rules are active or the search box has content, the sort adjustment feature for static playlists will be automatically disabled.

---

## Search & Filtering

### Keyword Search

The search box in the upper right supports the following filter modes:

| Mode | Description |
|------|-------------|
| Either | Search track titles, album titles, and artists |
| Track Title | Search track titles only |
| Album Title | Search album titles only |
| Artist | Search artist names only |

### Column Browser

Open via the filter button in the player controls:

- **Four-column Filter**: Genre → Album Artist → Song Artist → Album
- **Bidirectional**: Choosing a song artist also restricts which album artists appear.
- **Cascading Filter**: Selecting Genre filters available Artist list
- **Multi-select**: Each column supports selecting multiple items
- **Double-click to Play**: Double-click in any column to play matching tracks

---

## Dynamic Playlists

Dynamic Playlists are a powerful feature for automatically filtering tracks based on rules:

### Predicate Editor

- Supports creating complex **Hierarchical Predicate Networks** with nested condition groups
- Card-style rounded rectangle hierarchical layout for visualizing logical relationships between conditions
- Real-time preview of matching track count
- Supported condition fields: Name, Artist, Album, Album Artist, Track Number, Genre, Year, Length, Extension, Folder

### Data Source

- Configure the scope for dynamic playlist filtering:
  - **All Music** (default): Filter from the entire music library
  - **Specified Folder Playlists**: Filter tracks from one or more folder playlists
- Adjust Data Source in the playlist right-click menu or Predicate Editor
- When a Data Source is bound, the dynamic playlist icon changes to `folder.fill.badge.gearshape`

---

## Folder Playlists

Folder Playlists allow you to directly play audio files from a specified folder without importing them into the main library:

### Features

- **Isolated**: Tracks are completely isolated from the main library (All Music), keeping your main library clean
- **Auto Scan**: Automatically scans all supported audio files in the folder when first created
- **Lazy Reload**: Automatically detects folder changes and updates content when first switched to after app launch
- **Manual Rescan**: Right-click the playlist to manually trigger a rescan

### How to Use

1. Click the "+" button at the bottom of the sidebar, select "Add Folder Playlist"
2. Select the folder to monitor
3. The playlist will be automatically created and scan all audio files in that folder and its subfolders

### Notes

- Folder Playlists **do not support** the duplicate feature
- Tracks cannot be directly "deleted" from folder playlists (since files are managed by the external folder)
- You can import tracks from folder playlists to the main library, or use them as data sources for dynamic playlists

---

## Playing Queue Management

### Queue Operations

In the playing queue panel you can:

- **Drag to Reorder**: Drag tracks to adjust playback order
- **Remove Track**: Click × button or press Delete key
- **Scramble**: Click shuffle button at top
- **Move Up/Down**: Use arrow buttons for fine adjustments

### Loop Modes

| Mode | Icon | Description |
|------|------|-------------|
| Sequential | ⟳ | Play in order, stop when finished |
| Repeat One | ⟳1 | Repeat current track (gapless loop) |
| Shuffle | ⇄ | Random order playback of queue tracks |

---

## Importing Music

### Import Methods

1. **File Import**: Support selecting multiple audio files
2. **Folder Import**: Recursively scan folders for audio files
3. **Drag & Drop**: Drag files or folders into MadTunes window
4. **Open In / Share**: Use the system "Open In" or Share menu from Finder, Files app, or other apps to send audio files to MadTunes

### Import Features

- **Parallel Processing**: Up to 8 files reading metadata simultaneously
- **Duplicate Detection**: Automatically skip already imported identical files
- **Metadata Reading**: Automatically read ID3 tags and album artwork
- **Security-Scoped Bookmarks**: Use macOS security bookmarks to maintain file access permissions
- **Playlist Sync**: If you import while viewing the **Favorites** page or any custom static playlist, the imported tracks are automatically added to that playlist (duplicates are safely ignored)
- **Dynamic Playlist Protection**: Dragging files to a dynamic playlist will not automatically add tracks (dynamic playlist content is entirely rule-driven)

---

## Audio Features

### High-Quality Playback

MadTunes is specially optimized for the macOS audio system:

- **System-level AVPlayer Core**: Validated through over 100 rigorous tests, only the system-native AVPlayer ensures optimal audio quality on macOS. Tested albums include Tatsuya Kato (Shokugeki no Soma OST), Fish Leong ("Courage", "Sadly Not You"), FLOW ("Go!!!", "Sign"), ZUTOMAYO ("Hunch Gray"), Fang Shunji (mixed by Michael Chang), √5 ("Senbonzakura"), Jay Chou ("Track") — ensuring accurate reproduction of details across all music genres
- **HAL Buffer Adjustment**: Automatically increase output device buffer to prevent audio jitter
- **Accurate Stereo**: No HRTF processing, faithfully reproduces original mix
- **Gapless Loop**: In repeat one mode, seamless transition between track end and beginning

### Metadata Display

In the "Get Info" window you can view:

- Basic Info: Title, Artist, Album, Year, Genre
- Technical Info: Sample rate, Bit depth, Channels, Codec
- File Info: File path, File size, Modification date

---

## Data Management

### Library Storage

MadTunes uses SwiftData for persistent storage:

- Track metadata (not original audio files)
- Playlists
- Favorite markings
- File security bookmarks (macOS)

### Notes

- Deleting tracks from the library **does not** delete original audio files
- Album artwork is automatically compressed and cached (max 512×512, JPEG format)
- Re-importing existing files updates their metadata

---

## Interaction Style Summary

MadTunes follows these design principles:

1. **Direct Manipulation**: Double-click to play, drag to reorder, instant feedback
2. **Keyboard First**: Comprehensive keyboard navigation support, most operations possible without mouse
3. **Progressive Disclosure**: Grid → Album → Tracks, clear information hierarchy
4. **Non-destructive Editing**: All deletion operations only affect library index, original files remain safe
5. **macOS Native**: Follows Apple Human Interface Guidelines, supports system features like Spotlight, Force Touch

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Cannot play file | Check if file is in original location; try re-importing |
| Slow import | Normal with large numbers of files; supports background import |
| Album artwork not showing | Check if audio file has embedded artwork; supports FLAC/MP3/M4A artwork reading |
| Stuttering during playback | Check system audio settings; close other audio-using applications |

### Contact Support

For issues or suggestions, please submit feedback via the App Store page or GitHub repository.

---

*MadTunes - Born for those who pursue audio quality*
