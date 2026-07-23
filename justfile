build_dir := "build/pixi-fpga"
conda_output := env_var_or_default("VERYLOGIC_CONDA_OUTPUT", "dist/conda")
exe_suffix := if os() == "windows" { ".exe" } else { "" }
python_executable := if os() == "windows" { env_var("CONDA_PREFIX") + "/python.exe" } else { env_var("CONDA_PREFIX") + "/bin/python" }

default: build

# Materialize the minimal iCE40 LP384 database from the pinned IceStorm source.
prepare-ice40:
    python tools/prepare_ice40.py

# Validate the pinned Apycula generator source. Released chipdb payload comes from the locked wheel.
prepare-apicula:
    python tools/prepare_apicula.py

# Validate the pinned Project X-Ray database and nextpnr Xilinx metadata.
prepare-xilinx:
    python tools/prepare_xilinx.py

prepare-databases: prepare-ice40 prepare-apicula prepare-xilinx

# Configure iCE40 LP384, Himbaechel/Gowin GW1N-1, and Himbaechel/Xilinx XC7A100T.
configure: prepare-databases
    cmake -S . -B {{build_dir}} -G Ninja '-DARCH=ice40;himbaechel' '-DICE40_DEVICES=384' "-DICEBOX_DATADIR={{justfile_directory()}}/deps/icebox" '-DHIMBAECHEL_UARCH=gowin;xilinx' '-DHIMBAECHEL_GOWIN_DEVICES=GW1N-1' '-DHIMBAECHEL_XILINX_DEVICES=xc7a100t' "-DHIMBAECHEL_PRJXRAY_DB={{justfile_directory()}}/deps/prjxray-db" "-DXilinxChipdb_Python3_EXECUTABLE={{python_executable}}" -DBUILD_GUI=ON -DBUILD_PYTHON=ON -DBUILD_RUST=OFF -DBUILD_TESTS=OFF -DUSE_IPO=OFF -DCMAKE_BUILD_TYPE=Release

# Build both executables from the same CMake graph so common sources are configured once.
build: configure
    cmake --build {{build_dir}} --parallel --target nextpnr-ice40 nextpnr-himbaechel

# Exercise the read-only graphics bindings against all packaged architectures.
test-graphics: build
    "{{build_dir}}/nextpnr-ice40{{exe_suffix}}" --lp384 --package qn32 --run python/graphics_smoke.py
    "{{build_dir}}/nextpnr-himbaechel{{exe_suffix}}" --device GW1N-LV1QN48C6/I5 --run python/graphics_smoke.py
    "{{build_dir}}/nextpnr-himbaechel{{exe_suffix}}" --device xc7a100tcsg324-1 --run python/graphics_smoke.py

# Produce and independently smoke-test the self-contained Windows runtime.
package: build
    pwsh -NoProfile -File .github/ci/package_windows.ps1

# Build the win-64 conda package, then install and smoke-test it from a local channel.
conda-build: prepare-databases
    cmake -E remove_directory "{{conda_output}}"
    rattler-build build --recipe recipe/recipe.yaml --target-platform win-64 --output-dir "{{conda_output}}" --channel conda-forge --package-format conda --test skip --no-build-id
    python tools/test_conda_package.py "{{conda_output}}"

# Re-run the package smoke tests against the existing local package.
conda-test:
    python tools/test_conda_package.py "{{conda_output}}"

clean:
    cmake -E remove_directory {{build_dir}}
