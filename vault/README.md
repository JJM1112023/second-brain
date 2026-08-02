# Obsidian Vault — Second Brain

**This directory is generated.** Do not hand-edit the notes; edit the sources
and rerun the generator:

```bash
python3 scripts/gen_secondbrain.py
```

## Open the mind map

1. Install [Obsidian](https://obsidian.md/).
2. *Open folder as vault* → pick this `vault/` directory.
3. Open **[[Home]]** and press `Ctrl/Cmd+G` for **Graph view**.
4. Graph settings ship preconfigured in `.obsidian/graph.json` — pillars sit at
   the centre with skills and tool categories radiating out.

## Structure

| Folder | Contents |
|---|---|
| `Home.md` | Root map of content — start here |
| `Pillars/` | One note per pillar, linking to its skills |
| `Skills/` | One note per skill in `.claude/skills/` |
| `Tools/` | One note per README tool category |
| `Roadmap.md` | Build phases, mirrored in the Z.E.R.O. console |
| `Repo Map.md` | How the repository itself is wired |

## Where the links come from

Every `[[wikilink]]` is derived, not typed by hand: skills link to their pillar
and their siblings, pillars link to each other and back to `Home`, tool
categories cross-link across the arsenal. That is what makes the graph a real
map instead of a flat folder listing.

`scripts/check-vault.sh` fails the build if any wikilink points at a note that
does not exist, or if a note is unreachable from `Home`.

## The private half

This repository is public, so everything above is visible to anyone. Personal
notes live in a **separate private repository** cloned into `Private/` here:

```bash
git clone https://github.com/JJM1112023/second-brain-private vault/Private
```

`vault/Private/` is gitignored by the public repo and skipped by every check,
so Obsidian shows one unified graph — public knowledge plus private thinking —
while git keeps the two histories completely separate. Commit and push private
notes from inside `vault/Private/`; they only ever go to the private repo.
