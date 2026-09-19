#!/usr/bin/env python3
"""Fetch Apple documentation pages and render them as markdown.

developer.apple.com renders docs client-side, so fetching the HTML gives you an
empty shell. The content lives in a JSON file next to each page:

    https://developer.apple.com/tutorials/data<path>.json

Usage:
    fetch-docs.py                 Refresh every page in sources.txt into references/apple/
    fetch-docs.py --check         Report which pages changed upstream, write nothing
    fetch-docs.py <path-or-url>   Print one page as markdown to stdout (not saved)

Only the standard library and curl are required.
"""
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "references", "apple")
BASE = "https://developer.apple.com"


def fetch(path):
    path = path.replace(BASE, "").split("#")[0].split("?")[0].rstrip("/")
    url = f"{BASE}/tutorials/data{path}.json"
    r = subprocess.run(["curl", "-sfL", url], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"fetch failed ({r.returncode}): {url}")
    return path, json.loads(r.stdout)


def render(path, d):
    refs = d.get("references", {})
    out = []

    def inline(items):
        s = ""
        for i in items or []:
            t = i.get("type")
            if t == "text":
                s += i["text"]
            elif t == "codeVoice":
                s += "`" + i["code"] + "`"
            elif t == "reference":
                r = refs.get(i["identifier"], {})
                s += "[" + r.get("title", i["identifier"]) + "](" + r.get("url", "") + ")"
            elif t in ("emphasis", "strong", "newTerm", "inlineHead"):
                s += inline(i.get("inlineContent"))
            elif t == "link":
                s += "[" + i.get("title", "") + "](" + i.get("destination", "") + ")"
        return s

    def block(items, ind=""):
        for b in items or []:
            t = b.get("type")
            if t == "heading":
                out.append("\n" + "#" * b["level"] + " " + b["text"] + "\n")
            elif t == "paragraph":
                text = inline(b["inlineContent"])
                if text.strip():
                    out.append(ind + text + "\n")
            elif t == "codeListing":
                out.append("```" + (b.get("syntax") or ""))
                out.extend(b["code"])
                out.append("```\n")
            elif t in ("unorderedList", "orderedList"):
                for it in b["items"]:
                    start = len(out)
                    block(it["content"], ind + "  ")
                    if len(out) > start:
                        out[start] = ind + "- " + out[start].lstrip()
            elif t == "aside":
                out.append(ind + "> **" + (b.get("name") or b.get("style", "Note")) + "**")
                start = len(out)
                block(b["content"], ind)
                for n in range(start, len(out)):
                    out[n] = ind + "> " + out[n]
            elif t == "table":
                for n, row in enumerate(b["rows"]):
                    cells = [" ".join(inline(p.get("inlineContent")) for p in c) for c in row]
                    out.append("| " + " | ".join(cells) + " |")
                    if n == 0:
                        out.append("|" + " --- |" * len(cells))
                out.append("")
            elif t == "tabNavigator":
                for tab in b["tabs"]:
                    out.append(ind + "**" + tab["title"] + "**\n")
                    block(tab["content"], ind)
            elif t == "links":
                for i in b["items"]:
                    r = refs.get(i, {})
                    out.append("- [" + r.get("title", "") + "](" + r.get("url", "") + ") " + inline(r.get("abstract")))
            elif t == "termList":
                for it in b["items"]:
                    out.append("- " + inline(it["term"]["inlineContent"]) + ":")
                    block(it["definition"]["content"], "  ")

    meta = d.get("metadata", {})
    out.append("# " + meta.get("title", path))
    out.append("")
    out.append("Source: " + BASE + path)
    platforms = meta.get("platforms") or []
    if platforms:
        out.append("Availability: " + ", ".join(
            f"{p.get('name')} {p.get('introducedAt')}"
            + (" (beta)" if p.get("beta") else "")
            + (" (deprecated)" if p.get("deprecated") else "")
            for p in platforms))
    out.append("")
    abstract = inline(d.get("abstract"))
    if abstract:
        out.append(abstract + "\n")

    for s in d.get("primaryContentSections", []):
        kind = s.get("kind")
        if kind == "content":
            block(s["content"])
        elif kind == "declarations":
            for dd in s["declarations"]:
                langs = dd.get("languages") or ["swift"]
                if "swift" not in langs:
                    continue
                out.append("```swift")
                out.append("".join(t["text"] for t in dd["tokens"]).strip())
                out.append("```\n")
        elif kind == "parameters":
            out.append("\n## Parameters\n")
            for p in s.get("parameters", []):
                out.append("- `" + p["name"] + "`:")
                block(p["content"], "  ")

    # Topics tell you what members exist. See Also is navigation noise, so skip it.
    for s in d.get("topicSections", []):
        out.append("\n## " + s.get("title", "Topics") + "\n")
        for i in s["identifiers"]:
            r = refs.get(i, {})
            out.append("- [" + r.get("title", "") + "](" + r.get("url", "") + ") " + inline(r.get("abstract")))

    text = "\n".join(out)
    return re.sub(r"\n{3,}", "\n\n", text).strip() + "\n"


def filename(path):
    return re.sub(r"[^a-z0-9.-]+", "_", path.strip("/").lower()).strip("_") + ".md"


def sources():
    with open(os.path.join(HERE, "sources.txt")) as f:
        return [l.strip() for l in f if l.strip() and not l.startswith("#")]


def main(argv):
    if argv and not argv[0].startswith("--"):
        path, d = fetch(argv[0])
        sys.stdout.write(render(path, d))
        return 0

    check = "--check" in argv
    os.makedirs(OUT, exist_ok=True)
    changed, failed = [], []
    for src in sources():
        try:
            path, d = fetch(src)
        except Exception as e:  # noqa: BLE001
            failed.append(f"{src}: {e}")
            continue
        md = render(path, d)
        dest = os.path.join(OUT, filename(path))
        old = open(dest).read() if os.path.exists(dest) else None
        if old != md:
            changed.append(("new" if old is None else "changed") + "  " + path)
            if not check:
                with open(dest, "w") as f:
                    f.write(md)

    for c in changed:
        print(c)
    for f in failed:
        print("FAILED  " + f, file=sys.stderr)
    verb = "would update" if check else "updated"
    print(f"{len(changed)} page(s) {verb}, {len(failed)} failed, {len(sources())} total")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
