---
name: local-user-mermaid-diagrams
description: Author diagrams as mermaid sources, render them to SVG, and embed the SVG in an HTML page that depends on no other file. Use when a document needs diagrams.
---

# Diagrams that travel inside the page

Edit the `.mmd` file; treat the SVG as a build artifact; fold that SVG into the HTML so the finished page carries no companion files.

## Rendering

```bash
echo '{"args":["--no-sandbox","--disable-dev-shm-usage","--disable-gpu"]}' > $TMPDIR/pptr.json
echo '{"htmlLabels":false,"flowchart":{"htmlLabels":false},"themeVariables":{"fontFamily":"DejaVu Sans, Arial, sans-serif"}}' > $TMPDIR/mermaid.json
nix-shell --pure -p mermaid-cli --run "mmdc -p $TMPDIR/pptr.json -c $TMPDIR/mermaid.json -i diagram.mmd -o diagram.svg -b white"
```

## Getting the SVG into the page

Reserve each figure's place with two anchor comments and leave the filling to the script:

```html
<h2>Packet path</h2>
<!-- figure: packet-path src=diagrams/packet-path.svg -->
<!-- /figure: packet-path -->
```

```bash
python3 scripts/bundle_svg.py page.html
```

Because `src` resolves against the page's own directory and the anchors are left in place afterwards, the command is safe to repeat — do so whenever you have re-rendered.

## Shape

Choose proportions that suit a document. One long `LR` chain fares badly in a column of text; `flowchart TB` whose subgraphs each carry `direction LR` fares much better, since a diagram three thousand pixels across demands sideways scrolling that plenty of viewers simply refuse.

Keep the graph acyclic. It only takes one edge doubling back — the "return path" — to send an `LR` layout zigzagging over the page. Hang that kind of remark off the final node instead, via `~~~` or a dotted edge.

## Checking it

Syntax is all that parsing can confirm. Whether the fills, the colours and the arrangement came through is something you learn by rendering. So capture the finished page and study the image:

```bash
nix-shell --pure -p chromium --run 'chromium --headless --no-sandbox --disable-gpu --screenshot=shot.png --window-size=900,1600 page.html'
```

Every label has to be SVG text. Sanitizers and strict viewers throw HTML labels away and hand you empty boxes:

```bash
{ grep -o '<foreignObject' diagram.svg || true; } | wc -l   # must be 0
```
