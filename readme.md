# S16 - boot
This is S16's boot sector. It's built to be reliable, simple, and effective for 8086+ processors!

I got **some** inspiration from MS/IBM-DOS & CP/M, but I decided to throw out all of the janky parts.

Its **heavily** tuned for fat12 and single volumes. (WILL NOT WORK ON ANYTHING OTHER THAN FAT12 AND SINGLE VOLUMES!)

You can find my implementation of the boot sector [here!](BOOT.ASM)

## Specifation
S16's boot sector has a specifation in case someone wants to create a disk tool and wants to improve upon the boot sector.

[Spec](bootspec.txt)

## How does it work?

Well unlike MS/IBM-DOS's boot sector, I simply navigate through the root directory to find S16.SYS, load the first cluster at ``0000:0500h``, follow the fat chain until I've loaded every cluster, put boot drive into ``dl``, and then finally perform a far jump to S16.SYS. Instead of having a entire BIOS layer (like MS-DOS's ``IO.SYS``) I simply just go straight to S16's kernel, oh and S16.SYS doesn't have to be the first few clusters in the file system and can be anywhere and fragmented!

## Boot requirements

Minimum usable memory is ``128KiB``.
You'll also need to have ``S16.SYS`` on disk and the volume needs be the first on disk, oh and of course the volume needs to be fat12!

## License

Feel free to do whatever with this project! Honestly, if you wanna use my [boot sector implemenation](BOOT.ASM) in your own project, go for it!
No credits required btw! 

[MIT license](license)

