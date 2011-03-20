#!/bin/sh

SCRIPT_BASE_DIR=$(dirname "$(readlink -f "$0")")
SCRIPT_WORK_DIR=$(pwd)

if [ ! -d fred-staging ]; then
	git clone git://github.com/freenet/fred-staging.git
fi

if [ ! -d contrib-staging ]; then
	git clone git://github.com/freenet/contrib-staging.git
fi

if [ ! -d i2p ]; then
  git clone git://github.com/ducki2p/i2p.git
fi

"$SCRIPT_BASE_DIR"'/extract-java-native-libs.sh' contrib-staging rewrite-freenet-contrib
"$SCRIPT_BASE_DIR"'/extract-java-native-libs.sh' i2p rewrite-i2p-i2p
"$SCRIPT_BASE_DIR"'/extract-java-native-libs.sh' fred-staging rewrite-freenet-fred
