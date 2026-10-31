#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from tlc import jar

ROOT = Path(__file__).resolve().parents[2]
PLUGIN_COMMIT = "f14452f4630049f721e8871c714eac9596093f03"
PLUGIN_URL = "https://github.com/pstack-ports/grok-pstack.git"
PLUGIN_CACHE = Path.home() / ".cache/perimedi/grok-pstack" / PLUGIN_COMMIT
FENCE = re.compile(r"```mermaid\n(.*?)```", re.S)

MODELS = (
    (
        "dose-reminder",
        ROOT / "ios/formal/dose-reminder/DoseReminder.tla",
        ROOT / "ios/formal/dose-reminder/DoseReminder.cfg",
        ROOT / "ios/formal/dose-reminder/view.mjs",
        ROOT / "docs/statecharts/dose-reminder.md",
    ),
    (
        "symptom-sync",
        ROOT / "ios/formal/symptom-sync/SymptomSync.tla",
        ROOT / "ios/formal/symptom-sync/SymptomSyncChart.cfg",
        ROOT / "ios/formal/symptom-sync/view.mjs",
        ROOT / "docs/statecharts/symptom-sync.md",
    ),
)

PELE = Path.home() / ".cache/perimedi/pele"
PELE_VERSION = "1.9.0"
HAPPY_FILL = "#ffcbe6"
HAPPY_STROKE = "#c45c8a"
BUG_STROKE = "#e72e3b"
THICK = "8"
FADE = "0.22"
FOCUS_MAX = 1800
PAGE_WIDTH = 880
PAGE_STROKE = 5
FULL_LINK = "[The full picture](dose-reminder-full.svg)"
PREVENTED_LABEL = "A saved day is gone"
SYMPTOM_HAPPY = [
    (None, "No custom symptoms"),
    ("you add a symptom", "One custom symptom"),
    ("the other phone adds a symptom", "Two phones added the same name"),
    ("the phone saves the remembered pairs", "The pairs are saved and the store save is still open"),
    ("the store save lands", "One symptom remains, and the pair is remembered"),
]
CLASS_DEFS = (
    f"  classDef happy fill:{HAPPY_FILL},stroke:{HAPPY_STROKE}",
    f"  classDef bugPath stroke:{BUG_STROKE},stroke-width:2.5px",
)
STYLE = """
.pele { --pele-bg:#ffffff; --pele-fg:#1c1c1c; --pele-muted:#656565; --pele-line:#808080; --pele-surface:#fcfcfc; --pele-surface-alt:#f1f1f1; --pele-border:#c9c9c9; }
.pele .blue rect { fill:#c3e0ff; }
.pele .orange rect { fill:#f0d3bf; }
.pele .purple rect { fill:#e3d5ff; }
.pele .yellow rect { fill:#f0dcbf; }
.pele .teal rect { fill:#bfe3df; }
.pele .tan rect { fill:#e5d9ce; }
.pele .pink rect { fill:#ffcbe6; }
.pele .breaks rect { fill:#ffecee !important; stroke:#e72e3b !important; stroke-width:2.5px !important; }
.pele .breaks text { fill:#cd2834 !important; }
.pele .mayBreak rect { fill:#fff3e6 !important; stroke:#e8730c !important; stroke-width:2.5px !important; }
.pele .mayBreak text { fill:#b85a06 !important; }
.pele .happy rect { fill:#ffcbe6 !important; stroke:#c45c8a !important; stroke-width:4px !important; }
.pele .bugPath rect { stroke:#e72e3b !important; stroke-width:4px !important; }
.pele .prevented rect { fill:#e4e7ea !important; stroke:#5c6b73 !important; stroke-width:2.5px !important; }
.pele .prevented text { fill:#1c1c1c !important; }
@media (prefers-color-scheme: dark) {
  .pele { --pele-bg:#1f1f1f; --pele-fg:#f5f5f5; --pele-muted:#acacac; --pele-line:#939393; --pele-surface:#121212; --pele-surface-alt:#2c2c2c; --pele-border:#4e4e4e; }
  .pele .blue rect { fill:#1b3857; }
  .pele .orange rect { fill:#573117; }
  .pele .purple rect { fill:#3c2e57; }
  .pele .yellow rect { fill:#573d17; }
  .pele .teal rect { fill:#174641; }
  .pele .tan rect { fill:#3d3127; }
  .pele .pink rect { fill:#57233e; }
  .pele .breaks rect { fill:#2e2021 !important; stroke:#cf2b35 !important; }
  .pele .breaks text { fill:#ff6463 !important; }
  .pele .mayBreak rect { fill:#2e2619 !important; stroke:#d0700f !important; }
  .pele .mayBreak text { fill:#ffa257 !important; }
  .pele .happy rect { fill:#57233e !important; stroke:#c45c8a !important; stroke-width:4px !important; }
  .pele .bugPath rect { stroke:#e72e3b !important; stroke-width:4px !important; }
  .pele .prevented rect { fill:#2a2e31 !important; stroke:#9aa7af !important; stroke-width:2.5px !important; }
  .pele .prevented text { fill:#f5f5f5 !important; }
}
"""


