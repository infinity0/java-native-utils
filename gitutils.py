#!/usr/bin/python

import sys, os

def parse_rewrites(fp, ORIG_REPO, REWR_REPO):
	rewrites = {}	# dict { root: ( rewr_root, paths ) }
	orig_repo, rewr_repo, orig_root, rewr_root	= None, None, None, None

	for line in fp.readlines():
		line = line.rstrip()
		if not line or line.startswith("#"): continue
		if line.startswith("End"): break
		o_repo, r_repo, o_root, r_root__or__keep_path = line.split()

		# ignore rewrite settings for other repos
		if orig_repo is not None and o_repo != "|": break
		if o_repo == ORIG_REPO: orig_repo = ORIG_REPO
		if orig_repo is None: continue

		# ignore rewrite settings for other branches
		if rewr_repo is not None and r_repo != "|": break
		if r_repo == REWR_REPO: rewr_repo = r_repo
		if rewr_repo is None: continue

		if o_root != "|":
			orig_root = o_root
			rewr_root = r_root__or__keep_path
			rewrites[orig_root] = (rewr_root, [])
		else:
			rewrites[orig_root][1].append(r_root__or__keep_path)

	return rewrites

def iter_rewrite_paths(rewrites):
	for orig_root, rewrite in rewrites.iteritems():
		rewr_root, sub_trees = rewrite
		if not sub_trees: sub_trees = ["."] # add everything, when sub_trees is empty
		for path in sub_trees:
			old_path = os.path.normpath(os.path.join(orig_root, path))
			new_path = os.path.normpath(os.path.join(rewr_root, path))
			yield old_path, new_path

if __name__ == "__main__":
	if sys.argv[1] == "parse-rewrites":
		REWRITE_FILE = sys.argv[2]
		ORIG_REPO = sys.argv[3]
		REWR_REPO = sys.argv[4]

		with open(REWRITE_FILE) as fp:
			rewrites = parse_rewrites(fp, ORIG_REPO, REWR_REPO)

		for old_path, new_path in iter_rewrite_paths(rewrites):
			print old_path, new_path
