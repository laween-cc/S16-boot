[BITS 16]
ORG 7C3EH ; Past the BPB

; S16 boot sector implementation example
; FAT12 ONLY!

BOOT: ; Assuming bios put the boot drive in dl
    CLI ; Disable interrupts to make disk reads safer
    XOR CX, CX
    MOV DX, CX
    MOV ES, CX

    MOV SS, CX
    MOV SP, 7C00H

ENFORCE:
    INT 12H ; Enforce minimum memory to be 64KiB
    CMP AX, 64
    JL ERROR

COMPUTE:
    ; Root sector
    ; Reserved logical sectors + (2 * logical_sectors_per_fat)
    MOV AL, [7C0EH]
    MOV CL, [7C16H]
    ADD CL, CL
    ADD CL, AL

    ; Root sectors
    ; Root directory entries * 32 / 512
    MOV BX, [7C11H]
    SHL BX, 5
    SHR BX, 9

    ; First data sector
    ; Root sector + root sectors
    MOV AL, CL
    ADD AL, BL
    MOV BYTE [DATASECTOR], AL

S16:
    ; Read the entire root into memroy
    MOV DH, BL
    MOV BX, ROOTDUMP
    CALL DISK

    MOV CX, [7C11H]
FIND:

    CMP BYTE [BX], 0
    JE ERROR

    MOV SI, FILE
    MOV CX, FILELEN
    MOV DI, BX
    ; CLD
    REPE CMPSB
    JNZ SKIP

    MOV SI, BX

    ; Load first cluster
    ; (N - 2) * sectors per cluster + first data sector
    MOV CX, [SI + 26]
    SUB CX, 2
    MOV DH, [7C0DH]
    MUL DH
    MOV AL, [DATASECTOR]
    XOR AH, AH
    ADD CX, AX
    MOV BX, 0500H
    CALL DISK


    ; Load the first fat table into memory
    MOV CX, [7C0EH]
    MOV DH, [7C16H]
    MOV BX, FATDUMP
    CALL DISK

    MOV SI, [SI + 26] ; Current cluster
    MOV BX, 0700H ; Current dump address
FAT:
    ; Follow fat chain and read all of the clusters
    ; N + (N / 2) + FATDUMP
    MOV AX, SI
    SHR SI, 1
    ADD SI, AX
    ADD SI, FATDUMP
    MOV SI, [SI]

    TEST AX, 1 ; 00000001B ; Check if its even or odd
    JZ EVENFAT

    ; odd
    ; N << 4
    SHR SI, 4
    JMP LOADFAT
EVENFAT:
    ; even
    ; N & 0FFFH
    AND SI, 0FFFH
LOADFAT:
    CMP SI, 0FF8H 
    JGE DONE ; Assume clusters already loaded
    CMP SI, 0002H
    JL ERROR ; Assume corrupted fat12
    CMP SI, 0FEFH
    JG ERROR ; Assume corrupted fat12

    ; Load cluster & continue
    ; (N - 2) * sectors per cluster + first data sector
    MOV CX, SI
    SUB CX, 2
    MOV DH, [7C0DH]
    MUL DH
    MOV AL, [DATASECTOR]
    XOR AH, AH
    ADD CX, AX
    CALL DISK

    ADD BX, 0200H
    JMP FAT
DONE:
    ; MOV DL, [BOOTDRIVE]
    JMP 0000:0500H
SKIP:
    ADD BX, 32 ; Next entry
    DEC CX
    JNZ FIND

ERROR: ; I tried to make this as small as possible
    ; Clear the screen
    MOV AX, 0003H 
    INT 10H

    ; Write the error message to the screen
    MOV BX, 0007H
    MOV AH, 0EH
    MOV SI, BOOTMSG
    MOV CL, BOOTLEN
    CALL WRITE

    ; Write the help message to the screen
    MOV SI, HELPMSG
    MOV CL, HELPLEN
    CALL WRITE

    ; Wait for key press and then cold reboot
    STI ; Interrupts need to be enabled so we can read keyboard input
    XOR AH, AH
    INT 16H
    INT 19H

WRITE:
    LODSB
    INT 10H
    DEC CL
    JNZ WRITE
    RET

DISK:
    ; Read disk
    ; Parameters:
    ; dl = boot drive (0 - 255)
    ; dh = sectors to read (1 - 128)
    ; cx = logical starting sector (0 - 65535)
    ; es:bx = dump 
    ; Note: WILL clobber some registers

    PUSH ES
    PUSH BX
    PUSH DX

    MOV BP, CX ; Preserve the LBA
    MOV AH, 08H
    INT 13H

    JC ERROR ; Don't clean the stack just error!

    INC DH ; We need number of heads to start from 1
    AND CL, 3FH ; 00111111B ; We only need the sectors per track

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
    SHL CL, 6 ; Shift bits 0 - 1 to 7 - 6 and clear bits 0 - 5
    ; AND AH, 3FH
    OR CL, AH ; Combine the bits

    POP DX
    XCHG AL, DH ; Switch registers
    POP BX
    POP ES

    MOV AH, 02H
    INT 13H

    JC ERROR
    RET

FILE: DB "SYSTEM  SYS"
FILELEN: EQU 11
BOOTMSG: DB "BOOT ERROR"
BOOTLEN: EQU $ - BOOTMSG
HELPMSG: DB 0AH, 0DH, "PRESS ANY KEY TO REBOOT.."
HELPLEN: EQU $ - HELPMSG

; Random dump addresses
DATASECTOR: EQU 1500H
ROOTDUMP: EQU 1501H
FATDUMP: EQU 5501H

; Pad left over space
PADLEN: EQU 448 - ($ - $$)
DB PADLEN DUP(0)
