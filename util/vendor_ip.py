#!/usr/bin/env python3
"""
vendor_ip.py -- copy upstream IP into vendor/ at a pinned commit.

This is the same methodology lowRISC documents for OpenTitan's hw/vendor
(util/vendor.py): upstream code is *copied in*, not submoduled, so one clone of
qsoc gives every file at a frozen, auditable state -- no --recursive, no
detached HEAD, no gigabyte checkout. See vendor/manifest.yml for why.

For each upstream in vendor/manifest.yml this tool:
  1. clones the upstream repo to a temp dir at the recorded `commit:` (or, with
     --update, at the branch/ref and then resolves the SHA it landed on),
  2. copies either the listed `files:` (glob-aware) or the whole tree,
  3. NEVER copies the upstream .git -- the temp clone is thrown away,
  4. applies any patches in vendor/patches/<vendor>_<repo>/*.patch in order,
  5. records the resolved SHA in vendor/vendor.lock.yml and writes it back into
     the manifest `commit:` field so the import is reproducible.

Usage:
  vendor_ip.py --list                       # show what would be done
  vendor_ip.py NAME [NAME ...]              # vendor specific upstream(s)
  vendor_ip.py --all                        # vendor every non-skipped upstream
  vendor_ip.py NAME --update                # move to the ref's current tip and re-pin
  vendor_ip.py NAME --ref <sha|branch|tag>  # vendor at an explicit ref, then pin

By default an upstream whose `commit:` is still "TODO" is vendored at its
default branch and the resolved SHA is pinned. Pass --ref to be explicit.

`license: UNRESOLVED` upstreams are skipped unless --allow-unresolved is given,
so undefined-licence code is never copied in by accident.
"""
from __future__ import annotations

import argparse
import fnmatch
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

REPO = Path(__file__).resolve().parent.parent
MANIFEST = REPO / "vendor" / "manifest.yml"
LOCKFILE = REPO / "vendor" / "vendor.lock.yml"
PATCH_ROOT = REPO / "vendor" / "patches"
TODO = "TODO"


# --- helpers ---------------------------------------------------------------
def run(cmd, cwd=None, check=True):
    return subprocess.run(cmd, cwd=cwd, check=check, text=True,
                          capture_output=True)


def target_dir(name: str) -> Path:
    """`pulp-platform/timer_unit` -> vendor/pulp-platform/timer_unit."""
    vendor, _, repo = name.partition("/")
    return REPO / "vendor" / vendor.lower() / repo


def patch_dir(name: str) -> Path:
    """Patches live in vendor/patches/<vendor>_<repo>/."""
    vendor, _, repo = name.partition("/")
    return PATCH_ROOT / f"{vendor.lower()}_{repo}"


def load_manifest() -> dict:
    return yaml.safe_load(MANIFEST.read_text())


def dump_manifest(data: dict) -> None:
    # Preserve the leading comment block: rewrite only the `upstreams:` body.
    text = MANIFEST.read_text()
    marker = "\nupstreams:\n"
    head = text[: text.index(marker) + len(marker)]
    body = yaml.safe_dump({"upstreams": data["upstreams"]},
                          sort_keys=False, default_flow_style=False,
                          width=100).split("upstreams:\n", 1)[1]
    MANIFEST.write_text(head + body)


def load_lock() -> dict:
    if LOCKFILE.exists():
        return yaml.safe_load(LOCKFILE.read_text()) or {}
    return {}


def write_lock(lock: dict) -> None:
    header = (
        "# Lock file for vendored IP -- DO NOT EDIT BY HAND.\n"
        "# Written by util/vendor_ip.py. Records the exact upstream commit each\n"
        "# vendored tree was imported from, so the import is reproducible. Commit\n"
        "# this together with the vendored files and vendor/manifest.yml.\n\n"
    )
    LOCKFILE.write_text(header + yaml.safe_dump(lock, sort_keys=True,
                                                default_flow_style=False))


# --- core ------------------------------------------------------------------
def copy_tree(src: Path, dst: Path, files: list[str] | None) -> int:
    """Copy from a clone into the vendor target. Never copies .git."""
    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True)
    copied = 0

    if not files:
        # Whole repo minus .git
        for item in src.iterdir():
            if item.name == ".git":
                continue
            target = dst / item.name
            if item.is_dir():
                shutil.copytree(item, target,
                                ignore=shutil.ignore_patterns(".git"))
            else:
                shutil.copy2(item, target)
            copied += 1
        return copied

    # Selective: each entry may be an exact path, a glob, or a dir / "dir/**".
    # Resolve src once so every path we compare is under the same real prefix
    # (on macOS /var/folders is a symlink to /private/var/folders, and mixing
    # resolved and unresolved paths breaks Path.relative_to).
    src = src.resolve()
    all_files = [p for p in src.rglob("*")
                 if p.is_file() and ".git/" not in str(p.relative_to(src)) + "/"]
    seen: set[Path] = set()
    for pattern in files:
        pat = pattern.rstrip("/")
        matched = []
        base = (src / pat.replace("/**", "")).resolve()
        if base.is_dir():
            matched = [p for p in base.rglob("*") if p.is_file()]
        else:
            for p in all_files:
                rel = str(p.relative_to(src))
                if fnmatch.fnmatch(rel, pat) or fnmatch.fnmatch(rel, pat + "/*"):
                    matched.append(p)
        if not matched:
            print(f"      WARNING: pattern matched nothing: {pattern}")
        for p in matched:
            if p in seen:
                continue
            seen.add(p)
            rel = p.relative_to(src)
            out = dst / rel
            out.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, out)
            copied += 1
    return copied


