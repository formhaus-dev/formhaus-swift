# Product video

The formhaus-swift product video, built from sources. HTML scenes play the recorded footage of the iOS demo and the React form on a timeline driven by a frame number, and Playwright captures every frame.

Requires Xcode with an iOS Simulator runtime, Node 22.12 or later, ffmpeg and gifski (`brew install ffmpeg gifski`). `npm ci` runs on the first call.

## Edit texts

Every on-screen text, the beat order and durations, the devices and simulators, the edited JSON line, the colors and the fonts are in `script.json`. Colors in braces, such as `{color.text.default}`, resolve from the formhaus tokens in `@formhaus/core/tokens`. The `camera` keys of a two-device beat set the zoom and whether each device is held at its top or bottom edge.

After an edit, run `./render.sh`. Texts do not need new footage. The scenario count comes from `Tests/FormhausCoreTests/Fixtures` at build time.

To preview in a browser, run `node tools/build.mjs && node tools/serve.mjs`, open the printed URL, and stop the server when done. `?frame=N` shows one frame. The preview follows `prefers-reduced-motion`. To check single frames without a full render, run `node tools/still.mjs 3.5 12 30` with the times in seconds. The PNGs go to `out/stills/`.

## Record footage

```sh
./record.sh
```

It writes everything to `footage/`:

- the iOS demo in script mode on a headless simulator. The app writes the time of each mark and tap, with the frame of the tapped field, to its container, and the touch circles are drawn from that file. With `-demoTicker` the app draws its display frame number in the top left corner, which the device mask hides. `tools/retime.mjs` reads it to rebuild the clip at a constant 60 fps and writes the frame gaps to `footage/raw/<id>.retime.json`. A clip with a gap over two frames is recorded again;
- the same definition in `@formhaus/react`, rendered frame by frame in headless Chromium. A fake clock and paused animations advance exactly 1/60 s per frame, and every frame is a PNG at device scale 2. The pointer moves on every frame, and the touch circles come from the click points;
- a macOS render of the same form, drawn offscreen by `mac/` with `NSHostingView`.

To record one scene again, pass its footage ids from `script.json`:

```sh
./record.sh ios-styles
./record.sh web-tour web-variant
```

The web side follows the marks in `script.json` (`marks.tour`). They match the iOS timings in `Examples/FormhausDemo/FormhausDemo/Resources/demo-timings.json`. The scenes refer to marks by name, and the footage is mapped to the times the app recorded, so small timing changes need no edit.

Record on an idle machine. Before each iOS clip the script waits until the load average drops below 4. Only the encoding steps run under `nice`.

## Render

```sh
./render.sh
```

It composes every frame at 3840×2160 and writes to `out/`:

- `formhaus-swift.mp4`, H.264 at 3840×2160
- `formhaus-swift-1080p.mp4`, H.264 at 1920×1080 and 60 fps, downscaled from the 4K master with lanczos
- `formhaus-swift.webm`, VP9 at 1920×1080
- `formhaus-swift.gif`, 800 px wide at 15 fps, captured without camera moves to stay under 3 MB
- `poster.png`

All runs are headless.
