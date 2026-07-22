"""Prepare the pinned, minimal IceStorm database used by local builds."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


REPOSITORY = "https://github.com/YosysHQ/icestorm"
REVISION = "68044cc4dac829729ccd0ee88d0780525b515746"
ROOT = Path(__file__).resolve().parent.parent
ICESTORM = ROOT / "deps" / "icestorm"
ICEBOX = ICESTORM / "icebox"
CHIPDB = ICEBOX / "chipdb-384.txt"
TIMING = ICEBOX / "timings_lp384.txt"
STAMP = ICEBOX / ".verylogic-ice40-384-revision"


def run(*args: str, capture_output: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        check=True,
        text=True,
        capture_output=capture_output,
    )


def git(*args: str, capture_output: bool = False) -> subprocess.CompletedProcess[str]:
    return run("git", "-C", str(ICESTORM), *args, capture_output=capture_output)


def ensure_checkout() -> None:
    if not (ICESTORM / ".git").is_dir():
        ICESTORM.mkdir(parents=True, exist_ok=True)
        _ = git("init", "--quiet")
        _ = git("remote", "add", "origin", REPOSITORY)

    revision_exists = subprocess.run(
        ["git", "-C", str(ICESTORM), "cat-file", "-e", f"{REVISION}^{{commit}}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0
    if not revision_exists:
        _ = git("fetch", "--depth", "1", "origin", REVISION)

    current_result = subprocess.run(
        ["git", "-C", str(ICESTORM), "rev-parse", "--verify", "HEAD"],
        text=True,
        capture_output=True,
        check=False,
    )
    current = current_result.stdout.strip() if current_result.returncode == 0 else ""
    if current != REVISION:
        _ = git("checkout", "--detach", REVISION)


def is_current() -> bool:
    return (
        CHIPDB.is_file()
        and TIMING.is_file()
        and STAMP.is_file()
        and STAMP.read_text(encoding="ascii").strip() == REVISION
    )


def generate_chipdb() -> None:
    temporary = CHIPDB.with_suffix(".txt.tmp")
    try:
        with temporary.open("w", encoding="utf-8", newline="\n") as output:
            _ = subprocess.run(
                [sys.executable, str(ICEBOX / "icebox_chipdb.py"), "-3"],
                check=True,
                stdout=output,
                text=True,
            )
        os.replace(temporary, CHIPDB)
    finally:
        _ = temporary.unlink(missing_ok=True)


def main() -> None:
    ensure_checkout()
    if is_current():
        print(f"IceStorm LP384 database is up to date at {REVISION[:8]}")
        return

    generate_chipdb()
    _ = shutil.copy2(ICESTORM / "icefuzz" / "timings_lp384.txt", TIMING)
    with STAMP.open("w", encoding="ascii", newline="\n") as output:
        _ = output.write(f"{REVISION}\n")
    print(f"Prepared IceStorm LP384 database at {REVISION[:8]}")


if __name__ == "__main__":
    main()