def norm(text: str) -> str:
    return text.strip("\n") + "\n"


def fence(text: str) -> str | None:
    match = FENCE.search(text)
    if match is None:
        return None
    return norm(match.group(1))


def plugin_dir() -> Path:
    script = PLUGIN_CACHE / "skills/statechart/scripts/statechart"
    if script.is_file():
        rev = subprocess.run(
            ["git", "-C", str(PLUGIN_CACHE), "rev-parse", "HEAD"],
            text=True,
            capture_output=True,
            check=False,
        )
        if rev.stdout.strip() == PLUGIN_COMMIT:
            return PLUGIN_CACHE
    if PLUGIN_CACHE.exists():
        shutil.rmtree(PLUGIN_CACHE)
    PLUGIN_CACHE.mkdir(parents=True)
    init = subprocess.run(["git", "init", "-q"], cwd=PLUGIN_CACHE, text=True, capture_output=True, check=False)
    if init.returncode != 0:
        print(init.stderr.strip() or "git init failed", file=sys.stderr)
        raise SystemExit(2)
    remote = subprocess.run(
        ["git", "remote", "add", "origin", PLUGIN_URL],
        cwd=PLUGIN_CACHE,
        text=True,
        capture_output=True,
        check=False,
    )
    if remote.returncode != 0:
        print(remote.stderr.strip() or "git remote add failed", file=sys.stderr)
        raise SystemExit(2)
    fetched = subprocess.run(
        ["git", "fetch", "--depth", "1", "origin", PLUGIN_COMMIT],
        cwd=PLUGIN_CACHE,
        text=True,
        capture_output=True,
        check=False,
    )
    if fetched.returncode != 0:
        print(fetched.stderr.strip() or "git fetch failed", file=sys.stderr)
        raise SystemExit(2)
    checked = subprocess.run(
        ["git", "checkout", "--quiet", "FETCH_HEAD"],
        cwd=PLUGIN_CACHE,
        text=True,
        capture_output=True,
        check=False,
    )
    if checked.returncode != 0:
        print(checked.stderr.strip() or "git checkout failed", file=sys.stderr)
        raise SystemExit(2)
    return PLUGIN_CACHE


def generate(tool: Path, java: str, jar_path: Path, spec: Path, cfg: Path, view: Path, out: Path) -> int:
    env = os.environ.copy()
    env["TLA2TOOLS"] = str(jar_path)
    env["JAVA"] = java
    try:
        proc = subprocess.run(
            [str(tool), str(spec), "--config", str(cfg), "--view", str(view), "--out", str(out)],
            text=True,
            capture_output=True,
            timeout=180,
            check=False,
            env=env,
        )
    except subprocess.TimeoutExpired:
        print(f"statechart timed out for {spec.name}", file=sys.stderr)
        return 2
    if proc.returncode not in {0, 1}:
        sys.stderr.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        return 2
    return proc.returncode


def split_top(text: str) -> list[str]:
    parts: list[str] = []
    buf: list[str] = []
    depth = 0
    quote = False
    index = 0
    while index < len(text):
        char = text[index]
        if char == '"':
            quote = not quote
            buf.append(char)
            index += 1
            continue
        if not quote:
            if text.startswith("|->", index):
                buf.append("|->")
                index += 3
                continue
            if text.startswith("<<", index) or text.startswith(">>", index):
                depth += 1 if text[index] == "<" else -1
                buf.append(text[index : index + 2])
                index += 2
                continue
            if char in "[{":
                depth += 1
            elif char in "]}":
                depth -= 1
            elif char == "," and depth == 0:
                parts.append("".join(buf).strip())
                buf = []
                index += 1
                continue
        buf.append(char)
        index += 1
    tail = "".join(buf).strip()
    if tail:
        parts.append(tail)
    return parts


