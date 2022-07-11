#!/bin/bash

# Check if the input scene file and the name of the mp4 have been provided
if [ $# -ne 2 ] || ! [[ $1 == *.txt ]]; then
    echo "Usage: RayCharles.sh inputScene.txt animationName"
    exit 1
fi

scene=$1
mp4Name=$2
if ! [ -f $scene ]; then
    echo "$1 does not exist"
    exit 1
fi

# Create the directory where allocate the png files
if [ ! -d ./pngFrames ]; then
    mkdir pngFrames
fi

# Create the directory where allocate the animation
if [ ! -d ./animations ]; then
    mkdir animations
fi

# Build
dub build --compiler ldc2

for angle in $(seq 0 359); do
    # Angle with three digits, e.g. angle="1" → angleNNN="001"
    angleNNN=$(printf "%03d" $angle)
    ./RayCharles render $scene -df angle:$angle -d 3 -spp 4 \
        -pfm=img.pfm -png=pngFrames/img$angleNNN.png
done

rm img.pfm

# -r 30: Number of frames per second
ffmpeg -r 30 -f image2 -s 640x480 -start_number 0 -i pngFrames/img%03d.png \
    -codec:v libx264 -pix_fmt yuv420p \
    animations/$mp4Name.mp4