%if 0
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

print_newline:
    push ax

    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    pop ax

    ret

print_hex:
    push eax
    push ecx
    push edx

    mov edx, eax
    mov ecx, (32 / 4)
    puts hex_prefix
.loop:
    rol edx, 4
    lea bx, [hex_table] ; base addres
    mov al, dl          ; index
    and al, 0x0f
    xlatb
    putchar al
    loop .loop

    newline

    pop edx
    pop ecx
    pop eax
    ret

hex_table:  db '0123456789ABCDEF', 0
hex_prefix: db '0x'


%macro putchar 1
    push ax
    mov al, %1
    mov ah, 0x0E
    int 0x10
    pop ax
%endmacro

%macro puts 1
    push si
    mov si, %1
    call print_string
    pop si
%endmacro

%endif

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

section .text
global main

main:
    jmp short start

start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov sp, STACK_BOTTOM

    mov cx, MBR_SIZE
    mov si, LOAD_ADDR
    mov di, RELOCATE_ADDR
    rep movsb

    push es
    push RELOCATE_ADDR + (load_loader2 - $$)
    retf

load_loader2:
    mov [drive_number], dl
    xor ax, ax
    int 0x13
    jc boot_fault

    mov ah, 0x08
    int 0x13
    jc boot_fault

    inc dh
    mov [head_num], dh

    mov al, cl
    and al, 0x1f
    mov [sector_per_track], al

    xchg cl, ch
    shr cl, 6
    inc cx
    mov [cylinder_num], cx

    mov dx, (NEXT_LOADER_ADDR >> 4)

    mov ecx, [loader2_size]
    shr ecx, 9  ; divide by 512

    mov ax, 1
    mov es, dx
    xor bx, bx
.loading:
    call load_sector
    add dx, 0x20
    mov es, dx
    inc ax
    loop .loading

enable_a20_gate:
    call wait_Keyboard_out
    mov al, 0xD1
    out 0x64, al
    call wait_Keyboard_out
    mov al, 0xDF
    out 0x60, al
    call wait_Keyboard_out

detecting_memory_e820:
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

    cmp eax, edx                ; Check result.
    jne boot_fault

    test ebx, ebx               ; If ebx resets to 0, list is complete
    je .finish

    cmp cl, 20
    jbe .not_acpi_entry

    test [es:di + 20], byte 1
    je .skip

.not_acpi_entry:
    mov ecx, [es:di + 8]
    or ecx, [es:di + 12]
    jz .skip

    inc bp
    add di, 24  ; Set next entry address.

.skip:
    jmp .loop

.finish:


set_vbe:
    mov al, 0x13
    xor ah, ah
    int 0x10

setup_gdt:
    ; First, setup temporary GDT.
    lgdt [for_load_gdt]

    mov eax, CR0
    or eax, 0x00000001
    mov CR0, eax
    jmp CODE_SEGMENT:enter_protected_mode


wait_Keyboard_out:
    in  al, 0x64
    and al, 0x02
    in  al, 0x60
    jnz wait_Keyboard_out
    ret


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

boot_fault:
    int 0x18    ; Boot Fault Routine

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

    db 0xFF
    db 0xFF
    dw 0x0000
    db 0x00
    db 10011010b
    db 11001111b
    db 0

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

    jmp NEXT_LOADER_ADDR

times (440 - ($ - $$)) db 0
loader2_size: ; Size of Loader2 is written by img_util.
dd 0
times ((MBR_SIZE - 2) - ($ - $$)) db 0
dw 0xAA55
