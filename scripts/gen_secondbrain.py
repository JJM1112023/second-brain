#!/usr/bin/env python3
"""gen_secondbrain.py — build the second brain from the repo itself.

Single source of truth. Everything downstream is generated:

    .claude/skills/*/SKILL.md  ─┐
    README.md                  ─┤──> parse ──> model ──> ┌── vault/            (Obsidian mind map)
    (pillar map, below)        ─┘                        ├── zero-brain/brain.json (Z.E.R.O. app data)
                                                         └── SECOND_BRAIN_INDEX.md (generated block)

Run it after adding a skill or a README entry:

    python3 scripts/gen_secondbrain.py

Output is deterministic (everything sorted, no timestamps) so CI can run the
generator and assert `git diff --exit-code` — a stale vault fails the build.

    python3 scripts/gen_secondbrain.py --check   # report drift, write nothing
"""
from __future__ import annotations

import argparse
import html
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / ".claude" / "skills"
README = ROOT / "README.md"
VAULT = ROOT / "vault"
MANIFEST = ROOT / "vault" / ".generated"
BRAIN_JSON = ROOT / "zero-brain" / "brain.json"
BRAIN_JS = ROOT / "zero-brain" / "brain-data.js"
INDEX_MD = ROOT / "SECOND_BRAIN_INDEX.md"

GEN_BEGIN = "<!-- BEGIN GENERATED: skill-catalog -->"
GEN_END = "<!-- END GENERATED: skill-catalog -->"

REPO_URL = "https://github.com/JJM1112023/second-brain"
PAGES_URL = "https://jjm1112023.github.io/second-brain"

# ── Pillars ────────────────────────────────────────────────────────────────
# The one hand-maintained mapping in this file. Any skill missing from it lands
# in "Unsorted" rather than disappearing, and --check reports it.
PILLARS = [
    {
        "id": "memory",
        "name": "Memory & Second Brain",
        "emoji": "🧠",
        "color": "#00ccff",
        "blurb": "The core. Where knowledge is stored, structured, and survives between sessions.",
        "skills": [
            "obsidian-memory",
            "advanced-claude-md",
            "workspace-org",
            "hermes-learn",
            "skill-generator",
        ],
    },
    {
        "id": "interface",
        "name": "Jarvis Interface",
        "emoji": "🎙️",
        "color": "#00ff88",
        "blurb": "How you talk to the brain — voice, dashboards, and the daily briefing.",
        "skills": ["hermes-jarvis", "wispr-flow", "morning-brief", "agent-os"],
    },
    {
        "id": "agents",
        "name": "Agent Engine",
        "emoji": "🤖",
        "color": "#cc44ff",
        "blurb": "The automation muscle — orchestration, parallelism, safety rails.",
        "skills": [
            "always-on-agents",
            "agent-harness",
            "agentic-harness",
            "agent-teams",
            "paperclip-teams",
            "claude-managed-agents",
            "browser-automation",
            "autoresearch",
            "n8n-vs-mcp",
            "human-validation",
            "claude-security",
        ],
    },
    {
        "id": "business",
        "name": "Business Launchpad",
        "emoji": "💼",
        "color": "#ff8800",
        "blurb": "Turning the brain into revenue — the LLC, client sites, and service lines.",
        "skills": [
            "claude-freelance",
            "premium-website",
            "claude-cms",
            "claude-seo",
            "ghl-automation",
            "buildpartner",
            "lovable-ai",
            "vibe-coding",
            "hermes-oracle",
        ],
    },
    {
        "id": "maintenance",
        "name": "Repo Maintenance",
        "emoji": "🛠️",
        "color": "#dddd44",
        "blurb": "Keeping the repository itself healthy and consistent.",
        "skills": ["add-entry", "review"],
    },
    {
        "id": "arsenal",
        "name": "Tool Arsenal",
        "emoji": "🗡️",
        "color": "#ff4444",
        "blurb": "The curated sysadmin tool library in README.md, grouped by domain.",
        "skills": [],
    },
]

UNSORTED = {
    "id": "unsorted",
    "name": "Unsorted",
    "emoji": "📥",
    "color": "#8899aa",
    "blurb": "Skills not yet assigned to a pillar. Add them to PILLARS in scripts/gen_secondbrain.py.",
    "skills": [],
}


