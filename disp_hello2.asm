[BITS 16]
ORG 0x7C00

start:
mov si,msg
call print_string

fin:
hlt
jmp fin

print_char:
mov ah,0x0E
mov bh,0x00
mov bl,0x0F

int 0x10
ret

print_string:
next:
mov al,[si]
inc si
or al,al
jz exit
call print_char
jmp next
exit:
ret

msg db "Hello World!", 0

times 510 - ($ - $$) db 0
dw 0xaa55
