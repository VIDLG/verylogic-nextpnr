default: build

# Build the minimal headless generic backend.
configure:
    cmake -S . -B build/pixi -G Ninja -DARCH=generic -DBUILD_GUI=OFF -DBUILD_RUST=OFF -DBUILD_TESTS=OFF -DCMAKE_BUILD_TYPE=Release

build: configure
    cmake --build build/pixi --parallel

clean:
    cmake -E remove_directory build/pixi

# Build local backends plus GUI, Rust integration, and tests.
submodules:
    git submodule update --init 3rdparty/corrosion 3rdparty/googletest tests

configure-full: submodules
    cmake -S . -B build/pixi-full -G Ninja '-DARCH=generic;himbaechel' '-DHIMBAECHEL_UARCH=example;gowin' -DHIMBAECHEL_GOWIN_DEVICES=GW1N-1 -DBUILD_GUI=ON -DBUILD_RUST=ON -DBUILD_TESTS=ON -DCMAKE_BUILD_TYPE=Release

build-full: configure-full
    cmake --build build/pixi-full --parallel

test-full: build-full
    ctest --test-dir build/pixi-full --output-on-failure

clean-full:
    cmake -E remove_directory build/pixi-full

# Build the iCE40 backend using the database revision pinned by CI.
fetch-icestorm:
    python -c "import pathlib, subprocess; p = pathlib.Path('deps/icestorm'); p.parent.mkdir(exist_ok=True); subprocess.check_call(['git', 'clone', 'https://github.com/YosysHQ/icestorm', str(p)]) if not p.exists() else None; subprocess.check_call(['git', '-C', str(p), 'checkout', '68044cc4dac829729ccd0ee88d0780525b515746'])"

prepare-icestorm: fetch-icestorm
    python deps/icestorm/icebox/icebox_chipdb.py -3 > deps/icestorm/icebox/chipdb-384.txt
    python deps/icestorm/icebox/icebox_chipdb.py > deps/icestorm/icebox/chipdb-1k.txt
    python deps/icestorm/icebox/icebox_chipdb.py -5 > deps/icestorm/icebox/chipdb-5k.txt
    python deps/icestorm/icebox/icebox_chipdb.py -u > deps/icestorm/icebox/chipdb-u4k.txt
    python deps/icestorm/icebox/icebox_chipdb.py -8 > deps/icestorm/icebox/chipdb-8k.txt
    cmake -E copy deps/icestorm/icefuzz/timings_hx1k.txt deps/icestorm/icefuzz/timings_hx8k.txt deps/icestorm/icefuzz/timings_lp1k.txt deps/icestorm/icefuzz/timings_lp384.txt deps/icestorm/icefuzz/timings_lp8k.txt deps/icestorm/icefuzz/timings_u4k.txt deps/icestorm/icefuzz/timings_up5k.txt deps/icestorm/icebox

configure-ice40: prepare-icestorm
    cmake -S . -B build/pixi-ice40 -G Ninja "-DARCH=ice40" "-DICEBOX_DATADIR={{justfile_directory()}}/deps/icestorm/icebox" -DBUILD_GUI=OFF -DBUILD_RUST=OFF -DBUILD_TESTS=OFF -DCMAKE_BUILD_TYPE=Release

build-ice40: configure-ice40
    cmake --build build/pixi-ice40 --parallel

clean-ice40:
    cmake -E remove_directory build/pixi-ice40
