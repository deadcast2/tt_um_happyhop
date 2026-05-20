<!---
This file is the project datasheet, rendered on the Tiny Tapeout submissions page.
Keep images under 512 kB each and all images combined under 1 MB.
-->

## How it works

`happyhop` is a single-tile VGA video generator that draws a colored bouncing
object on a 640x480 monitor with no framebuffer.

The chip runs at a 25.175 MHz pixel clock and produces a standard VGA signal.
A "race the beam" renderer is used: a sync generator emits HSync/VSync and
tracks the current `(x, y)` position of the scanning beam, and a small pixel
function decides the color of each pixel combinationally based on whether it
lies inside the object being drawn.

The object's position is updated once per VSync. When an edge of the screen
is reached, the corresponding velocity component flips sign and the object
bounces away. There is no framebuffer, no memory of past frames - the whole
image is recomputed every frame.

In its initial form the object is a solid colored square; later revisions
upgrade it to a smiley face using a small sprite-mask ROM that defines a
circular face plus eyes and a mouth.

## How to test

1. Plug the Tiny Tapeout VGA PMOD into the chip's output PMOD socket.
2. Connect the PMOD's VGA connector to a monitor that accepts 640x480 @ 60 Hz.
3. Apply power. The bouncing object should appear immediately; no input
   controls are required.

## External hardware

- Tiny Tapeout VGA PMOD (Matt Venn's RGB222 + HSync/VSync design).
- A VGA-capable display set to 640x480 @ 60 Hz.
