%include "io64.inc"

extern puts
extern printf
extern atoi
extern strlen

; sys calls
sys_write: equ 1
sys_open: equ 2
sys_exit: equ 60
; flags
O_RDONLY: equ 0
; i/o
std_out: equ 1

%macro print 2
    mov rsi, %1
    mov rdx, %2
    call cout_str_w_len
%endmacro

%macro printl 2
    print %1, %2
    NEWLINE
%endmacro

section .data
    filename: db "/home/ubuntu/Documents/AR.P1-master/AR.P1.ASM/output.wav", 0
    filename_len: equ $-filename
    welcome: db "FFT ASM", 0
    welcome_len: equ $-welcome
    
    format_str: db "%s", 0
    
    max_str_len: db 0xffffffffffffffff
    
    missing_args_str: db "No file name provided.", 0
    missing_args_str_len: equ $-missing_args_str

    invalid_sampling_rate_str: db "Invalid sampling rate provided.", 0
    invalid_bit_depth_str: db "Invalid bit depth provided.", 0

section .bss
    argc: resq 1
    argv: resq 1

section .text
global CMAIN ;CMAIN/_start
CMAIN:
    mov rbp, rsp; for correct debugging

    mov [argc], rdi
    cmp byte [argc], 1
    ;JZ missing_args

   ; save argc and argv
    mov rcx, [argc]
    mov [argv], rsi
    mov rbx, rsi

    printl welcome,welcome_len
    printl filename, filename_len ; TODO use cli arg

    mov rdi, filename ; TODO use cli arg
    mov rax, sys_open
    mov rsi, O_RDONLY    
    syscall
    
    xor rax, rax
    ret

cout_str_w_len:
    ;rsi -str ptr
    ;rdx - num of bytes to print
    mov rax, sys_write
    mov rdi, std_out
    syscall
    ret
invalid_bit_depth:
    PRINT_STRING invalid_bit_depth_str
    NEWLINE
    call exit
invalid_sampling_rate:
    PRINT_STRING invalid_sampling_rate_str
    NEWLINE
    call exit    
exit:
    mov rax, sys_exit
    xor rdi, rdi
    syscall
print_argv:
    ;argv in rbx
    mov rdi, [rbx]
    call strlen_o
    
    mov rdx, rax
    mov rax, sys_write
    mov rsi, rdi
    mov rdi, std_out
    syscall
    NEWLINE
    
    ;TODO loop
   
    ret
strlen_o:
    ;string ptr in rdi
    push rbx
    push rcx

    mov rbx, rdi
    xor al, al
    
    mov rcx, [max_str_len]; max iterations in repne
    repne scasb; compare each byte in string with al to find null/0 (while rdi ne al)
    
    sub rdi, rbx
    mov rax, rdi
    mov rdi, rbx

    pop rcx
    pop rbx
    ret
missing_args:
    PRINT_STRING missing_args_str
    NEWLINE
    call exit