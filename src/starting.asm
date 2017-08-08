[BITS 16]
ORG 0x500
	JMP	MAIN2

; Preprocessor directives
%include "Print.inc"


; Data Section 
msgphello DB 0x0D, 0x0A, "Hello", 0x0D, 0x0A, 0x00

; Starting Kernel Procedure
MAIN2:
	; 汎用レジスタ初期化
	XOR AX, AX
	XOR BX, BX
	XOR CX, CX
	XOR DX, DX
	; データセグメント初期化
	MOV DS, AX
	MOV ES, AX
	
	; スタックポインタを0x0009FFFCに設定する
	MOV	AX, 0x9000
	MOV	SS, AX
	MOV	SP, 0xFFFC
	
	CALL _setup_gdt	 ; GDT設定処理関数をコール

	HLT


; Set up IDT
_setup_idt: ; GDT設定処理
	CLI
	PUSHA
	LIDT [gdt_toc] ;　GDTを読み込む
	STI
	POPA
	RET

; Global Descriptor Table
gdt_toc:
	DW 8*3
	DD _gdt

_gdt:
	; Null descriptor
	DW 0x0000
	DW 0x0000
	DW 0x0000
	DW 0x0000

	; Code descriptor
	DB 0xFF
	DB 0xFF
	DW 0x0000
	DB 0x00
	DB 10011010b
	DB 11001111b
	DB 0

	; Data descriptor
	DB 0xFF
	DB 0xFF
	DW 0x0000
	DB 0x00
	DB 10010010b
	DB 11001111b
	DB 0

