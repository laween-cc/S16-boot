BITS 16
ORG 7C00H

; Example for the boot sector (data area and the boot signature are not included)
; BIOS REQUIREMENTS: IBM compatible bios
; PROCESSOR REQUIREMENTS: 8086+ processor

BOOT:
    CLI ; disable interrupts as they arent needed during this stage
    XOR AX, AX
    MOV ES, AX
    MOV DS, AX

    MOV SS, AX
    MOV SP, 7C00H
   
    ; Linear search through root to find SYSTEM.SYS
    ; Skip CBh, E5h, and stop on 00h
    

ERROR: ; I tried to make this as small as possible
    MOV AX, 0003H ; Clear the screen
    INT 10H

    ; Write error message to the screen
    MOV BX, 0007H
    MOV AH, 0EH
    MOV SI, ERRMSG
    MOV CL, ERRMSGLEN
    CALL ERRWRITE
    ; Write the help message to screen
    ; MOV SI, ERRHELP
    MOV CL, ERRHELPLEN
    CALL ERRWRITE

    ; Wait for key press and then cold reboot
    STI ; Interrupts are gonna need to be enabled for this
    XOR AH, AH
    INT 16H
    INT 19H

ERRWRITE:
    LODSB
    INT 10H
    DEC CL
    JNZ ERRWRITE
    RET

READ: 
    ; Disk read
    ; Parameters:
    ; cx = absolute starting sector
    ; dh = sectors to read (1 - X)
    ; dl = boot drive
    ; es:bx = memory dump
    ; Return:
    ; some registers clobbered
    ; es:bx is not clobbered
    
    PUSH ES ; Preserve these registers as we're going to need them for the int 13,2h call
    PUSH BX ;
    PUSH DX ;  
 
    MOV BP, DX ; Preserve LBA
    MOV AH, 08H ; Get drive parameters
    INT 13H

    JC ERROR ; Don't clean the stack! Just error

    INC DH ; We need number of heads to start from 1
    AND CL, 3FH ; 00111111B ; Zero out the cylinder bits sense we only need the sectors per track
    
    ; Cylinder
    ; LBA / (HPC * SPT)
    MOV AL, DH
    XOR AH, AH
    MUL CL

    XCHG BP, AX
    XOR DX, DX
    DIV BP
    MOV BP, AX

    ; Head
    ; LBA % (HPC * SPT) / SPT
    MOV AX, DX
    DIV CL    

    ; Sector
    ; LBA % (HPC * SPT) % SPT + 1
    INC AH

    MOV CX, BP ; Put cylinder in the right place
    SHL CL, 6 ; Shift bits 0 - 1 to bits 7 - 6 and zero out bits 0 - 5
    ; AND AH, 3FH ; 00111111B
    OR CL, AH ; Combine the bits    

    POP DX
    XCHG AL, DH ; Switch registers
    POP BX
    POP ES

    MOV AH, 02H
    INT 13H
   
    JC ERROR ; Handle the error here to save bytes
    RET

FILENAME: DB "SYSTEM  "
EXTENSION: DB "SYS"
FILELEN: EQU $ - FILENAME
ERRMSG: DB "BOOT ERROR!"
ERRMSGLEN: EQU $ - ERRMSG
ERRHELP: DB 0AH, 0DH,  "PRESS ANY KEY TO REBOOT.."
ERRHELPLEN: EQU $ - ERRHELP
DATAAREA: EQU 7DEEH

; Random dump addresses
ROOTDUMP: EQU 2000H

; Padding
DB 494 - ($ - $$) DUP(0)
