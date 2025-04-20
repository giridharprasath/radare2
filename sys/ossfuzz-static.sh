#!/bin/sh
# ossfuzz_static.sh - Revised static build script for radare2 for OSS-Fuzz.
# This script builds radare2 as static libraries (r2-static) suitable for linking
# with fuzz targets. (It replaces our older sys/static.sh.)
# It has been updated for the new Ubuntu base image where the ASan runtime
# requires different compiler/linker flags.

# Patch to use llvm-ar if available.
if command -v llvm-ar >/dev/null 2>&1; then
    export AR=llvm-ar
fi

# For static linking, we DO NOT want to force complete static linking of the sanitizer runtime.
# (The final fuzz target will link dynamically to the sanitizer runtime via $LIB_FUZZING_ENGINE.)
# So we do NOT add "-static" here.
# Instead, ensure that LDFLAGS includes the sanitizer flag so that libasan is linked.
 # Original ASan link flags (no -static here)
#export LDFLAGS="${LDFLAGS:-} ${SANITIZER_FLAGS_address} ${LIB_FUZZING_ENGINE} -Wl,--allow-multiple-definitions"
export LDFLAGS="${LDFLAGS:-} ${SANITIZER_FLAGS_address} ${LIB_FUZZING_ENGINE}"
#export LDFLAGS="${LDFLAGS} ${COVERAGE_FLAGS:-}"

#export LDFLAGS="${LDFLAGS:-} -fsanitize=address -Wl,--allow-multiple-definition"

[ "$NOLTO" != 1 ] && { export CFLAGS="${CFLAGS} -flto"; export LDFLAGS="${LDFLAGS} -flto"; }

# Determine the installation prefix for the static build.
if [ -n "$1" ]; then
    PREFIX="$1"
else
    PREFIX="/usr"
fi

# Build configuration:
# Remove any old build files
[ -f config-user.mk ] && ${MAKE:-make} mrproper >/dev/null 2>&1

# Always compile with PIC.
export CFLAGS="${CFLAGS} -fPIC"

# Set additional configuration arguments.
CFGARGS="--with-static-themes"
# You might disable loadlibs if needed:
# CFGARGS="$CFGARGS --disable-loadlibs"

# Copy a plugins configuration file.
cp -f dist/plugins-cfg/plugins.static.nogpl.cfg plugins.cfg

# Run configuration steps.
./configure-plugins || exit 1
./configure --prefix="$PREFIX" --without-gpl --with-libr $CFGARGS || exit 1

# Build radare2.
${MAKE:-make} -j 8 || exit 1

# Define the list of binaries to build in the "binr" directory.
BINS="rarun2 r2pm rasm2 radare2 ragg2 rabin2 rax2 rahash2 rafind2 r2agent radiff2 r2r"

# Build each binary in the binr subdirectory.
for a in ${BINS} ; do
(
    cd binr/$a
    ${MAKE:-make} clean
    if [ "`uname`" = Darwin ]; then
        ${MAKE:-make} -j4 || exit 1
    else
        if [ "${STATIC_BINS}" = 1 ]; then
            CFLAGS="-static $CFLAGS" LDFLAGS="-static $LDFLAGS" ${MAKE:-make} -j4 || exit 1
        else
            ${MAKE:-make} -j4 || exit 1
        fi
    fi
)
done

# Remove any previous static build output and create a new directory.
rm -rf r2-static
mkdir r2-static || exit 1

# Install into r2-static.
${MAKE:-make} install DESTDIR="${PWD}/r2-static" || exit 1
