#!/bin/bash
#Script for renaming images to format readable by the smei website php scripts and copying them to the appropriate directory on the web server.
#ex: sh rename_images.sh source destination [optional: Any or all of "fish ham ecl mer rem fishv hamv eclv merv remv ecler1 merer1"  or none for all ]
#source: directory with images directly inside of it.
#destination: will become parent of the subdirectory starting with the year; ex: destination/2003/05/13/etc...
 
sourceDirectory=$1
destinationDirectory=$2
inclusionFilter=$3
 
if [ $sourceDirectory == '' ] || [ $destinationDirectory == '' ]
then
	echo 'Please provide valid source and destination directories'
	exit
fi
 
function getBaseFilename {
	baseFilename=${file:((${#sourceDirectory}+1))}
}
 
#Assumes remote copy if there is a ':' in the destination directory.
function getUsername {
	echo $destinationDirectory | grep -b -o -q -i ':'
	if [ $? == 0 ]
	then
		grepPos=$(echo $destinationDirectory | grep -b -o ':')
		charPos=${grepPos:0:((${#grepPos}-2))}
		username=${destinationDirectory:0:charPos}
		localOrRemote='remote'
	else
		localOrRemote='local'
	fi
}
 
function getFilename {
	grepStrUT=$(echo $file | grep -b -o 'UT')
	positionUT=${grepStrUT:0:2} #only works for offsets <= 99
	dateString=${file:$((positionUT-13)):13}
	year=${dateString:0:4}
	month=${dateString:4:2}
	day=${dateString:6:2}
	UT=${dateString:9:2}
	extension=${file: -4} #whitespace before negative number is necessary
	filename=$year-$month-$day-$UT$extension
}
 
#Creates subdirectory based on the plot type as discerned from information in the filename.
#Loops through the array of names for a particular file, if it greps a match it exits and keeps the imageType,
#if it finds no match then that file will not be copied. The last continue is for the outer loop.
function getImageType {
	getBaseFilename #creates baseFilename
 
	if [ -z "$inclusionFilter" ] #if inclusionFilter has zero length, then use the default of all images. (inclusionFilter='')
	then
		typeArray=( 'fisheye' 'h-a' 'ecliptic' 'meridional' 'remote' 'fisheyev' 'h-av' 'eclipticv' 'meridionalv' 'remotev' 'eclipticer1', 'meridionaler1')
	else
		typeArray=$inclusionFilter
	fi
 
	for typeCheck in ${typeArray[@]}
	do
		if [[ ${typeCheck: -1} == [Vv] ]] 
		then
			velFilter=0
			typeCheck=${typeCheck:0:((${#typeCheck}-1))}
		else
			velFilter=1
		fi
 
		if [[ ${typeCheck: -3} == [Ee][Rr][1] ]] 
		then
			errFilter=0
			typeCheck=${typeCheck:0:((${#typeCheck}-3))}
		else
			errFilter=1
		fi
 
		shopt -s nocasematch
		if [ $typeCheck == 'hammer-aitoff' ] || [ $typeCheck == 'hammer' ] || [ $typeCheck == 'ham' ]	
		then
			typeCheck='h-a'
		fi
		shopt -u nocasematch		
 
		echo $baseFilename | grep -b -o -q -i $typeCheck
		typeGrep=$?
 
		echo $baseFilename | grep -b -o -q -i '_v' 
		velGrep=$?
 
		echo $baseFilename | grep -b -o -q -i 'er1' 
		errGrep=$?
 
		echo $baseFilename | grep -b -o -q -i '[S][AB]' 
		stereoGrep=$?
 
		if [ $typeGrep == 0 ] && [ $velGrep == $velFilter ] && [ $errGrep == $errFilter ] && [ $stereoGrep != 0 ]
		then 
			case $typeCheck in
				'fisheye') ;& 'fish') ;& 'fis')
					imageType='fisheyerecons'
					break
				;;
				'h-a') ;& 'h')			
					imageType='hammerrecons'
					break				
				;;
				'ecliptic') ;& 'ecl')
					imageType='eclipticrecons'
					break
				;;
				'meridional') ;& 'mer')
					imageType='meridionalrecons'
					break
				;;
				'remote') ;& 'rem') 
					imageType='smei3drecons'
					break
				;;
			esac
		else
			imageType='other'	
		fi
	done
 
	if [ $imageType == 'other' ] #if not one of the above five image types, go to the next image without copying
	then
		continue
	fi
 
	if [ $velFilter == 0 ]
	then
		imageType=${imageType}V
	fi		
 
	if [ $errFilter == 0 ]
	then
		imageType=${imageType}Er1
	fi		
}
 
function mkdirAndCopy {
	if [ $localOrRemote == 'local' ]
	then
		mkdir -p $destinationDirectory/$year/$month/$day/$imageType
		cp $file $destinationDirectory/$year/$month/$day/$imageType/$filename
	elif [ $localOrRemote == 'remote' ]
	then
		properDestDir=${destinationDirectory:((${#username}+1))}
ssh -T $username << ENDSSH #single quotes or double quotes here will prevent expansion of the heredoc
		mkdir -p $properDestDir/$year/$month/$day/$imageType
ENDSSH
		scp $file $destinationDirectory/$year/$month/$day/$imageType/$filename	
	fi		
}
 
for file in $1/*
do
	if [ "$file" != "$0" ] #The first parameter that is looped over is the scripts name 'image_renamer.sh'. So skip it.
	then
		getImageType #creates imageType, also does inclusion type filtering	
 
		getFilename	#creates year, month, and day
 
		getUsername #creates username and checks if local or remote copy
 
		#echo $baseFilename #Comment the line below and uncomment this line to see what will get copied.
		mkdirAndCopy		
	fi 
done
