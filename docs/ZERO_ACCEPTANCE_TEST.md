# Z.E.R.O. Acceptance Test

This gate must pass before phone installation, public deployment, or promotion from `testing`.

## Start a private local preview

From the repository root on Windows:

```powershell
py scripts\preview-zero.py
```

Expected URL: `http://127.0.0.1:8765/zero-brain/`

The launcher binds to `127.0.0.1`, so other devices cannot access it.

## Visual gate

- [ ] Dashboard loads without a blank screen.
- [ ] Neural graph, HUD, top bar, side controls, and bottom controls render.
- [ ] No controls overlap at desktop width.
- [ ] Browser console contains no uncaught errors.
- [ ] Text remains readable at 100% browser zoom.
- [ ] Reduced-motion mode does not break layout or controls.

## Core interaction gate

- [ ] Left-drag rotates the graph smoothly.
- [ ] Mouse wheel zooms without jumping.
- [ ] Clicking a visible node selects it.
- [ ] FOCUS centers the selected node.
- [ ] Search returns matching results.
- [ ] Opening a search result clears the result overlay.
- [ ] ISOLATE emphasizes the selected neighborhood.
- [ ] Selecting outside an isolated neighborhood clears stale isolation.
- [ ] Escape closes the active layer without unexpectedly clearing unrelated state.
- [ ] Mission Control opens, closes, scrolls, and retains its scroll position.
- [ ] Roadmap changes appear in the audit trail.
- [ ] Export/download actions produce a non-empty file.

## Persistence and recovery gate

- [ ] Selection and supported workspace state survive a reload.
- [ ] Invalid local-storage records do not crash startup.
- [ ] Clearing site data restores a clean initial state.
- [ ] A second tab is not used for editing until multi-tab conflict protection is implemented.

## Responsive gate

Use browser device emulation before physical-phone testing.

- [ ] 1280 x 720 desktop.
- [ ] 768 x 1024 tablet portrait.
- [ ] 390 x 844 mobile portrait.
- [ ] No horizontal overflow at 390 px.
- [ ] Simulated pinch zoom does not spin, jump, or select a phantom node.
- [ ] A one-finger gesture after pinch continues from the current position.

## Offline/PWA gate

- [ ] First online load completes.
- [ ] Reload fetches the current dashboard assets.
- [ ] Offline reload opens the cached shell.
- [ ] Returning online receives updated assets after a version change.
- [ ] No failed HTTP response is stored as a valid offline page.

## Privacy and release gate

- [ ] No API keys, tokens, credentials, personal exports, or device files appear in page source or network requests.
- [ ] GitHub Pages deployment remains manual-only.
- [ ] No phone installation occurs before owner visual approval.
- [ ] No promotion to a release branch occurs before this checklist is recorded as passed.

## Acceptance record

- Tester:
- Date:
- Browser and version:
- Commit tested:
- Result: PASS / FAIL
- Defects found:
- Screenshots or console log location:
- Approval to proceed to phone test: YES / NO
