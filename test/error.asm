section .text
global _start

msg	db 'I colud die.', 0
msglen	equ $ - msg

_start:
	mov int64 [count], msglen
	mov rcx, msg
.loop:
	mov rdx, 1
	mov rax, 4
	mov rbx, 1
	int 0x80
	inc rcx
	dec int64 [count]
	jne .loop
	mov rax, [rsi]
	mov rax, 1
	mov rbx, 0
	int 0x80

section .data

count	dd 0
