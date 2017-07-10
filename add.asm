
n .data
	outbuff db 10

section .text
	global main

main:
	mov	al, 2
	add	al, 1
	or	al, 0x30
	mov	[outbuff], al
	mov	al, 0
	mov	[outbuff + 1], al
	mov	eax, 4
	mov	ecx, outbuff
	mov	edx, 2
	int	0x80
	mov	eax, 1
	mov	ebx, 0
	int	0x80
