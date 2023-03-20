#!/bin/bash

set -uex

TMP_DIR="$(mktemp -d)"

cd "${TMP_DIR}"

sudo apt-get install autoconf libconfuse-dev libyajl-dev libasound2-dev libiw-dev asciidoc libpulse-dev libnl-genl-3-dev meson

cd
git clone https://github.com/fspv/i3status.git
cd i3status
mkdir build
cd build
meson ..
ninja

sudo ninja install

rm -rf "${TMP_DIR}"
