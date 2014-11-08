#!/bin/bash

xterm -display :0 -e instead -debug -gamespath ./ -game .

#if [ $2 ]; then
 # kill $2
 # wait $!
#fi
#gamespath=$1
#expression="xterm -display :0 -e instead -debug -gamespath ./ -game ."
#eval $expression
#echo $!