def parse_tla(text: str):
    value = text.strip()
    if value == "TRUE":
        return True
    if value == "FALSE":
        return False
    if value == "<<>>":
        return {}
    if value.startswith("<<") and value.endswith(">>"):
        inner = split_top(value[2:-2].strip())
        return {str(index + 1): parse_tla(part) for index, part in enumerate(inner)}
    if value.startswith("[") and value.endswith("]"):
        fields = {}
        for part in split_top(value[1:-1].strip()):
            key, raw = part.split("|->", 1)
            fields[key.strip()] = parse_tla(raw.strip())
        return fields
    if value.startswith('"') and value.endswith('"'):
        return value[1:-1]
    return value


def parse_trace(output: str) -> list[dict]:
    start = output.find("State 1:")
    if start < 0:
        return []
    blocks = re.split(r"\nState \d+: ", "\n" + output[start:])
    parsed = []
    for block in blocks:
        block = block.strip()
        if not block:
            continue
        header, _, body = block.partition("\n")
        action = "Init"
        named = re.search(r"<([A-Za-z]+)", header)
        if named and named.group(1) != "Initial":
            action = named.group(1)
        variables = {}
        for line in body.splitlines():
            if not line.startswith("/\\ "):
                break
            name, raw = line[3:].split(" = ", 1)
            variables[name.strip()] = parse_tla(raw)
        if variables:
            parsed.append({"action": action, "vars": variables})
    return parsed


def happy_trace(java: str, jar_path: Path, spec: Path) -> list[dict]:
    with tempfile.TemporaryDirectory(prefix="dose-happy-") as raw:
        work = Path(raw)
        shutil.copy(spec, work / spec.name)
        (work / "DoseHappy.tla").write_text(
            "---- MODULE DoseHappy ----\n"
            "EXTENDS DoseReminder\n"
            "NotHappy ==\n"
            '  \\/ Len(rows) # 1\n'
            '  \\/ Visible # "taken"\n'
            '  \\/ live # "none"\n'
            "  \\/ q # <<>>\n"
            "  \\/ glass # FALSE\n"
            "====\n",
            encoding="utf-8",
        )
        (work / "happy.cfg").write_text(
            "SPECIFICATION Spec\nINVARIANT NotHappy\n",
            encoding="utf-8",
        )
        proc = subprocess.run(
            [
                java,
                "-XX:+UseParallelGC",
                "-jar",
                str(jar_path),
                "-workers",
                "1",
                "-fp",
                "0",
                "-metadir",
                "meta",
                "-config",
                "happy.cfg",
                "DoseHappy.tla",
            ],
            cwd=work,
            text=True,
            capture_output=True,
            timeout=180,
            check=False,
        )
        output = proc.stdout + proc.stderr
        if "Invariant NotHappy is violated" not in output:
            print(output[-2000:], file=sys.stderr)
            raise RuntimeError("the taken dose with an empty queue is unreachable")
        return parse_trace(output)


def view_labels(view: Path, trace: list[dict]) -> list[dict]:
    with tempfile.TemporaryDirectory(prefix="chart-view-") as raw:
        payload = Path(raw) / "trace.json"
        payload.write_text(json.dumps(trace), encoding="utf-8")
        script = Path(raw) / "labels.mjs"
        script.write_text(
            "import { pathToFileURL } from 'node:url';\n"
            "import { readFileSync } from 'node:fs';\n"
            "const view = await import(pathToFileURL(process.argv[2]).href);\n"
            "const trace = JSON.parse(readFileSync(process.argv[3], 'utf8'));\n"
            "const out = [];\n"
            "for (let i = 0; i < trace.length; i++) {\n"
            "  const label = view.state(trace[i].vars);\n"
            "  const text = typeof label === 'string'\n"
            "    ? label\n"
            "    : Object.entries(label).map(([name, value]) => `${name} ${value}`).join(', ');\n"
            "  let step = null;\n"
            "  if (i > 0 && view.step) step = view.step(trace[i].action, trace[i - 1].vars, trace[i].vars);\n"
            "  out.push({ text, step });\n"
            "}\n"
            "process.stdout.write(JSON.stringify(out));\n",
            encoding="utf-8",
        )
        proc = subprocess.run(
            ["node", str(script), str(view), str(payload)],
            text=True,
            capture_output=True,
            timeout=30,
            check=False,
        )
        if proc.returncode != 0:
            print(proc.stderr, file=sys.stderr)
            raise RuntimeError("the chart view rejected a TLC state")
        return json.loads(proc.stdout)


