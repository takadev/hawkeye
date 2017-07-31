; メモリマップ
; 0x00000500 +--------------------------------+
;            |      ブートローダ(2段階目)        |
; 0x00007C00 +--------------------------------+
;            |      ブートローダ(1段階目)        |
; 0x00007E00 +--------------------------------+
;            |        読み込んだFAT領域         |
; 0x0000A200 +--------------------------------+
;            |     読み込んだルートディレクトリ    |
; 0x0000BE00 +--------------------------------+
;            ~            未使用               ~
; 0x000A0000 +--------------------------------+

[BITS 16]

ORG	0x7C00

JMP	BOOT		;BS_jmpBoot
BS_jmpBoot2	DB	0x90
BS_OEMName	DB	"MyOS    "
BPB_BytsPerSec	DW	0x0200		; 1セクタのバイト数(512バイト)
BPB_SecPerClus	DB	0x01		; 1クラスタごとのセクタ数
BPB_RsvdSecCnt	DW	0x0001		; ブートセクタサイズ(1セクタ)
BPB_NumFATs	DB	0x02			;TotalFATs
BPB_RootEntCnt	DW	0x00E0		; ルートディレクトリの最大エントリ数
BPB_TotSec16	DW	0x0B40		;TotalSectors
BPB_Media	DB	0xF0			;MediaDescriptor
BPB_FATSz16	DW	0x0009			; FAT領域のセクタサイズ(9セクタ)

; 1トラックにつき何セクタあるか。
; フロッピーの場合は0x12(18)セクタです。
BPB_SecPerTrk	DW	0x0012
BPB_NumHeads	DW	0x0002		; ヘッドの数
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
	
	; レジスタを0に初期化
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

	CALL ResetFloppyDrive

	MOV AX, 2000 ; LBA方式セクタ番号を10進数で指定
	CALL ReadSectors

	HLT


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


; フロッピーディスクのFAT領域をメモリへ読み込む
LOAD_FAT:
	; FATを読み込むアドレス0x7E00を引数BXに入れる
	MOV	BX, WORD [BX_FAT_ADDR]

	; FATの開始セクタを取得
	ADD	AX, WORD [BPB_RsvdSecCnt]

	; FATの開始セクタを一旦CXレジスタに退避
	XCHG AX, CX

	; FATのサイズを計算(FATのセクタ数を取得)
	MOV	AX, WORD [BPB_FATSz16]

	; FATの予備領域も念のため読み込む
	; AXの値 × BPB_NumHeadsをAXに格納
	MUL	WORD[BPB_NumFATs]
				
	; CXにFATのサイズを、AXにFATの開始セクタを入れる
	XCHG AX, CX

READ_FAT:
	; FATを1セクタずつ読み込む
	CALL ReadSector

	; BXにはFATを格納するアドレスを指定する
	; 1セクタ読み込んだので格納アドレスに512バイト足す
	ADD	BX, WORD [BPB_BytsPerSec]

	; 次のセクタを読み込むのでAXに1をたす
	INC	AX

	; FATのサイズ分読み込むので1セクタ読み込むごとに1減らす	
	DEC	CX

	; DEC CXでZFが0になれば読み込み終わり
	JCXZ FAT_LOADED

	; 繰り返し次のセクタを読み込む
	JMP	READ_FAT

	RET

FAT_LOADED:
	HLT

