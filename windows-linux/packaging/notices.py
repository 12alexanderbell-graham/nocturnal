#!/usr/bin/env python3
"""Writes THIRD-PARTY-NOTICES.txt: the licence of every crate built into the Windows and Linux apps, as their
licences ask for when the code ships in a binary. Run from windows-linux/ after `cargo fetch`."""
import glob
import json
import os
import subprocess
import sys

TARGETS = ["x86_64-unknown-linux-gnu", "x86_64-pc-windows-gnu"]
LICENSE_GLOBS = ["LICENSE*", "LICENCE*", "COPYING*", "COPYRIGHT*", "NOTICE*", "UNLICENSE*", "license*"]


def shipped():
    """Crates that end up in a release binary on either target (no build-only or dev-only ones)."""
    out = {}
    for target in TARGETS:
        meta = json.loads(subprocess.check_output(
            ["cargo", "metadata", "--format-version", "1", "--locked", "--filter-platform", target]))
        packages = {p["id"]: p for p in meta["packages"]}
        nodes = {n["id"]: n for n in meta["resolve"]["nodes"]}
        roots = [p for p in meta["workspace_members"]]
        seen, todo = set(), list(roots)
        while todo:
            pid = todo.pop()
            if pid in seen:
                continue
            seen.add(pid)
            for dep in nodes[pid]["deps"]:
                if any(k["kind"] in (None, "normal") for k in dep["dep_kinds"]):
                    todo.append(dep["pkg"])
        for pid in seen:
            if pid not in roots:
                p = packages[pid]
                out[(p["name"], p["version"])] = p
    return [out[k] for k in sorted(out)]


def main():
    parts = ["Nocturnal for Windows and Linux includes the following open-source software.\n"
             "Each is used under the licence shown; the full texts follow each entry.\n"]
    missing, seen_texts, crates = [], {}, shipped()
    for p in crates:
        d = os.path.dirname(p["manifest_path"])
        files = sorted({f for g in LICENSE_GLOBS for f in glob.glob(os.path.join(d, g)) if os.path.isfile(f)})
        head = f"\n{'=' * 78}\n{p['name']} {p['version']}\nLicence: {p.get('license') or 'see below'}\n"
        if p.get("repository"):
            head += f"Source: {p['repository']}\n"
        parts.append(head)
        if not files:
            missing.append(p["name"])
            parts.append("(No licence file is included in this crate's package; its licence is the one named above.)\n")
        for f in files:
            with open(f, encoding="utf-8", errors="replace") as fh:
                text = fh.read().strip()
            key = " ".join(text.split())
            if key in seen_texts:
                parts.append(f"\n--- {os.path.basename(f)}: the same text as under {seen_texts[key]} above ---\n")
            else:
                seen_texts[key] = f"{p['name']} {p['version']}"
                parts.append(f"\n--- {os.path.basename(f)} ---\n{text}\n")
    parts.append(f"\n{'=' * 78}\nmingw-w64 runtime (Windows build only)\n"
                 "Licence: ZPL-2.1, MIT and public domain parts. Source: https://www.mingw-w64.org\n")
    with open(sys.argv[1] if len(sys.argv) > 1 else "THIRD-PARTY-NOTICES.txt", "w", encoding="utf-8") as fh:
        fh.write("".join(parts))
    print(f"{len(crates)} crates; no licence file in: {', '.join(missing) or 'none'}")


if __name__ == "__main__":
    main()
