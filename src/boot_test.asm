[BITS 16]

ORG	0x7C00

JMP	BOOT		;BS_jmpBoot

BS_OEMName	DB	"MyOS    "
BPB_BytsPerSec	DW	0x0200		;BytesPerSector
BPB_SecPerClus	DB	0x01		;SectorPerCluster
BPB_RsvdSecCnt	DW	0x0001		;ReservedSectors
BPB_NumFATs	DB	0x02			;TotalFATs
BPB_RootEntCnt	DW	0x00E0		;MaxRootEntries
BPB_TotSec16	DW	0x0B40		;TotalSectors
BPB_Media	DB	0xF0			;MediaDescriptor
BPB_FATSz16	DW	0x0009			;SectorsPerFAT

; 1トラックにつき何セクタあるか。
; フロッピーの場合は0x12(18)セクタです。
BPB_SecPerTrk	DW	0x0012
BPB_NumHeads	DW	0x0002		;NumHeads
BPB_HiddSec	DD	0x00000000		;HiddenSector
BPB_TotSec32	DD	0x00000000	;TotalSectors

BS_DrvNum	DB	0x00			;DriveNumber
BS_Reserved1	DB	0x00		;Reserved
BS_BootSig	DB	0x29			;BootSignature
BS_VolID	DD	0x20120627		;VolumeSerialNumber 日付を入れました
BS_VolLab	DB	"MyOS       "	;VolumeLabel
BS_FilSysType	DB	"FAT12   "	;FileSystemType

BOOT:
	CLI
	
	; レジスタ初期化
	XOR	AX, AX
	MOV	DS, AX
	MOV	ES, AX
	MOV	FS, AX
	MOV	GS, AX

	XOR	BX, BX
	XOR	CX, CX
	XOR	DX, DX

	; スタックベースアドレス、オフセットアドレス初期化
	MOV	SS, AX		; ベースアドレスを0x0000
	MOV	SP, 0xFFFC	; オフセットアドレスを0xFFFC

	mov si, ImageName
	call DisplayMessage

	call ResetFloppyDrive

	MOV AX, 2000 ; 10進数
	CALL ReadSectors

	HLT

DisplayMessage:
	PUSH	AX
	PUSH	BX
StartDispMsg:
	LODSB
	OR	AL, AL
	JZ	.DONE
	MOV	AH, 0x0E
	MOV	BH, 0x00
	MOV	BL, 0x07
	INT	0x10
	JMP	StartDispMsg
.DONE:
	POP	BX
	POP	AX
	RET

; フロッピードライブの初期化
ResetFloppyDrive:
	MOV	AH, 0x00
	MOV	DL, 0x00
	INT	0x13
	JC FAILURE
	RET
FAILURE:
	HLT
	JMP FAILURE

; セクタの読み込み
ReadSectors:
	; LBAからCHSへ変換
	CALL LBA2CHS
	; セクタ読み込みモード
	MOV AH, 0x02
	; 1つのセクタだけ読み込み
	MOV AL, 0x01
	; 物理トラック指定
	MOV CH, BYTE [physicalTrack]
	; 物理シリンダ指定
	MOV CL, BYTE [physicalSector]
	; 物理ヘッド指定
	MOV DH, BYTE [physicalHead]
	; 1番目のドライブから読み込みます
	MOV DL, BYTE [BS_DrvNum]
	MOV BX, 0x1000
	; アドレス0x10000から開始するセグメントに読み込みます
	MOV ES, BX
	; セグメントの最初に読み込みます。オフセットに0x0000を指定。
	MOV BX, 0x0000
	; セクタを読み込みます
	INT 0x13
	RET


