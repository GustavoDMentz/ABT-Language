#!/usr/bin/env python3
"""Reject personal filesystem paths and credential-shaped strings in tracked text."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
PATTERNS = {
    "Linux home": re.compile(r"/home/[A-Za-z0-9_-]+(?:/|\b)"),
    "macOS home": re.compile(r"/Users/[A-Za-z0-9_-]+(?:/|\b)"),
    "Windows home": re.compile(r"[A-Za-z]:\\Users\\[^\\\s]+", re.I),
    "GitHub token": re.compile(r"\b(?:ghp_|github_pat_)[A-Za-z0-9_]+"),
}

def main():
    paths = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    problems = []
    for name in filter(None, paths):
        path = ROOT / name
        if not path.is_file():
            continue
        try:
            content = path.read_text()
        except UnicodeError:
            continue
        for label, pattern in PATTERNS.items():
            for match in pattern.finditer(content):
                line = content.count("\n", 0, match.start()) + 1
                problems.append(f"{name}:{line}: {label}")
    print("\n".join(problems) if problems else "Privacy check passed: no personal paths or token-shaped strings in tracked text.")
    return bool(problems)

if __name__ == "__main__":
    raise SystemExit(main())
