#!/usr/bin/awk
# Converts from edge list graph to METIS format.
# http://people.sc.fsu.edu/~jburkardt/data/metis_graph/metis_graph.html
# edge list is  a file with just lines like <vertex1> <vertex2>
# If it's anything other than whitespace delimited, use awk's -F flag to set FS
# If you want to convert a weighted edge list (<vertex1> <vertex2> <weight>)
# then set weighted to 1.
# usage: awk [-v weighted=1] -f el2metis.awk <input_file>
BEGIN {
	nvert = 0;
	printf "%% Converted from %s", (weighted?"weighted ":"")
	print "edge list format"
	print "% From the file " ARGV[1];
}

{
	if (weighted) {
		E[$1] = E[$1] (E[$1] ? "  " : "") $2 " " $3;
		E[$2] = E[$2] (E[$2] ? "  " : "") $1 " " $3;
	} else {
		E[$1] = E[$1] (E[$1] ? " " : "") $2;
		E[$2] = E[$2] (E[$2] ? " " : "") $1;
	}
	if ($1 > nvert)
		nvert = $1;
	if ($2 > nvert)
		nvert = $2;
}

END {
	if (E[0])
		printf "%d %d", (nvert+1), NR;
	else
		printf "%d %d", nvert, NR;
	print (weighted ? " 1" : " 0");
	for (i = 0; i <= nvert; i++) {
		if (E[i])
			print E[i]
	}
}

