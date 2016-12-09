#!/bin/bash
# A script to download all the datasets.
# This probably never needs to be done, but it keeps everything straight.
# usage:  get-datasets.sh [--download] <output-dir>
usage='usage: get-datasets.sh [--dir=<output-dir>]

	Running the script with no arguments will simply print out all the URLs
	for each dataset along with their formats.'

DOWNLOAD_DIR=""
if [ $# -ge 1 ]; then
	case $1 in
		--dir=*)
		DOWNLOAD_DIR=${1#*=}
		if [ -z "$DOWNLOAD_DIR" ]; then
			echo "If you want to download the files specify a directory."
			echo -e "$usage"
			exit 2
		fi
		;;
		-h|--help)
			echo "$usage"
			exit 0
		;;
		*)
			echo "Unrecognized option."
			echo "$usage"
		;;
	esac
fi

if [ ! -z "$DOWNLOAD_DIR" ]; then
	echo "Downloading to $DOWNLOAD_DIR"
fi

echo -e "GraphBIG data cannot be download noninteractively. Please go to\n"
echo https://github.com/graphbig/graphBIG/wiki/GraphBIG-Dataset

