build_dir := "build/pixi-fpga"
conda_output := "dist/conda"
exe_suffix := if os() == "windows" { ".exe" } else { "" }

default: build

# Prepare only the iCE40 LP384 database used by the distributable build.
prepare-ice40:
    python tools/prepare_ice40.py

# Configure the two production backends: iCE40 LP384 and Himbaechel/Gowin GW1N-1.
configure: prepare-ice40
    cmake -S . -B {{build_dir}} -G Ninja '-DARCH=ice40;himbaechel' '-DICE40_DEVICES=384' "-DICEBOX_DATADIR={{justfile_directory()}}/deps/icestorm/icebox" '-DHIMBAECHEL_UARCH=gowin' '-DHIMBAECHEL_GOWIN_DEVICES=GW1N-1' -DBUILD_GUI=ON -DBUILD_PYTHON=ON -DBUILD_RUST=OFF -DBUILD_TESTS=OFF -DUSE_IPO=OFF -DCMAKE_BUILD_TYPE=Release

# Build both executables from the same CMake graph so common sources are configured once.
build: configure
    cmake --build {{build_dir}} --parallel --target nextpnr-ice40 nextpnr-himbaechel

# Exercise the read-only graphics bindings against both packaged architectures.
test-graphics: build
    "{{build_dir}}/nextpnr-ice40{{exe_suffix}}" --lp384 --package qn32 --run python/graphics_smoke.py
    "{{build_dir}}/nextpnr-himbaechel{{exe_suffix}}" --device GW1N-LV1QN48C6/I5 --run python/graphics_smoke.py

# Produce and independently smoke-test the self-contained Windows runtime.
package: build
    pwsh -NoProfile -File .github/ci/package_windows.ps1

# Build the win-64 conda package, then install and smoke-test it from a local channel.
conda-build:
    cmake -E remove_directory {{conda_output}}
    rattler-build build --recipe recipe/recipe.yaml --target-platform win-64 --output-dir {{conda_output}} --channel conda-forge --package-format conda --test skip
    python tools/test_conda_package.py {{conda_output}}

# Re-run the package smoke tests against the existing local package.
conda-test:
    python tools/test_conda_package.py {{conda_output}}

clean:
    cmake -E remove_directory {{build_dir}}