def state_index(mermaid: str) -> dict[str, str]:
    stack: list[str] = []
    index: dict[str, str] = {}
    for line in mermaid.splitlines():
        stripped = line.strip()
        opened = re.match(r'state "(.*)" as (\w+) \{', stripped)
        if opened:
            stack.append(opened.group(1))
            continue
        if stripped == "}":
            if stack:
                stack.pop()
            continue
        leaf = re.match(r"(\w+): (.*)$", stripped)
        if leaf and stack[:1] != ["Legend"]:
            index[", ".join([*stack, leaf.group(2)])] = leaf.group(1)
    return index


def bug_paths(report: str) -> list[list[tuple[str | None, str]]]:
    paths: list[list[tuple[str | None, str]]] = []
    current: list[tuple[str | None, str]] | None = None
    for line in report.splitlines():
        if line.startswith("## ") and line.endswith(" breaks"):
            current = []
            paths.append(current)
            continue
        if current is None:
            continue
        numbered = re.match(r"^\d+\. (.*)$", line)
        if not numbered:
            if line.startswith("## "):
                current = None
            continue
        body = numbered.group(1)
        if ": " in body:
            step, state = body.split(": ", 1)
        else:
            step, state = None, body
        current.append((step, state))
    return paths


def relations(mermaid: str) -> list[tuple[str, str, str]]:
    found = []
    for line in mermaid.splitlines():
        match = re.match(r"  (?:\[\*\]|([A-Za-z0-9_]+)) --> ([A-Za-z0-9_]+)(?:: (.*))?$", line)
        if not match:
            continue
        found.append((match.group(1) or "[*]", match.group(2), match.group(3) or ""))
    return found


def path_edges(
    rels: list[tuple[str, str, str]],
    path: list[tuple[str | None, str]],
    ids: dict[str, str],
) -> list[tuple[int, str | None]]:
    chosen = []
    nodes = []
    for step, state in path:
        if state not in ids:
            raise RuntimeError(f"chart has no state for {state}")
        nodes.append((step, ids[state]))
    for (_prev_step, source), (step, target) in zip(nodes, nodes[1:]):
        matches = [
            index
            for index, (left, right, title) in enumerate(rels)
            if left == source and right == target and (not step or step in title)
        ]
        if not matches:
            raise RuntimeError(f"chart has no arrow for {step} from {source} to {target}")
        chosen.append((matches[0], step))
    return chosen


def wrapped(label: str) -> str:
    parts = [part.strip() for part in label.split(", ") if part.strip()]
    return "<br/>".join(parts) if parts else label


def svg_width(svg: str) -> int:
    match = re.search(r'<svg\b[^>]*\bwidth="(\d+)"', svg)
    if match is None:
        raise RuntimeError("the picture has no width")
    return int(match.group(1))


def stroke_px(width: int) -> str:
    return str(max(int(THICK), round(PAGE_STROKE * width / PAGE_WIDTH)))


def mark_prevented(mermaid: str) -> tuple[str, str]:
    ids = state_index(mermaid)
    sid = ids.get(PREVENTED_LABEL)
    if sid is None:
        raise RuntimeError(f"chart has no state for {PREVENTED_LABEL}")
    lines = []
    for line in mermaid.splitlines():
        stripped = line.strip()
        if stripped == f"class {sid} pink":
            lines.append(f"  class {sid} prevented")
            continue
        if stripped == "class lg0 pink":
            lines.append("  class lg0 prevented")
            continue
        if stripped == "lg0: Lost":
            lines.append("  lg0: Prevented")
            continue
        lines.append(line)
    extra = "  classDef prevented fill:#e4e7ea,stroke:#5c6b73,stroke-width:2.5px"
    if extra not in lines:
        lines.append(extra)
    return "\n".join(lines) + "\n", sid


