[BITS 16]

ORG 0x7C00

mov ax, 0x0820
mov es,ax
mov ch,0
mov dh,0
mov cl,2

readloop:
	mov si,0
retry:
	mov ah,0x02
	mov al,1
	mov bx,0
	mov dl,0x00
	int 0x13
	jnc next
	add si,1
	cmp si,5
	jae error
	mov ah,0x00
	mov dl,0x00
	int 0x13
	jmp retry
next:
	mov ax,es
	add ax,0x0020
	mov es,ax
	add cl,1
	cmp cl,18
	jbe readloop
	mov cl,1
	add dh,1
	cmp dh,2
	jb readloop
	mov dh,0
	add ch,1
	cmp ch,10
	jb readloop
error:
	hlt


times 510 - ($ - $$) DB 0
DW 0xaa55
