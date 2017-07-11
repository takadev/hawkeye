[BITS 16]
ORG 0x7C00

ReadSectors:
	mov ah, 0x02
	mov al, 0x01
	mov ch, 0x01
	mov cl, 0x02
	mov dh, 0x00
	mov dl, 0x00
	mov bx, 0x1000
	mov es, bx
	mov bx, 0x0000
	int 0x13

times 510 - ($ - $$) db 0
dw 0xaa55
