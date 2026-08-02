# 🧠 Second Brain Index — Jarvis Command Center

> **Owner:** John Maguire · **Mission:** An Obsidian-styled, Jarvis-based second brain — every skill and tool cataloged, searchable, and ready to power the LLC, websites, and digital services.

This file is the **master map** of everything in this repository. When you (or any AI assistant) need to know *"where is X and what does it do?"* — start here.

---

## 🚀 The three faces of the brain

The same data, rendered three ways. All of it is generated from the repo itself
by `scripts/gen_secondbrain.py`, so none of it can drift out of sync.

| Face | Open it with | Best for |
|---|---|---|
| **Obsidian mind map** | Open `vault/` as a vault → `Home` → `Ctrl/Cmd+G` | Thinking, linking, writing |
| **Z.E.R.O. console** | `zero-brain/index.html`, or [live](https://jjm1112023.github.io/second-brain/zero-brain/) | Searching, exploring the graph, capturing |
| **This index** | Right here | Skimming the whole catalog as text |

```bash
python3 scripts/gen_secondbrain.py   # rebuild all three after adding a skill or tool
bash scripts/check-vault.sh          # verify links, frontmatter, and freshness
```

**Adding to the brain:** drop a `SKILL.md` under `.claude/skills/<name>/`, or add a
README entry with the `add-entry` skill. Then assign the skill to a pillar in the
`PILLARS` map at the top of `scripts/gen_secondbrain.py` and rerun the generator.
Skip the pillar assignment and it still shows up — filed under **Unsorted**, with a
warning — so nothing is ever silently lost.

---

<!-- BEGIN GENERATED: skill-catalog -->
<!-- Regenerate with: python3 scripts/gen_secondbrain.py -->

## 📍 How this repo fits the mission

| Piece | Where it lives | What it is |
|---|---|---|
| **Tool library** | `README.md` | 180 curated tools across 12 categories |
| **Skill library** | `.claude/skills/` | 31 reusable AI workflows |
| **Obsidian mind map** | `vault/` | Generated vault — open in Obsidian, press `Ctrl/Cmd+G` |
| **Z.E.R.O. console** | `zero-brain/` | Live browser dashboard over the same data |
| **This index** | `SECOND_BRAIN_INDEX.md` | The map that ties it all together |
| **AI operating rules** | `CLAUDE.md` | How assistants must behave in this repo |

## 🗂️ Skill catalog — organized by pillar

### 🧠 Memory & Second Brain

*The core. Where knowledge is stored, structured, and survives between sessions.*

| Skill | What it does |
|---|---|
| `advanced-claude-md` | Advanced CLAUDE.md and system prompt optimization — structure, imports, rules hierarchy, and quality improvement patterns from the Claude Code Advanced Course. |
| `hermes-learn` | Teach Claude (or Hermes Agent) a new workflow from any source — URL, PDF, doc, code folder, or pasted notes — and save it as a reusable skill.md that auto-loads in future sessions. |
| `obsidian-memory` | Persistent memory layer using Obsidian + NotebookLM MCP — store, retrieve, and cross-reference knowledge across AI sessions so context is never lost between conversations. |
| `skill-generator` | Meta-skill — generate a new .claude/skills/ entry from any pasted video description, article, or doc. Extracts tool names, URLs, chapter structure, and key concepts, then writes the SKILL.md, adds README entries, commits, and pushes. Formalizes the hermes-learn pattern. |
| `workspace-org` | Workspace organization for personal, business, and client projects in Claude Code — session naming, worktrees, project separation, and context hygiene. |

### 🎙️ Jarvis Interface

*How you talk to the brain — voice, dashboards, and the daily briefing.*

| Skill | What it does |
|---|---|
| `agent-os` | Agentic OS — the full Agent Operating System running at localhost:3737/hermes. Covers the sidebar layout, agent roster, orchestration tools, and navigation tabs inside the Hermes web UI. |
| `hermes-jarvis` | Hermes-Jarvis voice interface — the orb UI inside localhost:3737/hermes. Covers Neural Link controls (Realtime, Live, Wake word, Auto mode, Briefing, Ash persona) and how to interact. |
| `morning-brief` | Automated morning brief — aggregates news, calendar, tasks, emails, and market data into a single daily summary delivered via your preferred channel (voice, Slack, email, or Telegram). |
| `wispr-flow` | Wispr Flow — system-wide voice-to-text for Mac. Dictate into any app including Claude Code, terminals, and chat interfaces. Covers setup, dictation patterns, and voice prompting for agentic workflows. |

### 🤖 Agent Engine

*The automation muscle — orchestration, parallelism, safety rails.*

| Skill | What it does |
|---|---|
| `agent-harness` | Build larger projects using agent harnesses — orchestrator + worker patterns, task queues, and structured handoffs between Claude instances. |
| `agent-teams` | Parallelization techniques — agent teams, stochastic consensus, debate patterns, and multi-agent problem solving with Claude Code. |
| `agentic-harness` | Agentic harness engineering — the model is the brain (rented), the harness is the body (owned). Covers the agent loop, harness anatomy, content forge pattern, voice-reviewer agent, handoff prompts, and the build-with-frontier/execute-with-open-source strategy. |
| `always-on-agents` | Always-on agentic OS — running 3 AI agents 24/7 for 30 days. Covers the complete stack: CLAUDE.md for persistent memory, MCP for tool connections, and a setup you can build in under 30 minutes. |
| `autoresearch` | Karpathy-style auto-research loop — Claude autonomously researches a topic, generates hypotheses, tests them, and iteratively improves its own knowledge base. |
| `browser-automation` | Browser automation with Claude Code — choosing between Playwright, Browser Use, Computer Use, and browser-cdp based on the task type. |
| `claude-managed-agents` | Claude Managed Agents — Anthropic-hosted agent runtime. Covers the three core concepts (agent/environment/session), production checklist, four build steps, secrets management, scheduling, and cost breakdown. |
| `claude-security` | Security practices for Claude Code projects — auto-mode classifier, OAuth, permission scoping, secrets management, and protecting against prompt injection. |
| `human-validation` | Human-validation zones — structured checkpoints in agentic workflows where a human must review before the AI continues. The pattern that makes autonomous agents safe to run on real work. |
| `n8n-vs-mcp` | n8n vs MCP decision guide — when to use visual workflow automation (n8n) vs native AI tool connections (MCP), and how Claude/Hermes fit as no-code workflow builders. |
| `paperclip-teams` | Paperclip-orchestrated agent teams — run a lead orchestrator that coordinates multiple specialized sub-agents using local or free Claude Code instances for complex multi-step work. |

### 💼 Business Launchpad

*Turning the brain into revenue — the LLC, client sites, and service lines.*

| Skill | What it does |
|---|---|
| `buildpartner` | BuildPartner — AI-accelerated product development tool built on Claude Code. Covers the 10x speed methodology, how it pairs with Claude Code, and when to use it vs. building directly with the CLI. |
| `claude-cms` | Build a client-handoff website with a built-in CMS using Claude Code — blueprint extractor, one-shot build, safety layer, MongoDB Atlas backend, Vercel deployment. Clients edit their own site without touching code or touching you. |
| `claude-freelance` | Sell Claude Code builds as a $5,000 local business service — the pricing model, client pitch, WordPress workflow, and agency economics. Build in 2 hours what used to take 2 weeks. |
| `claude-seo` | Claude SEO — 12 open-source Claude Code skills that replace a $5–10K/month SEO agency stack. Covers parallel SEO audits, health scores, PDF reports, schema markup, GEO (AI search optimization), sitemap, hreflang, and competitor analysis. One install command. |
| `ghl-automation` | Automate GoHighLevel with Claude Code via the GHL CLI — build triggers, conditions, and email sequences in plain English without ever opening the GHL dashboard. Full workflow automation through prompts. |
| `hermes-oracle` | Hermes Oracle — one-click SEO blog post publishing. Pulls trending news from Twitter/X, generates SEO-optimized content, and publishes to WordPress automatically. |
| `lovable-ai` | Lovable AI — prompt-to-app builder. Describe a web app in plain English, get a working full-stack app deployed in minutes. Covers the build loop, tech stack, GitHub sync, and when to use Lovable vs Claude Code. |
| `premium-website` | Build a $10,000-quality website with Claude Code — the 8-pillar checklist, design skills setup, reference-based prompting, imagery, polish passes, and live deployment. No coding, no templates, no generic AI look. |
| `vibe-coding` | Vibe Coding Incubator — AI-first developer training. Build real apps with LLMs, prompting patterns, and agentic workflows from idea to deployed product. Covers the core methodology and how it pairs with Claude Code. |

### 🛠️ Repo Maintenance

*Keeping the repository itself healthy and consistent.*

| Skill | What it does |
|---|---|
| `add-entry` | Add a new tool or resource entry to README.md in the correct format |
| `review` | Write-review-fix loop for a shell script or the current branch's changed .sh files |

### 🗡️ Tool Arsenal

| Category | Subcategories | Tools |
|---|---|---|
| CLI Tools | 5 | 29 |
| Web Tools | 8 | 28 |
| Manuals/Howtos/Tutorials | 4 | 26 |
| Blogs | 0 | 9 |
| Systems/Services | 3 | 4 |
| Monitoring/Observability | 2 | 9 |
| DevOps & Cloud | 5 | 22 |
| Infrastructure | 4 | 13 |
| Security | 4 | 21 |
| One-liners | 0 | 2 |
| Lists | 0 | 4 |
| Other | 0 | 13 |

<!-- END GENERATED: skill-catalog -->

---

## 🗺️ Roadmap — from repo to living Jarvis

The canonical, tickable version lives in `vault/Roadmap.md` and renders as a live
checklist in the Z.E.R.O. console (your ticks persist in the browser).

- [x] **Phase 0 — Collect**: skills and tools gathered
- [x] **Phase 1 — Index**: everything visible and searchable
- [x] **Phase 2 — Vault**: the Obsidian mind map, generated from the repo
- [x] **Phase 3 — Console**: Z.E.R.O. running over the same data, offline-capable
- [ ] **Phase 4 — Desktop foundation**: clean folder structure (see `workspace-org`)
- [ ] **Phase 5 — Live memory**: wire `obsidian-memory` to `vault/` as the permanent store
- [ ] **Phase 6 — Voice**: `hermes-jarvis` + `wispr-flow` — talk to the brain
- [ ] **Phase 7 — Always on**: `always-on-agents` + `morning-brief` running daily
- [ ] **Phase 8 — Multi-model**: route each task to the best model
- [ ] **Phase 9 — Business**: LLC launch — `claude-freelance` offer, `premium-website` + `claude-cms` delivery, `claude-seo` + `ghl-automation` services

---

## 🔍 Quick-find cheatsheet

- *"How do I remember things between sessions?"* → `obsidian-memory`
- *"How do I talk to it?"* → `hermes-jarvis`, `wispr-flow`
- *"How do I make money with it?"* → `claude-freelance`, `premium-website`, `claude-seo`
- *"How do I keep it safe?"* → `claude-security`, `human-validation`
- *"How do I teach it something new?"* → `hermes-learn`, `skill-generator`
- *"Where are the curated tools?"* → `README.md`, or search the Z.E.R.O. console
- *"Where's the mind map?"* → `vault/Home.md`, opened in Obsidian
