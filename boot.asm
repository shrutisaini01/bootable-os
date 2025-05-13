[BITS 16]
[ORG 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov si, welcome_msg
    call print_string

    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, 0x80
    int 0x13
    jc try_floppy

    mov ah, 0x42
    mov dl, 0x80
    mov si, disk_address_packet
    int 0x13
    jc disk_error

    jmp switch_to_pm

try_floppy:
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, 0x00
    mov bx, 0x1000
    int 0x13
    jc disk_error

switch_to_pm:
    cli
    lgdt [gdt_descriptor]
    in al, 0x92
    or al, 2
    out 0x92, al
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected_mode

disk_error:
    mov si, disk_error_msg
    call print_string
    jmp $

print_string:
    lodsb
    or al, al
    jz done
    mov ah, 0x0E
    int 0x10
    jmp print_string
done:
    ret

[BITS 32]
protected_mode:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    jmp 0x1000

disk_address_packet:
    db 0x10
    db 0
    dw 1
    dd 0x1000
    dq 1

gdt_start:
    dd 0x0
    dd 0x0

    dw 0xffff
    dw 0x0
    db 0x0
    db 10011010b
    db 11001111b
    db 0x0

    dw 0xffff
    dw 0x0
    db 0x0
    db 10010010b
    db 11001111b
    db 0x0

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

welcome_msg db 'MinimalOS Bootloader...', 13, 10, 0
disk_error_msg db 'Disk read error!', 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55