def focus_chart(
    mermaid: str,
    rels: list[tuple[str, str, str]],
    edges: list[tuple[int, str | None]],
    happy_ids: list[str],
    bug_ids: list[str],
) -> str:
    inverse = {sid: label for label, sid in state_index(mermaid).items()}
    lines = ["stateDiagram-v2"]
    seen: list[str] = []
    happy = set(happy_ids)
    for index, step in edges:
        left, right, title = rels[index]
        for nid in (left, right):
            if nid == "[*]" or nid in seen:
                continue
            seen.append(nid)
            lines.append(f"  {nid}: {wrapped(inverse[nid])}")
        src = "[*]" if left == "[*]" else left
        lines.append(f"  {src} --> {right}: {step or title}")
    lines.extend(CLASS_DEFS)
    for sid in happy_ids:
        if sid in seen:
            lines.append(f"  class {sid} happy")
    for sid in bug_ids:
        if sid in seen and sid not in happy:
            lines.append(f"  class {sid} bugPath")
            lines.append(f"  class {sid} breaks")
    return "\n".join(lines) + "\n"


def finish_mermaid(text: str, happy_ids: list[str]) -> str:
    lines = text.splitlines()
    for line in CLASS_DEFS:
        if line not in lines:
            lines.append(line)
    for sid in happy_ids:
        line = f"  class {sid} happy"
        if line not in lines:
            lines.append(line)
    return "\n".join(lines) + "\n"


def ensure_pele() -> Path:
    module = PELE / "node_modules/pele/dist/pele.js"
    package = PELE / "node_modules/pele/package.json"
    if package.is_file() and json.loads(package.read_text(encoding="utf-8")).get("version") == PELE_VERSION:
        return module
    PELE.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run(
        ["npm", "install", "--prefix", str(PELE), f"pele@{PELE_VERSION}"],
        text=True,
        capture_output=True,
        timeout=180,
        check=False,
    )
    if proc.returncode != 0 or not module.is_file():
        sys.stderr.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        raise RuntimeError("could not install pele@1.9.0")
    return module


def render_svg(module: Path, mermaid: str) -> str:
    with tempfile.TemporaryDirectory(prefix="pele-") as raw:
        work = Path(raw)
        source = work / "chart.mmd"
        source.write_text(mermaid, encoding="utf-8")
        script = work / "render.mjs"
        script.write_text(
            "import { readFileSync, writeFileSync } from 'node:fs';\n"
            "import { pathToFileURL } from 'node:url';\n"
            "const pele = await import(pathToFileURL(process.argv[2]).href);\n"
            "const result = pele.render(readFileSync(process.argv[3], 'utf8'), "
            "{ limit: 1000000, outputLimit: 8000000, maxEdges: 10000 });\n"
            "writeFileSync(process.argv[4], result.svg);\n",
            encoding="utf-8",
        )
        out = work / "chart.svg"
        proc = subprocess.run(
            ["node", str(script), str(module), str(source), str(out)],
            text=True,
            capture_output=True,
            timeout=60,
            check=False,
        )
        if proc.returncode != 0:
            sys.stderr.write(proc.stdout)
            sys.stderr.write(proc.stderr)
            raise RuntimeError("Pele could not render the chart")
        svg = out.read_text(encoding="utf-8")
    if "statechart-colors" not in svg:
        tag_end = svg.find(">")
        svg = svg[: tag_end + 1] + "<style>/* statechart-colors */" + STYLE + "</style>" + svg[tag_end + 1 :]
    return svg


