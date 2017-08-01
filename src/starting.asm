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
	; メッセージ表示
	MOV SI, msgphello
	CALL DisplayMessage
	
	HLT