# ── Parsing ────────────────────────────────────────────────────────────────
def parse_frontmatter(text: str) -> tuple[dict, str]:
    """Split a leading `---` YAML-ish block into a flat dict plus the body."""
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}, text
    meta: dict[str, str] = {}
    for line in text[4:end].splitlines():
        if ":" in line and not line.startswith((" ", "\t", "#")):
            key, _, value = line.partition(":")
            meta[key.strip()] = value.strip()
    return meta, text[end + 5 :]


def parse_skills() -> list[dict]:
    skills = []
    for skill_md in sorted(SKILLS_DIR.glob("*/SKILL.md")):
        meta, body = parse_frontmatter(skill_md.read_text(encoding="utf-8"))
        slug = meta.get("name") or skill_md.parent.name
        sections = [
            m.group(1).strip()
            for m in re.finditer(r"^##\s+(.+)$", body, flags=re.MULTILINE)
        ]
        links = sorted(
            {
                m.group(0)
                for m in re.finditer(r"https?://[^\s)\]\"'>]+", body)
                if not m.group(0).endswith(",")
            }
        )
        skills.append(
            {
                "slug": slug,
                "title": slug.replace("-", " ").title(),
                "description": meta.get("description", "").strip(),
                "sections": sections,
                "links": links[:12],
                "path": str(skill_md.relative_to(ROOT)),
                "words": len(body.split()),
            }
        )
    return skills


ENTRY_RE = re.compile(
    r'^&nbsp;&nbsp;:small_orange_diamond: <a href="([^"]+)"><b>([^<]+)</b></a>\s*-?\s*(.*?)<br>\s*$'
)


def clean(text: str) -> str:
    """HTML fragment → plain text."""
    return html.unescape(re.sub(r"<[^>]+>", "", text)).strip()


def parse_readme() -> list[dict]:
    """README.md → [{name, slug, subcategories: [{name, tools: [...]}]}]."""
    categories: list[dict] = []
    category = None
    subcategory = None

    for line in README.read_text(encoding="utf-8").splitlines():
        if line.startswith("#### ") and not line.startswith("##### "):
            name = clean(line[5:])
            category = {"name": name, "slug": slugify(name), "subcategories": []}
            categories.append(category)
            subcategory = None
            continue

        if line.startswith("##### "):
            if category is None:
                continue
            name = clean(line[6:].replace(":black_small_square:", ""))
            subcategory = {"name": name, "tools": [], "synthetic": False}
            category["subcategories"].append(subcategory)
            continue

        match = ENTRY_RE.match(line)
        if not match or category is None:
            continue
        if subcategory is None:
            # Entries that sit directly under a #### with no ##### above them.
            # Synthesized so they still get a node, but not counted as a
            # sub-domain — there is no such heading in README.md.
            subcategory = {"name": category["name"], "tools": [], "synthetic": True}
            category["subcategories"].append(subcategory)
        url, name, desc = match.groups()
        subcategory["tools"].append(
            {"name": clean(name), "url": url, "description": clean(desc).rstrip(".")}
        )

    return categories


def real_subs(cat: dict) -> list:
    """Subcategories that actually have a ##### heading in README.md."""
    return [s for s in cat["subcategories"] if not s["synthetic"]]


