#!/bin/sh

SCRIPT_BASE_DIR=$(dirname "$(readlink -f "$0")")
SCRIPT_WORK_DIR=$(pwd)
SCRIPT_NAME="gitutils-$(basename "$0")"

REPO_TMP=java-native-utils_tmp
REPO_JNU=java-native-utils

rm -rf "$REPO_TMP"
git init "$REPO_TMP"

select_and_rewrite_repo() {
	ORIG_REPO="$1"
	REWR_REPO="$2"
	ORIG_PROJ="$3"

	if [ ! -d "$ORIG_REPO" ]; then
		git clone git://github.com/"$ORIG_PROJ"/"$ORIG_REPO".git
	fi

	ORIG_BRAN=$(cd "$ORIG_REPO" && git branch | grep '^\*' | cut -f2 '-d ')

	if [ ! -d "$REWR_REPO" ]; then
		"$SCRIPT_BASE_DIR"'/extract-java-native-libs.sh' "$ORIG_REPO" "$REWR_REPO"
	fi

	cd "$REWR_REPO"
	git filter-branch -f --index-filter 'git rm -rq --cached --ignore-unmatch *.dll *.so *.jnilib *.tar.* *.jar'
	cd ..

	cd "$REPO_TMP"
	git remote add "$REWR_REPO" ../"$REWR_REPO"
	git fetch "$REWR_REPO"
	git checkout -b "$REWR_REPO" -t "$REWR_REPO"/"$ORIG_BRAN"
	cd ..

}

select_and_rewrite_repo i2p rewrite-i2p-i2p ducki2p
select_and_rewrite_repo fred-staging rewrite-freenet-fred freenet
select_and_rewrite_repo contrib-staging rewrite-freenet-contrib freenet

cd "$REPO_TMP"
for remote in $(git remote); do git remote rm "$remote"; done
git checkout -b master rewrite-freenet-contrib
GIT_COMMITTER_NAME="$SCRIPT_NAME" GIT_COMMITTER_EMAIL="x@x.x" \
   GIT_AUTHOR_NAME="$SCRIPT_NAME"    GIT_AUTHOR_EMAIL="x@x.x" \
git merge  -m "$SCRIPT_NAME: merge freenet-fred into freenet-contrib" rewrite-freenet-fred
git checkout -b merge-point-freenet "07de42c37350637cd274aa0c8c06972a0a30f092"
GIT_COMMITTER_NAME="$SCRIPT_NAME" GIT_COMMITTER_EMAIL="x@x.x" GIT_COMMITTER_DATE="1093075150 +0000" \
   GIT_AUTHOR_NAME="$SCRIPT_NAME"    GIT_AUTHOR_EMAIL="x@x.x"    GIT_AUTHOR_DATE="1093075150 +0000" \
git merge -m "$SCRIPT_NAME: merge freenet-fred into freenet-contrib" db10da0ea0e7c9f7e1d35ca1b5044575bd32ab39
git checkout -b merge-point-i2p "f811fe7dc26f6bd39b81f7e5493cb8c3ce53d9ec"
echo "$(git rev-parse merge-point-i2p) $(git rev-parse merge-point-i2p^) $(git rev-parse merge-point-freenet)" > .git/info/grafts
git filter-branch -- --all
rm .git/info/grafts
git rev-parse merge-point-i2p
echo "491ff3e54842a37e04b8506b738e0e8601b52591" "should have been printed above"
cd ..

rm -rf "$REPO_JNU"
git clone -n "file://$SCRIPT_WORK_DIR/$REPO_TMP" "$REPO_JNU"
cd "$REPO_JNU"
for remote in $(git branch -r | tail -n+2); do git checkout -b "${remote#origin/}" -t "$remote"; done
git remote rm origin
git checkout master
git gc --aggressive
git rev-parse merge-point-i2p
echo "491ff3e54842a37e04b8506b738e0e8601b52591" "should have been printed above"
cd ..
