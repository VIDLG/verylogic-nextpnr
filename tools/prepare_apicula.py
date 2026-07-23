"""Initialize and validate the pinned Apycula source submodule."""

from __future__ import annotations

import subprocess
from pathlib import Path


REVISION = "4dd5b01f6aa873a684dc2e600a31af9671a09662"
ROOT = Path(__file__).resolve().parent.parent
APICULA = ROOT / "deps" / "apicula"


def run(*args: str, capture_output: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        check=True,
        text=True,
        capture_output=capture_output,
    )


def main() -> None:
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
            "deps/apicula",
        )
    if (APICULA / ".git").exists():
        current = run(
            "git", "-C", str(APICULA), "rev-parse", "HEAD", capture_output=True
        ).stdout.strip()
        if current != REVISION:
            raise RuntimeError(
                f"Apycula submodule is at {current}, expected pinned revision {REVISION}"
            )

    required = [APICULA / "apycula" / "chipdb.py", APICULA / "setup.py"]
    missing = [path for path in required if not path.is_file()]
    if missing:
        raise RuntimeError(f"Apycula submodule is incomplete: missing {missing}")

    print(
        f"Prepared Apycula source at {REVISION[:8]}; "
        "released Gowin chipdb payload remains supplied by the pinned wheel"
    )


if __name__ == "__main__":
    main()
