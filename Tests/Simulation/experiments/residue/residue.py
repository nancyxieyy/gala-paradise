#!/usr/bin/env python3
"""Run the preregistered 60-cell residue experiment without importing run.py.

Full per-engine inputs/outputs go to build/simulation/residue. The committed
evidence contains every cell's metrics, lossless count traces, event tallies,
source hashes and deterministic output hashes. No product parameters change.
"""

import collections
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[4]
SCENARIOS = Path(__file__).resolve().parent
OUT = ROOT / "build/simulation/residue"
SEEDS = [7, 19, 42, 73, 101]
DOSES = [0, 10, 20, 26, 30]
FIELDS = ("world", "eventLog", "samples", "capacityEvidence")
COUNT_COLUMNS = ["total", "living", "eggs", "matureEggs", "corpses", "stains", "nests"]
DOTNET = (os.environ.get("GALA_DOTNET") or shutil.which("dotnet")
          or str(ROOT / "build/toolchain/dotnet/dotnet"))
ENGINES = {
    "swift": [str(OUT / "world-sim")],
    "cs": [DOTNET, str(ROOT / "Tests/Simulation/bin/Release/net10.0/Simulation.dll")],
}


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def command(args):
    return subprocess.check_output(args, cwd=ROOT, text=True, stderr=subprocess.STDOUT)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n")


def load(path):
    return json.loads(path.read_text())


def equal(left, right, path="root"):
    """Use run.py's numeric tolerance, while rejecting shape/text differences."""
    if isinstance(left, bool) or isinstance(right, bool):
        require(type(left) is type(right) and left == right, path)
    elif isinstance(left, (int, float)) and isinstance(right, (int, float)):
        require(math.isclose(left, right, rel_tol=1e-10, abs_tol=1e-10), path)
    elif isinstance(left, dict) and isinstance(right, dict):
        require(left.keys() == right.keys(), path + ": keys")
        for key in left:
            equal(left[key], right[key], path + "/" + key)
    elif isinstance(left, list) and isinstance(right, list):
        require(len(left) == len(right), path + ": length")
        for index, (a, b) in enumerate(zip(left, right)):
            equal(a, b, path + f"/{index}")
    elif left != right:
        try:
            same = math.isclose(float(left), float(right), rel_tol=1e-10, abs_tol=1e-10)
        except (ValueError, TypeError):
            same = False
        require(same, path + f": {left!r} != {right!r}")


def deterministic(output):
    data = copy.deepcopy(output)
    data["metrics"].pop("elapsedMs", None)
    return data


def digest(value):
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return hashlib.sha256(encoded).hexdigest()


def run(engine, scenario, tag):
    source = OUT / f"{tag}-input.json"
    target = OUT / f"{tag}-{engine}.json"
    save(source, scenario)
    command(ENGINES[engine] + [str(source), str(target)])
    return load(target)


def run_pair(scenario, tag):
    left = run("swift", scenario, tag)
    right = run("cs", scenario, tag)
    for field in FIELDS:
        equal(left[field], right[field], tag + "/" + field)
    equal(deterministic(left)["metrics"], deterministic(right)["metrics"], tag + "/metrics")
    return left, right


def metrics(output):
    world = output["world"]
    events = output["eventLog"]
    observed = output["capacityEvidence"]
    stages = collections.Counter(c["stage"] for c in world["creatures"])
    result = {
        "living": sum(stages[s] for s in ("adult", "baby", "gold")),
        "eggLayingEvents": sum(e["trigger"] == "fertility" for e in events),
        "hatchEvents": sum(e["trigger"] == "incubation" for e in events),
        "births": world["births"],
        "firstAt32": observed["firstAt32"],
        "matureEggSeconds": observed["matureEggSeconds"],
        "matureEggWallSeconds": observed["matureEggWallSeconds"],
        "nests": sum(h["nest"] for h in world["habitats"]),
        "deaths": world["deaths"],
        "eggs": stages["egg"],
        "corpses": stages["corpse"],
        "stains": stages["stain"],
        "total": len(world["creatures"]),
        "removedCorpses": sum(e["trigger"] == "vacuum" and e["previous"] == "corpse" for e in events),
    }
    return result


