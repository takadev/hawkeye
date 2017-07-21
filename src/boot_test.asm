; Print one character
%macro putchar 1
    push ax
    mov al, %1
    mov ah, 0x0E
    int 0x10
    pop ax
%endmacro

; Sub-routine print_string wrapper.
%macro puts 1
    push si
    mov si, %1
    call print_string
    pop si
%endmacro

print_string:
    push ax
    mov ah, 0x0E
.loop:
    lodsb       ; Grab a byte from SI
    or al, al   ; Check for 0
    jz .done

    int 0x10

    jmp .loop
.done:
    pop ax
    ret

; Constant
MBR_SIZE         equ 512
LOAD_ADDR        equ 0x7C00
NEXT_LOADER_ADDR equ LOAD_ADDR
STACK_BOTTOM     equ 0x1500
RELOCATE_ADDR    equ STACK_BOTTOM
PART_TABLE_ADDR  equ RELOCATE_ADDR + MBR_SIZE - 66
MEMORY_INFOS     equ RELOCATE_ADDR + MBR_SIZE
PART_ENTRY_SIZE  equ 16

bits 16
org RELOCATE_ADDR

; jump start code.
; It must be here before any data.
begin:
    jmp short _main

; Start loader1
; DL is boot disk number
_main:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    putchar "A"
.fin:
    hlt
    jmp .fin

    mov sp, STACK_BOTTOM

    ; Copy this MBR from LOAD_ADDR to RELOCATE_ADDR.
    mov cx, MBR_SIZE
    mov si, LOAD_ADDR
    mov di, RELOCATE_ADDR
    rep movsb

    ; Calculate destination address.
    ; And push segment and addr to jump.
    push es
    push RELOCATE_ADDR + (load_loader2 - $$)
    retf

; Load next sector.
load_loader2:
    mov [drive_number], dl

    ; Reset disk system.
    ; If reset disk cause error, it jumps to boot_fault.
    xor ax, ax
    int 0x13
    jc boot_fault

    ; Get drive parameter.
    ; The carry flag will be set if extensions are NOT supported.
    ; CH ttttttttb  tttttttt is lower 8bit of the number of track (0-base).
    ; CL ttssssssb  tt is upper 2bit of the number of track.
    ;               ssssss: The number of sector (1-base).
    ; DH The number of head (0-base)
    ; DL The number of drive
    mov ah, 0x08
    int 0x13
    jc boot_fault

    ; Store the number of head.
    inc dh
    mov [head_num], dh

    ; Store sector per track
    mov al, cl
    and al, 0x1f
    mov [sector_per_track], al

    ; Store cylinder per platter
    xchg cl, ch
    shr cl, 6
    inc cx
    mov [cylinder_num], cx

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
; }}}


enable_a20_gate:
; {{{
    call wait_Keyboard_out
    mov al, 0xD1
    out 0x64, al
    call wait_Keyboard_out
    mov al, 0xDF
    out 0x60, al
    call wait_Keyboard_out
; }}}


; Memory infomation entry
;   uint64_t Base address
;   uint64_t Length of region (If this value is 0, ignore the entry)
;   uint32_t Region "type"
;       Type 1: Usable (normal) RAM
;       Type 2: Reserved - unusable
;       Type 3: ACPI reclaimable memory
;       Type 4: ACPI NVS memory
;       Type 5: Area containing bad memory
;   uint32_t ACPI 3.0 Extended Attributes bitfield (If 24 bytes are returned, instead of 20).
;       Bit 0 if this bit is clear, the entire entry should be ignored.
;       Bit 1 if this bit is set, the entry is non-volatile.
;       The remaining 30 bits are currently undefined.
detecting_memory_e820:
;{{{
    mov ax, (MEMORY_INFOS >> 4) ; Destination buffer.
    mov es, ax
    xor di, di
    xor ebx, ebx                ; First, ebx must be zero.
    xor ebp, ebp                ; Store the number of entry.

.loop:
    mov [es:di + 20], byte 1   ; flag for validating ACPI 3.X entry.
    mov ecx, 24                 ; Buffer size.
    mov edx, 0x0534D4150        ; Place "SMAP" into edx.
    mov eax, 0xE820
    int 0x15
    jc .finish
    ; On first call, set carry flag means "unsupported function".
    ; On the other, set carry flag means "end of list are reached".
    ; In this, ebx are preserved for next function call.
    ; And cl are stored buffer size of actual loaded by BIOS.
    ; es, di is same input value.

    cmp eax, edx                ; Check result.
    jne boot_fault

    test ebx, ebx               ; If ebx resets to 0, list is complete
    je .finish

    ; If this entry is ACPI 3.x entry, jump for cheking flag.
    cmp cl, 20
    jbe .not_acpi_entry

    ; If ignore bit is set, skip this entry.
    test [es:di + 20], byte 1
    je .skip

.not_acpi_entry:
    ; Check length, length is 64bit.
    ; if length uint64_t is 0, skip entry
    mov ecx, [es:di + 8]
    or ecx, [es:di + 12]
    jz .skip

    inc bp
    add di, 24  ; Set next entry address.

.skip:
    jmp .loop

.finish:
;}}}


