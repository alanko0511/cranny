# Cranny

A tiny macOS menu-bar app that browses a YouTube channel's videos and plays them in a small,
always-on-top floating window tucked into a corner of your screen. Open source, lightweight,
and respectful of YouTube's Terms of Service.

> The name "Cranny" (as in "nook and cranny") reflects the idea: a little player that tucks
> into a corner and stays out of the way.

## What it does

- **Browse a channel** — add YouTube channels and see a scrollable list of their uploads
  (newest first) with thumbnails, titles, durations, and dates.
- **Play in a corner** — click a video and it plays in a small, draggable, **always-on-top**
  window. Resting, it looks like a floating audio player with a tiny live video; hover it and
  it expands to a full 16:9 frame with YouTube's native controls.

The player follows you across Spaces, floats over fullscreen apps, and never steals focus from
whatever you're working in.

## Compliance (by design)

Cranny is deliberately **ToS-compliant**, which rules out some things on purpose:

- The player stays **genuinely visible** (small is fine; never hidden, 0px, or off-screen).
- **YouTube's native controls and ads are left untouched** — no ad-skipping, no audio-only,
  no background/keep-playing-when-hidden, no downloading or audio extraction.
- Playback is through YouTube's **official IFrame Player API**; channel data comes from the
  **YouTube Data API v3**. Closing the player stops playback.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) to build from source
- Your **own** YouTube Data API key (free — see below)

## Build from source

```sh
brew install xcodegen
xcodegen generate          # generates Cranny.xcodeproj from project.yml
open Cranny.xcodeproj       # then build & run (⌘R), or:
# xcodebuild -project Cranny.xcodeproj -scheme Cranny -configuration Debug build
```

The `.xcodeproj` is generated and git-ignored. After adding/removing source files, re-run
`xcodegen generate`.

## Get a free YouTube Data API key

Cranny ships **no API key** (that would violate the API ToS in a public repo). Each user
brings their own:

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a project (or pick one).
3. **APIs & Services → Library →** enable **"YouTube Data API v3"**.
4. **APIs & Services → Credentials → Create credentials → API key.**
5. Open Cranny's **Settings → API Key** and paste it.

The key is stored in your **macOS Keychain** — never bundled, logged, or shared. Typical usage
is a few quota units per channel refresh, far under the free 10,000 units/day.

## Adding channels

In **Settings → Channels** (or the `＋` in the popover), paste a channel's **`@handle`** or a
**`youtube.com/channel/UC…`** URL. Legacy `/c/` and `/user/` URLs aren't supported — open the
channel on YouTube and copy its `@handle` instead.

## Privacy & attribution

Cranny talks only to Google/YouTube endpoints (over HTTPS) to fetch metadata and play videos.
Playback data is shared with YouTube and subject to
[YouTube's Terms of Service](https://www.youtube.com/t/terms) and
[Google's Privacy Policy](https://policies.google.com/privacy). Use of the API is governed by
the [YouTube API Services Terms](https://developers.google.com/youtube/terms/api-services-terms-of-service).
Video and channel metadata are shown as returned by the API, and every video links back to its
YouTube watch page.

## License

MIT.
