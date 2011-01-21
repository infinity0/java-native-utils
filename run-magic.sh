#!/bin/sh

SCRIPT_BASE_DIR=$(dirname "$(readlink -f "$0")")
SCRIPT_WORK_DIR=$(pwd)

if [ ! -d fred-staging ]; then
	git clone git://github.com/freenet/fred-staging.git
fi

if [ ! -d i2p ]; then
	git clone git://github.com/robertfoss/i2p.git
	cd i2p
	git checkout unknown
	git filter-branch --env-filter "source $SCRIPT_BASE_DIR/env-filter_fix-commit-metadata-i2p.sh" HEAD
	cd ..
fi

"$SCRIPT_BASE_DIR"'/extract-java-native-libs.sh' fred-staging jnu_fred-staging
"$SCRIPT_BASE_DIR"'/extract-java-native-libs.sh' i2p jnu_i2p core/java
