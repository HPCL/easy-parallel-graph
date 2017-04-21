#!/usr/bin/awk
# Given a weighted edge list (one <v1> <v2> <weight> on each line)
# and a changed edge list file (<v1> <v2> <weight> <0|1> on each line)
# where 1 means insert, 0 means delete. For example, 44  26769 15.000000 1 
# This does not check that it's inserting duplicate edges nor that
# a deleted edge actually existed before.
BEGIN {
	usage = "awk -f change_edgelist.awk -v CEL=<wel changes file> <wel file>"
	if (CEL == "") {
		print usage
		exit 2
	}
	# Read in the changes
	while (getline line < CEL) {
		split(line, splitline, " ")
		s    = splitline[1]
		t    = splitline[2]
		wt   = splitline[3]
		type = splitline[4]
		if (type == "1") # insertion
			print s " " t " " int(wt)
		if (type == "0") # deletion
			deletion[s,t] = wt
	}
}

{
	if (deletion[$1,$2] != "")
		; # The edge is deleted (don't print)
	else
		print
}

