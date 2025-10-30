BITS 16
ORG 7C00H

; BIOS REQUIREMENTS: IBM compatible bios
; PROCESSOR REQUIREMENTS: 8086 / 8088+ processor
; USABLE MEMORY REQUIREMENT: 64KiB
; DISK SHOULD HAVE 512E OR NATIVE 512 BYTE SECTORS
; FAT12 ONLY

BOOT:
    CLI ; disable interrupts as they arent needed during this stage ; also to make disk reads safer!
    XOR CX, CX
    MOV ES, CX
    MOV DS, CX

    MOV SS, CX
    MOV SP, 7C00H

    ; Load the entire root into memory
    ; Starting sector = 2 * logical sectors per fat + 1 ; Assuming reserved logical sectors is 1
    ; Sectors to read = root directory entires * 32 / 512

    MOV CL, [7C00H + 016H]
    ADD CL, CL
    INC CL
    ; XOR CH, CH
    MOV AX, [7C00H + 011H]
    SHL AX, 5
    SHR AX, 9
    MOV DH, AL
    
    ; Get first data sector while we're at it
    ; root staring sector + root sectors    
    ADD AL, DH
    MOV BYTE [FIRSTDATA], AL ; Store it in memory

    MOV BX, ROOTDUMP
    CALL READ ; Does not overwrite BX
    
    ; Locate SYSTEM.SYS
    
    MOV AX, [7C00H + 011H] ; I'll use AX as a counter for now..
SYSTEM:

    CMP BYTE [BX], 00H ; No more entries
    JE ERROR
    
    CMP BYTE [BX], 0E5H ; Deleted entry
    JE SKIP 
    
    MOV SI, BX
    MOV DI, FILENAME
    MOV CX, FILELEN
    ; CLD
    REPE CMPSB ; Using CMPSB to save bytes
    JZ SKIP

    MOV SI, BX  

    ; Load the first cluster of SYSTEM.SYS into 0000:0500h
    ; (N - 2) * sectors per cluster + first data sector
    MOV AX, [SI + 26]
    SUB AX, 2
    MOV CL, [7C00H + 00DH]
    SHL AX, CL
    ADD AX, [FIRSTDATA]
    MOV DH, CL
    MOV CX, AX
    MOV BX, 0500H
    CALL READ

    ; Load the first fat table into memory
    MOV CX, 1 ; Assuming reserved sectors to be 1
    MOV DH, [7C00H + 016H] ; Assuming logical sectors per fat is not > 1 - 128
    MOV BX, FATDUMP
    CALL READ
    
    MOV SI, [SI + 26] ; Cluster
    MOV BX, 0700H ; Dump address
FAT:
    ; Get the next cluster
    ; N + (N / 2) + FATDUMP
    MOV AX, SI
    SHR SI, 1
    ADD SI, AX
    ADD SI, FATDUMP
    MOV SI, [SI]

    TEST AX, 1 ; Check if even or odd
    JZ FATEVEN

    ; Odd
    ; N << 4
    SHR SI, 4
    JMP NEXTCLUSTER
FATEVEN:
    
    ; Even
    ; N & 0FFFh
    AND SI, 0FFFH
NEXTCLUSTER:
    CMP SI, 0FF0H
    JGE DONE ; Assume the clusters have been loaded
    CMP SI, 0002H
    JL ERROR ; Assume corrupted fat12 volume
    CMP SI, 0FEFH
    JG ERROR ; Assume corrupted fat12 volume


    ; Load the cluster into memory
    ; (N - 2) * sectors per cluster + first data sector
    MOV AX, SI
    SUB AX, 2
    MOV CL, [7C00H + 00DH]
    SHL AX, CL
    ADD AX, [FIRSTDATA]  
    MOV DH, CL
    MOV CX, AX
    CALL READ
    
    ADD BX, 0200H
    JMP FAT ; Continue getting the clusters
DONE:

    JMP 0050:0000H
SKIP:
    ADD BX, 32 ; Next entry
    DEC AX
    JNZ SYSTEM

ERROR: ; I tried to make this as small as possible to save bytes
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

FILENAME: DB "SYSTEM  SYS"
FILELEN: EQU $ - FILENAME
ERRMSG: DB "BOOT ERROR!"
ERRMSGLEN: EQU $ - ERRMSG
ERRHELP: DB 0AH, 0DH,  "PRESS ANY KEY TO REBOOT.."
ERRHELPLEN: EQU $ - ERRHELP

; Random dump addresses
ROOTDUMP: EQU 7E00H
FIRSTDATA: EQU 2000H
FATDUMP: EQU 2001H

; Padding
DB 448 - ($ - $$) DUP(0)