def color_edges(svg: str, bug: set[int], happy: set[int], thick: str) -> str:
    pattern = re.compile(
        r'(<g class="pele-edge pele-transition" data-id="edge(\d+)">)(.*?)(</g>)',
        re.S,
    )

    def paint_marker(body: str, color: str, opacity: str) -> str:
        updated, count = re.subn(
            r'(<path\b[^>]*class="pele-marker"[^>]*?)fill="[^"]*"',
            rf'\1fill="{color}" fill-opacity="{opacity}"',
            body,
            count=1,
            flags=re.S,
        )
        if count:
            return updated
        updated, _count = re.subn(
            r'(<path\b[^>]*?)fill="[^"]*"([^>]*class="pele-marker")',
            rf'\1fill="{color}" fill-opacity="{opacity}"\2',
            body,
            count=1,
            flags=re.S,
        )
        return updated

    def paint(match: re.Match[str]) -> str:
        index = int(match.group(2))
        if index in bug:
            color, width, opacity = BUG_STROKE, thick, "1"
        elif index in happy:
            color, width, opacity = HAPPY_STROKE, thick, "1"
        else:
            color, width, opacity = "#b5b5b5", "2", FADE
        body = re.sub(
            r"<path\b",
            f'<path stroke="{color}" stroke-width="{width}" stroke-opacity="{opacity}"',
            match.group(3),
            count=1,
        )
        return match.group(1) + paint_marker(body, color, opacity) + match.group(4)

    return pattern.sub(paint, svg)


def fade_nodes(svg: str, keep: set[str]) -> str:
    pattern = re.compile(r'(<g class="pele-node [^"]*" data-id="([^"]+)")')

    def paint(match: re.Match[str]) -> str:
        if match.group(2) in keep:
            return match.group(0)
        return match.group(1) + ' opacity="0.28"'

    return pattern.sub(paint, svg)


def drawn_edges(svg: str, rels: list[tuple[str, str, str]]) -> None:
    edge_ids = {int(item) for item in re.findall(r'data-id="edge(\d+)"', svg)}
    if edge_ids != set(range(len(rels))):
        raise RuntimeError(f"Pele drew {sorted(edge_ids)} and the mermaid has {len(rels)} arrows")


def picture(
    name: str,
    spec: Path,
    view: Path,
    mermaid: str,
    report: str,
    java: str,
    jar_path: Path,
) -> tuple[str, str, str | None]:
    prevented: str | None = None
    if name == "symptom-sync":
        mermaid, prevented = mark_prevented(mermaid)
    ids = state_index(mermaid)
    rels = relations(mermaid)
    bug: set[int] = set()
    bug_ids: list[str] = []
    kept: list[tuple[int, str | None]] = []
    seen: set[int] = set()
    for path in bug_paths(report):
        for index, step in path_edges(rels, path, ids):
            bug.add(index)
            if index not in seen:
                seen.add(index)
                kept.append((index, step))
        for _step, state in path:
            sid = ids[state]
            if sid not in bug_ids:
                bug_ids.append(sid)
    if name == "dose-reminder":
        labeled = view_labels(view, happy_trace(java, jar_path, spec))
        happy_path = [(item["step"], item["text"]) for item in labeled]
    else:
        happy_path = list(SYMPTOM_HAPPY)
    happy_ids: list[str] = []
    happy: set[int] = set()
    for _step, state in happy_path:
        sid = ids[state]
        if sid not in happy_ids:
            happy_ids.append(sid)
    for index, step in path_edges(rels, happy_path, ids):
        happy.add(index)
        if index not in seen:
            seen.add(index)
            kept.append((index, step))
    drawn = finish_mermaid(mermaid, happy_ids)
    rels = relations(drawn)
    module = ensure_pele()
    full = render_svg(module, drawn)
    drawn_edges(full, rels)
    keep = set(happy_ids) | set(bug_ids)
    if prevented:
        keep.add(prevented)
    embedded_thick = THICK if name == "dose-reminder" else stroke_px(svg_width(full))
    full = fade_nodes(color_edges(full, bug, happy, embedded_thick), keep)
    focus = None
    if name == "dose-reminder":
        small = focus_chart(drawn, rels, kept, happy_ids, bug_ids)
        small_rels = relations(small)
        focus = render_svg(module, small)
        drawn_edges(focus, small_rels)
        width = svg_width(focus)
        if width > FOCUS_MAX:
            raise RuntimeError(f"the short dose picture is {width}px wide")
        focus_bug: set[int] = set()
        focus_happy: set[int] = set()
        for pos, (index, _step) in enumerate(kept):
            if index in bug:
                focus_bug.add(pos)
            elif index in happy:
                focus_happy.add(pos)
        focus = color_edges(focus, focus_bug, focus_happy, stroke_px(width))
        if BUG_STROKE not in focus or HAPPY_STROKE not in focus or 'stroke-width="' + stroke_px(width) not in focus:
            raise RuntimeError("the short dose picture does not draw the thick paths")
    return drawn, full, focus


