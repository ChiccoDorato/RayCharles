#!/bin/bash

# Create the directory where allocate pfm files
if [ ! -d ./pfmFrames ]; then
    mkdir pfmFrames
fi

# Create the directory where allocate png files
if [ ! -d ./pngFrames ]; then
    mkdir pngFrames
fi

# Build
dub build

for angle in $(seq 0 359); do
    # Angle with three digits, e.g. angle="1" → angleNNN="001"
    angleNNN=$(printf "%03d" $angle)
    ./RayCharles demo -a $angle -pfm=pfmFrames/img$angleNNN.pfm -png=pngFrames/img$angleNNN.png
done

# -r 30: Number of frames per second
ffmpeg -r 30 -f image2 -s 640x480 -i pngFrames/img%03d.png \
    -codec:v libx264 -pix_fmt yuv420p \
    animation.mp4