#!/usr/bin/env python3
"""Compare ecology behaviour of the current checkout against a base git ref.

Builds the headless Swift world simulator for HEAD and for the base ref (in a
temporary git worktree), runs every scenario in Tests/Simulation/scenarios with
both, and reports whether world state, event log and samples are identical.

    python3 Tests/Simulation/diff_base.py                      # base = fork point with origin/main
    python3 Tests/Simulation/diff_base.py --base <ref>
    python3 Tests/Simulation/diff_base.py --require-identical  # exit 1 on any difference

The report is printed, written to build/simulation/behavior-diff.md and, on
GitHub Actions, appended to the job summary.
"""
import argparse
import json
import os
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "simulation" / "diff"
METRICS = ["population", "eggs", "nests", "deaths", "migrations", "births"]


def git(*args, cwd=ROOT, check=True):
    result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    if check and result.returncode != 0:
        raise SystemExit(f"git {' '.join(args)} failed:\n{result.stderr}")
    return result.stdout.strip()


def resolve_base(requested):
    if requested:
        ref = requested
    elif os.environ.get("GITHUB_BASE_REF"):
        ref = "origin/" + os.environ["GITHUB_BASE_REF"]
    else:
        ref = "origin/main"
    head = git("rev-parse", "HEAD")
    target = git("rev-parse", ref)
    fork = git("merge-base", "HEAD", target, check=False) or target
    if fork == head:
        # We are on the base branch itself (e.g. a push to main): compare with the parent commit.
        parent = git("rev-parse", "HEAD~1", check=False)
        if parent:
            return parent, f"{ref} (HEAD is on it; comparing with parent)"
    return fork, ref


def build_sim(source_root, output):
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["swiftc", "-O",
         str(source_root / "Sources" / "World.swift"),
         str(source_root / "Tests" / "Simulation" / "main.swift"),
         "-o", str(output)],
        check=True,
    )


def run_sim(binary, scenario_path, output_path):
    result = subprocess.run([str(binary), str(scenario_path), str(output_path)], capture_output=True, text=True)
    if result.returncode != 0:
        return None, (result.stderr or result.stdout).strip()[-400:]
    return json.loads(output_path.read_text()), None


def first_event_difference(a, b):
    for index, (x, y) in enumerate(zip(a, b)):
        if x != y:
            return index, x, y
    if len(a) != len(b):
        index = min(len(a), len(b))
        return index, (a[index] if index < len(a) else None), (b[index] if index < len(b) else None)
    return None


def describe_event(event):
    if event is None:
        return "(none)"
    return f"t={event.get('timestamp')} {event.get('trigger')} {event.get('previous')}→{event.get('new')} @{event.get('location')}"


def format_metric(base, head):
    if base == head:
        return f"{base:g}"
    return f"{base:g} → **{head:g}**"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base", help="git ref to compare against (default: fork point with origin/main)")
    parser.add_argument("--require-identical", action="store_true", help="fail if any scenario differs")
    args = parser.parse_args()

    base_sha, base_label = resolve_base(args.base)
    head_sha = git("rev-parse", "HEAD")
    worktree = ROOT / "build" / "base-src"
    if worktree.exists():
        git("worktree", "remove", "--force", str(worktree), check=False)
        shutil.rmtree(worktree, ignore_errors=True)
    git("worktree", "prune")
    git("worktree", "add", "--detach", str(worktree), base_sha)

    try:
        head_bin = ROOT / "build" / "world-sim-head"
        base_bin = ROOT / "build" / "world-sim-base"
        build_sim(ROOT, head_bin)
        build_sim(worktree, base_bin)

        OUT.mkdir(parents=True, exist_ok=True)
        rows = []
        differing = 0
        for scenario_path in sorted((ROOT / "Tests" / "Simulation" / "scenarios").glob("*.json")):
            name = scenario_path.stem
            head, head_error = run_sim(head_bin, scenario_path, OUT / f"{name}-head.json")
            base, base_error = run_sim(base_bin, scenario_path, OUT / f"{name}-base.json")
            if head_error:
                raise SystemExit(f"HEAD simulator failed on {name}: {head_error}")
            if base_error:
                rows.append((name, "new / unsupported on base", "", "—"))
                continue
            same = all(head[key] == base[key] for key in ("world", "eventLog", "samples"))
            metrics = " · ".join(
                f"{key} {format_metric(base['metrics'][key], head['metrics'][key])}" for key in METRICS
            )
            if same:
                rows.append((name, "identical", metrics, ""))
                continue
            differing += 1
            diff = first_event_difference(base["eventLog"], head["eventLog"])
            if diff:
                index, before, after = diff
                where = f"event #{index}: base `{describe_event(before)}` / head `{describe_event(after)}`"
            else:
                where = "event log identical; world state or samples differ"
            rows.append((name, "**differs**", metrics, where))

        lines = [
            "## Ecology behaviour vs base",
            "",
            f"Base: `{base_sha[:10]}` ({base_label}) · Head: `{head_sha[:10]}` · Swift headless simulator, same host.",
            "",
            "| Scenario | Result | Metrics (base → head) | First difference |",
            "| --- | --- | --- | --- |",
        ]
        lines += [f"| {name} | {result} | {metrics} | {where} |" for name, result, metrics, where in rows]
        lines += ["", f"{differing} scenario(s) differ." if differing else "All scenarios identical to base."]
        report = "\n".join(lines) + "\n"

        print(report)
        (ROOT / "build" / "simulation" / "behavior-diff.md").write_text(report)
        summary = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary:
            with open(summary, "a") as handle:
                handle.write(report)
            # Also as an annotation, so the report is readable through the API.
            escaped = report.replace("%", "%25").replace("\r", "").replace("\n", "%0A")
            level = "warning" if differing else "notice"
            print(f"::{level} title=Ecology behaviour vs base::{escaped}")

        if args.require_identical and differing:
            sys.exit(1)
    finally:
        git("worktree", "remove", "--force", str(worktree), check=False)


if __name__ == "__main__":
    main()
