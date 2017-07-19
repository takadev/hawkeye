bits 16

org 0x7c00

jmp boot

boot:
	mov al, 0x041
	call sub1

sub1:
	mov bh, 0xee
	mov bl, 0xff
	call sub2
	ret

sub2:
	call print_string
	ret

print_string:
	push ax
	mov ah, 0x0E
.loop:
	lodsb
	or al, al
	jz .done
	int 0x10
	jmp .loop
.done:
	pop ax
	ret

times 510 - ($ - $$) db 0
dw 0xaa55
