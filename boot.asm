[BITS 16]           ; We need 16-bit code for real mode
[ORG 0x7C00]        ; BIOS loads bootloader at this address

start:
    cli             ; Disable interrupts
    xor ax, ax      ; Clear AX register
    mov ds, ax      ; Set DS to 0
    mov es, ax      ; Set ES to 0
    mov ss, ax      ; Set SS to 0
    mov sp, 0x7C00  ; Set stack pointer
    sti             ; Enable interrupts

    mov si, welcome_msg
    call print_string

    ; Try to detect USB drive
    mov ah, 0x41    ; Check if BIOS supports extended disk services
    mov bx, 0x55AA
    mov dl, 0x80    ; First hard drive (usually USB)
    int 0x13
    jc try_floppy   ; If not supported, try floppy

    ; Load kernel from USB
    mov ah, 0x42    ; Extended read sectors
    mov dl, 0x80    ; First hard drive (USB)
    mov si, disk_address_packet
    int 0x13
    jc disk_error

    jmp switch_to_pm

try_floppy:
    ; Load kernel from floppy
    mov ah, 0x02    ; BIOS read sector function
    mov al, 1       ; Number of sectors to read
    mov ch, 0       ; Cylinder number
    mov cl, 2       ; Sector number (1 is bootloader)
    mov dh, 0       ; Head number
    mov dl, 0x00    ; Drive number (first floppy drive)
    mov bx, 0x1000  ; Load kernel to this address
    int 0x13        ; Call BIOS interrupt
    jc disk_error   ; If carry flag is set, there was an error

switch_to_pm:
    ; Switch to protected mode
    cli
    lgdt [gdt_descriptor]    ; Load GDT

    ; Enable A20 line
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Set PE bit in CR0
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Jump to 32-bit code
    jmp 0x08:protected_mode

disk_error:
    mov si, disk_error_msg
    call print_string
    jmp $

print_string:
    lodsb           ; Load byte from SI into AL
    or al, al       ; Check if AL is 0 (end of string)
    jz done         ; If zero, we're done
    mov ah, 0x0E    ; BIOS teletype function
    int 0x10        ; Call BIOS interrupt
    jmp print_string
done:
    ret

[BITS 32]
protected_mode:
    ; Set up segment registers
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Jump to kernel
    jmp 0x1000

; Disk Address Packet for USB
disk_address_packet:
    db 0x10        ; Size of packet
    db 0           ; Reserved
    dw 1           ; Number of sectors to read
    dd 0x1000      ; Transfer buffer
    dq 1           ; Starting sector (LBA)

; GDT
gdt_start:
    ; Null descriptor
    dd 0x0
    dd 0x0

    ; Code segment descriptor
    dw 0xffff    ; Limit (bits 0-15)
    dw 0x0       ; Base (bits 0-15)
    db 0x0       ; Base (bits 16-23)
    db 10011010b ; Access byte
    db 11001111b ; Flags and Limit (bits 16-19)
    db 0x0       ; Base (bits 24-31)

    ; Data segment descriptor
    dw 0xffff    ; Limit (bits 0-15)
    dw 0x0       ; Base (bits 0-15)
    db 0x0       ; Base (bits 16-23)
    db 10010010b ; Access byte
    db 11001111b ; Flags and Limit (bits 16-19)
    db 0x0       ; Base (bits 24-31)

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; Size of GDT
    dd gdt_start                ; Address of GDT

welcome_msg db 'MinimalOS Bootloader...', 13, 10, 0
disk_error_msg db 'Disk read error!', 13, 10, 0

times 510-($-$$) db 0   ; Pad with zeros
dw 0xAA55              ; Boot signature 