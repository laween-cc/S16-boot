# S16 - boot
This is S16's boot sector. It's built to be reliable, simple, and effective for 8086+ processors!

I got **some** inspiration from MS/IBM-DOS & CP/M, but I decided to throw out all of the janky parts.

It uses S16's own file system (S16FS) to locate ``SYSTEM.SYS`` from root and load into memory. You can find more information about it [here.](s16fs.txt)

You can find my implementation of the boot sector [here!](boot.asm)

## Specifation
S16's boot sector has a specifation in case someone wants to create a disk tool or wants to improve upon the boot sector.

[Spec](bootspec.txt)

## License

Feel free to do anything with this project! No credits required.

[MIT license](license)