def validate_trace(output, scenario):
    """Independently integrate the compressed trace, including endpoint rules."""
    evidence = output["capacityEvidence"]
    trace = evidence["observations"]
    start = scenario.get("initial", {}).get("time", 0)
    require(trace and trace[0]["firstTime"] == start, "missing initial observation")
    expected = start
    egg_seconds = wall_seconds = 0
    first = -1
    for span in trace:
        a, b, counts = span["firstTime"], span["lastTime"], span["counts"]
        require(a == expected and b >= a and (b - a) % 2 == 0, "trace continuity")
        require(len(counts) == len(COUNT_COLUMNS), "trace shape")
        require(counts[0] == sum(counts[i] for i in (1, 2, 4, 5)), "trace stage partition")
        ticks = int((b - a) / 2) + 1 - (1 if a == start else 0)
        egg_seconds += ticks * 2 * counts[3]
        wall_seconds += ticks * 2 * (counts[3] > 0)
        if first < 0 and counts[0] >= 32:
            first = a
        expected = b + 2
    require(trace[-1]["lastTime"] == start + scenario["duration"], "trace end")
    require(egg_seconds == evidence["matureEggSeconds"], "egg-second integral")
    require(wall_seconds == evidence["matureEggWallSeconds"], "wall-second integral")
    require(first == evidence["firstAt32"], "first threshold crossing")
    result = metrics(output)
    mature = sum(c["stage"] == "egg" and c["age"] >= 180 for c in output["world"]["creatures"])
    expected_counts = [result["total"], result["living"], result["eggs"], mature,
                       result["corpses"], result["stains"], result["nests"]]
    require(trace[-1]["counts"] == expected_counts, "final observation")
    require(result["births"] == result["eggLayingEvents"] + 2 * result["hatchEvents"],
            "births must include eggs and two juveniles per hatch")


def framework_checks():
    fixture = {
        "name": "cleanup-fixture", "seed": 7, "duration": 8,
        "habitats": [{"id": "nest"}], "actions": [],
        "creatures": [{"stage": s, "location": "nest"} for s in
                      ("adult", "corpse", "corpse", "stain")],
    }
    keep, _ = run_pair(fixture, "check-omitted")
    for disabled in (None, 0, -1):
        other, _ = run_pair(dict(fixture, removeCorpsesEvery=disabled), f"check-disabled-{disabled}")
        equal(deterministic(keep), deterministic(other), "omitted/disabled interval")
    cleaned, _ = run_pair(dict(fixture, removeCorpsesEvery=4), "check-remove4")
    removed = [e for e in cleaned["eventLog"] if e["trigger"] == "vacuum"]
    require(len(removed) == 2 and all(e["timestamp"] == 6 for e in removed), "cleanup timing")
    require(metrics(cleaned)["corpses"] == 0 and metrics(cleaned)["stains"] == 1,
            "cleanup must only remove corpses")
    quantized, _ = run_pair(dict(fixture, removeCorpsesEvery=3), "check-remove3")
    equal(deterministic(cleaned), deterministic(quantized), "nonaligned first boundary")
    protected = copy.deepcopy(fixture)
    protected["creatures"][1]["protection"] = True
    protected["removeCorpsesEvery"] = 4
    safe, _ = run_pair(protected, "check-protected")
    require(metrics(safe)["corpses"] == 1, "existing protected remove rule")

    # A full world with two mature eggs cannot hatch. A stain control keeps
    # the initial count fixed without adding births, and gives a known integral.
    blocked = {
        "name": "integral-fixture", "seed": 19, "duration": 6,
        "habitats": [{"id": "nest"}], "actions": [],
        "creatures": ([{"stage": "egg", "age": 178, "location": "nest"}] * 2
                      + [{"stage": "stain", "location": "nest"}] * 36),
    }
    output, _ = run_pair(blocked, "check-integral")
    validate_trace(output, blocked)
    require(output["capacityEvidence"]["matureEggSeconds"] == 12, "two eggs x six seconds")
    require(output["capacityEvidence"]["matureEggWallSeconds"] == 6, "wall time counts once")
    require(output["capacityEvidence"]["firstAt32"] == 0, "initial count above threshold")
    for output, scenario in ((keep, fixture), (cleaned, dict(fixture, removeCorpsesEvery=4)),
                             (safe, protected)):
        validate_trace(output, scenario)
    print("PASS framework: omitted/null/disabled, cleanup time/type/protection, odd boundary, integrals", flush=True)


