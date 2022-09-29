#!/usr/bin/env bash
set -euo pipefail

echo Creating Docker build environment
image_name="vnote-$(id -un)"
GID="$(id -g)"
docker build --build-arg UID="$UID" --build-arg GID="$GID" -t "$image_name" .

# build script adapted from the AppImage instructions:
# https://docs.appimage.org/packaging-guide/from-source/native-binaries.html
# (CAP_SYS_ADMIN and /dev/fuse are needed for linuxdeploy to use FUSE)
#
# FIXME(qxcv): the code below fails for two reasons:
#
# (1) As of September 2022, there's a bug in boost::filesystem that causes it to
#     fail to copy files across filesystem boundaries, which causes the AppImage
#     build process to fail. I believe this is due to the Docker bind mount,
#     since the image builds fine outside of the container.
#
# (2) Even if you successfully build the AppImage outside of the container, it
#     still fails to run due to an error related to libnss3.so (it fails to load
#     libsoftokn3.so or something like that). This is due to a known conflict
#     between some apps and AppImageKit.
#
#     The standard way to fix this issue is by removing the problem libraries
#     from the AppImage. However, the --exclude-library flag on the linuxdeploy
#     AppImage is not sufficient for this purpose, since the Qt plugin goes and
#     puts the problematic files right back into the AppDir. To fix this, you
#     have to (1) run linuxdeploy as usual, (2) delete the problem files from
#     the AppDir that linuxdeploy populates (libnss3.so, libnssutil3.so), and
#     then (3) apply appimagetool to the updated AppDir to overwrite the
#     AppImage produced in the first step.
#
# It's probably worth revisiting this in a few months once the boost::filesystem
# fix has propagated to linuxdeploy, at which point I can code a hacky fix to
# the libnss*3.so woes and ship it in this script.
echo Building vnote
docker run --rm -i \
    -v "$(pwd)":/vnote -w /vnote \
    --cap-add SYS_ADMIN --device /dev/fuse \
    --security-opt apparmor:unconfined \
    vnote:latest bash <<EOF
set -euo pipefail

echo "Creating build dir"
mkdir -p build
cd build

echo "Executing qmake"
qmake ../vnote.pro

echo "Executing make && make install"
make -j"\$(nproc)"
make install INSTALL_ROOT=AppDir

echo Copying all AppDir contents into this directory
rm -rf AppDir
find . -name "AppDir" -type d -exec cp -r "{}" ./ \;

echo "Downloading latest AppImage builder"
wget -N https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
wget -N https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
chmod +x linuxdeploy*.AppImage

echo "Building AppImage"
export QML_SOURCES_PATHS="\$(readlink -f "\$(pwd)/../src")"
LD_LIBRARY_PATH=./AppDir/usr/lib ./linuxdeploy-x86_64.AppImage --appdir AppDir --plugin qt --output appimage
EOF
