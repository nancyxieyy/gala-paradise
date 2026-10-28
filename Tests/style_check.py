#!/usr/bin/env python3
"""Check task 001 source widths and optionally compare lexical tokens to a git ref.

Only whitespace outside literals/comments and Swift statement semicolons are
ignored. No trailing commas, parentheses, identifiers, comments, literal text,
or other tokens are normalized. String interpolation is kept as part of its
literal, including the expression's exact spelling and whitespace.
"""

import argparse
from dataclasses import dataclass
import pathlib
import re
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
LIMIT = 120


@dataclass(frozen=True)
class Token:
    kind: str
    text: str
    start: int
    end: int


class Lexer:
    """Small Swift/C# lexer that preserves literal and comment payloads verbatim.

    Handles escaped, multiline, raw and verbatim strings, character literals,
    nested Swift block comments, and nested literals inside interpolations.
    It does not parse or rewrite expressions.
    """

    def __init__(self, source, language):
        self.source = source
        self.language = language

    def comment_end(self, start):
        text = self.source
        if text.startswith("//", start):
            end = text.find("\n", start)
            return len(text) if end < 0 else end
        depth = 1
        cursor = start + 2
        while cursor < len(text):
            if self.language == "swift" and text.startswith("/*", cursor):
                depth += 1
                cursor += 2
            elif text.startswith("*/", cursor):
                depth -= 1
                cursor += 2
                if depth == 0:
                    return cursor
            else:
                cursor += 1
        raise ValueError(f"Unterminated block comment at offset {start}")

    def interpolation_end(self, start, opening, closing):
        text = self.source
        depth = 1
        cursor = start
        while cursor < len(text):
            if text.startswith(("//", "/*"), cursor):
                cursor = self.comment_end(cursor)
                continue
            literal = self.literal_end(cursor)
            if literal is not None:
                cursor = literal
                continue
            if text.startswith(opening, cursor):
                depth += 1
                cursor += len(opening)
            elif text.startswith(closing, cursor):
                depth -= 1
                cursor += len(closing)
                if depth == 0:
                    return cursor
            else:
                cursor += 1
        raise ValueError(f"Unterminated interpolation at offset {start}")

    def literal_end(self, start):
        text = self.source
        if self.language == "swift":
            match = re.match(r'(#{0,})"', text[start:])
        else:
            match = re.match(r'(?:\$+@?|@\$?)?["\']', text[start:])
        if not match:
            return None
        prefix = match.group()[:-1]
        quote = match.group()[-1]
        quote_start = start + len(prefix)
        quote_count = 1
        if quote == '"' and text.startswith('"""', quote_start):
            quote_count = 3
            if self.language == "cs":
                while text.startswith('"' * (quote_count + 1), quote_start):
                    quote_count += 1
        delimiter = quote * quote_count
        suffix = prefix if self.language == "swift" else ""
        raw_cs = self.language == "cs" and quote_count >= 3
        verbatim = "@" in prefix and self.language == "cs"
        interpolated_cs = "$" in prefix and self.language == "cs"
        escape = "\\" + suffix
        cursor = quote_start + quote_count
        while cursor < len(text):
            if verbatim and text.startswith('""', cursor):
                cursor += 2
                continue
            if text.startswith(delimiter + suffix, cursor):
                return cursor + len(delimiter + suffix)
            if self.language == "swift" and text.startswith(escape + "(", cursor):
                cursor = self.interpolation_end(cursor + len(escape) + 1, "(", ")")
                continue
            if interpolated_cs and text[cursor] == "{":
                braces = prefix.count("$") if raw_cs else 1
                marker = "{" * braces
                if not raw_cs and text.startswith("{{", cursor):
                    cursor += 2
                    continue
                if text.startswith(marker, cursor):
                    cursor = self.interpolation_end(cursor + braces, marker, "}" * braces)
                    continue
            if not raw_cs and not verbatim and text.startswith(escape, cursor):
                cursor += len(escape) + 1
            else:
                cursor += 1
        raise ValueError(f"Unterminated literal at offset {start}")

    def tokens(self):
        text = self.source
        cursor = 0
        while cursor < len(text):
            if text[cursor].isspace():
                cursor += 1
                continue
            start = cursor
            if text.startswith(("//", "/*"), cursor):
                cursor = self.comment_end(cursor)
                kind = "comment"
            else:
                literal = self.literal_end(cursor)
                if literal is not None:
                    cursor = literal
                    kind = "literal"
                elif text[cursor] == "`" and self.language == "swift":
                    end = text.find("`", cursor + 1)
                    if end < 0:
                        raise ValueError(f"Unterminated identifier at offset {cursor}")
                    cursor = end + 1
                    kind = "identifier"
                else:
                    match = re.match(
                        r'(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][+-]?\d+)?[\w]*'
                        r'|[\w@$]+|.', text[cursor:]
                    )
                    cursor += len(match.group()) if match else 1
                    kind = "code"
            yield Token(kind, text[start:cursor], start, cursor)