SVG_BLOCK = re.compile(r"<svg\b.*?</svg>", re.S)


def image_link(doc: Path) -> str:
    alt = "One dose reminder" if doc.stem == "dose-reminder" else "Custom symptom sync"
    return f"![{alt}]({doc.name.replace('.md', '.svg')})"


def full_picture(doc: Path) -> Path:
    return doc.with_name(f"{doc.stem}-full.svg")


def page_matches(doc: Path, drawn: str, full_svg: str, focus_svg: str | None) -> bool:
    if not doc.is_file():
        return False
    page = doc.read_text(encoding="utf-8")
    embedded = focus_svg if focus_svg is not None else full_svg
    side = doc.with_suffix(".svg")
    ok = (
        fence(page) == norm(drawn)
        and side.is_file()
        and side.read_text(encoding="utf-8") == embedded
        and image_link(doc) in page
        and "<svg" not in page
    )
    if focus_svg is None:
        return ok
    full = full_picture(doc)
    return (
        ok
        and full.is_file()
        and full.read_text(encoding="utf-8") == full_svg
        and FULL_LINK in page
        and svg_width(focus_svg) <= FOCUS_MAX
    )


def write_page(doc: Path, drawn: str, full_svg: str, focus_svg: str | None) -> None:
    page = doc.read_text(encoding="utf-8") if doc.is_file() else ""
    fenced = "```mermaid\n" + norm(drawn) + "```"
    if FENCE.search(page):
        page = FENCE.sub(fenced, page, count=1)
    else:
        page = page.rstrip() + "\n\n" + fenced + "\n"
    page = SVG_BLOCK.sub("", page)
    link = image_link(doc)
    if link not in page:
        page = page.replace(fenced, link + "\n\n" + fenced, 1)
    if focus_svg is not None and FULL_LINK not in page:
        page = page.replace(link, link + "\n\n" + FULL_LINK, 1)
    if not page.endswith("\n"):
        page += "\n"
    doc.write_text(page, encoding="utf-8")
    doc.with_suffix(".svg").write_text(focus_svg if focus_svg is not None else full_svg, encoding="utf-8")
    if focus_svg is not None:
        full_picture(doc).write_text(full_svg, encoding="utf-8")


def main() -> int:
    write = "--write" in sys.argv
    java = shutil.which("java")
    if java is None:
        print("java is not on PATH", file=sys.stderr)
        return 2
    tool = plugin_dir() / "skills/statechart/scripts/statechart"
    if not tool.is_file():
        print("statechart tool is missing from the pinned plugin", file=sys.stderr)
        return 2
    jar_path = jar()
    failed = False
    for name, spec, cfg, view, doc in MODELS:
        if not spec.is_file() or not cfg.is_file() or not view.is_file():
            print(f"missing inputs for {name}", file=sys.stderr)
            return 2
        with tempfile.TemporaryDirectory(prefix=f"statechart-{name}-") as raw:
            code = generate(tool, java, jar_path, spec, cfg, view, Path(raw))
            if code == 2:
                return 2
            chart_path = Path(raw) / "chart.mmd"
            report_path = Path(raw) / "report.md"
            if not chart_path.is_file() or not report_path.is_file():
                print(f"{name}: the tool wrote no chart", file=sys.stderr)
                failed = True
                continue
            try:
                drawn, full_svg, focus_svg = picture(
                    name,
                    spec,
                    view,
                    chart_path.read_text(encoding="utf-8"),
                    report_path.read_text(encoding="utf-8"),
                    java,
                    jar_path,
                )
            except RuntimeError as err:
                print(f"{name}: {err}", file=sys.stderr)
                return 2
            if page_matches(doc, drawn, full_svg, focus_svg):
                print(f"ok: {name} fence and picture match")
                continue
            if write:
                write_page(doc, drawn, full_svg, focus_svg)
                if page_matches(doc, drawn, full_svg, focus_svg):
                    print(f"wrote: {name}")
                    continue
            print(f"{name}: mermaid fence or picture does not match", file=sys.stderr)
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
