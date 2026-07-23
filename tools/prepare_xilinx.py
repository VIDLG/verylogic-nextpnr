"""Prepare pinned metadata and Project X-Ray data for Himbaechel/Xilinx."""

from __future__ import annotations

import subprocess
from pathlib import Path


PRJXRAY_REVISION = "5191a7ba8a56c8fdf63b12ab531dfb386ce06973"
META_REVISION = "491aefcc15be159efc8ad8bff2a1a4b93fe487fe"
ROOT = Path(__file__).resolve().parent.parent
PRJXRAY_DB = ROOT / "deps" / "prjxray-db"
XILINX_META = ROOT / "himbaechel" / "uarch" / "xilinx" / "meta"


def run(*args: str, capture_output: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        check=True,
        text=True,
        capture_output=capture_output,
    )


def revision(path: Path) -> str:
    return run(
        "git", "-C", str(path), "rev-parse", "HEAD", capture_output=True
    ).stdout.strip()


def ensure_submodules() -> None:
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
            "deps/prjxray-db",
            "himbaechel/uarch/xilinx/meta",
        )
    revisions = [
        (PRJXRAY_DB, PRJXRAY_REVISION),
        (XILINX_META, META_REVISION),
    ]
    for path, expected in revisions:
        if (path / ".git").exists():
            current = revision(path)
            if current != expected:
                raise RuntimeError(
                    f"submodule {path} is at {current}, expected pinned revision {expected}"
                )

    required = [
        XILINX_META / "artix7" / "wire_intents.json",
        PRJXRAY_DB / "artix7" / "xc7a100t" / "tilegrid.json",
        PRJXRAY_DB / "artix7" / "xc7a100tcsg324-1" / "package_pins.csv",
    ]
    missing = [path for path in required if not path.is_file()]
    if missing:
        raise RuntimeError(f"Project X-Ray database is incomplete: missing {missing}")


def main() -> None:
    ensure_submodules()
    print(f"Prepared Project X-Ray XC7A100T data at {PRJXRAY_REVISION[:8]}")


if __name__ == "__main__":
    main()
