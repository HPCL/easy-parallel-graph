#!/bin/bash
# Converts edge list to matrix market format
# el (in SNAP form) has # as comments
BEGIN {
	zero_indexed = "yes" # Change this to "no" if 1-indexed

	first = "yes"
	ncomments = 0
	if (zero_indexed == "yes") {
		offs = 1
	} else {
		offs = 0
	}
}

/^#/ {
	gsub(/#/, "%")
	ncomments++
	print
}

!/^[#%]/ {
	if (first) {
		cmd = "wc -l " FILENAME " | cut -d ' ' -f 1"
		cmd | getline n
		close(cmd)
		vfile = FILENAME
		gsub(/\.[^\.]+$/, "", vfile) # strip off file extension
		cmd = "tail -n 1 " vfile ".v"
		cmd | getline nrow
		print "%% Generated with el2mtx.awk from " FILENAME
		print (nrow+offs) " " (nrow+offs) " " (n - ncomments)
	}
	first = ""
	if (zero_indexed == "yes") {
		print ($1 + offs) " " ($2 + offs) " " "1.00e+00"
	} else {
		print ($1 + offs) " " ($2 + offs) " " "1.00e+00"
	}
}
