#!/usr/bin/python

import sys, os
from subprocess import Popen, PIPE

PATH = os.environ["GITUTILS_KEEP_PATH"].split(":")
ROOT = os.environ.get("GITUTILS_KEEP_ROOT", "")

def git_cmd(*args):
	#print >>sys.stderr, "+ git", " ".join(args)
	return Popen(["git"] + list(args), stdout=PIPE).communicate()[0].rstrip('\n')

def split_to_list(out):
	return out.split('\n') if out else []

## prune paths

tree_old = sys.argv[1]

parts = {}
for path in PATH:
	treeinfo = git_cmd("ls-tree", tree_old, os.path.join(ROOT, path))
	if treeinfo: parts[path] = treeinfo.split('	')[0].split(' ')
#print >>sys.stderr, parts

git_cmd("rm", "-rq", "--cached", "--ignore-unmatch", "*")

for path, (mode, nodetype, sha1) in parts.iteritems():
	if nodetype[0] == 'b': # blob
		git_cmd("update-index", "--add", "--cacheinfo", mode, sha1, path)
	elif nodetype[0] == 't': # tree
		git_cmd("read-tree", "--prefix=%s/" % path, sha1)

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
