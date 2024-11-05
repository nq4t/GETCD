;GETCD V 1.0 | 3-NOV-2024 Jay Moore/dewdude@pickmy.org
;Finds CDROM drive letter and places in CDROM
;environment variable
;
;A replacement for FINDCD.EXE written in NASM Assembly and
;manipulates a lot of memory directly. Not a drop-in
;replacement, but close. Designed as a .BAT utility, the
;only user interaction is feeding it a path/filename and
;checking the environment variable. Default returns first
;CDROM drive that has a disc.
;
;GETCD [/?] SEARCHSTRING
;
;SEARCHSTRING can be a file, directory name, path, or wildcard.
;Not specifying a file does a wildcard search on root of CD.
;You do not need to add a leading \ to the string.
;/? displays the usual help, except poorly written.
;
;CDROM=E:
;
;Is how the variable will be set. If you desire a trailing \;
;just have your script 'set CDROM=%CDROM%\'
;
;This will absolutely overwrite any existing CDROM= contents with
;the above format; and will also shift data around to make it the
;exact length. It will also create an environment variable if none
;exists. This is contrast with FINDCD.EXE; which not only needs
;you to set the CDROM= variable first, but requires patching the
;.exe to change the file search. Gross.
;
;Displayed output is minimal. The only error displayed is if the
;environment block is full. A lack of CDROM drives will exit with
;errorlevel 255. Anything else just doesn't change (or create) the
;CDROM variable. You'll need to do that after execution in your script.
;
;argument section of PSP starts at 80h; byte count, bytes, terminator. 
;term is 0x0D, but it's not included in byte count. this can include
;spaces if full name.ext is used or user just hit space. 
;the pointer to parent's PSP lives at 16h; env-block pointer is 2Ch
;offset 3 one segment back is the block allocation size. 
;this means I initialize di to 10h now and just leave es where it is
;as all counts are relative from di's initialization

[CPU 8086]
[BITS 16]
org 100h 

section .text
   global start

start:
    xor cx, cx                  ; clear out cx
    mov si, 80h                 ; move si to psp argument count
    mov cl, [si]                ; load argument byte count

argproc:
    jcxz varinit                ; stop if cx is 0
    inc si                      ; increment si
    cmp byte [si], 20h          ; Invalid char/space check
    jbe skipit                  ; jump to loop if <20h
    cmp byte [si], 5ch          ; is it backslash
    jz skipit                   ; jump if it is
    cmp word [si], 3f2fh        ; check for /?
    jz hllp                     ; jump if it is
    jmp ldfile                  ; land here when done
skipit:
    loop argproc                ; dec cx, jmp argproc ;)

 ldfile: 
    lea di, filename            ; load filename to di
    repe movsb                  ; copy argument to filename
    mov byte [di], 0            ; null for good measure

varinit: 
    mov es, [16h]               ; parent psp pointer
    mov ax, [es:2ch]            ; load block segment
    dec ax                      ; segment one below
    mov es, ax                  ; go back a segment
    mov ax, [es:3h]             ; this is the size
    mov cl, 4                   ; load 4 to cl for shl
    shl ax, cl                  ; bit shift left 4
    mov [blocksize], ax         ; store
    mov di, 10h                 ; move di up to env blk

readblock: 
    cmp word [es:di], 0         ; end of block?
    jz endofblock               ; variiable missing
    lea si, envname             ; load envname address
    mov cx, 6                   ; load six 
    repe cmpsb                  ; repe compare string
    jnz readblock               ; if not variable, go back up
    sub di, 6                   ; subtract 6
    mov [envstart], di          ; write starting location
    add di, 6                   ; place it back

findend: 
    inc di                      ; now to find the end
    cmp word [es:di], 0         ; is it the end?
    jnz findend                 ; jump back up if not

endofblock:
    inc di                      ; actual end of block
    mov [blockend], di          ; write that down
    cmp word [envstart], 0      ; did we find a var
    jz noenv                    ; jump if novar
    mov di, [envstart]          ; go back to the env start
    mov ax, 1212h               ; get the asciz length
    int 2fh                     ; in to cx
    cmp cx, 9                   ; and see if it's 9
    jb envtoosmall              ; jump to envtosmall if too small
    ja envtoobig                ; jump to envtoobig if too big

envokay: 
    add di, 6                   ; drive letter is six in
    jmp drivego                 ; es:di ready for letter

envtoobig:
    mov si, di                  ; duplicate pointers
    mov word [es:di+7], 0x003A  ; write : and null
    add si, 9                   ; put si where i need di
    call endcheck               ; check relative position
    call bytesize               ; get byte count to copy
    xchg di, si                 ; now we swap
    cld                         ; clear that direction
    call copybytes              ; copy byte routine
    mov word [es:di], 0         ; double null new end
    mov di, [envstart]          ; go back to the env
    jmp envokay                 ; might as well jump

noenv:
    call envfree                ; check free space
    mov di, [blockend]          ; go to block end


