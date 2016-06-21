This is a seeking audio player that uses the concurrency extensions.
It is an example of an actually useful program (I use it every day) as
opposed to squint which is just useful for testing and demonstration purposes.

You use it like `aplay foobar.mp3`. It creates a simple graphical user interface
for seeking and pausing your audio file.

Compare it to aplaynoextensions.c to see what this looks like without
the concurrency primitives in the compiler.
