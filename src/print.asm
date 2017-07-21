; 改行なしで文字列を表示する
%macro print 1
	push si
	mov si, %1
	call print_string
	pop si
%endmacro

; 改行込みで文字列を表示する
%macro println 1
	print %1
	call print_newline
%endmacro

; ASCIIコードを1文字表示する
%macro put 1
	push ax
	push bx
	mov al, %1
	call print_char
	pop bx
	pop ax
%endmacro

; Constant
MBR_SIZE         equ 512
SECTOR_SIZE      equ 512
LOAD_ADDR        equ 0x7C00
NEXT_LOADER_ADDR equ LOAD_ADDR
STACK_TOP        equ 0x500
STACK_SIZE       equ 0x1000
STACK_BOTTOM     equ STACK_TOP + STACK_SIZE
RELOCATE_ADDR    equ STACK_BOTTOM
PART_TABLE_ADDR  equ RELOCATE_ADDR + MBR_SIZE - 66
MEMORY_INFOS     equ RELOCATE_ADDR + MBR_SIZE
PART_ENTRY_SIZE  equ 16
BOOTABLE_FLAG    equ 0x80

bits 16
org LOAD_ADDR

boot:
	jmp short main ; メインラベルへショートジャンプ

main:
	mov ax, cs ; CSセグメントで全てのセグメントを上書き
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax

	mov sp, STACK_BOTTOM ; スタックポインタを一番下に設定

	; MBRをメモリのLOAD_ADDRからRELOCATE_ADDRへコピー
	mov cx, MBR_SIZE ; MBR_SIZEの回数だけ繰り返す
	mov si, LOAD_ADDR ; コピー元のアドレス
	mov di, RELOCATE_ADDR ; コピー先のアドレス
	rep movsb

    ; 次の行き先アドレスを計算
    ; スタックに積んでretfで積んだ先へジャンプ
    ; MBRをコピーしたRELOCATE_ADDRに
    ; load_loader2と現在のアドレスを引いた分
    ; (MBRのサイズ)をプラスすることで
    ; 別セグメントのload_loader2へジャンプする
    push es
    push RELOCATE_ADDR + (load_loader2 - $$)
    retf


; Load next sector.
load_loader2:
	mov [drive_number], dl

	; 初めにディスクのリセットを行う
	; もし失敗した場合はboot_faultへジャンプする
	xor ax, ax ; axを0へ。axが0x00の場合、int 0x13はリセットファンクションとなる
	int 0x13 ; HDDやROMディスクなどへのアクセスを行う割り込み
	jc boot_fault ; CFが0の場合(失敗した)、boot_falutへ

	; ドライバのパラメータの取得
	; 拡張子がサポートされていない場合、
	; キャリーフラグが設定され、失敗します。
	; ドライバのパラメータは
	; CHにトラックの情報がttttttttbの形式で格納されます
	; ttttttttbはトラック数(0始まり)の下位8ビットです。
	; CLにトラックの上位2bitとセクタの情報が格納されます。
	; ttssssssbのttはトラック数の上位2bit
	; ssssssはセクター数になります。セクタは1始まりです。
	; DHにはヘッドの数が格納されます。0始まりです。
	; DLはドライブ数が格納されます。
	mov ah, 0x08	; 0x08はドライブパラメータ読み込み
	int 0x13		; HDDやROMディスクなどへのアクセスを行う割り込み
	jc boot_fault	; CFが0の場合(失敗した)、boot_falutへ

	; ヘッドの情報をメモリに保存する
	; dhに最大ヘッド数が格納(ヘッドは0始まり)されるので
	; メモリの[head_num]番地へdhを保存
	inc dh				; ヘッド数は0始まりなのでインクリメントする
	mov [head_num], dh	; メモリに保存

	; セクタの情報をメモリに保存する
	; clには最大トラック数と最大セクタ数が
	; ttssssssの形で格納されるのでそこからセクタの情報を取得し
	; メモリの[sector_per_track]へ保存する
	mov al, cl		; alへclをコピー
	and al, 0x1f	; ttssssssと00011111(0x1f)をAND演算で下位5bit分をalへ格納
	mov [sector_per_track], al	; メモリに保存

	; シリンダの情報をメモリに保存する
	; ch:tttttttt cl:ttssssssの状態(ch cl)から
	; ch:ttssssss cl:tttttttt  clとchを入れ替える
	; ch:ttssssss cl:000000tt  clを右へ6シフトする
	xchg cl, ch		; clとchを入れ替える 
	shr cl, 6		; 右へ6論理シフトする
	inc cx			; cxをインクリメントする
	mov [cylinder_num], cx ; メモリへ保存

	; Set begin load segment.
	mov dx, (NEXT_LOADER_ADDR >> 4)

	; Calculate the number of sector for loding.
	mov ecx, [loader2_size]
	shr ecx, 9  ; divide by 512

	; Load sector. FIXME: Check segment boundary
	mov ax, 1
	mov es, dx
	xor bx, bx
.loading:
	call load_sector
	add dx, 0x20
	mov es, dx
	inc ax
	loop .loading


.fin:
	hlt
	jmp .fin


; Boot fault process (reboot).
boot_fault:
    int 0x18  ; Boot Fault Routine

print_string:
next:
	mov al, [si]
	inc si
	or al, al
	jz exit
	call print_char
	jmp next
exit:  
 	ret

print_char:
	mov ah,0x0E
	mov bh,0x00
	mov bl,0x0F
	int 0x10
	ret

print_newline:
	push ax
	mov ah, 0x0E
	mov al, 0x0D ; CR
	int 0x10
	mov al, 0x0A ; LF
	int 0x10
	pop ax
	ret

msg1: db "H", 0
msg2: db "E", 0
msg3: db "L", 0
msg4: db "O", 0
msg5: db "W", 0
msg6: db "O", 0
msg7: db "R", 0
msg8: db "D", 0

times 510 - ($ - $$) db 0
dw 0xaa55