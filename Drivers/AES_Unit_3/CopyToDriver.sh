#!/bin/sh
paths="C:/Users/Severin/Git_Repositories/_MasterCode/Vitis/aes_phase3_plat/
	C:/Users/Severin/Git_Repositories/_MasterCode/Vivado/ip_repo/AES_Unit_3_1.0
	C:/Users/Severin/Git_Repositories/_MasterCode/Vitis/aes_phase3_app"

for path in $paths
do
echo Copying to directory $path ...

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

done
