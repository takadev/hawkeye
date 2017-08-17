; FAT12ファイルシステム読み込み関連

%ifndef __FAT12_INC_INCLUDED__
%define __FAT12_INC_INCLUDED__

[BITS 16]
%include "BPB.inc"

; Variable

; 見つかったカーネルイメージの最初のクラスタ番号を保存します
KernelImageCluster DW 0x0000

; Define

; ブートローダのセグメント開始位置
%define ES_BASE_ADDR 0x07C0

; カーネルを読み込むセグメント開始位置(0x00008000)
%define RMODE_BASE_SEG 0x0800
%define	RMODE_BASE_ADDR 0x0000

; 0x000007C00をベースアドレスとしたBXに設定するアドレス
; ブートローダが読み込んだFAT領域のアドレス
%define BX_FAT_ADDR 0x0200

; 0x000007C00をベースアドレスとしたBXに設定するアドレス
; ブートローダが読み込んだルートディレクトリ領域のアドレス
%define BX_RTDIR_ADDR 0x2600


; Find Kernel File
; カーネルイメージを探索する
Find_File:
	PUSHA
	MOV BX, ES_BASE_ADDR
	MOV ES, BX
	MOV BX, BX_RTDIR_ADDR

	; BPB_RootEntCntはBPB.incに定義してある
	MOV CX, WORD [BPB_RootEntCnt]

	; KernelImageNameはcommon.incに定義してある
	MOV SI, KernelImageName

Finding_File:
	MOV DI, BX
	PUSH CX
	MOV CX, 0x000B
	PUSH DI
	PUSH SI
	REPE CMPSB
	POP SI
	POP DI
	JCXZ Found_File
	ADD BX, 0x0020
	POP CX
	; 次のエントリへ
	LOOP Finding_File
	JMP FAILURE

FAILURE:
	POPA
	; 見つからなかったときは返り値としてAXに-1を返す
	MOV AX, -1

	RET

Found_File:
	POP CX

	; 見つかったファイルの最初のクラスタ番号を保存
	MOV WORD [KernelImageCluster], BX
	POPA

	; 見つかった場合は返り値としてAXに0を返す
	MOV AX, 0

	RET

; Load Kernel File
Load_File:
	PUSHA
	MOV WORD [datasector], 0x0021
	MOV BX, ES_BASE_ADDR
	MOV ES, BX

	; カーネルイメージの開始クラスタ番号
	MOV BX, WORD [KernelImageCluster]
	ADD BX, 0x001A
	MOV AX, WORD [ES:BX]

	; カーネルを読み込むセグメント
	MOV BX, RMODE_BASE_SEG
	MOV ES, BX

	; カーネルを読み込むアドレス
	MOV BX, RMODE_BASE_ADDR
	PUSH BX
	MOV WORD [cluster], AX
	
Load_Image:
	MOV AX, WORD [cluster]
	POP BX
	XOR BX, BX
	CALL ClusterLBA

	XOR CX, CX
	MOV CL, BYTE [BPB_SecPerClus]

	CALL ReadSector
	MOV BX, ES

	; ESを0x200だけずらす
	ADD BX, 0x0020

	; ESを更新する(ESは読み込んだバイト数になる)
	MOV ES, BX

ES_ADDED:
	PUSH BX

	; 次のクラスタ番号取得
	MOV AX, WORD [cluster]
	MOV CX, AX
	MOV DX, AX
	SHR DX, 0x0001

	; 次のクラスタ番号オフセット取得
	ADD CX, DX

	; ESをスタックへ
	PUSH ES
	MOV BX, ES_BASE_ADDR
	MOV ES, BX
	
	; ブートローダが読み込んだFATを利用
	MOV BX, BX_FAT_ADDR

	; 次のクラスタ番号のオフセットを足す
	ADD BX, CX
	MOV DX, WORD [ES:BX]

	; ESを復帰(読み込んだバイト数)
	POP ES
	TEST AX, 0x0001
	JNZ ODD_CLUSTER
EVEN_CLUSTER:
	AND DX, 0x0FFF
	JMP LOCAL_DONE
ODD_CLUSTER:
	SHR DX, 0x0004
LOCAL_DONE:
	MOV WORD [cluster], DX
	CMP DX, 0x0FF0
	JB Load_Image
		
ALL_DONE:
	POP BX
	XOR BX, BX
	; 0クリアしています（無駄な処理です）
	MOV WORD [ImageSizeBX], BX
	MOV BX, ES
	; リードしたバイト数を計算
	SUB BX, RMODE_BASE_SEG

	; 保存する
	MOV WORD [ImageSizeES], BX
	POPA
	RET

; セクタを読み込む
; Input: BX:読み込んだセクタを格納するアドレスを入れておく  
;      : AX:読み込みたいLBAのセクタ番号
ReadSector:
	; エラーがあった場合5回まで繰り返す
	MOV	DI, 0x0005
SECTORLOOP:
	PUSH AX
	PUSH BX
	PUSH CX
	CALL LBACHS

	; BIOSのリードセクタ
	MOV	AH, 0x02
	; 1セクタ読み込み
	MOV AL, 0x01

	MOV CH, BYTE [absoluteTrack] ; シリンダ
	MOV CL, BYTE [absoluteSector] ; セクタ
	MOV DH, BYTE [absoluteHead] ; ヘッド
	MOV DL, BYTE [BS_DrvNum] ; ドライブ

	; BIOS処理を呼出す
	INT 0x13

	; エラーチェック
	JNC SUCCESS
	MOV AH, 0x01
	INT 0x13

	; フロッピーディスクをリセット
	XOR AX, AX

	; BIOS処理を呼出す
	INT 0x13

	; エラーカウンタを減らす
	DEC DI
	POP CX
	POP BX
	POP AX

	; 処理を繰り返す
	JNZ SECTORLOOP
	INT 0x18
SUCCESS:
	POP CX
	POP BX
	POP AX
	RET

; PROCEDURE ClusterLBA
; convert FAT cluster into LBA adressing scheme
; LBA = (cluster - 2 ) * sectors per cluster
; INPUT  : AX : クラスタ番号
; OUTPUT : AX : ファイル開始セクタ番号
ClusterLBA:
	SUB AX, 0x0002
	XOR CX, CX
	MOV CL, BYTE [BPB_SecPerClus]
	MUL CX
	ADD AX, WORD [datasector]
	RET


; PROCEDURE LBACHS
; convert LBA addressing scheme to CHS addressing scheme
; absolutesector = (logical sector / setors per track) + 1
; absolute head  = (logical sector / sectors per track) MOD number of heads
; absolute track = (logical sector / ( sectors per track * number of heads ) )
LBACHS:
	XOR DX, DX
	DIV WORD [BPB_SecPerTrk]
	INC DL
	MOV BYTE [absoluteSector], DL
	XOR DX, DX
	DIV WORD [BPB_NumHeads]
	MOV BYTE [absoluteHead], DL
	MOV BYTE [absoluteTrack], AL
	RET


%endif