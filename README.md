# PCE_Blox

Falling Blocks-type game written in Assembler for PC Engine in 1999


## Build

This was originally built back in 1998/1999 with MagicKit 2.01; subsequent versions of the
"standard" library appear to have changed sematics which might cause it to no longer build.

So, I have packaged the original build into a ZIP file in the build directory, called "19990527.zip".

As the standard library of include files has changed over the years, I have taken a copy of
the include files from version 2.00, and deleted (or disabled) unreferenced portions of code
which I was able to identify.  These files are now in the "INCLUDE" folder.

In order to build, you will need to set the PCE_INCLUDE environment variable to point to the
include folder of this repository, and assemble using the command:
```
pceas -l 3 GAME.ASM
```

Feel free to peruse the code, and I hope you can enjoy the game.