; LBAからCHSへ変換
; 入力 AX:LBA方式セクタ番号
; 出力 AX:quotient
;      DX:Remainder
;
; 物理セクタ番号 = (LBA mod トラック毎のセクタ数) + 1
; 物理ヘッド番号 = (LBA / トラック毎のセクタ数) mod ヘッド数 
; 物理シリンダー番号 = LBA / (トラック毎のセクタ数 × ヘッド数)
LBA2CHS:
	; DXを0へ初期化
	XOR	DX, DX

	; まずAXレジスタの値(LBA) ÷ トラック毎のセクタ数(BPB_SecPerTrk)を計算
	DIV	WORD [BPB_SecPerTrk]

	; DL(DXが余り)に1をプラスすることで物理セクタ番号がわかる
	INC	DL

	; 計算した物理セクタ番号を変数に格納
	MOV	BYTE [physicalSector], DL

	; DXを0へ初期化
	XOR	DX, DX

	; AXには先ほどの割り算の商が入っているので
	; それをヘッド数(BPB_NumHeads)で割ることで
	; 物理ヘッド番号がわかる
	DIV	WORD [BPB_NumHeads]

	; 余り(DX)が物理ヘッド番号になる
	MOV	BYTE [physicalHead], DL

	; ALは(LBA / シリンダ毎のセクタ数 / ヘッド数
	; が格納されていて、物理トラック数になる
	MOV	BYTE [physicalTrack], AL	
	RET


; Load FAT From Floppy
LOAD_FAT:
	; FATを読み込むアドレス0x7E00を引数BXに入れる
	MOV	BX, WORD [BX_FAT_ADDR]

	; FATの開始セクタを取得
	ADD	AX, WORD [BPB_RsvdSecCnt]

	; FATの開始セクタを一旦CXレジスタに退避
	XCHG	AX, CX

	; FATのサイズを計算(FATのセクタ数を取得)
	MOV	AX, WORD [BPB_FATSz16]

	; FATの予備領域も念のため読み込む
	; AXの値 × BPB_NumHeads→AXに格納
	MUL	WORD[BPB_NumFATs]
				
	; CXにFATのサイズを、AXにFATの開始セクタを入れる
	XCHG	AX, CX

READ_FAT:
	; FATを1セクタずつ読み込む
	call	ReadSector

	; 1セクタ読み込んだので格納アドレスに512バイトを足す
	ADD	BX, WORD [BPB_BytsPerSec]

	; 次のセクタを読み込むのでAXに1をたす
	INC	AX

	; FATのサイズ分読み込むので1セクタ読み込むごとに1減らす	
	DEC	CX

	; DEC CXでZFが0になれば読み込み終わり
	JCXZ	FAT_LOADED

	; 次の処理へ
	JMP	READ_FAT

FAT_LOADED:
	HLT


; ReadSector
; Read 1 Sector 
; Input: BX:読み込んだセクタを格納するアドレスを入れておく  
;      : AX:読み込みたいLBAのセクタ番号
ReadSector:
	; エラー発生時5回までリトライする
	MOV	DI, 0x0005
SECTORLOOP:
	; AX、BX、CXをスタックに退避
	PUSH	AX
	PUSH	BX
	PUSH	CX

	; AXのLBAを物理番号に変換
	CALL	LBA2CHS

	; セクタ読み込みモード
	MOV	AH, 0x02

	; 1セクタ読み込み
	MOV	AL, 0x01

	; LBA2CHSで計算したトラック番号
	MOV	CH, BYTE [physicalTrack]

	; LBA2CHSで計算したセクタ番号
	MOV	CL, BYTE [physicalSector]

	; LBA2CHSで計算したヘッド番号
	MOV	DH, BYTE [physicalHead]

	; ドライブ番号（Aドライブ）
	MOV	DL, BYTE [BS_DrvNum]

	; BIOS処理呼び出し
	INT	0x13

	; CFを見て成功か失敗かを判断
	JNC	SUCCESS

	; ここからエラー発生時の処理。ドライブ初期化モード
	XOR	AX, AX

	; エラーが発生した時はヘッドを元に戻す
	INT	0x13

	; エラーカウンタを減らす
	DEC	DI

	; AX、BX、CXの値が変更されたので
	POP	CX
	POP	BX
	POP	AX

	; 退避したいたデータをスタックから元に戻す
	; DEC DIの計算結果が0でなければ、セクタ読み込みをリトライ
	JNZ	SECTORLOOP
	INT	0x18
SUCCESS:
	; 成功時の処理レジスタの値を元に戻す
	POP	CX
	POP	BX
	POP	AX
	RET	

; Variable

; データセグメントの0x7E00にFATを読み込む
BX_FAT_ADDR		DW 0x7E00

physicalSector	DB 0x00
physicalHead	DB 0x00
physicalTrack	DB 0x00

ImageName	DB "Bood-bye Small World", 0x00

TIMES 510 - ($ - $$) DB 0
DW 0xAA55
