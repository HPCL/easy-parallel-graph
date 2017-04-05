#!/usr/bin/awk
# Parses the RAPL code.
BEGIN {
	usage = "awk -v value=<power|energy|time> [-v pre=<prepend string>] -f parse_RAPL.awk <file>"
	PKG=2
	if (value == "power") {
		expr = "Average.*PACKAGE_ENERGY:PACKAGE[0-9]+ \\*"
		ele = 3
	} else if (value == "energy") {
		expr = "Total Energy.*PACKAGE_ENERGY:PACKAGE[0-9]+ \\*"
		ele = 3
	} else if (value == "time") {
		# Time's the first value for every RAPL measurement
		expr = "Total Energy for rapl:::PACKAGE_ENERGY:PACKAGE[0-9]+"
		ele = 1
	} else {
		printf "%s\n", usage
		exit 2
	}
}
$0 ~ expr {
	# We sum over all the packages (physical CPUs) that RAPL measures
	c++
	if (c % PKG == 0) {
		printf "%s,%f\n", pre, t+$ele
		t = 0
	} else {
		t += $ele
	}
}
