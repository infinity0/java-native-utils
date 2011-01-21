#!/bin/sh
# it's best to run this script from tmpfs, such as /dev/shm/my_test_dir

PKG_SRC="$1"
PKG_DST="$2"
export GITUTILS_KEEP_ROOT="$3"
export GITUTILS_KEEP_PATH="src/freenet/support/CPUInformation:src/net/i2p/util/NativeBigInteger.java:test/net/i2p/util/NativeBigIntegerTest.java"

###############################################################################

SCRIPT_BASE_DIR=$(dirname "$(readlink -f "$0")")
SCRIPT_WORK_DIR=$(pwd)

if [ ! -d "$PKG_SRC"/.git ]; then echo >&2 "No git repo in $PKG_SRC; fix this and re-try."; exit 1; fi

## log the commits from the source repo

cd "$PKG_SRC"
OLDIFS="$IFS"
IFS=":"
for path in $GITUTILS_KEEP_PATH; do
	if [ -n "$GITUTILS_KEEP_ROOT" ]; then
		G_K_PATH="$G_K_PATH $GITUTILS_KEEP_ROOT/$path"
	else
		G_K_PATH="$G_K_PATH $path"
	fi
done
IFS="$OLDIFS"
git log -- $G_K_PATH > "../commits_${PKG_SRC}.log"
cd ..

## clone a temp repo

rm -rf "$PKG_DST"-tmp
git clone "file://$SCRIPT_WORK_DIR/$PKG_SRC" "$PKG_DST"-tmp

## filter the temp repo to keep the given paths

cd "$PKG_DST"-tmp
# make a dummy commit at HEAD
touch GITUTILS_KEEP_DUMMY
git add GITUTILS_KEEP_DUMMY
git commit -m "GITUTILS_KEEP dummy commit"
# do the actual filter
git filter-branch --commit-filter "$SCRIPT_BASE_DIR"'/commit-filter_keep-path.py $@' HEAD
# drop the dummy commit
git reset --hard HEAD^
# log the commits from the temp repo
git log > "../commits_${PKG_DST}.log"
cd ..

## test that both logs are the same, using size (since commit SHA1s will be different)

SZ_1=$(stat -c "%s" "commits_${PKG_SRC}.log")
SZ_2=$(stat -c "%s" "commits_${PKG_DST}.log")
if [ "$SZ_1" != "$SZ_2" ]; then echo >&2 "Unexpected size difference in commit logs of repos."; exit 1; fi

## clone the temp repo to the proper dest, to remove unneeded objects

rm -rf "$PKG_DST"
git clone "file://$SCRIPT_WORK_DIR/$PKG_DST-tmp" "$PKG_DST"
cd "$PKG_DST"
git remote rm origin
git gc
cd ..

rm -rf "$PKG_DST"-tmp

echo "Git repo pruned successfully to: $PKG_DST"
echo "Kept paths: $GITUTILS_KEEP_PATH"
