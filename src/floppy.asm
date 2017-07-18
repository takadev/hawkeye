[BITS 16]
ORG 0x7C00

JMP ResetFloppyDrive

ResetFloppyDrive:
	mov ah, 0x00
	mov dl, 0x00
	int 0x13
	jc failure
	hlt
failure:
	hlt

times 510 - ($ -$$) db 0
dw 0xaa55
