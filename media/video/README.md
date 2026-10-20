# Product video

The formhaus-swift product video, built from sources. HTML scenes play the recorded footage of the iOS demo and the React form on a timeline driven by a frame number, and Playwright captures every frame.

Requires Xcode with an iOS Simulator runtime, Node 22.12 or later, ffmpeg and gifski (`brew install ffmpeg gifski`). `npm ci` runs on the first call.

## Edit texts

Every on-screen text, the beat order and durations, the devices and simulators, the edited JSON line of beat 3, the colors and the fonts are in `script.json`. Colors in braces, such as `{color.text.default}`, resolve from the formhaus tokens in `@formhaus/core/tokens`.

After an edit, run `./render.sh`. Texts do not need new footage. The scenario count comes from `Tests/FormhausCoreTests/Fixtures` at build time.

To preview in a browser, run `node tools/build.mjs && node tools/serve.mjs`, open the printed URL, and stop the server when done. `?frame=N` shows one frame. The preview follows `prefers-reduced-motion`. To check single frames without a full render, run `node tools/still.mjs 3.5 12 30` with the times in seconds. The PNGs go to `out/stills/`.

## Record footage

```sh
./record.sh
```

It builds the demo app, records the iOS script mode on a headless simulator and the same definition in `@formhaus/react` with headless Chromium, and writes everything to `footage/`. To record one scene again, pass its footage ids from `script.json`:

```sh
./record.sh ios-styles
./record.sh web-tour web-variant
```

The web side follows the marks in `script.json` (`marks.tour`). They match the iOS timings in `Examples/FormhausDemo/FormhausDemo/Resources/demo-timings.json`. If the demo script or its timings change, update the marks.

## Render

```sh
./render.sh
```

It writes to `out/`:

- `formhaus-swift.mp4`, H.264 at 3840×2160
- `formhaus-swift-1080p.mp4`, H.264 at 1920×1080
- `formhaus-swift.webm`, VP9 at 1920×1080
- `formhaus-swift.gif`, 800 px wide at 15 fps, captured without camera moves to stay under 3 MB
- `poster.png`

`SCALES=1 ./render.sh` skips the 4K capture. All runs are headless.