set_vbe:
;{{{
    mov al, 0x13
    xor ah, ah
    int 0x10
; }}}


setup_gdt:
; {{{
    ; First, setup temporary GDT.
    lgdt [for_load_gdt]

    mov eax, CR0
    or eax, 0x00000001
    mov CR0, eax
    jmp CODE_SEGMENT:enter_protected_mode
; }}}


;---------------------------------------------------------------------
; Sub-routines
;---------------------------------------------------------------------
; {{{
wait_Keyboard_out:
; {{{
    in  al, 0x64
    and al, 0x02
    in  al, 0x60
    jnz wait_Keyboard_out
    ret
; }}}


; Load one sector into es:bx
; @ax Begin sector(LBA)
; @es:bx pointer to target buffer
load_sector:
    push cx
    push dx
    push ax

    call lba_to_chs

    mov ch, [cylinder]
    mov cl, [cylinder + 1]
    shl cl, 6
    or cl, [sector]
    mov dh, [head]
    mov dl, [drive_number]
    mov ax, 0x0201
    int 0x13
    jc boot_fault

    pop ax
    pop dx
    pop cx

    ret


; Convert LBA to CHS
; @ax LBA
; @return
lba_to_chs:
    push bx
    push dx
    push cx

    mov bx, ax

    mov ax, [head_num]          ; Cylinder = LBA / (The number of head * Sector per track)
    mul word [sector_per_track]
    mov cx, ax
    mov ax, bx
    xor dx, dx                  ; Clear for div instruction.
    div cx
    mov [cylinder], ax

    mov ax, bx                  ; Head = (LBA / Sector per track) % The number of head
    xor dx, dx                  ; Clear for div instruction.
    div word [sector_per_track]
    xor dx, dx                  ; Clear for div instruction.
    div word [head_num]
    mov [head], dl

    mov ax, bx
    xor dx, dx                  ; Clear for div instruction.
    div word [sector_per_track] ; Sector = (LBA % Sector per track) + 1
    inc dx
    mov [sector], dl

    pop cx
    pop dx
    pop bx

    ret

; Boot fault process (reboot).
boot_fault:
    int 0x18    ; Boot Fault Routine

; DATA
drive_number:     db 0
head:             db 0
sector:           db 0
cylinder:         dw 0
head_num:         dw 0
sector_per_track: dw 0
cylinder_num:     dw 0

for_load_gdt:
    dw (3 * 8)
    dd temporary_gdt

CODE_SEGMENT equ (1 * 8)
DATA_SEGMENT equ (2 * 8)
temporary_gdt:
    dw 0x0000 ; Null descriptor
    dw 0x0000
    dw 0x0000
    dw 0x0000

    ; Code descriptor
    db 0xFF
    db 0xFF
    dw 0x0000
    db 0x00
    db 10011010b
    db 11001111b
    db 0

    ; Data descriptor
    db 0xFF
    db 0xFF
    dw 0x0000
    db 0x00
    db 10010010b
    db 11001111b
    db 0

bits 32
enter_protected_mode:
    cli

    mov ax, DATA_SEGMENT
    mov ss, ax
    mov ds, ax
    mov es, ax
    ; mov fs, ax
    ; mov gs, ax

    mov esp, NEXT_LOADER_ADDR

    ; Set arguments of loader2
    xor dh, dh
    mov dl, [drive_number]
    push dx

    mov eax, [loader2_size]
    push eax

    push ebp

    mov eax, MEMORY_INFOS
    push eax

    add esp, -4 ; for return address.

    ; Jump to second loader.
    jmp NEXT_LOADER_ADDR

;times (440 - ($ - $$)) db 0
loader2_size: ; Size of Loader2 is written by img_util.
dd 0
times ((MBR_SIZE - 2) - ($ - $$)) db 0
dw 0xAA55
