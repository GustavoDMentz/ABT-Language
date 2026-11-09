#!/usr/bin/env python3
"""Remove only a verified per-user ABT installation."""
from install import uninstall

if __name__ == "__main__":
    try:
        uninstall()
    except (OSError, ValueError) as exc:
        import sys
        print(f"ABT: {exc}", file=sys.stderr)
        sys.exit(2)