def normalized(source, language):
    """Keep lexical atoms and payloads in their original order.

    Punctuation is compared character by character: Swift uses the same glyphs
    for optional suffixes, generic delimiters and operators, and a whitespace
    formatter can separate adjacent glyphs without changing their spelling.
    Identifiers/numbers remain whole so merging names cannot pass this check.

    >>> normalized('let x=1;', 'swift') == normalized('let x = 1', 'swift')
    True
    >>> normalized('int x=1;', 'cs') == normalized('int x = 1;', 'cs')
    True
    >>> normalized('int x=1;', 'cs') == normalized('int x=1', 'cs')
    False
    >>> normalized('let x="a b"', 'swift') == normalized('let x="ab"', 'swift')
    False
    >>> normalized('// keep  this', 'swift') == normalized('// keep this', 'swift')
    False
    >>> normalized('let x=1.2', 'swift') == normalized('let x=1.3', 'swift')
    False
    >>> normalized('let x=1', 'swift') == normalized('letx=1', 'swift')
    False
    >>> normalized('x + y', 'cs') == normalized('x - y', 'cs')
    False
    """
    # The only non-whitespace normalization: Swift permits an optional ';'
    # between statements. C# semicolons are mandatory and are never ignored.
    return [
        (token.kind, token.text)
        for token in Lexer(source, language).tokens()
        if not (language == "swift" and token.kind == "code" and token.text == ";")
    ]


def source_paths():
    paths = list((ROOT / "Sources").glob("*.swift"))
    paths += list((ROOT / "Windows").glob("*.cs"))
    paths += [ROOT / name for name in (
        "Tests/WorldTests.swift", "Tests/Simulation/main.swift",
        "Tests/CoreTests/Program.cs", "Tests/Simulation/Program.cs",
    )]
    return sorted(paths)


def width_errors(path):
    source = path.read_text(encoding="utf-8")
    literals = [t for t in Lexer(source, path.suffix[1:]).tokens() if t.kind == "literal"]
    offset = 0
    errors = []
    for number, line in enumerate(source.splitlines(keepends=True), 1):
        content = line.rstrip("\r\n")
        width = len(content.expandtabs(4))
        if width > LIMIT:
            begin = offset + len(content) - len(content.lstrip())
            end = offset + len(content.rstrip())
            # A long line is exempt only when ONE literal covers at least 80%
            # of its nonindent text, and the remaining code fits within 120.
            # Multiple short literals on a dense code line do not qualify.
            exempt = False
            for literal in literals:
                covered = max(0, min(end, literal.end) - max(begin, literal.start))
                if covered >= (end - begin) * 0.8 and width - covered <= LIMIT:
                    exempt = True
                    break
            if not exempt:
                errors.append(f"{path.relative_to(ROOT)}:{number}: {width} columns (limit {LIMIT})")
        offset += len(line)
    return errors


def equivalent_errors(base):
    subprocess.run(["git", "rev-parse", "--verify", base + "^{commit}"], cwd=ROOT,
                   check=True, stdout=subprocess.DEVNULL)
    changed = subprocess.check_output(
        ["git", "diff", "--name-only", "-z", base, "--", "*.swift", "*.cs"], cwd=ROOT
    ).decode().split("\0")
    errors = []
    count = 0
    for name in filter(None, changed):
        before = subprocess.run(["git", "show", f"{base}:{name}"], cwd=ROOT,
                                capture_output=True, text=True)
        path = ROOT / name
        if before.returncode or not path.is_file():
            errors.append(f"{name}: added/deleted source has no equivalent base file")
            continue
        language = path.suffix[1:]
        left = normalized(before.stdout, language)
        right = normalized(path.read_text(encoding="utf-8"), language)
        count += 1
        if left != right:
            index = next((i for i, pair in enumerate(zip(left, right)) if pair[0] != pair[1]),
                         min(len(left), len(right)))
            old = left[index] if index < len(left) else "<end>"
            new = right[index] if index < len(right) else "<end>"
            errors.append(f"{name}: token {index + 1} differs: {old!r} -> {new!r}")
    return errors, count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--equivalent", metavar="BASE_REF", help="also compare tokens with this git ref")
    args = parser.parse_args()
    try:
        paths = source_paths()
        errors = [error for path in paths for error in width_errors(path)]
        if not errors:
            print(f"PASS line width: {len(paths)} files; limit {LIMIT} (single-literal lines excepted)")
        if args.equivalent:
            differences, count = equivalent_errors(args.equivalent)
            errors.extend(differences)
            if not differences:
                print(f"PASS token equivalence: {count} changed Swift/C# files vs {args.equivalent}")
                print("Normalization: whitespace outside literals/comments; Swift statement semicolons only.")
        for error in errors:
            print(error, file=sys.stderr)
        return 1 if errors else 0
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Style check failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
