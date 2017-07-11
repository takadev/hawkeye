[bits 16]

org	0x7C00

JMP	entry

entry:
	mov ax,0
	mov ss,ax
	mov sp,0x7c00
	mov ds,ax
	mov es,ax
	mov si,msg
putloop:
	mov al,[si]
	add si,1
	cmp al,0
	je fin
	mov ah,0x0e
	mov bx,15
	int 0x10
	jmp putloop
fin:
	hlt
	mov si, ImageName
	call displayMessage
	mov si, msg
	call dispTest
msg:
	db "Hello, world"
	db 0x0a, 0

ImageName:
	db "Good-bye Small World"
	db 0x0a,0

displayMessage:
	push ax
	push bx
startDispMsg:
	lodsb
	or al,al
	jz .done
	mov ah, 0x0E
	mov bh, 0x00
	mov bl, 0x07
	int 0x10
	jmp startDispMsg
.done:
	pop bx
	pop ax
	ret

dispTest:
	lodsb
	or al,al
	jz finish
	mov ah, 0x0E
	mov bh, 0x00
	mov bl, 0x07
	int 0x10
	jmp dispTest
finish:
	ret

times 510 - ($ - $$) db 0

dw 0xAA55

