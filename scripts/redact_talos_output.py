#!/usr/bin/env python3
"""Redact sensitive values from talosctl dry-run output for PR comments."""

import re
import sys

KEY_LINE = re.compile(r"^(\s*)([A-Za-z0-9_.-]+):\s*(.+)$")
SENSITIVE_KEY = re.compile(
    r"(?i)(token|secret|password|key|crt|cert|certificate|ca|secretbox|bootstrap|private|public)"
)
BASE64_VALUE = re.compile(r"[A-Za-z0-9+/=]{40,}")


def should_redact(key: str, value: str) -> bool:
    if SENSITIVE_KEY.search(key):
        return True
    trimmed = value.strip().strip('"').strip("'")
    return bool(BASE64_VALUE.fullmatch(trimmed))


def redact_value(value: str) -> str:
    stripped = value.strip()
    if stripped.startswith('"') and stripped.endswith('"'):
        return '"<redacted>"'
    if stripped.startswith("'") and stripped.endswith("'"):
        return "'<redacted>'"
    return "<redacted>"


def redact_line(line: str) -> str:
    if BASE64_VALUE.search(line):
        return BASE64_VALUE.sub("<redacted>", line)
    return line


def main() -> int:
    for raw in sys.stdin:
        line = raw.rstrip("\n")
        if line.startswith("+++") or line.startswith("---"):
            print(line)
            continue
        prefix = ""
        content = line
        if line.startswith("+") or line.startswith("-"):
            prefix = line[0]
            content = line[1:]
        match = KEY_LINE.match(content)
        if match:
            indent, key, value = match.groups()
            if should_redact(key, value):
                print(f"{prefix}{indent}{key}: {redact_value(value)}")
            else:
                print(line)
            continue
        print(prefix + redact_line(content) if prefix else redact_line(content))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
