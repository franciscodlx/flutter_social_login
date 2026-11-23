"""Tags the packages whose pubspec version is not on pub.dev yet.

pub.dev only accepts automated publishing from a workflow started by a tag push,
so this script pushes `<package>-v<version>` (publish.yml does the publishing)
and waits for pub.dev to list that version before tagging the next package:
packages go in dependency order, so the core is there before the providers.

    python3 .github/scripts/release.py          only print the plan (PRs)
    python3 .github/scripts/release.py --push   tag, push and wait (release workflow)
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PACKAGES = os.path.join(ROOT, "packages")
WAIT_SECONDS = 20 * 60


def read_pubspec(path):
    """name, version, publishable and the hosted dependencies of a pubspec (no YAML library needed)."""
    name = version = None
    publishable = True
    deps = set()
    section = None
    for line in open(path, encoding="utf-8"):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        top = re.match(r"^(\w+):\s*(.*?)\s*$", line)
        if top:
            section = top.group(1)
            if section == "name":
                name = top.group(2)
            elif section == "version":
                version = top.group(2)
            elif section == "publish_to" and top.group(2).strip("'\"") == "none":
                publishable = False
            continue
        dep = re.match(r"^  (\w+):", line)
        if dep and section == "dependencies":
            deps.add(dep.group(1))
    return name, version, publishable, deps


def workspace_packages():
    found = {}
    for entry in sorted(os.listdir(PACKAGES)):
        pubspec = os.path.join(PACKAGES, entry, "pubspec.yaml")
        if os.path.exists(pubspec):
            name, version, publishable, deps = read_pubspec(pubspec)
            if publishable:
                found[name] = {"version": version, "deps": deps}
    # Dependency order: a package comes after the workspace packages it depends on.
    ordered, done = [], set()

    def visit(name, path=()):
        if name in done:
            return
        if name in path:
            raise SystemExit(f"dependency cycle: {' -> '.join(path + (name,))}")
        for dep in sorted(found[name]["deps"] & found.keys()):
            visit(dep, path + (name,))
        done.add(name)
        ordered.append(name)

    for name in found:
        visit(name)
    return [(name, found[name]["version"]) for name in ordered]


def pub_versions(name):
    """Versions on pub.dev, or None when the package does not exist there."""
    try:
        with urllib.request.urlopen(f"https://pub.dev/api/packages/{name}", timeout=30) as res:
            return {v["version"] for v in json.load(res)["versions"]}
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout.strip()


def main():
    push = "--push" in sys.argv
    pending, problems = [], []
    for name, version in workspace_packages():
        versions = pub_versions(name)
        if versions is None:
            problems.append(f"{name} no existe en pub.dev: publica la primera versión a mano (flutter pub publish) y activa la publicación automática")
        elif version not in versions:
            pending.append((name, version))
        else:
            print(f"= {name} {version} ya está en pub.dev")

    for name, version in pending:
        print(f"{'+' if push else '~'} {name} {version} (tag {name}-v{version})")
    if not pending:
        print("Nada nuevo que publicar.")

    if push:
        for name, version in pending:
            tag = f"{name}-v{version}"
            if git("ls-remote", "--tags", "origin", f"refs/tags/{tag}"):
                print(f"  {tag} ya existe en el remoto; espero a pub.dev")
            else:
                git("tag", tag)
                git("push", "origin", f"refs/tags/{tag}")
                print(f"  push {tag}")
            deadline = time.time() + WAIT_SECONDS
            while version not in (pub_versions(name) or set()):
                if time.time() > deadline:
                    raise SystemExit(f"{name} {version} no apareció en pub.dev en {WAIT_SECONDS // 60} min: revisa el workflow 'Publish to pub.dev' del tag {tag}")
                time.sleep(20)
            print(f"  {name} {version} publicado")

    if problems and push:
        print("\n" + "\n".join(problems), file=sys.stderr)
        sys.exit(1)
    for problem in problems:
        print(f"::warning::{problem}")


main()