; FATを読み込んだ直後で
; AXにルートディレクトリ開始セクタ番号が入っています
LOAD_ROOT:
	; BX_RTDIR_ADDRのアドレスに格納します
	MOV	BX, WORD [BX_RTDIR_ADDR]

	; CXレジスタを0に初期化
	XOR	CX, CX

	; FATを読み込んだ直後なので、
	; AXにはルートディレクトリの開始が入っています
	MOV	WORD [datasector], AX

	; ルートディレクトリ開始セクタ番号を退避CXレジスタに(AXは0になる)
	XCHG AX, CX

	; エントリのサイズは32バイト(0x0020)
	MOV	AX, 0x0020

	; エントリの数 × エントリのサイズをAXに格納
	MUL	WORD [BPB_RootEntCnt]

	; AXに1セクタのバイト数を足す
	ADD	AX, WORD [BPB_BytsPerSec]

	; AXから1を引く
	DEC	AX

	; AXの値 ÷ 1セクタのバイト数
	DIV	WORD [BPB_BytsPerSec]

	; AXとCXを入れ替える
	; AX = ルートディレクトリの開始セクタ番号
	; CX = ルートディレクトリのセクタ数
	XCHG AX, CX

	; CXにはルートディレクトリのサイズ(セクタ数)が入っているので足す
	ADD	WORD [datasector], CX

	RET


; Browse Root directory
BROWSE_INI:
	; 読み込んだルートディレクトリのアドレスを取得します
	MOV	BX, WORD [BX_RTDIR_ADDR]

	; エントリの数を取得します
	MOV	CX, WORD [BPB_RootEntCnt]

	; 読み込みたいファイル名のアドレスを取得します(11文字)
	MOV	SI, ImageName

; ルートディレクトリ探索開始
BROWSE_ROOT:
	; ルートディレクトリのエントリのアドレスをDIに格納		
	MOV	DI, BX

	; CX(エントリ数)を退避
	PUSH CX

	; CXに0x00B(11文字)を格納
	MOV	CX, 0x000B

	; DIを退避
	PUSH DI
	; SIを退避
	PUSH SI

	; 文字列CMPSB命令を繰り返す
	; REPEはCXに格納されている値(11文字)分CMPSB命令を繰り返します
	; CMPSB命令はDS:SIに格納されている1バイトと
	; ES:DIに格納されている1バイトを比較します
	; 比較結果は一致しなかったバイト数がCXに格納されます
	REPE CMPSB

	; SIを元の値に戻します
	POP	SI
	; DIを元の値に戻します
	POP	DI

	; CXが0であればFinishへ
	JCXZ BROWSE_FINISHED

	; 次のエントリを見に行くため32バイト足します
	ADD	BX, 0x0020

	; CXを元の値に戻します
	POP	CX

	; 次のエントリを見に行きます。BROWSE_ROOTにジャンプ
	; LOOP命令はCXの値(エントリの数)分ループします
	LOOP BROWSE_ROOT

	; エントリを全部見終わってファイルが無ければ失敗
	JMP	FAILURE

; ファイル発見
BROWSE_FINISHED:
	; CXの値を元に戻します(PUSHしたままなのでSPを元にもどす)
	POP	CX

	; ファイルの開始クラスタ番号は、エントリの先頭から
	; 0x001A(26)バイトにあるので、
	; (DIR_FstClusLOのオフセット)足す
	MOV	AX, WORD [BX + 0x001A]

	; ファイルを格納する先のデータセグメントをBXに入れる
	MOV	BX, WORD[ES_IMAGE_ADDR]

	; ESにBXの値を格納する(ESセグメントに格納する)
	MOV	ES, BX

	; BXを0に初期化(ESセグメントのオフセット)
	XOR	BX, BX

	; ファイルを格納する先のオフセットをスタックに退避
	PUSH BX

	; ファイルの開始クラスタ番号をclusterに入れる
	MOV	WORD [cluster], AX


