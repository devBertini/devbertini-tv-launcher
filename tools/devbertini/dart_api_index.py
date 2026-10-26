#!/usr/bin/env python3
"""Prints the public declarations of Dart files, without bodies: what agents working in parallel call, in one
context pack, instead of each reading the same sources (skill agents-and-models, references/brief.md, section 3).

    python -B tools/devbertini/dart_api_index.py lib/devbertini/vitrine lib/providers/watch_next_service.dart ...

For each file: its top-level classes, mixins, enums, extensions, typedefs, functions and constants, and inside each
class its public constructors, fields, getters, setters and methods, each on one line with the first line of its doc
comment. Private names (a leading underscore) and bodies are left out. A line-based reading of formatted code (as
dart format writes it), not a parser: a signature that spans lines is joined until its body or its end.
"""
import pathlib
import re
import sys

TOP = re.compile(r"^(?:abstract\s+|sealed\s+|base\s+|final\s+|interface\s+|mixin\s+)*(class|mixin|enum|extension|typedef)\s+([A-Za-z]\w*)")
TOP_MEMBER = re.compile(r"^(?:const|final|var|late|[A-Za-z][\w<>,?\s\.\(\)\[\]]*?)\s+([A-Za-z]\w*)\s*(?:=|\(|;)")
MEMBER = re.compile(r"^  (?!_)(?:@\w+\s+)*((?:static|final|const|late|factory|external|abstract|covariant)\s+)*[A-Za-z]")


def joined(lines, i):
    """The declaration starting at line i, up to its body, its arrow or its end: the first '{', '=>' or ';' outside
    its parentheses and brackets (so named parameters in braces stay), joined over at most 12 lines."""
    text = ""
    for line in lines[i:i + 12]:
        text += " " + re.sub(r"//.*$", "", line.strip())
        depth = 0
        for j, ch in enumerate(text):
            if ch in "([<":
                depth += 1
            elif ch in ")]>" and depth > 0:
                depth -= 1
            elif depth == 0 and (ch in "{;" or text.startswith("=>", j)):
                return re.sub(r"\s+", " ", text[:j]).strip()
    return re.sub(r"\s+", " ", text).strip()


def public(name):
    return not name.startswith("_")


def index(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    out = []
    doc = ""
    depth = 0
    in_class = None
    for i, raw in enumerate(lines):
        stripped = raw.strip()
        if stripped.startswith("///"):
            if not doc:
                doc = stripped[3:].strip()
            continue
        if depth == 0:
            m = TOP.match(raw)
            if m:
                in_class = m.group(2) if public(m.group(2)) else None
                if in_class:
                    out.append(joined(lines, i) + (f"   // {doc}" if doc else ""))
            elif raw and not raw.startswith((" ", "}", "import", "export", "part", "library", "//", "/*", "*", "@")):
                m2 = TOP_MEMBER.match(raw)
                if m2 and public(m2.group(1)):
                    out.append(joined(lines, i) + (f"   // {doc}" if doc else ""))
        elif depth == 1 and in_class and MEMBER.match(raw):
            sig = joined(lines, i)
            name = re.search(r"([A-Za-z_]\w*)\s*(?:\(|=|$|;)", re.sub(r"\b(get|set|operator)\s+", "", sig))
            if not sig.startswith(("return", "if ", "for ", "super", "assert")) and not (name and name.group(1).startswith("_")):
                out.append("    " + sig + (f"   // {doc}" if doc else ""))
        doc = "" if stripped and not stripped.startswith("@") else doc
        # Braces outside strings and comments, roughly: enough for formatted code.
        code = re.sub(r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"|//.*$", "", raw)
        depth += code.count("{") - code.count("}")
        if depth <= 0:
            depth = 0
            if stripped.startswith("}"):
                in_class = None
    return out


def main(args):
    sys.stdout.reconfigure(encoding="utf-8")
    files = []
    for arg in args:
        p = pathlib.Path(arg)
        files.extend(sorted(p.rglob("*.dart")) if p.is_dir() else [p])
    for f in files:
        decls = index(f)
        if decls:
            print(f"## {f.as_posix()}")
            print("\n".join(decls))
            print()


if __name__ == "__main__":
    main(sys.argv[1:])
