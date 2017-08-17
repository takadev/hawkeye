; BIOS parameter block
%ifndef __BPB_INC_INCLUDED__
%define __BPB_INC_INCLUDED__

[BITS 16]
BS_OEMName DB "MyOS    "
BPB_BytsPerSec DW 0x0200		; 1セクタのバイト数(512バイト)
BPB_SecPerClus DB 0x01		; 1クラスタごとのセクタ数
BPB_RsvdSecCnt DW 0x0001		; ブートセクタサイズ(1セクタ)
BPB_NumFATs DB 0x02		; TotalFATs
BPB_RootEntCnt DW 0x00E0		; ルートディレクトリの最大エントリ数
BPB_TotSec16 DW 0x0B40		; TotalSectors
BPB_Media DB 0xF0		;MediaDescriptor
BPB_FATSz16 DW 0x0009		; FAT領域のセクタサイズ(9セクタ)
BPB_SecPerTrk DW 0x0012		; 1トラックにつき何セクタあるか。(18)
BPB_NumHeads DW 0x0002		; ヘッドの数
BPB_HiddSec DD 0x00000000	;HiddenSector
BPB_TotSec32 DD 0x00000000	;TotalSectors

BS_DrvNum DB 0x00		;DriveNumber
BS_Reserved1 DB 0x00		;Reserved
BS_BootSig DB 0x29		;BootSignature
BS_VolID DD 0x20090321	;VolumeSerialNumber
BS_VolLab DB "MyOS    "	;VolumeLabel
BS_FilSysType DB "FAT12   "	;FileSystemType

%endif