; Load Image 
LOAD_IMAGE:
	; clusterに入っているクラスタ番号をAXに入れる
	MOV	AX, WORD [cluster]

	; ファイルを格納する先のオフセットを元に戻す
	POP	BX

	; ファイルの先頭セクタ番号を計算する
	CALL ClusterLBA

	; CXレジスタを0に初期化
	XOR	CX, CX

	; 1クラスタあたりのセクタ数をCLに入れる	
	MOV	CL, BYTE [BPB_SecPerClus]

	; ファイルの一部(1セクタ)をES:BXに読み込む
	CALL ReadSector

	; 1セクタ読み込んだので1セクタ
	; (0x200バイト(512))分オフセットを進める
	ADD	BX, 0x0200

	; BXの内容が変更されるので退避
	PUSH BX

	; ここから次のクラスタを調べる
	; AXの値は変更されてしまったので、再度clusterを入れる
	MOV	AX, WORD [cluster]

	; CXに調べるクラスタ番号を入れる
	MOV	CX, AX

	; DXに調べるクラスタ番号を入れる
	MOV	DX, AX

	; クラスタ番号 / 2
	SHR	DX, 0x0001

	; クラスタのオフセットを計算
	ADD	CX, DX

	; 読み込んだFAT領域のアドレスをBXに入れます
	MOV	BX, WORD [BX_FAT_ADDR]

	; 調べたいクラスタのアドレスを計算
	ADD	BX, CX

	; DXにクラスタの値を入れる
	MOV	DX, WORD [BX]

	; 奇数か、偶数かを調べる
	TEST AX, 0x0001

	; ZFが0でない場合ODD_CLUSTER(奇数)へ
	JNZ	ODD_CLUSTER

; 偶数クラスタの処理
EVEN_CLUSTER:
	; 次クラスタの値を取得（DX）
	AND	DX, 0x0FFF

	; 次クラスタ読み込み完了
	JMP	LOCAL_DONE

; 奇数クラスタの処理
ODD_CLUSTER:	
	; 次クラスタの値を取得（DX）				
	SHR	DX, 0x0004

; 次クラスタ読み込み完了処理
LOCAL_DONE:

	; 次クラスタ番号をclusterへ
	MOV	WORD [cluster], DX

	; 終端クラスタか調べる
	CMP	DX, 0x0FF0
	;　終端クラスタでない場合はLOAD_IMAGEへ戻る
	JB LOAD_IMAGE
		
; ファイル読み込み完了
ALL_DONE:
	; スタックポインタを戻すため、意味は無いがBXの値を元に戻す
	POP	BX

	; 成功メッセージを表示
	MOV	SI, msgIMAGEOK
	CALL DisplayMessage	

	; ES_IMAGE_ADDRは0x0050
	PUSH WORD [ES_IMAGE_ADDR]
	PUSH WORD 0x0000
	RETF

	HLT
	
	
; PROCEDURE ClusterLBA
; convert FAT cluster into LBA addressing scheme
; LAB = (cluster - 2 ) * sectors per cluster
; INPUT  : AX : クラスタ番号
; OUTPUT : AX : ファイル開始セクタ番号
ClusterLBA:
	SUB	AX, 0x0002			
	XOR	CX, CX
	MOV	CL, BYTE [BPB_SecPerClus]
	MUL	CX
	; ここでdatasectorはファイル領域の開始セクタ番号
	; そこにクラスタ番号から計算したオフセットを足せば
	; 読み込みたいファイルのセクタ番号を取得できる
	ADD	AX, WORD [datasector]
	RET


; 複数セクタの読み込み
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

	; アドレス0x10000から開始するセグメントに読み込みます
	MOV BX, 0x1000
	MOV ES, BX

	; セグメントの最初に読み込みます。オフセットに0x0000を指定。
	MOV BX, 0x0000

	; セクタを読み込みます
	INT 0x13
	RET

; 1セクタを読み込む
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

; 文字列表示
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

; Variable

; データセグメントの0x7E00にFATを読み込む
BX_FAT_ADDR		DW 0x7E00

; ルートディレクトリを0xA200へ読み込む
BX_RTDIR_ADDR   DW 0xA200

physicalSector	DB 0x00
physicalHead	DB 0x00
physicalTrack	DB 0x00

cluster DB 0x00
datasector DB 0x00

ImageName	DB "Bood-bye Small World", 0x00
msgIMAGEOK  DB "Load image OK", 0x00

TIMES 510 - ($ - $$) DB 0
DW 0xAA55
