"""Prepare the pinned, minimal IceStorm database used by local builds."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


REVISION = "68044cc4dac829729ccd0ee88d0780525b515746"
ROOT = Path(__file__).resolve().parent.parent
ICESTORM = ROOT / "deps" / "icestorm"
SOURCE_ICEBOX = ICESTORM / "icebox"
OUTPUT_ICEBOX = ROOT / "deps" / "icebox"
CHIPDB = OUTPUT_ICEBOX / "chipdb-384.txt"
TIMING = OUTPUT_ICEBOX / "timings_lp384.txt"
STAMP = OUTPUT_ICEBOX / ".verylogic-ice40-384-revision"


def run(*args: str, capture_output: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        check=True,
        text=True,
        capture_output=capture_output,
    )


def ensure_checkout() -> None:
    if (ROOT / ".git").exists():
        _ = run(
            "git",
            "-C",
            str(ROOT),
            "submodule",
            "update",
            "--init",
            "--depth",
            "1",
            "deps/icestorm",
        )
    if (ICESTORM / ".git").exists():
        current = run(
            "git", "-C", str(ICESTORM), "rev-parse", "HEAD", capture_output=True
        ).stdout.strip()
        if current != REVISION:
            raise RuntimeError(
                f"IceStorm submodule is at {current}, expected pinned revision {REVISION}"
            )

    required = [
        SOURCE_ICEBOX / "icebox_chipdb.py",
        ICESTORM / "icefuzz" / "timings_lp384.txt",
    ]
    missing = [path for path in required if not path.is_file()]
    if missing:
        raise RuntimeError(f"IceStorm submodule is incomplete: missing {missing}")


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
                [sys.executable, str(SOURCE_ICEBOX / "icebox_chipdb.py"), "-3"],
                check=True,
                stdout=output,
                text=True,
            )
        os.replace(temporary, CHIPDB)
    finally:
        _ = temporary.unlink(missing_ok=True)


def main() -> None:
    ensure_checkout()
    OUTPUT_ICEBOX.mkdir(parents=True, exist_ok=True)
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
