"""Install and smoke-test the locally built package through a static channel."""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


def main() -> None:
    output_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "dist/conda")
    packages = sorted((output_dir / "win-64").glob("verylogic-nextpnr-*.conda"))
    if len(packages) != 1:
        raise SystemExit(
            f"expected one verylogic-nextpnr package under {output_dir / 'win-64'}, "
            f"found {len(packages)}"
        )

    package = packages[0].resolve()
    version = package.name.removeprefix("verylogic-nextpnr-").rsplit("-", 1)[0]
    channel = (output_dir / "test-channel").resolve()
    shutil.rmtree(channel, ignore_errors=True)

    subprocess.run(
        ["rattler-build", "publish", str(package), "--to", channel.as_uri()],
        check=True,
    )
    subprocess.run(
        [
            "pixi",
            "exec",
            "--force-reinstall",
            "--channel",
            channel.as_uri(),
            "--channel",
            "conda-forge",
            "--spec",
            f"verylogic-nextpnr=={version}",
            "cmd.exe",
            "/d",
            "/s",
            "/c",
            "nextpnr-ice40 --version && "
            "nextpnr-ice40 --lp384 --package qn32 --test && "
            "nextpnr-himbaechel --version && "
            "nextpnr-himbaechel --device GW1N-LV1QN48C6/I5 --test",
        ],
        check=True,
    )


if __name__ == "__main__":
    main()
