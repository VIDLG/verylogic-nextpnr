#!/bin/bash

function checkout_revision {
    local repository=$1
    local path=$2
    local revision=$3

    git init --quiet ${path}
    git -C ${path} remote add origin ${repository}
    git -C ${path} fetch --depth 1 origin ${revision}
    git -C ${path} checkout --detach FETCH_HEAD
    git -C ${path} submodule update --init --recursive --depth 1
}

# Install the pinned Yosys revision without downloading unrelated history.
function build_yosys {
    PREFIX=`pwd`/.yosys
    YOSYS_PATH=${DEPS_PATH}/yosys
    mkdir -p ${YOSYS_PATH}
    checkout_revision https://github.com/YosysHQ/yosys ${YOSYS_PATH} ${YOSYS_REVISION}
    pushd ${YOSYS_PATH}
    make -j`nproc` PREFIX=$PREFIX
    make install PREFIX=$PREFIX
    popd
}

function build_icestorm {
    PREFIX=`pwd`/.icestorm
    ICESTORM_PATH=${DEPS_PATH}/icestorm
    mkdir -p ${ICESTORM_PATH}
    checkout_revision https://github.com/YosysHQ/icestorm ${ICESTORM_PATH} ${ICESTORM_REVISION}
    pushd ${ICESTORM_PATH}
    make -j`nproc` PREFIX=${PREFIX}
    make install PREFIX=${PREFIX}
    popd
}

function build_trellis {
    PREFIX=`pwd`/.trellis
    TRELLIS_PATH=${DEPS_PATH}/prjtrellis
    mkdir -p ${TRELLIS_PATH}
    checkout_revision https://github.com/YosysHQ/prjtrellis ${TRELLIS_PATH} ${TRELLIS_REVISION}
    pushd ${TRELLIS_PATH}
    mkdir -p libtrellis/build
    pushd libtrellis/build
    cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} ..
    make -j`nproc`
    make install
    popd
    popd
}

function build_prjoxide {
    PREFIX=`pwd`/.prjoxide
    PRJOXIDE_PATH=${DEPS_PATH}/prjoxide
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y ;\
    mkdir -p ${PRJOXIDE_PATH}
    checkout_revision https://github.com/gatecat/prjoxide ${PRJOXIDE_PATH} ${PRJOXIDE_REVISION}
    pushd ${PRJOXIDE_PATH}
    cd libprjoxide
    PATH=$PATH:$HOME/.cargo/bin cargo install --root $PREFIX --path prjoxide
    popd
}
