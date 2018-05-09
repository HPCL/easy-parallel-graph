#!/bin/bash
# Unzips the datasets and saves them into the specified directory.
# The dataset config file has the following three-line pattern:
# dataset name\ndataset homepage\ndataset url
# e.g.
# facebook_combined
# https://snap.stanford.edu/data/egonets-Facebook.html
# https://snap.stanford.edu/data/facebook_combined.txt.gz
# TODO: Add so you can specify only _some_ datasets

USAGE='usage: unzipper.sh <dataset file> <dataset_dir> [set of dataset names]
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
		: # Unused
	elif [ "$(expr $cnt % 3 = 2)" -eq 1 ]; then
		data_url="$line"
	fi
	if [ "$(expr $cnt % 3 = 2)" -eq 1 ]; then
		echo "Decompressing into $dir_name..."
		zf="${data_url##*/}"
		cd $DATA_DIR/$dir_name
		# TODO: The compressed files are currently deleted. -k option isn't on Talapas
		case $zf in
			*.tar.bz2) cp $zf $zf.bak && tar xvjf $zf && mv $zf.bak $zf  ;;
			*.tar.gz)  cp $zf $zf.bak && tar xvzf $zf && mv $zf.bak $zf  ;;
			*.bz2)     cp $zf $zf.bak && bunzip2 $zf  && mv $zf.bak $zf  ;;
			*.gz)      cp $zf $zf.bak && gunzip $zf   && mv $zf.bak $zf  ;;
			*.tar)     cp $zf $zf.bak && tar xvf $zf  && mv $zf.bak $zf  ;;
			*.tbz2)    cp $zf $zf.bak && tar xvjf $zf && mv $zf.bak $zf  ;;
			*.tgz)     cp $zf $zf.bak && tar xvzf $zf && mv $zf.bak $zf  ;;
			*.zip)     cp $zf $zf.bak && unzip $zf    && mv $zf.bak $zf  ;;
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

