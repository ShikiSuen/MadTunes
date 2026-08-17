# MadTunes, a tool for loudness measurement of files on macOS. #

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/madtunes/id6760667980)

MadTunes is a local music player designed for audiophiles and music producers, featuring a classic iTunes 11-style grid browsing experience with accurate, pure high-fidelity audio playback.

> See `Description` chapter below.

![MadTunes](./Screenshots/Screenshot-Grid.avif)

MadTunes source code is released under the GNU Affero General Public License v3 (AGPLv3). See `LICENSE`.

**Prebuilt binaries and build artifacts distributed by the project maintainer are provided under a non-commercial license.** Commercial exploitation of those prebuilt binaries is prohibited; see `LICENSE-BINARY` for details.

A separate limited exception also applies to Apple Inc.'s use of the vertically scrollable Album Grid View implementation in this repository; see `LICENSES/APPLE-EXCEPTION.md`. This exception does not cover any horizontally scrollable Album Grid View implementation.

## Binaries ##

Binaries of all versions are not provided.

You are expected to either compile the binary by yourself or buy at Mac App Store.

The charged fee is not mandatory since you can always compile the binaries for your own purposes. However, I will really appreciate if you can buy a copy on Mac App Store to support the development and maintenance of this app.

### How to Compile ###

Xcode 26 with Swift 6.2 is recommended for the compilation. Apple always eager to push its latest toolchain as a hard requirement for compiling modern Xcode projects.

## Description ##

**Why MadTunes?**

As a music creator, you need playback tools that accurately reveal mixing details. Validated through over 100 rigorous tests, only the system-native AVPlayer ensures optimal audio quality on macOS. MadTunes builds upon this foundation, faithfully presenting original audio without additional sound processing, letting you hear the true studio-grade sound.

**Key Features:**

• **Broad Format Support** — MP3, FLAC, AAC, WAV, AIFF, Ogg Vorbis, Opus, and more mainstream audio formats (audio files only);
• **Gapless Loop Playback** — Designed for loopable audio, seamless transition at loop points;
• **Accurate Stereo** — Faithfully reproduces original mixing, no HRTF interference;
• **Powerful Keyboard Navigation** — Full keyboard support, from grid navigation to queue management without mouse;
• **Smart Search & Filter** — Keyword search + three-column cascading filter (Genre/Artist/Album);
• **Flexible Playing Queue** — Drag to reorder, play next, shuffle, complete playback control;
• **Playlist Management** — Create personal playlists to organize your music collection;
• **Classic Grid Layout** — Late-2012 iTunes 11-style album grid you are missing since macOS 10.15 Catalina: click to expand, double-click to play, intuitive and efficient.

**Optimized for macOS:**

• System-built-in native Apple AVPlayer core — validated through over 100 tests to ensure best audio quality on macOS;
• Adaptive HAL buffer to eliminate audio jitter;
• Security-scoped bookmarks for persistent file access;
• Native SwiftUI interface with smooth animations and Liquid Glass effects;
• Full support for macOS 15 Sequoia and later.

MadTunes collects no user data. All music files are processed locally—your privacy is fully protected.

**Supported Formats:** MP3, FLAC, AAC, M4A, WAV, AIFF, Ogg Vorbis, Opus, CAF

> CoreAudio may support new formats per certain macOS releases. Please file issues if new formats are implementable in MadTunes.

## Installation ##
You can build the executables from the Xcode project, or buy one from Mac App Store.

## Motives

I used Foobar 2000 on macOS for a long time. However, after more than four years of use, I realized it had significant audio performance issues. As a music creator, I also tried mixing my own work. However, my mixes were often criticized as “terrible”, yet when listening in that player it was always hard to tell the difference between my work and commercially released soundtrack albums in terms of mix quality. Over time, this misleading listening reference prevented me from accurately understanding the sonic characteristics of professional mixes, making it difficult to attract clients. I had to keep creating while also learning programming part-time as a second source of income. Later, when I took over maintenance of R128x (an audio loudness analysis tool) and added a listening feature, I realized for the first time that an ordinary Mac can sound this good. It was at that moment that I understood I had been misled by that player for years, and I was furious. The name MadTunes is both “Mad + Tunes” and a pun on “媽的 Tunes” (damn Tunes), meant to express that sentiment.

> Proprietary freeware creates a deeply uncomfortable power dynamic: because developers offer the software gratis, they bear no obligation to promptly rectify defects or usability issues. Even skilled programmers wishing to improve the tool find themselves reduced to submitting naive feature requests or bug reports like any lay user, leaving resolution entirely to the developer's whim with zero agency whatsoever. Express even slight urgency, and one risks being branded a freeloader, potentially facing public shaming or ganging-up by the community. This structural impasse is precisely why someone among the users had to rewrite a similar application as open-source. Ironically, this act of creating an alternative is frequently perceived as hostile, inviting reciprocal hostility.

## Concepts

The audio playback function of MadTunes relies on the AVPlayer system component for implementation and does not have built-in DSP processing capabilities. This minimizes distortion throughout the entire pipeline. However, users can still use an audio routing driver to route the audio output signal to professional DSP Rack Apps like Apple MainStage.

Although MadTunes’ UI operation experience on macOS and iPad (FullScreen) may resemble iTunes 11 (released in 2012) in some respects, its design goals are completely different from the consumer-market focus of Apple Music / iTunes. In BlackHole loopback null tests with matched playback volume, Apple Music's stereo playback of the same file nulls against MadTunes' output at -96.9 dBFS — both players take the same CoreAudio path, and neither colors the signal. The practical difference is behavioral rather than sonic: MadTunes applies no DSP and no level normalization of its own, so learners analyzing album mixing characteristics hear the mix exactly as delivered. Additionally, some audio material (for example, game or ambient music) is designed to loop seamlessly end-to-end. In many players, single-track repeat playback often introduces a brief gap at the transition point, interrupting the overall beat pace. MadTunes includes dedicated handling for these cases to ensure truly pace-uninterrupted loop playback.

The UI design for iPhone and small-window iPad follows the UI design language used in Windows Phone 7 / 8 around 2012.

## Technical Notes

When writing an audiophile audio player for Mac, you must use AVPlayer (from macOS built-in AVFoundation Framework); AVAudioEngine has no way to achieve the same playback fidelity. This conclusion comes from over a hundred trials and errors during development. These albums / tracks are used during the tests.

- Brian Tyler: Call of Duty: Modern Warfare 3 (2011) Soundtrack
- KATOU Tatsuya: Shokugeki no Souma (TV Anime Soundtrack)
- Fish Leong: Courage
- FLOW: Go!!! & Sign
- Zutomayo: Hunch Grey
- Gene Fang (all albums mixed by Michael Chang)

Also, avoid setting `AVPlayerItem.audioTimePitchAlgorithm` to `.spectral` at 1x playback. Although documentation suggests the algorithm only "activates" when `rate != 1.0`, forcing `.spectral` keeps an extra DSP stage in the signal chain and defeats the bypass that `AVFoundation` otherwise applies at `rate == 1.0`. In A/B listening tests during development, this audibly degraded transient reproduction — instruments lost transient "breath" at higher volumes. For high-fidelity playback, preserve the default `.timeDomain` setting.

> The above notes are **not related to** Foobar2000 for macOS.

$ EOF.
