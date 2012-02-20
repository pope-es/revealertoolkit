#!/bin/bash
#
# NOTE: Must be launched from "output/parser/export" !!! (or a copy of it)

IFS="
"

for i in * ; do
	cd "$i"
	echo "Processing folder $( pwd )"
	mkdir mail files

  # Mail:
	for message in $( find text-*_RVT-Source -name FullMessage.html ); do
		ncd-cpath.sh $( dirname "$message" ) mail/ 
	done
#	find text-*_RVT-Source -name FullMessage.html -exec ncd-cpath.sh '{}' mail/ \; >/dev/null
	~/revealertoolkit/tools/RVT_pff_indexer.sh $PWD/mail/
	for line in $( find . -name FullMessage.html |cut -c3- | cut -d. -f1 | grep -v "^mail" ); do
	  rm -rf "$line"* 
	done
	
  # Other files. Multilevel... oh yeah bitch I am the dealer and u r my hook.
	# Soy la puta leche. Poesía pura:
	mv *Source files/ 2>/dev/null
	rmdir *Source 2>/dev/null
	rm text* 2>/dev/null
	for i in $( seq 1 5 ); do 
		mv files/*Source/* files/ 2>/dev/null
	done
	rm -rf *Source 2>/dev/null
	rm -rf files/*Source 2>/dev/null
	rm files/text-*.txt 2>/dev/null
	
	## 			O BIEN ::::::
# 	count=1;
# 	for file in $( find *Source -type f ); do
# 		echo "VOY A POR: $file"
# 		temp=$( basename "$file" )
# 		cp "$file" "files/${count}-$temp"
# 		count=$(( $count + 1 ))
# 	done
# 	rm text-*.txt
# 	rm files/*-pdf-*.txt files/*-text-*.txt files/*-RVT*
	
	
	cd ..
done

echo "Cleaning..."
# Cosas que me quiero petar (OJO DESDE DÓNDE LO TIRAS!!!!!!!!!!!!!!!)
find . -name "*RVT-Exception-Exceeded_Copy_Size_Limit.txt" -exec rm '{}' \;
find . -name "*RVT-Exception-No_Source.txt" -exec rm '{}' \;

# falta pensar: ¿qué hago con los Appointment.txt?


echo "Done"

