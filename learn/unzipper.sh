#!/bin/bash
# Unzips the datasets and saves them into the specified directory.
# The dataset config file has the following three-line pattern:
# facebook_combined
# https://snap.stanford.edu/data/egonets-Facebook.html
# https://snap.stanford.edu/data/facebook_combined.txt.gz

DATA_DIR="../experiment/datasets"
if [ -z "$1" ]; then
	echo "usage: unzipper.sh <dataset file> <dataset_dir>
		dataset_dir default: ../experiment/datasets>"
	exit 2
fi
if [ -n "$2" ]; then
	DATA_DIR="$2"
fi
dataset_file="$1"
cnt=0
while read -r line; do
	if [ "$(expr $cnt % 3 = 0)" -eq 1 ]; then
		dir_name="$line"
	elif [ "$(expr $cnt % 3 = 1)" -eq 1 ]; then
		base_url="$line" # Unused
	elif [ "$(expr $cnt % 3 = 2)" -eq 1 ]; then
		data_url="$line"
	fi
	if [ "$(expr $cnt % 3 = 2)" -eq 1 ]; then
		echo "Downloading and decompressing into $dir_name..."
		mkdir -p datasets/$dir_name
		zipped_file="$DATA_DIR/$dir_name/${data_url##*/}"
		curl "$data_url" > "$zipped_file"
		gunzip "$zipped_file"
	fi
	cnt=$(expr $cnt + 1)
done < "$dataset_file"