def record(scenario, tag, group, **labels):
    left, right = run_pair(scenario, tag)
    for output in (left, right):
        validate_trace(output, scenario)
    values = {"swift": metrics(left), "cs": metrics(right)}
    equal(values["swift"], values["cs"], tag + "/derived metrics")
    row = {
        "id": tag, "experiment": group, "seed": scenario["seed"], **labels,
        "parity": "PASS", "metrics": values,
        "capacityEvidence": left["capacityEvidence"],
        "eventTriggerCounts": dict(sorted(collections.Counter(e["trigger"] for e in left["eventLog"]).items())),
        "finalStageCounts": dict(sorted(collections.Counter(c["stage"] for c in left["world"]["creatures"]).items())),
        "deterministicOutputSha256": {"swift": digest(deterministic(left)), "cs": digest(deterministic(right))},
        "materializedInputSha256": digest(scenario),
    }
    print(f"PASS {tag}: {values['swift']}", flush=True)
    return row, left


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    plan_commit = command(["git", "log", "--format=%H", "--reverse", "--",
                           "Docs/residue-capacity-plan.md"]).splitlines()[0]
    require(plan_commit, "commit the experiment plan before running")
    print(command(["swiftc", "-O", "Sources/World.swift", "Tests/Simulation/main.swift",
                   "-o", str(OUT / "world-sim")]), end="")
    print(command([DOTNET, "build", "Tests/Simulation", "-c", "Release"]), end="")
    framework_checks()

    rows = []
    zero_controls = {}
    for seed in SEEDS:
        snapshots = {}
        for stage in ("corpse", "stain"):
            maximum = load(SCENARIOS / f"R1-{stage}-30.json")
            maximum.update(seed=seed, duration=0)
            initialized, _ = run_pair(maximum, f"setup-{stage}-{seed}")
            snapshots[stage] = initialized["world"]
        for field in ("rng", "serial", "seed", "habitats"):
            equal(snapshots["corpse"][field], snapshots["stain"][field], "paired initialization/" + field)
        equal(snapshots["corpse"]["creatures"][:8], snapshots["stain"]["creatures"][:8], "paired adults")
        for stage in ("corpse", "stain"):
            for dose in DOSES:
                scenario = load(SCENARIOS / f"R1-{stage}-{dose:02}.json")
                scenario["seed"] = seed
                initial = copy.deepcopy(snapshots[stage])
                initial["creatures"] = initial["creatures"][:8 + dose]
                scenario["initial"] = initial
                require(len(initial["creatures"]) == 8 + dose, "initial total")
                row, output = record(scenario, f"R1-{stage}-{dose:02}-{seed}", "R1",
                                     residue=stage, initialResidues=dose)
                rows.append(row)
                if dose == 0:
                    if seed in zero_controls:
                        equal(deterministic(output), zero_controls[seed], "duplicate zero-dose control")
                    else:
                        zero_controls[seed] = deterministic(output)

    original_f = load(ROOT / "Tests/Simulation/scenarios/F-two-hours.json")
    for group in ("keep", "remove60"):
        template = load(SCENARIOS / f"R2-{group}.json")
        unchanged = {k: v for k, v in template.items() if k != "removeCorpsesEvery"}
        require(unchanged == original_f, "R2 must preserve F input")
        for seed in SEEDS:
            scenario = dict(template, seed=seed)
            row, _ = record(scenario, f"R2-{group}-{seed}", "R2", cleanup=group)
            rows.append(row)
    require(len(rows) == 60, "complete matrix")

    sources = [ROOT / name for name in (
        "Sources/World.swift", "Windows/World.cs", "Tests/Simulation/main.swift",
        "Tests/Simulation/Program.cs", "Tests/Simulation/scenarios/F-two-hours.json",
        "Docs/residue-capacity-plan.md",
    )] + sorted(SCENARIOS.glob("*.json")) + [Path(__file__).resolve()]
    evidence = {
        "schema": 1,
        "planCommit": plan_commit,
        "productBaseCommit": command(["git", "rev-parse", plan_commit + "^"]),
        "matrix": {"seeds": SEEDS, "doses": DOSES, "duration": 7200, "step": 2,
                   "formalCells": 60, "formalEngineRuns": 120},
        "countColumns": COUNT_COLUMNS,
        "frameworkChecks": "PASS",
        "pairedInitialization": "same first eight adults, rng and serial for all R1 doses/types per seed",
        "zeroDoseDuplicateChecks": "PASS: all five seeds",
        "sourceSha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
        "toolchains": {"swift": command(["swiftc", "--version"]).strip(),
                       "dotnet": command([DOTNET, "--version"]).strip()},
        "runs": rows,
    }
    save(ROOT / "Docs/residue-capacity-evidence.json", evidence)
    print("PASS complete 60-cell / 120-engine matrix; evidence written", flush=True)


if __name__ == "__main__":
    main()
