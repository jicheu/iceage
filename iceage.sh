#!/bin/bash

# Check syntax
if [ $# -lt 2 ]
then
	echo "Usage: iceage VAULT PATH [type]"
	echo "VAULT: your (already created) glacier VAULT"
	echo "PATH: the path where to look for images to upload"
	echo "[type] optional type of file: image, video, ... everything file command can identify"
	echo "  all for every file"
	echo "  empty means *image* only"
	exit 1
fi

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
        echo "** Trapped CTRL-C"
	exit 2
}

vault=$1
path=$2
filetype="image"

# if filetype requested is all, then we'll fake the grep by looking for : which is present by default
if [ $# -eq 3 ]
then
	if [ $3 == "all" ]
	then
		filetype=":"
	else
		filetype=$3
	fi
fi

log="iceage.log"

# generate files to upload list
# TODO: choose type of file to upload, today it's hardcoded to grep for "image" type
function generate {
	touch imagelist.txt
	echo "Generating list of files to upload..."
	find $path -name "*" -follow -type f -print0 | xargs -0 file | grep $3 | awk -F ":" '{print $1}' > imagelist.txt
}

# what to do with existing image list
if [ -e imagelist.txt ] 
then
	echo "Imagelist already present, use it (yY) or regenerate(nN)"
	read answer
	if [[ `echo $answer | tr '[:upper:]' '[:lower:]'` == "n" ]]
	then
		rm imagelist.txt
		generate
	fi
else
	generate
fi

# if log exists, assume we are resuming, remove already uploaded files

if [ -e $log ] 
then
	echo "Resuming: let me remove files already uploaded"
	grep -v -i -f $log imagelist.txt > tmp.txt
	mv tmp.txt imagelist.txt
else
	touch $log
fi


echo "`wc -l imagelist.txt | awk '{print $1}'` files to upload. Grab a cup of coffee..."

while read line
do
	echo "Uploading $line (`ls -l ""$line"" | awk -F " " '{print $5}'` bytes) in vault $vault"
	# Upload with a name where we replace spaces by underscore. Avoid future trouble...
	glacier --region eu-west-1  archive upload --name "`echo $line | tr ' ' '_'`" $vault "$line"
	if [ $? == 0 ] 
	then
		echo "$line" >> $log
	fi
done <imagelist.txt

# generate error list
echo "Finished upload. Calculating the results..."
grep -v -i -f $log imagelist.txt > missing.txt
if [ -s missing.txt ]
then
	echo "Some files were not uploaded, check missing.txt"
else
	echo "all done!"
fi

exit 0
