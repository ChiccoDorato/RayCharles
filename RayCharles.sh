#!/bin/bash

for angle in $(seq 0 359); do
    # Angle with three digits, e.g. angle="1" → angleNNN="001"
    angleNNN=$(printf "%03d" $angle)
    ./RayCharles demo --width=640 --height=480 --angleDeg $angle --pngOutput=img$angleNNN.png
done

# -r 25: Number of frames per second
ffmpeg -r 25 -f image2 -s 640x480 -i img%03d.png \
    -codec:v libx264 -pix_fmt yuv420p \
    spheresPerspective.mp4
