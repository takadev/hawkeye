; FAT12 filesystem read only function

%ifndef __FAT12_INC_INCLUDED__
%define __FAT12_INC_INCLUDED__

[BITS 16]
%include "BPB.inc"

; Variable 
KernelImageCluster DW 0x0000	; 見つかったカーネルイメージの最初のクラスタ番号を保存します

; Define
%define ES_BASE_ADDR	0x07C0	; ブートローダのセグメント開始位置
%define RMODE_BASE_SEG	0x0800	; カーネルを読み込むセグメント開始位置（0x00008000）
%define	RMODE_BASE_ADDR 0x0000
%define BX_FAT_ADDR 	0x0200	; 0x000007C00をベースアドレスとしたBXに設定するアドレス
				; ブートローダが読み込んだFAT領域のアドレス 
%define BX_RTDIR_ADDR 0x2600	; 0x000007C00をベースアドレスとしたBXに設定するアドレス
				; ブートローダが読み込んだルートディレクトリ領域のアドレス

; Find Kernel File
Find_File:	; カーネルイメージを探索する
	PUSHA
	MOV	BX, ES_BASE_ADDR
	MOV	ES, BX
	MOV	BX, BX_RTDIR_ADDR
	MOV	CX, WORD [BPB_RootEntCnt]	; BPB.incに定義
	MOV	SI, KernelImageName		; common.incに定義

Finding_File:
	MOV	DI, BX
	PUSH CX
	MOV	CX, 0x000B
	PUSH DI
	PUSH SI
	REPE CMPSB
	POP	SI
	POP	DI
	JCXZ Found_File
	ADD	BX, 0x0020
	POP	CX
	; 次のエントリへ
	LOOP Finding_File
	JMP	FAILURE

FAILURE:
	POPA
	MOV	AX, -1	;　見つからなかったときは返り値としてAXに-1を返す

	RET

Found_File:
	POP	CX
	MOV	WORD [KernelImageCluster], BX	; 見つかったファイルの最初のクラスタ番号を保存
	POPA
	MOV	AX, 0	; 見つかった場合は返り値としてAXに0を返す
	
	RET

%endif