def slugify(name: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", name.lower())).strip("-")


def safe_title(name: str) -> str:
    """Obsidian note titles cannot contain path separators or `[]#|^`."""
    out = name.replace("/", " · ").replace("\\", " · ")
    for ch in "[]#|^:":
        out = out.replace(ch, "")
    return re.sub(r"\s+", " ", out).strip()


# ── Model ──────────────────────────────────────────────────────────────────
def build_model() -> dict:
    skills = parse_skills()
    by_slug = {s["slug"]: s for s in skills}
    categories = parse_readme()

    pillars = [dict(p) for p in PILLARS]
    assigned = {slug for p in pillars for slug in p["skills"]}
    orphans = sorted(set(by_slug) - assigned)
    if orphans:
        unsorted_pillar = dict(UNSORTED)
        unsorted_pillar["skills"] = orphans
        pillars.append(unsorted_pillar)

    # Attach resolved skill objects; drop mapped slugs that no longer exist.
    missing: list[str] = []
    for pillar in pillars:
        resolved = []
        for slug in pillar["skills"]:
            if slug in by_slug:
                resolved.append(by_slug[slug])
            else:
                missing.append(slug)
        pillar["skills"] = sorted(resolved, key=lambda s: s["slug"])

    tool_count = sum(
        len(sub["tools"]) for cat in categories for sub in cat["subcategories"]
    )
    return {
        "pillars": pillars,
        "categories": categories,
        "skills": skills,
        "orphans": orphans,
        "missing": sorted(set(missing)),
        "counts": {
            "skills": len(skills),
            "pillars": len(pillars),
            "categories": len(categories),
            "subcategories": sum(
                1
                for c in categories
                for s in c["subcategories"]
                if not s["synthetic"]
            ),
            "tools": tool_count,
        },
    }


# ── Vault emitter ──────────────────────────────────────────────────────────
def frontmatter(**fields) -> str:
    lines = ["---"]
    for key, value in fields.items():
        if isinstance(value, list):
            lines.append(f"{key}:")
            lines.extend(f"  - {item}" for item in value)
        else:
            lines.append(f"{key}: {value}")
    lines.append("---")
    return "\n".join(lines) + "\n"


def emit_vault(model: dict) -> dict[str, str]:
    """Return {relative path: file content} for the whole vault."""
    files: dict[str, str] = {}
    pillars = model["pillars"]
    categories = model["categories"]
    counts = model["counts"]

    # ── Home — the centre of the mind map ──
    home = [
        frontmatter(
            title="Home",
            tags=["moc", "home"],
            skills=counts["skills"],
            tools=counts["tools"],
        ),
        "# 🧠 Second Brain — Home\n",
        "> The root of the mind map. Open Obsidian's **Graph view** (`Ctrl/Cmd+G`) "
        "with this note focused to see the whole system radiate outwards.\n",
        "## Pillars\n",
    ]
    for pillar in pillars:
        count = len(pillar["skills"]) or (
            len(categories) if pillar["id"] == "arsenal" else 0
        )
        home.append(
            f"- {pillar['emoji']} [[{safe_title(pillar['name'])}]] — {pillar['blurb']} "
            f"*({count} notes)*"
        )
    home.append("\n## Fast lanes\n")
    home.append("- [[Roadmap]] — what is built and what is next")
    home.append("- [[Tool Arsenal]] — the curated sysadmin library")
    home.append("- [[Repo Map]] — scripts, PWA, CI, and hooks in this repository")
    home.append("- [[Z.E.R.O. Console]] — the live browser dashboard over this vault\n")
    home.append("## By the numbers\n")
    home.append("| Metric | Count |")
    home.append("|---|---|")
    home.append(f"| Skills | {counts['skills']} |")
    home.append(f"| Pillars | {counts['pillars']} |")
    home.append(f"| Tool categories | {counts['categories']} |")
    home.append(f"| Tool subcategories | {counts['subcategories']} |")
    home.append(f"| Curated tools | {counts['tools']} |")
    home.append("")
    files["Home.md"] = "\n".join(home)

    # ── Pillar notes ──
    for pillar in pillars:
        title = safe_title(pillar["name"])
        body = [
            frontmatter(
                title=title,
                tags=["pillar", f"pillar/{pillar['id']}"],
                color=pillar["color"],
            ),
            f"# {pillar['emoji']} {title}\n",
            f"{pillar['blurb']}\n",
            "Up: [[Home]]\n",
        ]
        if pillar["id"] == "arsenal":
            body.append("## Categories\n")
            for cat in categories:
                tools = sum(len(s["tools"]) for s in cat["subcategories"])
                body.append(f"- [[{safe_title(cat['name'])}]] — {tools} tools")
            body.append("")
        else:
            body.append("## Skills\n")
            for skill in pillar["skills"]:
                body.append(f"- [[{skill['slug']}]] — {skill['description']}")
            body.append("")
            siblings = [p for p in pillars if p["id"] != pillar["id"]]
            body.append("## Related pillars\n")
            for sibling in siblings:
                body.append(f"- [[{safe_title(sibling['name'])}]]")
            body.append("")
        files[f"Pillars/{title}.md"] = "\n".join(body)

    # ── Skill notes ──
    pillar_of = {
        skill["slug"]: pillar for pillar in pillars for skill in pillar["skills"]
    }
    for skill in model["skills"]:
        pillar = pillar_of.get(skill["slug"])
        pillar_title = safe_title(pillar["name"]) if pillar else "Unsorted"
        body = [
            frontmatter(
                title=skill["slug"],
                tags=["skill", f"pillar/{pillar['id']}" if pillar else "pillar/unsorted"],
                source=skill["path"],
            ),
            f"# {skill['title']}\n",
            f"{skill['description']}\n",
            f"Pillar: [[{pillar_title}]] · Up: [[Home]]\n",
            f"**Invoke:** `/{skill['slug']}` · **Source:** `{skill['path']}`\n",
        ]
        if skill["sections"]:
            body.append("## What is inside\n")
            body.extend(f"- {section}" for section in skill["sections"])
            body.append("")
        if skill["links"]:
            body.append("## External references\n")
            body.extend(f"- <{link}>" for link in skill["links"])
            body.append("")
        if pillar and len(pillar["skills"]) > 1:
            body.append("## Siblings in this pillar\n")
            body.extend(
                f"- [[{other['slug']}]]"
                for other in pillar["skills"]
                if other["slug"] != skill["slug"]
            )
            body.append("")
        files[f"Skills/{skill['slug']}.md"] = "\n".join(body)

    # ── Tool category notes ──
    for cat in categories:
        title = safe_title(cat["name"])
        total = sum(len(sub["tools"]) for sub in cat["subcategories"])
        body = [
            frontmatter(
                title=title,
                tags=["tools", f"tools/{cat['slug']}"],
                tools=total,
            ),
            f"# {cat['name']}\n",
            f"{total} curated tools. Pillar: [[Tool Arsenal]] · Up: [[Home]]\n",
        ]
        for sub in cat["subcategories"]:
            if not sub["synthetic"]:
                body.append(f"## {sub['name']}\n")
            for tool in sub["tools"]:
                desc = f" — {tool['description']}" if tool["description"] else ""
                body.append(f"- [{tool['name']}]({tool['url']}){desc}")
            body.append("")
        body.append("## Other categories\n")
        body.extend(
            f"- [[{safe_title(other['name'])}]]"
            for other in categories
            if other["slug"] != cat["slug"]
        )
        body.append("")
        files[f"Tools/{title}.md"] = "\n".join(body)

    # ── Repo map ──
    files["Repo Map.md"] = "\n".join(
        [
            frontmatter(title="Repo Map", tags=["repo", "moc"]),
            "# 🗺️ Repo Map\n",
            "How this repository is wired. Up: [[Home]]\n",
            "## Deliverables\n",
            "| Path | What it is |",
            "|---|---|",
            "| `README.md` | The curated tool list — the primary deliverable |",
            "| `vault/` | This Obsidian vault (generated) |",
            "| `zero-brain/` | [[Z.E.R.O. Console]] — the browser dashboard |",
            "| `index.html` | Immersive 3D landing page / PWA shell |",
            "| `.claude/skills/` | The skill library |",
            "",
            "## Bash layer\n",
            "| Script | Purpose |",
            "|---|---|",
            "| `src/syshealth.sh` | System health report |",
            "| `src/diskusage.sh` | Disk usage with alert thresholds |",
            "| `src/logclean.sh` | Rotate and compress old logs |",
            "| `src/netdiag.sh` | Network diagnostics |",
            "| `src/sslcheck.sh` | TLS certificate expiry checker |",
            "| `lib/common.sh` | Shared helpers (sourced, never executed) |",
            "",
            "## Validation\n",
            "| Gate | Command |",
            "|---|---|",
            "| Shell lint | `shellcheck -s bash -e 1072,1094 -x src/*.sh lib/common.sh` |",
            "| Functional tests | `bats test/` |",
            "| PWA shell | `bash scripts/validate-pwa.sh` |",
            "| README quality | `bash scripts/check-readme.sh` |",
            "| Vault integrity | `bash scripts/check-vault.sh` |",
            "| Regenerate everything | `python3 scripts/gen_secondbrain.py` |",
            "",
            "## Rules that never bend\n",
            "- Every commit carries a `signed-off-by` line.",
            "- Pull requests target `testing`, never `master`.",
            "- Editing PWA shell files means bumping `VERSION` in `sw.js`.",
            "- `vault/` and `zero-brain/brain.json` are generated — edit the sources, then rerun the generator.",
            "",
        ]
    )

    # ── Z.E.R.O. console note ──
    files["Z.E.R.O. Console.md"] = "\n".join(
        [
            frontmatter(title="Z.E.R.O. Console", tags=["app", "interface"]),
            "# 🧠 Z.E.R.O. Console\n",
            "The browser-side face of this vault. Pillar: [[Jarvis Interface]] · Up: [[Home]]\n",
            "## What it does\n",
            "- Renders every pillar, skill, and tool category as an interactive 3D knowledge graph",
            "- Full-text search across all skills and every curated tool",
            "- Click any node for its detail panel, external links, and neighbours",
            "- A roadmap checklist and a capture inbox, both persisted in `localStorage`",
            "- Exports captured notes as Markdown ready to drop into this vault",
            "- Works offline — precached by the service worker",
            "",
            "## Where\n",
            f"- Live: <{PAGES_URL}/zero-brain/>",
            "- Local: open `zero-brain/index.html`",
            "- Data: `zero-brain/brain.json` (generated by `scripts/gen_secondbrain.py`)",
            "",
            "## Feeding it\n",
            "The console reads the same model this vault is built from. Add a skill under "
            "`.claude/skills/` or an entry in `README.md`, rerun the generator, and both "
            "the graph and this vault pick it up.\n",
        ]
    )

    # ── Roadmap ──
    files["Roadmap.md"] = "\n".join(
        [
            frontmatter(title="Roadmap", tags=["roadmap", "moc"]),
            "# 🗺️ Roadmap\n",
            "Up: [[Home]]. The [[Z.E.R.O. Console]] renders these phases as a live "
            "checklist and remembers what you tick.\n",
            "## Phases\n",
            "- [x] **Phase 0 — Collect** — skills and tools gathered",
            "- [x] **Phase 1 — Index** — everything catalogued and searchable",
            "- [x] **Phase 2 — Vault** — this Obsidian vault, generated from the repo",
            "- [x] **Phase 3 — Console** — [[Z.E.R.O. Console]] running over the same data",
            "- [ ] **Phase 4 — Desktop foundation** — clean folder structure per [[workspace-org]]",
            "- [ ] **Phase 5 — Live memory** — wire [[obsidian-memory]] to this vault",
            "- [ ] **Phase 6 — Voice** — [[hermes-jarvis]] plus [[wispr-flow]]",
            "- [ ] **Phase 7 — Always on** — [[always-on-agents]] and [[morning-brief]] daily",
            "- [ ] **Phase 8 — Multi-model** — route each task to the best model",
            "- [ ] **Phase 9 — Business** — [[claude-freelance]] offer, [[premium-website]] and "
            "[[claude-cms]] delivery, [[claude-seo]] and [[ghl-automation]] services",
            "",
            "## Capture inbox\n",
            "Notes captured in the console export here as Markdown. Paste them in and link "
            "them to the pillar they belong to.\n",
        ]
    )

    # ── Vault README + Obsidian config ──
    files["README.md"] = "\n".join(
        [
            "# Obsidian Vault — Second Brain\n",
            "**This directory is generated.** Do not hand-edit the notes; edit the sources",
            "and rerun the generator:\n",
            "```bash",
            "python3 scripts/gen_secondbrain.py",
            "```\n",
            "## Open the mind map\n",
            "1. Install [Obsidian](https://obsidian.md/).",
            "2. *Open folder as vault* → pick this `vault/` directory.",
            "3. Open **[[Home]]** and press `Ctrl/Cmd+G` for **Graph view**.",
            "4. Graph settings ship preconfigured in `.obsidian/graph.json` — pillars sit at",
            "   the centre with skills and tool categories radiating out.\n",
            "## Structure\n",
            "| Folder | Contents |",
            "|---|---|",
            "| `Home.md` | Root map of content — start here |",
            "| `Pillars/` | One note per pillar, linking to its skills |",
            "| `Skills/` | One note per skill in `.claude/skills/` |",
            "| `Tools/` | One note per README tool category |",
            "| `Roadmap.md` | Build phases, mirrored in the Z.E.R.O. console |",
            "| `Repo Map.md` | How the repository itself is wired |\n",
            "## Where the links come from\n",
            "Every `[[wikilink]]` is derived, not typed by hand: skills link to their pillar",
            "and their siblings, pillars link to each other and back to `Home`, tool",
            "categories cross-link across the arsenal. That is what makes the graph a real",
            "map instead of a flat folder listing.\n",
            "`scripts/check-vault.sh` fails the build if any wikilink points at a note that",
            "does not exist, or if a note is unreachable from `Home`.\n",
            "## The private half\n",
            "This repository is public, so everything above is visible to anyone. Personal",
            "notes live in a **separate private repository** cloned into `Private/` here:\n",
            "```bash",
            "git clone https://github.com/JJM1112023/second-brain-private vault/Private",
            "```\n",
            "`vault/Private/` is gitignored by the public repo and skipped by every check,",
            "so Obsidian shows one unified graph — public knowledge plus private thinking —",
            "while git keeps the two histories completely separate. Commit and push private",
            "notes from inside `vault/Private/`; they only ever go to the private repo.\n",
        ]
    )

    files[".obsidian/graph.json"] = json.dumps(
        {
            "collapse-filter": False,
            "search": "",
            "showTags": True,
            "showAttachments": False,
            "hideUnresolved": True,
            "showOrphans": False,
            "collapse-color-groups": False,
            "colorGroups": [
                {"query": "tag:#pillar", "color": {"a": 1, "rgb": 16755200}},
                {"query": "tag:#skill", "color": {"a": 1, "rgb": 52735}},
                {"query": "tag:#tools", "color": {"a": 1, "rgb": 16729156}},
                {"query": "tag:#moc", "color": {"a": 1, "rgb": 65416}},
            ],
            "collapse-display": False,
            "showArrow": True,
            "textFadeMultiplier": -0.4,
            "nodeSizeMultiplier": 1.35,
            "lineSizeMultiplier": 1.1,
            "collapse-forces": False,
            "centerStrength": 0.42,
            "repelStrength": 11,
            "linkStrength": 0.85,
            "linkDistance": 190,
            "scale": 0.8,
            "close": False,
        },
        indent=2,
    ) + "\n"

    files[".obsidian/app.json"] = json.dumps(
        {"attachmentFolderPath": "attachments", "alwaysUpdateLinks": True,
         "newLinkFormat": "shortest", "useMarkdownLinks": False},
        indent=2,
    ) + "\n"

    files[".obsidian/appearance.json"] = json.dumps(
        {"accentColor": "#00ccff", "theme": "obsidian"}, indent=2
    ) + "\n"

    files[".obsidian/core-plugins.json"] = json.dumps(
        ["file-explorer", "global-search", "switcher", "graph", "backlink",
         "outgoing-link", "tag-pane", "outline", "word-count"],
        indent=2,
    ) + "\n"

    return files


# ── brain.json emitter ─────────────────────────────────────────────────────
def emit_brain(model: dict) -> str:
    """The Z.E.R.O. console's data file: graph nodes, edges, and a search index."""
    nodes = []
    edges = []

    def add_edge(source: str, target: str) -> None:
        edges.append({"s": source, "t": target})

    for pillar in model["pillars"]:
        pid = f"pillar:{pillar['id']}"
        nodes.append(
            {
                "id": pid,
                "kind": "pillar",
                "label": pillar["name"].upper(),
                "color": pillar["color"],
                "emoji": pillar["emoji"],
                "detail": pillar["blurb"],
                "pillar": pillar["id"],
            }
        )
        for skill in pillar["skills"]:
            sid = f"skill:{skill['slug']}"
            nodes.append(
                {
                    "id": sid,
                    "kind": "skill",
                    "label": skill["slug"],
                    "color": pillar["color"],
                    "detail": skill["description"],
                    "pillar": pillar["id"],
                    "sections": skill["sections"],
                    "links": skill["links"],
                    "path": skill["path"],
                    "invoke": f"/{skill['slug']}",
                }
            )
            add_edge(pid, sid)

    arsenal = "pillar:arsenal"
    tools_index = []
    for cat in model["categories"]:
        cid = f"cat:{cat['slug']}"
        total = sum(len(sub["tools"]) for sub in cat["subcategories"])
        nodes.append(
            {
                "id": cid,
                "kind": "category",
                "label": cat["name"],
                "color": "#ff4444",
                "detail": f"{total} curated tools across "
                f"{len(real_subs(cat)) or 1} subcategories.",
                "pillar": "arsenal",
                "count": total,
            }
        )
        add_edge(arsenal, cid)
        for sub in cat["subcategories"]:
            sid = f"sub:{cat['slug']}:{slugify(sub['name'])}"
            nodes.append(
                {
                    "id": sid,
                    "kind": "subcategory",
                    "label": sub["name"],
                    "color": "#ff8866",
                    "detail": f"{len(sub['tools'])} tools in {cat['name']}.",
                    "pillar": "arsenal",
                    "count": len(sub["tools"]),
                }
            )
            add_edge(cid, sid)
            for tool in sub["tools"]:
                tools_index.append(
                    {
                        "name": tool["name"],
                        "url": tool["url"],
                        "desc": tool["description"],
                        "cat": cat["name"],
                        "sub": sub["name"],
                        "node": sid,
                    }
                )

    roadmap = [
        {"id": "p0", "label": "Phase 0 — Collect skills and tools", "done": True},
        {"id": "p1", "label": "Phase 1 — Index everything, searchable", "done": True},
        {"id": "p2", "label": "Phase 2 — Obsidian vault generated from the repo", "done": True},
        {"id": "p3", "label": "Phase 3 — Z.E.R.O. console over the same data", "done": True},
        {"id": "p4", "label": "Phase 4 — Desktop foundation and folder hygiene", "done": False},
        {"id": "p5", "label": "Phase 5 — Live memory wired to the vault", "done": False},
        {"id": "p6", "label": "Phase 6 — Voice: hermes-jarvis + wispr-flow", "done": False},
        {"id": "p7", "label": "Phase 7 — Always on: agents + morning brief", "done": False},
        {"id": "p8", "label": "Phase 8 — Multi-model routing", "done": False},
        {"id": "p9", "label": "Phase 9 — Business launch", "done": False},
    ]

    payload = {
        "schema": 1,
        "repo": REPO_URL,
        "counts": model["counts"],
        "pillars": [
            {
                "id": p["id"],
                "name": p["name"],
                "emoji": p["emoji"],
                "color": p["color"],
                "blurb": p["blurb"],
            }
            for p in model["pillars"]
        ],
        "nodes": nodes,
        "edges": edges,
        "tools": tools_index,
        "roadmap": roadmap,
    }
    return json.dumps(payload, indent=1, ensure_ascii=False, sort_keys=False) + "\n"


# ── SECOND_BRAIN_INDEX.md generated block ──────────────────────────────────
def emit_index_block(model: dict) -> str:
    counts = model["counts"]
    out = [
        GEN_BEGIN,
        "<!-- Regenerate with: python3 scripts/gen_secondbrain.py -->",
        "",
        "## 📍 How this repo fits the mission",
        "",
        "| Piece | Where it lives | What it is |",
        "|---|---|---|",
        f"| **Tool library** | `README.md` | {counts['tools']} curated tools across "
        f"{counts['categories']} categories |",
        f"| **Skill library** | `.claude/skills/` | {counts['skills']} reusable AI workflows |",
        "| **Obsidian mind map** | `vault/` | Generated vault — open in Obsidian, press `Ctrl/Cmd+G` |",
        "| **Z.E.R.O. console** | `zero-brain/` | Live browser dashboard over the same data |",
        "| **This index** | `SECOND_BRAIN_INDEX.md` | The map that ties it all together |",
        "| **AI operating rules** | `CLAUDE.md` | How assistants must behave in this repo |",
        "",
        "## 🗂️ Skill catalog — organized by pillar",
        "",
    ]
    for pillar in model["pillars"]:
        if not pillar["skills"]:
            continue
        out.append(f"### {pillar['emoji']} {pillar['name']}")
        out.append("")
        out.append(f"*{pillar['blurb']}*")
        out.append("")
        out.append("| Skill | What it does |")
        out.append("|---|---|")
        for skill in pillar["skills"]:
            desc = skill["description"].replace("|", "\\|")
            out.append(f"| `{skill['slug']}` | {desc} |")
        out.append("")

    out.append("### 🗡️ Tool Arsenal")
    out.append("")
    out.append("| Category | Subcategories | Tools |")
    out.append("|---|---|---|")
    for cat in model["categories"]:
        tools = sum(len(s["tools"]) for s in cat["subcategories"])
        out.append(f"| {cat['name']} | {len(real_subs(cat))} | {tools} |")
    out.append("")
    out.append(GEN_END)
    return "\n".join(out)


def splice_index(model: dict) -> str:
    text = INDEX_MD.read_text(encoding="utf-8")
    block = emit_index_block(model)
    if GEN_BEGIN in text and GEN_END in text:
        start = text.index(GEN_BEGIN)
        end = text.index(GEN_END) + len(GEN_END)
        return text[:start] + block + text[end:]
    return text.rstrip("\n") + "\n\n" + block + "\n"


# ── Write / check ──────────────────────────────────────────────────────────
def collect_outputs(model: dict) -> dict[Path, str]:
    outputs: dict[Path, str] = {
        VAULT / rel: content for rel, content in emit_vault(model).items()
    }
    brain = emit_brain(model)
    outputs[BRAIN_JSON] = brain
    # Same payload, wrapped for a plain <script src>. The console loads this
    # rather than fetching the .json so it also works from file:// (where
    # fetch is blocked by CORS) and precaches cleanly for offline use.
    outputs[BRAIN_JS] = (
        "/* Generated by scripts/gen_secondbrain.py — do not edit. */\n"
        "window.__BRAIN__ = " + brain.rstrip("\n") + ";\n"
    )
    outputs[INDEX_MD] = splice_index(model)

    # Record exactly which vault files this run owns. The next run sweeps only
    # what is listed here, so the user's own notes and Obsidian's runtime state
    # (workspace.json, plugins, .trash) are never touched.
    owned = sorted(
        str(path.relative_to(VAULT)) for path in outputs if VAULT in path.parents
    )
    outputs[MANIFEST] = (
        "# Files owned by scripts/gen_secondbrain.py. Deleted when no longer\n"
        "# generated. Anything not listed here is yours and is left alone.\n"
        + "".join(f"{name}\n" for name in owned)
    )
    return outputs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="report drift and exit non-zero instead of writing",
    )
    args = parser.parse_args()

    model = build_model()

    if model["missing"]:
        print(
            "error: PILLARS references skills that do not exist: "
            + ", ".join(model["missing"]),
            file=sys.stderr,
        )
        return 1

    outputs = collect_outputs(model)

    if args.check:
        drift = [
            path
            for path, content in outputs.items()
            if not path.exists() or path.read_text(encoding="utf-8") != content
        ]
        stale = stale_vault_files(outputs)
        if drift or stale:
            print("second brain is out of date. Run: python3 scripts/gen_secondbrain.py")
            for path in sorted(drift):
                print(f"  changed: {path.relative_to(ROOT)}")
            for path in sorted(stale):
                print(f"  orphaned: {path.relative_to(ROOT)}")
            return 1
        print(
            f"second brain up to date "
            f"({model['counts']['skills']} skills, {model['counts']['tools']} tools, "
            f"{len(outputs)} generated files)"
        )
        return 0

    # Remove notes that no longer have a source before writing the new set.
    for path in stale_vault_files(outputs):
        path.unlink()
    for directory in sorted(
        (p for p in VAULT.rglob("*") if p.is_dir()), key=lambda p: -len(p.parts)
    ):
        if not any(directory.iterdir()):
            shutil.rmtree(directory)

    for path, content in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    if model["orphans"]:
        print(
            "warning: skills with no pillar (filed under Unsorted): "
            + ", ".join(model["orphans"])
        )
    print(
        f"wrote {len(outputs)} files — {model['counts']['skills']} skills, "
        f"{model['counts']['tools']} tools, {model['counts']['categories']} categories"
    )
    return 0


def previously_generated() -> list[Path]:
    """Vault files the last run claimed ownership of, per vault/.generated."""
    if not MANIFEST.exists():
        return []
    return [
        VAULT / line
        for line in MANIFEST.read_text(encoding="utf-8").splitlines()
        if line and not line.startswith("#")
    ]


def stale_vault_files(outputs: dict[Path, str]) -> list[Path]:
    """Previously generated vault files that this run no longer produces.

    Scoped to the manifest on purpose: sweeping everything under vault/ would
    delete the user's own notes and Obsidian's workspace state.
    """
    wanted = set(outputs)
    return [p for p in previously_generated() if p not in wanted and p.is_file()]


if __name__ == "__main__":
    sys.exit(main())
