# GETCD: MS-DOS .BAT Utility For Locating CD-ROM Drive

`GETCD.COM` is "batch utility" for MS-DOS to assist in locating a
CD-ROM drive based on file search. It is similar to `FINDCD.EXE` 
with the following exceptions
- it takes an argument to specify a file
- automatically creates/manages the CDROM= variable

It is written in NASM assembler; and is mostly the thing I wrote
while ~~attempting to learn~~ learning assembler.

## Usage

`GETCD.COM` does not display much in the way of user output. The
largest chunk can be seen by calling the basic help:

`getcd /?`

If you were to "place a CD" in a "CD drive" with the file what.txt
on it and ran this:

`getcd what.txt`

It looks like nothing happened. However, if you call `set` from the
command prompt to see the current variables; you should see `CDROM=D:`
(or whatever the actual drive letter is) now exists. 

`getcd` on it's own will default to a wildcard (*) search. This has
the effect of returning the first CD drive that has a disc in it, or
doesn't return some kind of error.

Wildcards are allowed in the search string; as well as just directory
names. The first drive that doesn't fail search is returned. 

`NO ENV FREE` is the only displayed error message if you don't have 
enough environment space free. Most failures should result in nothing
being changed. This plays well with being a batch utility:

```
@echo off
set CDROM=0:
getcd what.txt
if %CDROM%=0: goto nocd
(do stuff)
goto exit
nocd:
(stuff for no cd)
exit:
```

Additionally, you can look for errorlevel 255, which is returned if
there are no CDROM drives.

### Adapting scripts for FINDCD.EXE

You'll just need to modify `FINDCD` to `GETCD [file]`

### My scripts want a \ in the variable

`GETCD` is kind of picky in that it will make the CDROM variable
a drive letter, a colon, and no backslash. I may change this by
assuming an extra character is a backslash an not delete it.

But, for now; just do this in your .bat

```
set CDROM=%CDROM%\
```



## What does this do?

- It lets you specify a file to search CD-ROM drives for and puts
that drive letter in to the CDROM= environment variable. Then 
fancy .BAT scripts can go `call %CDROM%\install.bat` and
run the .bat off the CD.

## How does it differ from other utilities?

- The only utility I've actually found has been FINDCD.EXE. The
alternative is apparently for loops. I've seen mentions of other
utlities on sites devoted to .bat scripting; but never found an
exe.
The differences from FINDCD are passing a filename as an argument
and the automatic management of the variable. FINDCD used a hard
coded file in the binary as well as requiring you to preset the
variable. 
I decided to just toss all that aside and assume the user might
not do it right; or in the case of FINDCD; the variable length 
pre-set is longer than necessary. I have no clue what FINDCD is 
doing with the variable.

## Building

`nasm -o getcd.com getcd.asm`

The build system was FreeDOS with WatcomC, DJGPP, IA16, and a few other things on it. 

It was tested on MS-DOS 6.22 under an 86Box emulated 486/DX4 100.

## Random Things Passed As FAQ:

**Why a .COM and not a .EXE?**

   - We didn't need any of the fancy options a .exe gave us. Our binary is not over 65kB in size and doesn't have to be relocated to run. That is primarily what .exe would give me; the ability to relocate my code once loaded. I could have assembled this to an object file then linked it to an .EXE, but I still wouldn't be using any "EXE features"

**What are the minimum requirements?**

   - DOS 3.3 and a CD-ROM drive. The program doesn't use much ram and
    while will technically run on an 8088, the lack of CD-ROM drivers
    are a bigger issue.

**Will this work on FreeDOS?**

   - Yes, it's been known to. I have not tested the memory manipulating
    version; but early versions worked.

**What about n-DOS?**

   - No comment. It *should*, but it will depend if your CD-ROM extensions
    respond to the interrupts I use. 

**Why did you do this?**

   - I'd wanted to see if I could write x86 ASM for quite some time. I 
    hadn't learned ASM beyond knowing how CPU's work at a low level
    and what ASM was. I had an incorrect assumption that I didn't know 
    the levels of math required to make it work that I'd held for years.
    Anyway; I'd also incorrectly assumed after diving in that the magic
    of low-level would give me a secret way to look at drives without
    triggering errors. It did; but changing the interrupt vector isn't
    ASM specific..it was, like most things; a concept I'd heard about
    but really didn't undertand back in my teens when I first tried.
    I almost gave up and went to C when I was just trying to get the
    byte in the env block realizing that's why people have libaries.
    And, no; what little I read about the subject involved inline ASM.
    My most optimized version was 98 bytes. Yes, 98. It had no file
    argument or memory management. You had to make the environment; 
    variable, it put the letter at the byte after =, and that was it.
    Then I decided to add features for the sake of stability and users;
    plus what good is a clone if you don't improve it.
    So despite serving no real purpose and being a huge time-sink for
    something only I'll probably use; I'm at least better in ASM than
    when I started. Huge bar given I started at almost zero.

## License

MIT No Attribution

Copyright 2024 Jay Moore

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.