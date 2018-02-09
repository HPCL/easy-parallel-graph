#!/bin/bash
# Unzips the datasets and saves them into the specified directory.
# The dataset config file has the following three-line pattern:
# dataset name\ndataset homepage\ndataset url
# e.g.
# facebook_combined
# https://snap.stanford.edu/data/egonets-Facebook.html
# https://snap.stanford.edu/data/facebook_combined.txt.gz

USAGE='usage: unzipper.sh <dataset file> <dataset_dir>
		dataset_dir default: ../experiment/datasets>'
DATA_DIR="../experiment/datasets"
if [ -z "$1" ]; then
	echo $USAGE
	exit 2
fi
if [ -n "$2" ]; then
	DATA_DIR="$2"
fi
dataset_file="$1"
cnt=0
oldwd=$(pwd)
while read -r line; do
	if [ "${line:0:1}" = '#' ]; then
		continue
	fi
	if [ "$(expr $cnt % 3 = 0)" -eq 1 ]; then
		dir_name="$line"
	elif [ "$(expr $cnt % 3 = 1)" -eq 1 ]; then
		base_url="$line" # Unused
	elif [ "$(expr $cnt % 3 = 2)" -eq 1 ]; then
		data_url="$line"
	fi
	if [ "$(expr $cnt % 3 = 2)" -eq 1 ]; then
		echo "Downloading and decompressing into $dir_name..."
		mkdir -p $DATA_DIR/$dir_name
		zf="${data_url##*/}"
		cd $DATA_DIR/$dir_name
		if ! [ -f "$zf" ]; then
			curl "$data_url" > "$zf"
		fi
		# TODO: The compressed files are currently deleted. -k option isn't on Talapas
		case $zf in
			*.tar.bz2) tar xvjf $zf   ;;
			*.tar.gz)  tar xvzf $zf   ;;
			*.bz2)     bunzip2 $zf    ;;
			*.gz)      gunzip $zf     ;;
			*.tar)     tar xvf $zf    ;;
			*.tbz2)    tar xvjf $zf   ;;
			*.tgz)     tar xvzf $zf   ;;
			*.zip)     unzip $zf      ;;
			*)         echo 'Unknown file extension' ;;
		esac
		if [ -d "$dir_name" ]; then
			mv "$dir_name"/* .
			rmdir "$dir_name"
		fi
		cd $oldwd
	fi
	cnt=$(expr $cnt + 1)
done < "$dataset_file"

