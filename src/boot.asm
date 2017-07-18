MBR_SIZE	equ 512
SECTOR_SIZE	equ 512
BOOT_LOAD_ADDR	equ 0x7C00

print_string:
	push ax
	mov ah, 0x0E
.loop:
	lodsb
	or al, al
	jz .done
	int 0x10
	jmp .loop
.done:
	pop ax
	ret

print_newline:
	push ax
	mov ah, 0x0E
	mov al, 0x0D
	int 0x10
	mov al, 0x0A
	int 0x10
	pop ax
	ret


[BITS 16]

ORG	BOOT_LOAD_ADDR


; BIOS Parameter Blocks(FAT12)
JMP	BOOT

BS_OEMName	DB	"MyOS    "
BPB_BytsPerSec	DW	0x0200
BPB_SecPerClus	DB	0x01
BPB_RsvdSecCnt	DW	0x0001
BPB_NumFATs	DB	0x02
BPB_RootEntCnt	DW	0x00E0
BPB_TotSec16	DW	0x0B40
BPB_Media	DB	0xF0
BPB_FATSz16	DW	0x0009
BPB_SecPerTrk	DW	0x0012
BPB_NumHeads	DW	0x0002
BPB_HiddSec	DD	0x00000000
BPB_TotSec32	DD	0x00000000

BS_DrvNum	DB	0x00
BS_Reserved1	DB	0x00
BS_BootSig	DB	0x29
BS_VolID	DD	0x20170711
BS_VolLab	DB	"MyOS       "
BS_FilSysType	DB	"FAT12   "

BX_FAT_ADDR	DW 0x7E00

; UNKNOW
BX_ROOTDIR_ADDR	DW 0x0000

; Physical Sector, Head Track
physicalSector	DB 0x00
physicalHead	DB 0x00
physicalTrack	DB 0x00

; Cluster
cluster		DB 0x00


BOOT:
	; Initialize Data Segment
	XOR	AX,AX
	MOV	DS,AX
	MOV	ES,AX
	MOV	FS,AX
	MOV	GS,AX

	XOR	BX,BX
	XOR	CX,CX
	XOR	DX,DX

	; Initialize Stack Segment and Stack Pointer
	MOV	SS, AX
	MOV	SP, 0xFFFC

; Load FAT from Floopy
LOAD_FAT:
	MOV	BX, WORD [BX_FAT_ADDR]
	ADD	AX, WORD [BPB_RsvdSecCnt]
	XCHG	AX, CX
	MOV	AX, WORD [BPB_FATSz16]
	MUL	WORD [BPB_NumFATs]
	XCHG	AX, CX
READ_FAT:
	CALL	READ_SECTOR
	ADD	BX, WORD [BPB_BytsPerSec]
	INC	AX
	DEC	CX
	JCXZ	FAT_LOADED
	JMP	READ_FAT
FAT_LOADED:
	HLT

; load root dir
LOAD_ROOT:
	MOV	BX, WORD [BX_ROOTDIR_ADDR]
	XOR	CX, CX
	XCHG	AX, CX
	MOV	AX, 0x0020
	MUL	WORD [BPB_RootEntCnt]
	ADD	AX, WORD [BPB_BytsPerSec]
	DEC	AX
	DIV	WORD [BPB_BytsPerSec]
	XCHG	AX, CX

; Read 1 Sector
; Input BX: Address to store the read sector
;       AX: Sector number of the LBA to be read
READ_SECTOR:
	MOV	DI, 0x0005
SECTORLOOP:
	PUSH	AX
	PUSH	BX
	PUSH	CX
	CALL	LBA2CHA
	MOV	AH, 0x02
	MOV	AL, 0x01
	MOV	CH, BYTE [physicalTrack]
	MOV	CL, BYTE [physicalSector]
	MOV	DH, BYTE [physicalHead]
	MOV	DL, BYTE [BS_DrvNum]
	INT	0x13
	JNC	SUCCESS
	XOR	AX, AX
	INT	0x13
	DEC	DI
	POP	CX
	POP	BX
	POP	AX
	JNZ	SECTORLOOP
	INT	0x18
SUCCESS:
	POP	CX
	POP	BX
	POP	AX
	RET

; Logical address convert to physical address
LBA2CHA:
	XOR	DX, DX
	DIV	WORD [BPB_SecPerTrk]
	INC	DL
	MOV	BYTE [physicalSector], DL
	XOR	DX, DX
	DIV	WORD [BPB_NumHeads]
	MOV	BYTE [physicalHead], DL
	MOV	BYTE [physicalTrack], AL
	RET

MOV WORD [cluster], 0x0002
NEW_CLUSTER:
	MOV	AX, WORD [cluster]
	MOV	CX, AX
	MOV	DX, AX
	SHR	DX, 0x0001
	ADD	CX, DX
	MOV	BX, WORD [BX_FAT_ADDR]
	ADD	BX, CX
	MOV	DX, WORD [BX]
	TEST	AX, 0x0001
	JNZ	ODD_CLUSTER
	AND	DX, 0x0FFF
	JMP	LOCAL_DONE
ODD_CLUSTER:
	SHR	DX, 0x0004
LOCAL_DONE:
	MOV	WORD [cluster], DX
	CMP	DX, 0x0FF0
	JB	NEW_CLUSTER

TIMES SECTOR_SIZE - 2 - ($ -$$) DB 0

DW 0xAA55