def apply_patches(name: str, dst: Path) -> int:
    pdir = patch_dir(name)
    if not pdir.is_dir():
        return 0
    patches = sorted(pdir.glob("*.patch"))
    for patch in patches:
        print(f"      applying patch {patch.name}")
        # -p1, relative to the vendored dir, same rules as lowRISC vendor.py
        run(["git", "apply", "-p1", "--directory",
             str(dst.relative_to(REPO)), str(patch)], cwd=REPO)
    return len(patches)


def vendor_one(entry: dict, lock: dict, *, ref: str | None,
               update: bool, allow_unresolved: bool) -> bool:
    name = entry["name"]
    url = entry["url"]
    lic = entry.get("license")

    if lic == "UNRESOLVED" and not allow_unresolved:
        print(f"  SKIP {name}: license UNRESOLVED "
              f"(pass --allow-unresolved to override)")
        return False

    # Decide the ref to fetch.
    pinned = entry.get("commit")
    if ref:
        fetch_ref = ref
    elif update or not pinned or pinned == TODO:
        fetch_ref = None  # default branch
    else:
        fetch_ref = pinned

    dst = target_dir(name)
    print(f"  {name}")
    print(f"      url    {url}")
    print(f"      ref    {fetch_ref or '(default branch)'}")

    with tempfile.TemporaryDirectory() as tmp:
        clone = Path(tmp) / "clone"
        is_sha = bool(fetch_ref) and len(fetch_ref) == 40 and \
            all(c in "0123456789abcdef" for c in fetch_ref.lower())
        if is_sha:
            # Shallow fetch the exact commit only -- no history, no other refs.
            # Keeps gigabyte-scale repos (OpenTitan) to just the tree we need.
            run(["git", "init", "--quiet", str(clone)])
            run(["git", "remote", "add", "origin", url], cwd=clone)
            run(["git", "fetch", "--quiet", "--depth", "1", "origin", fetch_ref],
                cwd=clone)
            run(["git", "checkout", "--quiet", "FETCH_HEAD"], cwd=clone)
        elif fetch_ref:
            # A branch/tag: shallow clone that ref.
            run(["git", "clone", "--quiet", "--depth", "1", "--branch",
                 fetch_ref, url, str(clone)])
        else:
            # Default branch, shallow.
            run(["git", "clone", "--quiet", "--depth", "1", url, str(clone)])
        resolved = run(["git", "rev-parse", "HEAD"], cwd=clone).stdout.strip()
        print(f"      commit {resolved}")

        n = copy_tree(clone, dst, entry.get("files"))
        print(f"      copied {n} item(s) into {dst.relative_to(REPO)}")

    npatch = apply_patches(name, dst)
    if npatch:
        print(f"      {npatch} patch(es) applied")

    # Record: manifest commit + lock file.
    entry["commit"] = resolved
    lock[name] = {"url": url, "commit": resolved}
    return True


def main() -> int:
    ap = argparse.ArgumentParser(description="Vendor upstream IP into vendor/.")
    ap.add_argument("names", nargs="*", help="upstream name(s) to vendor")
    ap.add_argument("--all", action="store_true", help="vendor every upstream")
    ap.add_argument("--list", action="store_true", help="list upstreams, do nothing")
    ap.add_argument("--update", action="store_true",
                    help="move to the ref's current tip and re-pin the SHA")
    ap.add_argument("--ref", help="explicit sha/branch/tag to vendor at")
    ap.add_argument("--allow-unresolved", action="store_true",
                    help="also vendor upstreams whose license is UNRESOLVED")
    args = ap.parse_args()

    data = load_manifest()
    upstreams = {u["name"]: u for u in data["upstreams"]}

    if args.list:
        for u in data["upstreams"]:
            c = u.get("commit")
            state = "pinned" if c and c != TODO else "TODO"
            print(f"  {u['name']:45} {state:7} {u.get('license')}")
        return 0

    if args.all:
        targets = list(upstreams)
    elif args.names:
        targets = args.names
        unknown = [n for n in targets if n not in upstreams]
        if unknown:
            sys.exit(f"unknown upstream(s): {', '.join(unknown)}")
    else:
        ap.error("give upstream name(s), or --all, or --list")

    if args.ref and len(targets) != 1:
        sys.exit("--ref only makes sense with exactly one upstream")

    lock = load_lock()
    done = 0
    for name in targets:
        if vendor_one(upstreams[name], lock, ref=args.ref,
                      update=args.update,
                      allow_unresolved=args.allow_unresolved):
            done += 1

    if done:
        dump_manifest(data)
        write_lock(lock)
        print(f"\nVendored {done} upstream(s). Updated vendor/manifest.yml and "
              f"vendor/vendor.lock.yml.")
        print("Review, then: git add -A vendor/ && commit (via a PR).")
    else:
        print("\nNothing vendored.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
