#!/bin/sh

# script assumes fred-staging is cloned into the same directory as this script
# you can do this with:
#
# $ git clone git@github.com:freenet/fred-staging.git
#
# it's best to run this script from tmpfs, such as /dev/shm/my_test_dir

PKG=java-native-utils
export GITUTILS_KEEP_PATH="src/freenet/support/CPUInformation:src/net/i2p/util:test/net/i2p/util"
G_K_PATH="src/freenet/support/CPUInformation src/net/i2p/util test/net/i2p/util"

###############################################################################

cd $(dirname "$(readlink -f "$0")")
SCRIPT_BASE_DIR=$(pwd)

cd fred-staging
git log $G_K_PATH > "../${PKG}_fred-staging.log"
cd ..

rm -rf $PKG-tmp
git clone "file://$SCRIPT_BASE_DIR/fred-staging" $PKG-tmp

cd $PKG-tmp
touch GITUTILS_KEEP_DUMMY
git add GITUTILS_KEEP_DUMMY
git commit -m "GITUTILS_KEEP dummy commit"

rm -rf /dev/shm/git-filter-branch || exit 1
git filter-branch -d /dev/shm/git-filter-branch --commit-filter "$SCRIPT_BASE_DIR"'/commit-filter_keep-path.py $@' HEAD

git reset --hard HEAD^
git log > "../${PKG}_pruned.log"
cd ..

SZ_1=$(stat -c "%s" "${PKG}_fred-staging.log")
SZ_2=$(stat -c "%s" "${PKG}_pruned.log")
if [ "$SZ_1" != "$SZ_2" ]; then echo >&2 "Unexpected size difference in commit logs of repos."; exit 1; fi

rm -rf $PKG
git clone "file://$SCRIPT_BASE_DIR/$PKG-tmp" $PKG
cd $PKG
git remote rm origin
git gc
cd ..

echo "Git repo pruned successfully to: $PKG"
echo "Kept paths: $GITUTILS_KEEP_PATH"
