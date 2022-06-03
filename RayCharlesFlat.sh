#!/bin/bash

# Create the directory where allocate pfm files
if [ ! -d ./flatPfmFrames ]; then
    mkdir flatPfmFrames
fi

# Create the directory where allocate png files
if [ ! -d ./flatPngFrames ]; then
    mkdir flatPngFrames
fi

# Build
dub build

for angle in $(seq 330 429); do
    # Angle with three digits, e.g. angle="1" → angleNNN="001"
    angleNNN=$(printf "%03d" $angle)
    ./RayCharles demo -a $angle -pfm=flatPfmFrames/img$angleNNN.pfm -png=flatPngFrames/img$angleNNN.png \
        -alg flat -spp 4
done

# -r 30: Number of frames per second
ffmpeg -r 30 -f image2 -s 640x480 -start_number 340 -i flatPngFrames/img%03d.png \
    -codec:v libx264 -pix_fmt yuv420p \
    flatAnimation.mp4