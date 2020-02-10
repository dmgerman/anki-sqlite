#!/bin/bash

DATE=`date --date '-10 days' '+%Y-%m-%d'`
ANKI=/home/dmg/.local/share/Anki2/Dmg
#ANKIMEDIA=${ANKI}/collection.media
ANKIMEDIA=/tmp/resample
echo "From $DATE"

perl anki-reviews.pl /tmp/collection.anki2  --date=${DATE} > reviews.txt
perl anki-reviews.pl /tmp/collection.anki2 --field='audioSentence' --date=${DATE} >> reviews.txt


perl create-audio-file.pl $ANKI < reviews.txt > ${ANKIMEDIA}/files.txt


ffmpeg -f concat -safe 0 -i ${ANKIMEDIA}/files.txt -c copy /tmp/out.mp3
sox /tmp/out.mp3 -r 44100 /tmp/out2.mp3

echo "Done"
