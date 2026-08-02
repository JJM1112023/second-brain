#!/usr/bin/env python3
"""Tests for scripts/gen_secondbrain.py — the second-brain generator.

Covers the parts that silently rot if they break: README/SKILL parsing, the
pillar mapping, determinism (CI's `--check` gate depends on it), the two
brain payloads staying byte-identical, and stale-note cleanup.

No third-party dependencies. Run from anywhere:

    python3 test/gen_secondbrain_test.py
"""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GENERATOR = REPO_ROOT / "scripts" / "gen_secondbrain.py"

sys.path.insert(0, str(REPO_ROOT / "scripts"))
import gen_secondbrain as gen  # noqa: E402


class Failures(list):
    def check(self, label, condition, detail=""):
        if condition:
            print(f"  PASS  {label}")
        else:
            print(f"  FAIL  {label}{(' — ' + detail) if detail else ''}")
            self.append(label)


def test_parsing(f: Failures) -> None:
    print("— parsing —")
    model = gen.build_model()

    f.check("skills discovered", model["counts"]["skills"] > 0,
            str(model["counts"]["skills"]))
    f.check("every skill has a description",
            all(s["description"] for s in model["skills"]),
            ", ".join(s["slug"] for s in model["skills"] if not s["description"]))
    f.check("every skill maps to a real SKILL.md",
            all((REPO_ROOT / s["path"]).is_file() for s in model["skills"]))
    f.check("PILLARS references no phantom skills", not model["missing"],
            ", ".join(model["missing"]))
    f.check("every skill belongs to exactly one pillar",
            sorted(s["slug"] for p in model["pillars"] for s in p["skills"])
            == sorted(s["slug"] for s in model["skills"]))

    f.check("README categories parsed", model["counts"]["categories"] > 0,
            str(model["counts"]["categories"]))
    f.check("README tools parsed", model["counts"]["tools"] > 0,
            str(model["counts"]["tools"]))
    f.check("every tool has an absolute URL",
            all(
                t["url"].startswith(("http://", "https://"))
                for c in model["categories"]
                for s in c["subcategories"]
                for t in s["tools"]
            ))
    f.check("tool count matches README entry lines",
            model["counts"]["tools"]
            == sum(
                1
                for line in (REPO_ROOT / "README.md").read_text(encoding="utf-8").splitlines()
                if gen.ENTRY_RE.match(line)
            ))
    f.check("synthetic subcategories excluded from the count",
            model["counts"]["subcategories"]
            == sum(
                1
                for line in (REPO_ROOT / "README.md").read_text(encoding="utf-8").splitlines()
                if line.startswith("##### ")
            ))
    f.check("HTML entities decoded in category names",
            not any("&amp;" in c["name"] for c in model["categories"]))


def test_note_titles(f: Failures) -> None:
    print("— note titles —")
    f.check("path separators stripped from titles",
            gen.safe_title("Manuals/Howtos/Tutorials") == "Manuals · Howtos · Tutorials")
    f.check("obsidian-reserved characters stripped",
            "#" not in gen.safe_title("A#B") and "|" not in gen.safe_title("A|B"))
    f.check("ampersands survive", gen.safe_title("DevOps & Cloud") == "DevOps & Cloud")


def test_outputs(f: Failures) -> None:
    print("— generated outputs —")
    model = gen.build_model()
    outputs = gen.collect_outputs(model)

    f.check("vault notes emitted",
            sum(1 for p in outputs if p.suffix == ".md") > 20)
    f.check("brain.json emitted", gen.BRAIN_JSON in outputs)
    f.check("brain-data.js emitted", gen.BRAIN_JS in outputs)

    payload = json.loads(outputs[gen.BRAIN_JSON])
    wrapped = outputs[gen.BRAIN_JS]
    f.check("brain-data.js wraps the identical payload",
            wrapped.endswith(";\n")
            and json.loads(wrapped.split("window.__BRAIN__ = ", 1)[1].rstrip(";\n")) == payload)

    ids = [n["id"] for n in payload["nodes"]]
    f.check("node ids unique", len(ids) == len(set(ids)))
    f.check("every edge endpoint resolves",
            all(e["s"] in set(ids) and e["t"] in set(ids) for e in payload["edges"]))
    f.check("every tool points at a real node",
            all(t["node"] in set(ids) for t in payload["tools"]))
    f.check("counts agree with the model", payload["counts"] == model["counts"])
    f.check("roadmap present", len(payload["roadmap"]) > 0)

    home = outputs[gen.VAULT / "Home.md"]
    f.check("Home links every pillar",
            all(f"[[{gen.safe_title(p['name'])}]]" in home for p in model["pillars"]))

    f.check("SECOND_BRAIN_INDEX keeps its generated markers",
            gen.GEN_BEGIN in outputs[gen.INDEX_MD]
            and gen.GEN_END in outputs[gen.INDEX_MD])
    f.check("index block is spliced, not appended twice",
            outputs[gen.INDEX_MD].count(gen.GEN_BEGIN) == 1)


