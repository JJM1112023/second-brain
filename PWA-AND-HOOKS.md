# PWA install + git hook automation

## Install as an app

### Android (Chrome)
1. Visit https://jjm1112023.github.io/awesome-ninja-admins/
2. Chrome menu (⋮) → **Install app** (or **Add to Home screen**)
3. Launches full-screen, works offline after first load.

### Windows (Edge / Chrome)
1. Open the site.
2. Click the **install icon** in the address bar (⊞) → **Install**.
3. Gets its own Start-menu entry and window.

### iOS Safari
Share sheet → **Add to Home Screen**.

The service worker (`sw.js`) precaches the shell, so once installed the app opens instantly even offline. When you deploy an update, users get a small "New build available — Reload" toast.

## The two pages

| Page | URL | What it is |
| --- | --- | --- |
| Codex | `/` | The immersive 3D landing page over the curated tool list |
| Z.E.R.O. | `/zero-brain/` | The second-brain knowledge graph — search, detail panels, roadmap, capture inbox |

Both are precached, so **both work fully offline** once you have visited the site
once. The console keeps its whole dataset in `zero-brain/brain-data.js`, which means
it also runs straight off the filesystem — open `zero-brain/index.html` with no
server at all and it still works.

Its roadmap ticks and captured notes live in `localStorage`, so they survive
reloads and offline use. **Export captures as Markdown** and drop the file into
`vault/` to move a thought from the console into the Obsidian mind map.

## Git hook automation (local)

The repo ships two hooks under `.githooks/`:

| Hook          | What it does                                                                                       |
| ------------- | -------------------------------------------------------------------------------------------------- |
| `post-merge`  | After `git pull`, regenerates icons if `gen_icons.py`/manifest changed and bumps the SW build stamp. |
| `pre-push`    | Blocks the push if manifest JSON is bad, either page is missing its PWA wiring, the SW has syntax errors, or the generated second brain is stale. |

### Enable them once per clone
```bash
bash scripts/install-hooks.sh
```
That runs `git config core.hooksPath .githooks`, so hooks travel with the repo and don't have to be symlinked into `.git/hooks/`.

### Bypassing (rare)
- Skip lint on a push: `git push --no-verify`
- Skip auto-regen on a merge: `git merge --no-verify` (or `git -c core.hooksPath=/dev/null pull`)

### Requirements
- `python3` + `pillow` for icon regeneration: `pip install pillow`
- `node` (optional) for `node --check sw.js` — falls back to grep sanity if missing.
