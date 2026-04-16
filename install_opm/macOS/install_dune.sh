#!/bin/bash

set -e  # stop on error

INSTALL_DIR=~/opminstall
BRANCH="releases/2.10"

REPOS=(
    "https://gitlab.dune-project.org/core/dune-common.git"
    "https://gitlab.dune-project.org/core/dune-geometry.git"
    "https://gitlab.dune-project.org/core/dune-istl.git"
    "https://gitlab.dune-project.org/core/dune-grid.git"
)

# Create a parent directory
mkdir -p dune
cd dune

for REPO in "${REPOS[@]}"; do
    NAME=$(basename "$REPO" .git)

    echo "Cloning $NAME..."
    git clone -b "$BRANCH" "$REPO"

    cd "$NAME"
    mkdir -p build
    cd build

    echo "Building $NAME..."
    cmake .. -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"
    make -j8
    make install

    cd ../..
done

echo "All modules built and installed successfully."
