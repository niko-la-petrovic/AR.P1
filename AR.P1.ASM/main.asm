%include "io64.inc"

extern puts
extern printf
extern atoi
extern strlen

; sys calls
sys_read: 0
sys_write: equ 1
sys_open: equ 2
sys_exit: equ 60
; flags
O_RDONLY: equ 0
O_RDWR: equ 2
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
    goodbye_str: db "Finished.", 0
    goodbye_str_len: equ $-goodbye_str
    
    format_str: db "%s", 0
    
    max_str_len: db 0xffffffffffffffff
    
    missing_args_str: db "No file name provided.", 0
    missing_args_str_len: equ $-missing_args_str
    failed_file_open_str: db "Failed to open file.", 0

    too_many_args_str: db "Too many arguments provided.", 0
    invalid_sampling_rate_str: db "Invalid sampling rate provided.", 0
    invalid_bit_depth_str: db "Invalid bit depth provided.", 0

section .bss
    argc: resq 1
    argv: resq 1
    filename_arg: resq 1

section .text
global CMAIN ;CMAIN/_start
CMAIN:
    mov rbp, rsp; for correct debugging

    mov [argv], rsi
    mov [argc], rdi
    
;    print welcome,welcome_len
     cmp byte [argc], 1
    ;JZ missing_args

    mov rax, 2
    sub rax, [argc]
    js too_many_args

    mov rcx, [argc]
    mov rbx, rsi

;    printl welcome, welcome_len

    call get_filename
    mov [filename_arg], rsi
    mov rdi, [filename_arg]
    call cout_str
    
 ;   printl filename, filename_len ; TODO use cli arg

    mov rdi, filename ; TODO use cli arg
    mov rax, sys_open
    mov rsi, O_RDONLY    
    syscall
    
    cmp rax, 0
    js failed_file_open
    
    ; TODO read file
    
;    printl goodbye_str, goodbye_str_len
                            
    xor rax, rax
    ret

cout_str:
    ;str in rdi
    call strlen_o
    mov rdx, rax
    call cout_str_w_len
    ret
cout_str_w_len:
    ;rsi -str ptr
    ;rdx - num of bytes to print
    mov rax, sys_write
    mov rdi, std_out
    syscall
    ret
failed_file_open:
    PRINT_STRING failed_file_open_str
    NEWLINE
    call exit
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
get_filename:    
    ;argv in rbx
    ;argc in rcx
    ;rsi will contain argv[0]
    cmp rcx,0
    
    push rcx
    mov rdi, [rbx]
    call strlen_o
    
    mov rdx, rax
    mov rsi, rdi
    call cout_str_w_len
    NEWLINE
    
    pop rcx
    dec rcx
    cmp rcx, 0
    jnz too_many_args ; TODO set rsi to be argv[argc-1]
    ret
get_filename_1
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
too_many_args:
    PRINT_STRING too_many_args_str
    NEWLINE
    call exit