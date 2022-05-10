#!/bin/bash

# Create the directory where allocate png files
if [ ! -d ./AnimationFrames ]; then
    mkdir AnimationFrames
fi

for angle in $(seq 0 359); do
    # Angle with three digits, e.g. angle="1" → angleNNN="001"
    angleNNN=$(printf "%03d" $angle)
    ./RayCharles demo --width=640 --height=480 --angleDeg $angle --pngOutput=AnimationFrames/img$angleNNN.png
done

# -r 30: Number of frames per second
ffmpeg -r 30 -f image2 -s 640x480 -i AnimationFrames/img%03d.png \
    -codec:v libx264 -pix_fmt yuv420p \
    spheresPerspective.mp4