newenv: 
    lea si, envname             ; load address of envname
    mov cx, 8                   ; we want 8 bytes
    repe movsb                  ; write 'em
    mov word [es:di], 0000h     ; double null new term
    sub di, 2                   ; back di up two
    jmp drivego                 ; es:di is ready

envtoosmall:
    mov byte [oneornine], 01h   ; change envfree's cmp value
    call envfree                ; check environment space
    call endcheck               ; check relative position
    call bytesize               ; call for byte count
    add cx, 3                   ; add three to that count
    mov si, [blockend]          ; load the end of block offset to si
    mov di, [blockend]          ; load it again to di
    inc di                      ; move it up one
    std                         ; set direction flag
    call copybytes              ; copybytes routine
    mov word [es:di+1], 0x003A  ; write the : and null one byte up 

drivego:
    mov ax, 2524h               ; Ignore Critical Errors
    lea dx, [new24]             ; pointer to new handler
    int 21h                     ; interrupt to change ivt
    mov ax, 1500h               ; function to get drive info
    int 2Fh                     ; from int 2f
    xchg bx, cx                 ; swap count and starting number
    jcxz nodrives               ; see if we have drives
    add bl, 41h                 ; convert number to letter

loadltr: 
    push cx                     ; push drive count to stack
    mov [drivevar], bl          ; copy drive letter to ram
    lea dx, drivevar            ; load address of drivevar
    mov ah, 4Eh                 ; load find first file
    mov cl, 17h                 ; all the options
    int 21h                     ; call the interrupt
    jnc envset                  ; found file, go on
    pop cx                      ; pop drive count back in to CX
    inc bl                      ; increment to next drive
    loop loadltr                ; loop back around
    jmp exit                    ; no match, leave

envset:
    lea si, drivevar            ; loads address to si
    movsb                       ; moves ds:si to es:di
    jmp exit                    ; we're done, go home

nodrives:
    mov al, 0FFh                ; load errorlevel 255 to al

exit:
    mov ax, 4c00h               ; standard dos kernel terminate
    int 21h                     ; bye.

endcheck:
    push cx                     ; push cx to stack
    add cx, di                  ; add di to cx
    sub cx, [blockend]          ; subtract blockend from cx
    jcxz fakenew                ; jump if zero
    pop cx                      ; invert cx (it should be neg)
    ret                         ; go back to moving bytes

fakenew:
    sub sp, 04h                 ; reset the stack you animal
    mov di, [envstart]          ; load di
    jmp newenv                  ; pretend it's new

copybytes:
    push ds                     ; push ds on to the stack
    push es                     ; push es on to the stack
    pop ds                      ; pop es in to ds for this
    repe movsb                  ; copy ds:si to es:di till cx is 0
    pop ds                      ; pop ds's original value back out
    ret

envfree:
    mov ax, [blocksize]         ; load size
    sub ax, [blockend]          ; calculate free
    cmp al, [oneornine]         ; need n free
    jz blockfull                ; not enough space
    ret                         ; return if ok

bytesize:
    add di, cx                  ; place di at next variable
    mov cx, [blockend]          ; load the end of the block
    sub cx, di                  ; subtract the actual usage
    ret                         ; return from subroutine

hllp:
    lea dx, hlptxt              ; address of $-terminated strong
    mov ah, 09h                 ; display string function
    int 21h                     ; dos interrupt
    jmp exit                    ; exit

new24: 
	mov al, 3                   ; FAIL! (Hitting F, but faster)
	iret                        ; Return from interrupt.

section .data

hlptxt:
    db 'GETCD 1.0 | 4-NOV-2024 | dewdude@pickmy.org | Freeware/MIT', 0x0d, 0x0a
    db 'Sets "CDROM=[driveletter]:" by searching CD-ROM drives', 0x0d, 0x0a
    db 'USAGE: GETCD [/?] [FILE/OR/PATH/TO/FILE.EXT]', 0x0d, 0x0a
    db 'Finds file on CD-ROM drives. Returns first match. Allows wildcards.', 0x0d, 0x0a
    db 'Creates/adjusts variable. Default search is wildcard.$', 0x0d, 0x0a
blockfull: db 'NO ENV FREE $'
blocksize: db 0, 0             ; holds block size
envstart:  db 0, 0             ; start of cdrom=
blockend: db 0, 0              ; end of used block
oneornine: db 09h              ; default 9
envname: db 'CDROM='           ; variable name
drivevar: db '0:\'             ; variable's variable
filename: db '*', 0x00         ; (default) filename

;MIT No Attribution
;
;Copyright 2024 Jay Moore
;
;Permission is hereby granted, free of charge, to any person obtaining a copy of this
;software and associated documentation files (the "Software"), to deal in the Software
;without restriction, including without limitation the rights to use, copy, modify,
;merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
;permit persons to whom the Software is furnished to do so.
;
;THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
;INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
;PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
;HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
;OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
;SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

