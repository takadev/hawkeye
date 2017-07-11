[BITS 16]

ORG	0x7C00

JMP	BOOT
BS_jmpBoot2	DB	0x90
BS_OEMName	DB	"MyOS    "
BPB_BytsPerSec	DW	0x0200
BPB_SecPerClus	DB	0x01
BPB_RsvdSecCnt	DW	0x0001
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

BOOT:
	CLI
	HLT

TIMES 510 - ($ -$$) DB 0

DW 0xAA55
