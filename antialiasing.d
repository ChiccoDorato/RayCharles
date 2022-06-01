    /// Shoot a Ray in a given 2D Point (u, v) on the surface of the image
    pure nothrow @nogc @safe Ray fireRay(in int col, in int row, in float uPixel = 0.5, in float vPixel = 0.5) const
    in (col + uPixel >= 0 && col + uPixel <= image.width)
    in (row + vPixel >= 0 && row + vPixel <= image.height)
    {
        immutable float u = (col + uPixel) / image.width;
        immutable float v = 1.0 - (row + vPixel) / image.height;
        return camera.fireRay(u, v); 
    }

    /// Shoot a Ray in every 2D Point (u, v) on the surface of the image - Solve the rendering equation for every pixel
    void fireAllRays(in Color delegate(Ray) solveRendering)
    {
        for (uint row = 0; row < image.height; ++row){
            for (uint col = 0; col < image.width; ++col){
                Color colSum = Color(0.0, 0.0, 0.0);

                if (samplesPerSide > 0)
                {
                    for (uint interPixelRow = 0; interPixelRow < samplesPerSide; interPixelRow++)
                    {
                        for (uint interPixelCol = 0; interPixelCol < samplesPerSide; interPixelCol++)
                        {
                            immutable float u = (interPixelCol + pcg.randomFloat) / samplesPerSide;
                            immutable float v = (interPixelRow + pcg.randomFloat) / samplesPerSide;
                            Ray ray = fireRay(col, row, u, v);
                            colSum = colSum + solveRendering(ray);
                            
                            image.setPixel(col, row, colSum * (1 / (samplesPerSide * samplesPerSide)));
                        }
                    }
                }
                else 
                {
                Ray ray = fireRay(col, row);
                image.setPixel(col, row, solveRendering(ray));
                }
            }
        }
    }
}
