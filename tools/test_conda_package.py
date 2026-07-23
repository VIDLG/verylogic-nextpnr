"""Install and smoke-test the locally built package through a static channel."""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path


EXPECTED_PYTHON_VERSIONS = {"3.12", "3.13"}
PACKAGE_PATTERN = re.compile(
    r"^verylogic-nextpnr-(?P<version>.+)-py(?P<python>\d+)h[0-9a-f]+_\d+\.conda$"
)


def main() -> None:
    output_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "dist/conda")
    packages = sorted((output_dir / "win-64").glob("verylogic-nextpnr-*.conda"))
    variants: dict[str, tuple[str, Path]] = {}
    for package in packages:
        match = PACKAGE_PATTERN.fullmatch(package.name)
        if match is None:
            raise SystemExit(f"unexpected package filename: {package.name}")
        digits = match.group("python")
        python_version = f"{digits[0]}.{digits[1:]}"
        if python_version in variants:
            raise SystemExit(f"duplicate Python {python_version} package")
        variants[python_version] = (match.group("version"), package.resolve())

    if set(variants) != EXPECTED_PYTHON_VERSIONS:
        raise SystemExit(
            f"expected Python variants {sorted(EXPECTED_PYTHON_VERSIONS)}, "
            f"found {sorted(variants)}"
        )

    channel = (output_dir / "test-channel").resolve()
    shutil.rmtree(channel, ignore_errors=True)
    subprocess.run(
        [
            "rattler-build",
            "publish",
            *(str(package) for _, package in variants.values()),
            "--to",
            channel.as_uri(),
        ],
        check=True,
    )

    for python_version, (package_version, _) in sorted(variants.items()):
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
                f"python=={python_version}",
                "--spec",
                f"verylogic-nextpnr=={package_version}",
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
