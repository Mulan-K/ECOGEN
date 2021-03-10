#!/bin/bash

#Settings
#--------
listTestFileName="./libTests/tests.list"
mainOutput="./results/mainOutput.out"
reportFile="./results/report.out"
mail="nomail"

#First argument: Test-list file name
if [ "$1" != "" ]
then
	listTestFileName=$1
fi
#Second argument: Output file name
if [ "$2" != "" ]
then
	mainOutput=$2
fi
#Third argument: Report file name
if [ "$3" != "" ]
then
	reportFile=$3
fi
#Fourth argument: Mail
if [ "$4" != "" ]
then
	mail=$4
fi

#Saving main input file ECOGEN.xml
#---------------------------------
fich="ECOGEN.xml"
mv ./$fich ./mainInput.save
mkdir -p results

#Reading and storing test-case list
#----------------------------------
export nb_tests=$(awk 'END {print NR}' $listTestFileName)
export testsList=($(awk '{print $1}' $listTestFileName)) #catching test folders
export ncpu=($(awk '{print $2}' $listTestFileName)) #catching core numbers

rm -f $mainOutput
touch $mainOutput
rm -f $reportFile
touch $reportFile

#Looping on test cases
#---------------------
testNum=0
for ((k=0;k<$nb_tests;k++)) #array begin to 0
do 
	testNum=$(expr $testNum + 1)
	status="succeed"

	printf "Test case ${testsList[$k]} running on ${ncpu[$k]} cores..."

	#Running gmsh if necessary
	#*************************
	meshType=$(sed -n 's/<type structure="//p' ${testsList[$k]}meshV5.xml | sed -n 's/"\/>//p' | sed '{s/\t//g};{s/ //g}')
	if [ $meshType == "unStructured" ]
	then
		geoFile=$(sed '{s/\t//g};{s/ //g}' ${testsList[$k]}meshV5.xml | sed -n 's/^<filename="//p' | sed 's/\".*//' | sed 's/msh/geo/')
		gmsh -3 -part ${ncpu[$k]} $geoFile >> $mainOutput 2>&1
		if [ $? != 0 ]
		then
			status="failed: mesh generation failed"
		fi
	fi

	if [ $status == "succeed" ]
	then
		#Writing main input file ECOGEN.xml
		#**********************************
		echo "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>" > $fich
		echo "<ecogen>" >> $fich
		chaine="  <testCase>${testsList[$k]}</testCase>"
		echo $chaine >> $fich
		echo "</ecogen>" >> $fich

		#Running ECOGEN
		#**************
		mpirun -np ${ncpu[$k]} ECOGEN >> $mainOutput 2>&1

		#Writting report
		#***************
		errorCode=$?
		if [ $errorCode != 0 ]
		then
			status="failed: error $errorCode"
		else
			status="succeed"
		fi
	fi

	echo "Test case: '${testsList[$k]}' $status" >> $reportFile
	printf " $status\n"
	
done

#Reloading main input file ECOGEN.xml
#------------------------------------
rm -f $fich
mv ./mainInput.save ./$fich

#Ending and sending end e-mail
#-----------------------------
sujet="Job_Complete"
message="Hi Master. My job is complete."
echo $message
if [ $mail != "nomail" ]
then
	echo $message | mail -s $sujet $mail < $reportFile
	echo "Mail sent to: $mail"
fi

exit 0