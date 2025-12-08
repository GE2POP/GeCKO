#!/bin/bash

set -e -o pipefail

info=$1


info_R1=$(echo $info | sed 's/\.info$/\.R1\.info/')
info_R2=$(echo $info | sed 's/\.info$/\.R2\.info/')


R1_tot=$(grep -A 2 'Total basepairs' $info | grep 'Read 1' | awk '{print $3}')
R2_tot=$(grep -A 2 'Total basepairs' $info | grep 'Read 2' | awk '{print $3}')
R1_written=$(grep -A 2 'Total written' $info | grep 'Read 1' | awk '{print $3}')
R2_written=$(grep -A 2 'Total written' $info | grep 'Read 2' | awk '{print $3}')


sed 's/\.R2/\.R1/g' $info | awk -v T=$R1_tot -v W=$R1_written '{if ($1=="Total" && $2 == "basepairs") $4=T ; if ($1=="Total" && $2 == "written") $4=W ; print $0}' > $info_R1
awk -v T=$R2_tot -v W=$R2_written '{if ($1=="Total" && $2 == "basepairs") $4=T ; if ($1=="Total" && $2 == "written") $4=W ; print $0}' $info > $info_R2
