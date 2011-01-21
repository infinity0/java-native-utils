#!/bin/sh
# it's best to run this script from tmpfs, such as /dev/shm/my_test_dir

PKG=java-native-utils
export GITUTILS_KEEP_PATH="src/freenet/support/CPUInformation:src/net/i2p/util:test/net/i2p/util"
G_K_PATH="src/freenet/support/CPUInformation src/net/i2p/util test/net/i2p/util"

###############################################################################

SCRIPT_BASE_DIR=$(dirname "$(readlink -f "$0")")
SCRIPT_WORK_DIR=$(pwd)

if [ ! -d fred-staging/.git ]; then
	rm -rf fred-staging
	git clone git@github.com:freenet/fred-staging.git
fi

cd fred-staging
git log $G_K_PATH > "../${PKG}_fred-staging.log"
cd ..

rm -rf $PKG-tmp
git clone "file://$SCRIPT_WORK_DIR/fred-staging" $PKG-tmp

cd $PKG-tmp
touch GITUTILS_KEEP_DUMMY
git add GITUTILS_KEEP_DUMMY
git commit -m "GITUTILS_KEEP dummy commit"

git filter-branch --commit-filter "$SCRIPT_BASE_DIR"'/commit-filter_keep-path.py $@' HEAD

git reset --hard HEAD^
git log > "../${PKG}_pruned.log"
cd ..

SZ_1=$(stat -c "%s" "${PKG}_fred-staging.log")
SZ_2=$(stat -c "%s" "${PKG}_pruned.log")
if [ "$SZ_1" != "$SZ_2" ]; then echo >&2 "Unexpected size difference in commit logs of repos."; exit 1; fi

rm -rf $PKG
git clone "file://$SCRIPT_WORK_DIR/$PKG-tmp" $PKG
cd $PKG
git remote rm origin
git gc
cd ..

echo "Git repo pruned successfully to: $PKG"
echo "Kept paths: $GITUTILS_KEEP_PATH"
