#!/usr/bin/env python3
"""Fold SVG files into an HTML page's figure anchors, editing in place and repeatably.

    <!-- figure: packet-path src=diagrams/packet-path.svg -->
    <!-- /figure: packet-path -->

Every diagram mermaid emits is rooted at an element called `my-svg` and dressed by
`#my-svg` rules, so dropping two of them in untouched lets whichever definitions came
first take over, and the figures after it wear somebody else's colours and markers.
"""

import re
import sys
from collections import Counter
from pathlib import Path


def _unique_id_prefix(figure_name: str, occurrence: int) -> str:
    return f"fig-{figure_name}-{occurrence}-"  # no CSS id selector may open with a digit


def _stripped_of_document_prologue(svg: str) -> str:
    return re.sub(r"<\?xml.*?\?>|<!DOCTYPE[^>]*>", "", svg, flags=re.DOTALL).strip()


def _qualified_ids(svg: str, prefix: str) -> str:
    declared: list[str] = re.findall(r'\bid="([^"]+)"', svg)
    alternatives = "|".join(re.escape(d) for d in sorted(set(declared), key=len, reverse=True))
    renamed = re.sub(rf'\bid="({alternatives})"', rf'id="{prefix}\1"', svg)
    pointing_at_one = rf"#({alternatives})(?![\w:.-])"  # url(#x), href="#x", "#x{{", "#x "
    return re.sub(pointing_at_one, rf"#{prefix}\1", renamed)


def _fitted_to_text_column(svg: str) -> str:
    root_tag = svg[: svg.index(">") + 1]
    natural_width = root_tag.split('viewBox="')[1].split(" ")[2]
    fluid_root_tag = re.sub(
        r'\s(?:width|height)="[^"]*"', "", root_tag
    )  # the ratio rides in viewBox
    fluid_root_tag = fluid_root_tag.replace("<svg", '<svg width="100%"', 1)
    rest = fluid_root_tag + svg[len(root_tag) :]
    return f'<div style="max-width:{natural_width}px">{rest}</div>'


def _repeated_ids(html: str) -> list[str]:
    declared: list[str] = re.findall(r'\sid="([^"]+)"', html)
    return sorted(one for one, times in Counter(declared).items() if times > 1)


def _inline_figures(page: Path) -> int:
    occurrences: dict[str, int] = {}

    def filled(anchor: re.Match[str]) -> str:
        name, src = anchor.group("name"), anchor.group("src")
        occurrences[name] = occurrences.get(name, 0) + 1
        svg = _stripped_of_document_prologue((page.parent / src).read_text())
        svg = _qualified_ids(svg, _unique_id_prefix(name, occurrences[name]))
        figure = _fitted_to_text_column(svg)
        return f"<!-- figure: {name} src={src} -->\n{figure}\n<!-- /figure: {name} -->"

    bundled, inlined = re.subn(
        r"""<!--\s*figure:\s*(?P<name>[\w.-]+)\s+src=(?P<src>[^\s>]+)\s*-->
            .*?
            <!--\s*/figure:\s*(?P=name)\s*-->""",
        filled,
        page.read_text(),
        flags=re.DOTALL | re.VERBOSE,
    )
    shared = _repeated_ids(bundled)
    if shared:
        raise ValueError(f"the bundled page declares these ids twice: {', '.join(shared)}")

    _ = page.write_text(bundled)
    return inlined


if __name__ == "__main__":
    page_path = Path(sys.argv[1])
    print(f"inlined {_inline_figures(page_path)} figures into {page_path}")
