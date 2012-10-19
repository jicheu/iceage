#!/bin/bash

# Check syntax
if [ $# -ne 2 ]
then
	echo "Usage: iceage VAULT PATH"
	echo "VAULT: your (already created) glacier VAULT"
	echo "PATH: the path where to look for images to upload"
	exit 1
fi

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
        echo "** Trapped CTRL-C"
	exit 2
}

path=$2
vault=$1
log="iceage.log"

# generate files to upload list
# TODO: choose type of file to upload, today it's hardcoded to grep for "image" type
function generate {
	touch imagelist.txt
	echo "Generating list of files to upload..."
	find $path -name "*" -follow -type f -print0 | xargs -0 file | grep image | awk -F ":" '{print $1}' > imagelist.txt
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
	glacier archive upload --name "`echo $line | tr ' ' '_'`" $vault "$line"
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
