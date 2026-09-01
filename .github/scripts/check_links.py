#!/usr/bin/env python3
"""Check that every link in the tutorial points at something real.

Two classes of link, two failure modes this project has actually hit:

  relative   Links between lessons and into docs/archive/. These break when a
             lesson is renamed or archived, which has happened twice.

  code       Links into the application repository, of the form
             github.com/ephbaum/elxrBB/blob/main/<path>. These break when a
             lesson describes code that has not been merged yet -- which is
             the exact failure this tutorial's rule exists to prevent. A red
             build here means either the application branch has not landed or
             the lesson is ahead of the code.

Usage:
    check_links.py            # relative links only
    check_links.py --remote   # also verify links into the application repo
"""

import os
import re
import sys
import urllib.error
import urllib.request

LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
CODE_LINK = re.compile(
    r"^https://github\.com/ephbaum/elxrBB/(?:blob|tree)/(?P<ref>[^/]+)/(?P<path>.+)$"
)
SKIP_DIRS = {".git", ".github", "node_modules"}


def markdown_files(root="."):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if name.endswith(".md"):
                yield os.path.join(dirpath, name)


def links_in(path):
    with open(path, encoding="utf-8") as handle:
        for match in LINK.finditer(handle.read()):
            yield match.group(1)


def check_relative(path, target):
    """Return an error string, or None if the target resolves on disk."""
    target = target.split("#", 1)[0]
    if not target:
        return None
    resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
    if os.path.exists(resolved):
        return None
    return f"{path}: {target} does not exist"


def check_code(path, url):
    """Return an error string, or None if the file exists in the app repo."""
    match = CODE_LINK.match(url)
    if not match:
        return None

    request = urllib.request.Request(url, method="HEAD")
    request.add_header("User-Agent", "elxrBB-tutorial link check")
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            if response.status == 200:
                return None
            return f"{path}: {url} returned HTTP {response.status}"
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return (
                f"{path}: {url} is a 404 -- the code this lesson describes is "
                f"not on '{match.group('ref')}' yet"
            )
        return f"{path}: {url} returned HTTP {error.code}"
    except urllib.error.URLError as error:
        return f"{path}: could not reach {url} ({error.reason})"


def main(argv):
    remote = "--remote" in argv
    errors = []
    counts = {"relative": 0, "code": 0}

    for path in sorted(markdown_files()):
        for target in links_in(path):
            if target.startswith(("#", "mailto:")):
                continue

            if target.startswith("http"):
                if not remote:
                    continue
                if CODE_LINK.match(target):
                    counts["code"] += 1
                    if error := check_code(path, target):
                        errors.append(error)
                continue

            counts["relative"] += 1
            if error := check_relative(path, target):
                errors.append(error)

    checked = f"{counts['relative']} relative"
    if remote:
        checked += f", {counts['code']} into the application repo"
    print(f"checked {checked}")

    for error in errors:
        print(f"  BROKEN  {error}")

    if errors:
        print(f"\n{len(errors)} broken link(s)")
        return 1

    print("all links resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
