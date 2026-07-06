# 🧠 Second Brain Index — Jarvis Command Center

> **Owner:** John Maguire · **Mission:** An Obsidian-styled, Jarvis-based second brain — every skill and tool cataloged, searchable, and ready to power the LLC, websites, and digital services.

This file is the **master map** of everything in this repository. When you (or any AI assistant) need to know *"where is X and what does it do?"* — start here.

---

## 📍 How this repo fits the mission

| Piece | Where it lives | What it is |
|---|---|---|
| **Tool library** | `README.md` | 182 curated tools/resources (CLI, web, security, tutorials) |
| **Skill library** | `.claude/skills/` | 30 reusable AI workflows you've built |
| **This index** | `SECOND_BRAIN_INDEX.md` | The map that ties it all together |
| **AI operating rules** | `CLAUDE.md` | How assistants must behave in this repo |

---

## 🗂️ Skill Catalog — organized by pillar

### Pillar 1: 🧠 Memory & Second Brain (the core)

| Skill | What it does | Use it when |
|---|---|---|
| `obsidian-memory` | Persistent memory layer using Obsidian + NotebookLM MCP — knowledge survives across AI sessions | Setting up the vault; storing/retrieving anything long-term |
| `advanced-claude-md` | CLAUDE.md structure, imports, rules hierarchy — the assistant's "personality file" | Tuning how your AI remembers and behaves |
| `workspace-org` | Session naming, worktrees, project separation, context hygiene | Organizing personal vs. business vs. client work |
| `hermes-learn` | Teach the AI a new workflow from any URL/PDF/doc → saved as a reusable skill | Capturing new knowledge into the brain |
| `skill-generator` | Meta-skill: generates new skills from video descriptions/articles automatically | Scaling knowledge capture |

### Pillar 2: 🎙️ Jarvis Interface (voice & daily ops)

| Skill | What it does | Use it when |
|---|---|---|
| `hermes-jarvis` | The Jarvis voice orb UI (localhost:3737/hermes) — realtime voice, wake word, briefings | Talking to your second brain |
| `wispr-flow` | System-wide voice-to-text for dictating into any app, including Claude Code | Hands-free everything (huge for a hands-on learner) |
| `morning-brief` | Automated daily summary: news, calendar, tasks, emails, market data | Starting every day organized |
| `agent-os` | The full Agent Operating System web UI — agent roster, orchestration, navigation | Running the whole system from one dashboard |

### Pillar 3: 🤖 Agent Engine (automation muscle)

| Skill | What it does | Use it when |
|---|---|---|
| `always-on-agents` | 3 agents running 24/7 — CLAUDE.md memory + MCP + 30-min setup | Making the brain work while you sleep |
| `agent-harness` | Orchestrator + worker patterns, task queues, structured handoffs | Building bigger multi-step projects |
| `agentic-harness` | "Model is the brain (rented), harness is the body (owned)" — agent loop anatomy | Understanding/owning your agent stack |
| `agent-teams` | Parallel agents, consensus, debate patterns | Splitting big jobs across multiple AIs |
| `paperclip-teams` | Lead orchestrator coordinating specialized sub-agents | Complex multi-step work on a budget |
| `claude-managed-agents` | Anthropic-hosted agent runtime — scheduling, secrets, production checklist | Running agents in the cloud reliably |
| `browser-automation` | Choosing Playwright vs. Browser Use vs. Computer Use per task | Automating anything in a browser |
| `autoresearch` | Self-improving research loop — hypothesize, test, iterate | Deep research on autopilot |
| `n8n-vs-mcp` | Decision guide: visual workflows (n8n) vs. native AI tools (MCP) | Choosing the right automation plumbing |
| `human-validation` | Checkpoints where a human must approve before the AI continues | Keeping autonomous agents safe on real work |
| `claude-security` | Permission scoping, secrets management, prompt-injection defense | Locking the system down |

### Pillar 4: 💼 Business Launchpad (the LLC & digital services)

| Skill | What it does | Use it when |
|---|---|---|
| `claude-freelance` | The $5,000 local-business website service — pricing, pitch, economics | Defining your service offer |
| `premium-website` | $10K-quality website build: 8-pillar checklist, design, deployment | Delivering flagship client sites |
| `claude-cms` | Client-handoff sites with built-in CMS (MongoDB/Vercel) — clients edit themselves | Recurring-revenue website product |
| `claude-seo` | 12-skill SEO stack replacing a $5–10K/month agency — audits, reports, GEO | SEO as a service line |
| `ghl-automation` | GoHighLevel automation via plain English — triggers, emails, workflows | Marketing automation for clients |
| `buildpartner` | AI-accelerated product development methodology | Structuring client builds |
| `lovable-ai` | Prompt-to-app builder — full-stack apps in minutes | Rapid prototypes and MVPs |
| `vibe-coding` | AI-first developer training — idea to deployed product | Leveling up your own build skills |
| `hermes-oracle` | One-click SEO blog publishing from trending news → WordPress | Content marketing on autopilot |

### Pillar 5: 🛠️ Repo Maintenance

| Skill | What it does | Use it when |
|---|---|---|
| `add-entry` | Adds a tool to README.md in the correct format | Growing the tool library |

---

## 🗺️ Roadmap — from repo to living Jarvis

- [x] **Phase 0 — Collect**: 30 skills + 182 tools gathered *(done — this took the "massive amounts of time" and it was worth it)*
- [x] **Phase 1 — Index**: this file — everything visible and searchable
- [ ] **Phase 2 — Prune**: review the catalog above, mark anything dead, remove deliberately
- [ ] **Phase 3 — Desktop foundation**: finish Claude Code login on the new computer; clean folder structure (see `workspace-org`)
- [ ] **Phase 4 — Vault**: install Obsidian; wire up `obsidian-memory` as the permanent knowledge store
- [ ] **Phase 5 — Voice**: `hermes-jarvis` + `wispr-flow` — talk to the brain
- [ ] **Phase 6 — Always on**: `always-on-agents` + `morning-brief` running daily
- [ ] **Phase 7 — Multi-model**: add Grok, Perplexity, ChatGPT, Manus as workflow models (route each task to the best model)
- [ ] **Phase 8 — Business**: LLC launch — `claude-freelance` offer, `premium-website` + `claude-cms` delivery, `claude-seo` + `ghl-automation` services

---

## 🔍 Quick-find cheatsheet

- *"How do I remember things between sessions?"* → `obsidian-memory`
- *"How do I talk to it?"* → `hermes-jarvis`, `wispr-flow`
- *"How do I make money with it?"* → `claude-freelance`, `premium-website`, `claude-seo`
- *"How do I keep it safe?"* → `claude-security`, `human-validation`
- *"How do I teach it something new?"* → `hermes-learn`, `skill-generator`
- *"Where are the 182 tools?"* → `README.md`
