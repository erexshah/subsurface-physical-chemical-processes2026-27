#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/opminstall"
JOBS="${JOBS:-$(sysctl -n hw.logicalcpu)}"
BRANCH="${BRANCH:-}"

# Conda environment settings
CONDA_ENV_NAME="opmenv"
CONDA_PYTHON_VERSION="3.13.13"

OPM_MODULES=(
  "opm-common"
  "opm-grid"
  "opm-upscaling"
  "opm-simulators"
)

BREW_PREFIX=""
FMT_PREFIX=""
BOOST_PREFIX=""
LIBOMP_PREFIX=""

if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix)"
  FMT_PREFIX="$(brew --prefix fmt 2>/dev/null || true)"
  BOOST_PREFIX="$(brew --prefix boost 2>/dev/null || true)"
  LIBOMP_PREFIX="$(brew --prefix libomp 2>/dev/null || true)"
fi

# ----------------------------
# Create / activate conda env
# ----------------------------
if ! command -v conda >/dev/null 2>&1; then
  echo "conda not found. Please install Miniconda/Anaconda first."
  exit 1
fi

# Load conda functions into this shell
CONDA_BASE="$(conda info --base)"
# shellcheck disable=SC1090
source "$CONDA_BASE/etc/profile.d/conda.sh"

if conda env list | awk 'NF && $1 !~ /^#/ {print $1}' | grep -qx "$CONDA_ENV_NAME"; then
  echo "Conda environment '$CONDA_ENV_NAME' already exists."
else
  echo "Creating conda environment '$CONDA_ENV_NAME'..."
  conda create -y -n "$CONDA_ENV_NAME" -c conda-forge \
    "python=$CONDA_PYTHON_VERSION" \
    numpy scipy matplotlib jupyter pandas
fi

conda activate "$CONDA_ENV_NAME"

# Use the Python from the activated conda environment
CONDA_PYTHON="$(command -v python)"

PREFIX_PATHS=("$INSTALL_DIR")
[ -n "$CONDA_PREFIX" ] && PREFIX_PATHS+=("$CONDA_PREFIX")
[ -n "$BREW_PREFIX" ] && PREFIX_PATHS+=("$BREW_PREFIX")
[ -n "$BOOST_PREFIX" ] && PREFIX_PATHS+=("$BOOST_PREFIX")
[ -n "$FMT_PREFIX" ] && PREFIX_PATHS+=("$FMT_PREFIX")

CMAKE_PREFIX_PATH_JOINED=$(IFS=';'; echo "${PREFIX_PATHS[*]}")

export PKG_CONFIG_PATH="$INSTALL_DIR/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

mkdir -p opm
cd opm

for MODULE in "${OPM_MODULES[@]}"; do
  echo "======================================"
  echo " Building $MODULE"
  echo "======================================"

  if [ ! -d "$MODULE" ]; then
    if [ -n "$BRANCH" ]; then
      git clone -b "$BRANCH" "https://github.com/OPM/$MODULE.git"
    else
      git clone "https://github.com/OPM/$MODULE.git"
    fi
  else
    echo "$MODULE already exists, pulling latest changes"
    cd "$MODULE"
    git pull
    cd ..
  fi

  rm -rf "$MODULE/build"
  mkdir -p "$MODULE/build"
  cd "$MODULE/build"

  # ==================== CMAKE ARGUMENTS (array = safe) ====================
  cmake_args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"
    -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH_JOINED"
    -DOPM_ENABLE_PYTHON=ON
    -DOPM_ENABLE_EMBEDDED_PYTHON=ON
    -DOPM_INSTALL_PYTHON=ON
    -DPython3_EXECUTABLE="$CONDA_PYTHON"
    -DCMAKE_CXX_STANDARD=17
    -DCMAKE_CXX_STANDARD_REQUIRED=ON
    -DCMAKE_CXX_EXTENSIONS=OFF
    -DBoost_ROOT="$BOOST_PREFIX"
    -DBOOST_INCLUDEDIR="$BOOST_PREFIX/include"
    -DBoost_INCLUDE_DIR="$BOOST_PREFIX/include"
    -DBoost_NO_SYSTEM_PATHS=ON
    -DCMAKE_POLICY_DEFAULT_CMP0144=NEW
    -DCMAKE_CXX_FLAGS="-I$BOOST_PREFIX/include"
    -DUSE_OPENCL=OFF
  )

  [ -n "$FMT_PREFIX" ] && cmake_args+=("-Dfmt_DIR=$FMT_PREFIX/lib/cmake/fmt")

  if [ -n "$LIBOMP_PREFIX" ]; then
    cmake_args+=(
      -DOpenMP_C_FLAGS="-Xpreprocessor -fopenmp -I$LIBOMP_PREFIX/include"
      -DOpenMP_CXX_FLAGS="-Xpreprocessor -fopenmp -I$LIBOMP_PREFIX/include"
      -DOpenMP_C_LIB_NAMES=omp
      -DOpenMP_CXX_LIB_NAMES=omp
      -DOpenMP_omp_LIBRARY="$LIBOMP_PREFIX/lib/libomp.dylib"
    )
  fi

  cmake .. "${cmake_args[@]}"

  cmake --build . --parallel "$JOBS"
  cmake --install .

  cd ../..
done

echo "======================================"
echo " OPM build completed successfully"
echo " Install dir: $INSTALL_DIR"
echo " Conda env: $CONDA_ENV_NAME"
echo " Python: $CONDA_PYTHON"
echo "======================================"

# --- Ensure conda is available ---
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
else
    echo "Conda not found!"
    exit 1
fi

# --- Activate environment ---
conda activate "$CONDA_ENV_NAME"

# --- Patch flow binary with correct RPATH (only if not already present) ---
if ! otool -l "$INSTALL_DIR/bin/flow" | grep -q "$CONDA_PREFIX/lib"; then
    install_name_tool -add_rpath "$CONDA_PREFIX/lib" "$INSTALL_DIR/bin/flow"
    echo "RPATH added."
else
    echo "RPATH already exists. Skipping."
fi

echo "RPATH patch step completed."