def test_determinism(f: Failures) -> None:
    print("— determinism —")
    first = {str(p): c for p, c in gen.collect_outputs(gen.build_model()).items()}
    second = {str(p): c for p, c in gen.collect_outputs(gen.build_model()).items()}
    f.check("two runs produce identical bytes", first == second)


def test_cli(f: Failures) -> None:
    print("— CLI behaviour —")
    check = subprocess.run(
        [sys.executable, str(GENERATOR), "--check"],
        capture_output=True, text=True, cwd=REPO_ROOT,
    )
    f.check("--check passes against the committed tree",
            check.returncode == 0, check.stdout.strip() + check.stderr.strip())

    # --check must actually detect drift, and must not write anything.
    with tempfile.TemporaryDirectory() as tmp:
        clone = Path(tmp) / "repo"
        shutil.copytree(
            REPO_ROOT, clone,
            ignore=shutil.ignore_patterns(".git", "node_modules", "log"),
        )
        target = clone / "vault" / "Home.md"
        original = target.read_text(encoding="utf-8")
        target.write_text(original + "\ntampered\n", encoding="utf-8")

        drift = subprocess.run(
            [sys.executable, "scripts/gen_secondbrain.py", "--check"],
            capture_output=True, text=True, cwd=clone,
        )
        f.check("--check detects a tampered note", drift.returncode == 1)
        f.check("--check reports the changed path", "Home.md" in drift.stdout)
        f.check("--check writes nothing",
                target.read_text(encoding="utf-8") == original + "\ntampered\n")

        # A regenerate must repair the tampered note, sweep away notes it used
        # to own, and leave everything it never owned strictly alone.
        manifest = clone / "vault" / ".generated"
        stale = clone / "vault" / "Skills" / "deleted-skill.md"
        stale.write_text("---\ntitle: gone\n---\n", encoding="utf-8")
        manifest.write_text(
            manifest.read_text(encoding="utf-8") + "Skills/deleted-skill.md\n",
            encoding="utf-8",
        )

        mine = clone / "vault" / "My Note.md"
        mine.write_text("---\ntitle: My Note\n---\n\n[[Home]]\n", encoding="utf-8")
        workspace = clone / "vault" / ".obsidian" / "workspace.json"
        workspace.write_text('{"main":{}}', encoding="utf-8")

        regen = subprocess.run(
            [sys.executable, "scripts/gen_secondbrain.py"],
            capture_output=True, text=True, cwd=clone,
        )
        f.check("regenerate succeeds", regen.returncode == 0, regen.stderr.strip())
        f.check("regenerate restores the tampered note",
                target.read_text(encoding="utf-8") == original)
        f.check("regenerate sweeps notes it used to own", not stale.exists())
        f.check("regenerate keeps the user's own notes", mine.exists())
        f.check("regenerate keeps Obsidian workspace state", workspace.exists())
        f.check("manifest lists only generated files",
                "My Note.md" not in manifest.read_text(encoding="utf-8"))

        after = subprocess.run(
            [sys.executable, "scripts/gen_secondbrain.py", "--check"],
            capture_output=True, text=True, cwd=clone,
        )
        f.check("--check passes after regenerate", after.returncode == 0,
                after.stdout.strip())


def main() -> int:
    failures = Failures()
    test_parsing(failures)
    test_note_titles(failures)
    test_outputs(failures)
    test_determinism(failures)
    test_cli(failures)

    print()
    if failures:
        print(f"gen_secondbrain tests FAILED ({len(failures)}): " + "; ".join(failures))
        return 1
    print("gen_secondbrain tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
