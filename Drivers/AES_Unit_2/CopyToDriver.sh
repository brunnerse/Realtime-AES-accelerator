#!/bin/sh
path=~/Git_Repositories/_MasterCode/Vitis/aes_phase2_plat/

for file in $(ls)
do
if [[ $file == Makefile || ./$file == $0 ]]
then
	echo "Not copying the makefile and itself!"
else
	results=$(find $path -name $file) 
	for r in $results
	do
		echo Copying file $file to $r ...
		cp $file $r	
	done
fi
done
