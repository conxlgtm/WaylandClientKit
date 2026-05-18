#!/usr/bin/env python3
import json
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[2]
CATALOG = ROOT / "Sources" / "WaylandClient" / "WaylandClient.docc"


def symbol_graph_path() -> pathlib.Path | None:
    for path in (ROOT / ".build").glob("**/symbolgraph/WaylandClient.symbols.json"):
        return path
    return None


def symbol_titles(path: pathlib.Path) -> set[str]:
    with path.open(encoding="utf-8") as handle:
        payload = json.load(handle)

    titles = {"WaylandClient"}
    for symbol in payload.get("symbols", []):
        names = symbol.get("names", {})
        title = names.get("title")
        if isinstance(title, str):
            titles.add(title)
            titles.add(title.removesuffix("()"))
    return titles


def docc_symbol_links(markdown: str) -> list[str]:
    return [
        match.group(1)
        for match in re.finditer(r"``([^`\n]+)``", markdown)
        if match.group(1).strip()
    ]


def main() -> int:
    graph = symbol_graph_path()
    if graph is None:
        print("Missing WaylandClient symbol graph under .build/*/symbolgraph")
        return 1

    symbols = symbol_titles(graph)
    failed = False

    for markdown_file in sorted(CATALOG.glob("*.md")):
        text = markdown_file.read_text(encoding="utf-8")
        for link in docc_symbol_links(text):
            name = link.split("/")[-1]
            if name not in symbols:
                print(
                    f"Unresolved DocC symbol link in "
                    f"{markdown_file.relative_to(ROOT)}: {link}"
                )
                failed = True

    if failed:
        return 1

    print("DocC symbol links resolve against the public symbol graph.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
