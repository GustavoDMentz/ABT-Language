#!/usr/bin/env python3
"""Gera gráficos SVG sem dependências externas a partir das medições brutas."""
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent / "benchmarks" / "scalability"
rows = json.loads((HERE / "results.json").read_text())
groups = defaultdict(list)
for row in rows:
    if row["status"] == "pass":
        groups[row["mode"], row["n"]].append(row)


def chart(filename, field, title, unit, scale):
    width, height = 900, 500
    left, top, right, bottom = 94, 45, 35, 75
    w, h = width-left-right, height-top-bottom
    xs = [100, 1000, 10000, 100000]
    vals = [statistics.median([r[field] for r in g]) * scale for g in groups.values()]
    upper = math.ceil(max(vals) / (5 if field == "real_s" else 50)) * (5 if field == "real_s" else 50)
    upper = max(upper, 1)
    x = lambda n: left + (math.log10(n)-2)/3*w
    y = lambda v: top+h-v/upper*h
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" role="img" aria-label="{title}">',
             '<rect width="100%" height="100%" fill="white"/>',
             f'<text x="{width/2}" y="27" text-anchor="middle" font-family="sans-serif" font-size="20">{title}</text>']
    for i in range(6):
        v = upper*i/5
        yy = y(v)
        parts += [f'<line x1="{left}" y1="{yy:.1f}" x2="{width-right}" y2="{yy:.1f}" stroke="#ddd"/>',
                  f'<text x="{left-12}" y="{yy+5:.1f}" text-anchor="end" font-family="sans-serif" font-size="14">{v:g}</text>']
    for n in xs:
        xx=x(n)
        parts += [f'<line x1="{xx:.1f}" y1="{top}" x2="{xx:.1f}" y2="{top+h}" stroke="#eee"/>',
                  f'<text x="{xx:.1f}" y="{top+h+25}" text-anchor="middle" font-family="sans-serif" font-size="14">{n:,}</text>']
    parts += [f'<text x="{width/2}" y="{height-15}" text-anchor="middle" font-family="sans-serif" font-size="15">Incrementos sequenciais (escala log)</text>',
              f'<text transform="translate(22 {height/2}) rotate(-90)" text-anchor="middle" font-family="sans-serif" font-size="15">{unit}</text>']
    for mode, color in (("min", "#1764b1"), ("all", "#cf472e")):
        pts=[]
        for n in xs:
            g=groups.get((mode,n))
            if g:
                pts.append((x(n),y(statistics.median([r[field] for r in g])*scale)))
        parts.append(f'<polyline points="{" ".join(f"{a:.1f},{b:.1f}" for a,b in pts)}" fill="none" stroke="{color}" stroke-width="3"/>')
        for a,b in pts:
            parts.append(f'<circle cx="{a:.1f}" cy="{b:.1f}" r="5" fill="{color}"/>')
        legend_y=62 if mode=="min" else 86
        parts += [f'<line x1="{width-155}" y1="{legend_y}" x2="{width-130}" y2="{legend_y}" stroke="{color}" stroke-width="3"/>',
                  f'<text x="{width-120}" y="{legend_y+5}" font-family="sans-serif" font-size="14">compile={mode}</text>']
    parts += [f'<text x="{x(100000):.1f}" y="{top+h-12}" text-anchor="end" font-family="sans-serif" font-size="12" fill="#7a3333">100.000: falha de validação</text>', '</svg>']
    (HERE / filename).write_text("\n".join(parts)+"\n")


chart("tempo.svg", "real_s", "Tempo real × incrementos", "Tempo real (s)", 1)
chart("memoria.svg", "rss_kb", "Pico de RSS × incrementos", "RSS do processo (MiB)", 1/1024)
