org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

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

    mov ah, 0x0e
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

    ; call hello world
    mov si, msg_hello
    call puts

    hlt

.halt:
    jmp.halt

msg_hello: db 'Hello World!', ENDL, 0

times 510-($-$$) db 0
dw 0xAA55