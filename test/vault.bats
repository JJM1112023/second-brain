#!/usr/bin/env bats
# Tests for scripts/check-vault.sh — the integrity gate over the generated
# Obsidian vault. Each test builds a throwaway repo containing a minimal vault
# plus the real checker, breaks exactly one thing, and asserts the gate fires.

load test_helper

setup() {
  common_setup
  FIXTURE="${TEST_TMP}/fixture"
  mkdir -p "${FIXTURE}/scripts" "${FIXTURE}/vault/Pillars" "${FIXTURE}/vault/Skills"

  cp "${REPO_ROOT}/scripts/check-vault.sh" "${FIXTURE}/scripts/"

  # A tiny but structurally valid vault: Home → Pillar → Skill, all linked.
  cat > "${FIXTURE}/vault/Home.md" <<'EOF'
---
title: Home
tags:
  - moc
---

# Home

- [[Test Pillar]]
- [[Roadmap]]
- [[Repo Map]]
EOF

  cat > "${FIXTURE}/vault/Roadmap.md" <<'EOF'
---
title: Roadmap
---

Up: [[Home]]
EOF

  cat > "${FIXTURE}/vault/Repo Map.md" <<'EOF'
---
title: Repo Map
---

Up: [[Home]]
EOF

  cat > "${FIXTURE}/vault/README.md" <<'EOF'
# Vault

Generated. A literal `[[wikilink]]` in a code span must not be resolved.
See [[Home]].
EOF

  cat > "${FIXTURE}/vault/Pillars/Test Pillar.md" <<'EOF'
---
title: Test Pillar
tags:
  - pillar
---

Up: [[Home]] · [[demo-skill]]
EOF

  cat > "${FIXTURE}/vault/Skills/demo-skill.md" <<'EOF'
---
title: demo-skill
tags:
  - skill
---

Pillar: [[Test Pillar]]
EOF

  # The manifest marks which notes the generator owns. Structural rules apply
  # to these; anything else in the vault belongs to the user.
  cat > "${FIXTURE}/vault/.generated" <<'EOF'
# Files owned by scripts/gen_secondbrain.py.
Home.md
Roadmap.md
Repo Map.md
README.md
Pillars/Test Pillar.md
Skills/demo-skill.md
EOF

  # The checker's last step shells out to the generator; stub it so these
  # tests exercise link/frontmatter/reachability logic in isolation.
  mkdir -p "${FIXTURE}/scripts"
  cat > "${FIXTURE}/scripts/gen_secondbrain.py" <<'EOF'
#!/usr/bin/env python3
import sys
print("stub generator: up to date")
sys.exit(0)
EOF
}

teardown() { common_teardown; }

run_check() {
  run bash -c "cd '${FIXTURE}' && bash scripts/check-vault.sh"
}

@test "check-vault: passes on a well-formed vault" {
  run_check
  [ "$status" -eq 0 ]
  [[ "$output" == *"vault OK"* ]]
  [[ "$output" == *"all checks passed"* ]]
}

@test "check-vault: ignores wikilinks inside code spans" {
  run_check
  [ "$status" -eq 0 ]
  [[ "$output" != *"broken wikilink [[wikilink]]"* ]]
}

@test "check-vault: fails when a wikilink points at a missing note" {
  printf '\nSee [[Ghost Note]]\n' >> "${FIXTURE}/vault/Home.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"broken wikilink [[Ghost Note]]"* ]]
}

@test "check-vault: fails when a GENERATED note has no frontmatter" {
  printf '# Loose\n\n[[Home]]\n' > "${FIXTURE}/vault/Skills/loose.md"
  printf 'Skills/loose.md\n' >> "${FIXTURE}/vault/.generated"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing YAML frontmatter"* ]]
}

@test "check-vault: fails when a GENERATED note has no title" {
  printf -- '---\ntags:\n  - skill\n---\n\n[[Home]]\n' > "${FIXTURE}/vault/Skills/untitled.md"
  printf 'Skills/untitled.md\n' >> "${FIXTURE}/vault/.generated"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"frontmatter has no title"* ]]
}

@test "check-vault: fails when a GENERATED note is unreachable from Home" {
  printf -- '---\ntitle: Island\n---\n\nNothing links here.\n' > "${FIXTURE}/vault/Skills/island.md"
  printf 'Skills/island.md\n' >> "${FIXTURE}/vault/.generated"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"unreachable from Home.md"* ]]
}

@test "check-vault: your own unlinked note is reported, not failed on" {
  printf -- '---\ntitle: Scratch\n---\n\nMy own unlinked thinking.\n' > "${FIXTURE}/vault/Scratch.md"
  run_check
  [ "$status" -eq 0 ]
  [[ "$output" == *"of your own notes are not linked"* ]]
  [[ "$output" == *"vault/Scratch.md"* ]]
}

@test "check-vault: your own note may skip frontmatter" {
  printf 'Just a plain note, no frontmatter. [[Home]]\n' > "${FIXTURE}/vault/Plain.md"
  run_check
  [ "$status" -eq 0 ]
}

@test "check-vault: broken links are caught in your notes too" {
  printf -- '---\ntitle: Mine\n---\n\n[[Home]] and [[Nowhere]]\n' > "${FIXTURE}/vault/Mine.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"broken wikilink [[Nowhere]]"* ]]
}

@test "check-vault: backlinks count toward reachability" {
  # Only linked *from* the island note, never *to* it — still reachable.
  printf -- '---\ntitle: Island\n---\n\n[[Home]]\n' > "${FIXTURE}/vault/Skills/island.md"
  run_check
  [ "$status" -eq 0 ]
}

@test "check-vault: fails when a required note is missing" {
  rm "${FIXTURE}/vault/Roadmap.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing required note: vault/Roadmap.md"* ]]
}

@test "check-vault: fails when the vault does not exist" {
  rm -rf "${FIXTURE}/vault"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"vault/ does not exist"* ]]
}

@test "check-vault: surfaces generator drift" {
  cat > "${FIXTURE}/scripts/gen_secondbrain.py" <<'EOF'
#!/usr/bin/env python3
import sys
print("second brain is out of date. Run: python3 scripts/gen_secondbrain.py")
sys.exit(1)
EOF
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"out of date"* ]]
}
