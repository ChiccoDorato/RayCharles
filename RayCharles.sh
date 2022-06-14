#!/bin/bash

# Create the directory where allocate png files
if [ ! -d ./pngFrames ]; then
    mkdir pngFrames
fi

# Create the directory where allocate the animation
if [ ! -d ./animations ]; then
    mkdir animations
fi

# Build
dub build --compiler ldc2

for angle in $(seq 0 360); do
    # Angle with three digits, e.g. angle="1" → angleNNN="001"
    angleNNN=$(printf "%03d" $angle)
    ./RayCharles demo -a $angle -alg path -d 3 -spp 4 \
        -pfm=img.pfm -png=pngFrames/img$angleNNN.png
done

rm img.pfm

# -r 30: Number of frames per second
ffmpeg -r 30 -f image2 -s 640x480 -start_number 0 -i pngFrames/img%03d.png \
    -codec:v libx264 -pix_fmt yuv420p \
    animations/rollingWorld.mp4