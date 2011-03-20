#!/usr/bin/python

import sys, os
from gitutils import parse_rewrites, iter_rewrite_paths
from subprocess import Popen, PIPE

DEBUG_MODE = os.getenv("GITUTILS_DEBUG", False)
REWRITE_FILE = os.getenv("GITUTILS_REWRITE_FILE", "../../.../REWRITES")

def git_cmd(*args):
	if DEBUG_MODE:
		print >>sys.stderr, "+ git", " ".join(args)
	return Popen(["git"] + list(args), stdout=PIPE).communicate()[0].rstrip('\n')

def split_to_list(out):
	return out.split('\n') if out else []

with open(REWRITE_FILE) as fp:
	rewrites = parse_rewrites(fp, os.getenv("GITUTILS_ORIG_REPO"), os.getenv("GITUTILS_REWR_REPO"))
	#print >>sys.stderr, rewrites

tree_old = sys.argv[1]

## read objects to keep from index

keep_trees = {}  # dict { root: { path, treeinfo } }
for old_path, new_path in iter_rewrite_paths(rewrites):
	treeinfo = git_cmd("ls-tree", tree_old, old_path)
	if treeinfo: keep_trees[new_path] = treeinfo.split('	')[0].split(' ')

## re-attach objects to index

git_cmd("rm", "-rq", "--cached", "--ignore-unmatch", "*")
# sorted() is required so read-tree --prefix doesn't give errors
for new_path, treeinfo in sorted(keep_trees.iteritems()):
	mode, nodetype, sha1 = treeinfo
	if nodetype[0] == 'b': # blob
		git_cmd("update-index", "--add", "--cacheinfo", mode, sha1, new_path)
	elif nodetype[0] == 't': # tree
		args = ["read-tree", "--prefix=%s/" % new_path, sha1]
		if new_path == ".": del args[1]  # --prefix=./ gives error
		git_cmd(*args)
	else:
		raise ValueError("unexpected treeinfo: %s" % treeinfo)

tree_new = git_cmd("write-tree")

## parse parents list

parents = []
for arg in sys.argv[2:]:
	if not arg or arg == "-p": continue
	parents.append(arg)

## prune empty commits

treepars = {}
for par in parents:
	par_new = par
	par_tree = git_cmd("rev-parse", par+"^{tree}")

	gpar = split_to_list(git_cmd("rev-parse", par+"^@"))
	if len(gpar) == 1:
		gpar_tree = git_cmd("rev-parse", gpar[0]+"^{tree}")

		# if unique grandparent has same tree as parent, skip parent and use grandparent instead
		if par_tree == gpar_tree:
			par_new = gpar[0]

	treepars.setdefault(par_tree, []).append(par_new)

# don't set parents that point to the empty tree
treepars.pop("4b825dc642cb6eb9a060e54bf8d69288fbee4904", 0)

if tree_new in treepars:
	# suppress redundant repeat-merges like
	#
	#    +---+---+--- (etc)
	#   /     \   \
	#  Ax--By--Cy--Dy-- (etc) --- Pz
	#
	# [Ax = commit A with tree x]
	#
	# by dropping all other parents at Cy. when combined with the grandparent
	# rule above, this causes the redundant merges to drop out, resulting in
	#
	#  Ax--By--Pz
	#
	# a clean history, i.e. there is exactly one commit for each tree, namely
	# the commit where the tree first appeared in the original history.
	#
	# TODO only do this if the merge-base of all the parents exists
	treepars = { tree_new: treepars[tree_new] }

parents = []
for tree, pars in treepars.iteritems():
	if len(pars) == 1:
		parents.append(pars[0])
		continue

	pars = set(pars)
	for par in pars:
		ancs = set(split_to_list(git_cmd("rev-list", par)))
		# only keep parents that don't have ancestors with the same tree
		common = len(ancs & pars)
		assert common >= 1
		if common == 1: parents.append(par)

## make new commit

args = []
for par in parents:
	args.extend(["-p", par])

#print >>sys.stderr, "git commit-tree", tree_new, " ".join(args)
Popen(["git", "commit-tree", tree_new] + args).communicate()
