org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;
; FAT12 headers
;
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'               ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2800                     ; 1.4MB
bdb_media_descriptor_type:  db 0F0h                     ; 0F0h = 3.5" floppy
bdb_sectors_per_fat:        dw 9                        ; 9 sectors per FAT
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebd_drive_number:           db 0                        ; 0x00 floppy, 0x80 hdd, useless
                            db 0                        ; reserved
ebd_signature:              db 0x29
ebd_volume_id:              db 12h, 34h, 56h, 78h       ; serial number, value doesn't matter
ebd_volume_label:           db 'Grissia OS '            ; 11 bytes
ebd_system_id:              db 'FAT12   '               ; 8 bytes

;
; code starts here
;

start:
    jmp main

; 
; Print Hello World Onto Screen
; Params:
;       ds:si points to string
;
puts:
    ; save registers we will modify
    push si
    push ax


.loop:
    lodsb                                   ; loads next character in al
    or al, al
    jz .done

    mov ah, 0x0e                            ; BIOS interrupt calls INT 10h
    mov bh, 0
    int 0x10

    jmp .loop

.done:
    pop ax
    pop si
    ret

main:
    ; setup data segment
    mov ax, 0
    mov ds, ax                              ; can't directly write into ds/es
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00

    ; read something from floppy disk
    ; BIOS should set DL to drive number
    mov [ebd_drive_number], dl

    mov ax, 1                               ; LBA address, sector 1
    mov cl, 1                               ; number of sectors to read
    mov bx, 0x7E00                          ; memory address where to store read data
    call disk_read

    ; call hello world
    mov si, msg_hello
    call puts

    hlt

;
; Error handlers
;
floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                                 ; wait for key press BIOS call
    jmp 0FFFFh:0                            ; jump to the beginning of BIOS, should reboot

.halt:
    cli                                     ; disable interrupts, so that CPU can't get out halt stage
    hlt

;
; Disk routines
;

;
; Converts an LBA address to a CHS address
; Parameters:
;   - ax: LBA Address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
;
lba_to_chs:

    push ax
    push dx

    xor dx, dx                              ; dx = 0
    div word [bdb_sectors_per_track]        ; ax = LBA / Sectors per Track
                                            ; dx = LBA % Sectors per Track
    inc dx                                  ; dx = (LBA % Sectors per Track + 1) = sector
    mov cx, dx                              ; cx = sector

    xor dx, dx                              ; dx = 0
    div word [bdb_heads]                    ; ax = (LBA / Sectors per Track) / Heads
                                            ; dx = (LBA / Sectors per Track) % Heads
    mov dh, dl                              ; dh = head
    mov ch, al                              ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                               ; put upper two bits of cyclinder in CL

    pop ax
    mov dl, al                              ; restore DL
    pop ax
    ret

;
; Reads sector from disk
; Parameters:
;   - ax: LBA Address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to store read data
;
disk_read:

    push ax                                 ; save registers we will modify
    push bx
    push cx
    push dx
    push di

    push cx                                 ; temporarily save CL (number of sectors to read)
    call lba_to_chs                         ; convert LBA to CHS
    pop ax                                  ; AL = number of sectors to read

    mov ah, 02h
    mov di, 3                               ; retry count

.retry:
    pusha                                   ; push all registers, we don't know what register will BIOS modify
    stc                                     ; set carry flag, some BIOS don't set it
    int 13h                                 ; BIOS interrupt calls INT 13h
    jnc .done                               ; jmp if carry not set

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di                             ; check if di still alive
    jnz .retry

.fail:
    ; after attempts all failed
    jmp floppy_error

.done:
    popa

    push di                                 ; restore registers modified
    push dx
    push cx
    push bx
    push ax
    ret

;
; Reset disk controller
; Parameters:
;   - dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_hello:                  db 'Hello World!', ENDL, 0
msg_read_failed:            db 'Read from disk failed!', ENDL, 0

times 510-($-$$) db 0
dw 0xAA55