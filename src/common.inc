%ifndef	_COMMON_INC_INCLUDED
%define _COMMON_INC_INCLUDED

; プロテクティッドモードでカーネルイメージを置くアドレス
%define IMAGE_PMODE_BASE 0x100000

; リアルモードでカーネルイメージを置くアドレス
%define IMAGE_RMODE_BASE 0x8000

; カーネルイメージのファイル名(FAT12では11文字にしなければならない)
KernelImageName	DB "KIMAGE     "

; カーネルイメージのファイルサイズを格納する変数
ImageSize 	DD 0x00000000
ImageSizeBX	DW 0x0000
ImageSizeES	DW 0x0000

%endif