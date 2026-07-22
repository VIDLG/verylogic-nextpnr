#!/bin/bash

export MISTRAL_PATH=${DEPS_PATH}/mistral

function get_dependencies {
    # Fetch only the pinned Mistral revision and its required submodules.
    mkdir -p ${MISTRAL_PATH}
    git init --quiet ${MISTRAL_PATH}
    git -C ${MISTRAL_PATH} remote add origin https://github.com/Ravenslofty/mistral.git
    git -C ${MISTRAL_PATH} fetch --depth 1 origin ${MISTRAL_REVISION}
    git -C ${MISTRAL_PATH} checkout --detach FETCH_HEAD
    git -C ${MISTRAL_PATH} submodule update --init --recursive --depth 1
}

function build_nextpnr {
    mkdir build
    pushd build
    cmake .. -DARCH=mistral -DMISTRAL_ROOT=${MISTRAL_PATH}
    make nextpnr-mistral -j`nproc`
    popd
}

function run_tests {
    :
}

function run_archcheck {
    pushd build
    ./nextpnr-mistral --device 5CEBA2F17A7 --test
    popd
}
