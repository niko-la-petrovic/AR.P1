%include "io64.inc"

extern puts
extern printf
extern atoi
extern strlen
extern fprintf
extern calloc
extern free
extern aligned_alloc

;sys calls
sys_read: equ 0
sys_write: equ 1
sys_open: equ 2
sys_close: equ 3
sys_exit: equ 60
sys_unlink: equ 87
sys_time: equ 201
;flags
O_RDONLY: equ 00
O_WRONLY: equ 01
O_RDWR: equ 02
O_CREAT: equ 0100
O_TRUNC: equ 0x200
;i/o
std_in: equ 0
std_out: equ 1
std_err: equ 2

%macro print 2
    mov rsi, %1
    mov rdx, %2
    call cout_str_w_len
%endmacro

%macro printl 2
    print %1, %2
    NEWLINE
%endmacro

section .rodata
    filename: db "/home/ubuntu/Documents/AR.P1-master/AR.P1.ASM/output.wav", 0
    filename_len: equ $-filename

    out_filename: db "./output.bin", 0
    out_filename_len: equ $-out_filename

    ;strings
    welcome: db "FFT ASM", 0
    welcome_len: equ $-welcome
    goodbye_str: db "Finished.", 0
    goodbye_str_len: equ $-goodbye_str
    
    missing_args_str: db "No file name provided.", 0
    missing_args_str_len: equ $-missing_args_str
    failed_file_open_str: db "Failed to open file ", 0

    too_many_args_str: db "Too many arguments provided.", 0
    invalid_sampling_rate_str: db "Invalid sampling rate provided.", 0
    invalid_bit_depth_str: db "Invalid bit depth provided.", 0
    invalid_in_file_header_str: db "Invalid input file header.", 0
    invlid_in_file_read_str: db "Invalid input file read.", 0
    memory_allocation_err_str: db "Failed to allocate memory.", 0
    
    format_str: db "%s", 0
    format_int: db "%d", 0
    
    max_str_len: db 0xffffffffffffffff
    null_byte: db 0    
section .data
    last_time: dq 1
    signal_counter: dq 1
section .bss
    argc: resq 1
    argv: resq 1
    
    filename_arg: resq 1
    
    fd: resq 1
    fd_in: resq 1
    fd_out: resq 1
    
    data_len: resb 4
    half_data_len: resb 4
    signal_ptr: resq 1

    %define buffer_len 32;16 shorts
    align 32
    buffer: resb buffer_len
    %define header_buffer_len 44;WAV file header
    header_buffer: resb header_buffer_len
    
    signal_ptr_len: resb 4
section .text
global CMAIN ;CMAIN/_start
CMAIN:
    mov rbp, rsp;for correct debugging

    mov [argv], rsi
    mov [argc], rdi
    
    ;print welcome,welcome_len
    
     cmp byte [argc], 1
    ;jz missing_args

    mov rax, 2
    sub rax, [argc]
    ;js too_many_args

    mov rcx, [argc]
    mov rbx, rsi

    ;printl welcome, welcome_len

    call get_filename
    mov [filename_arg], rsi
    mov rdi, rsi
    call cout_str
    
    ;printl filename, filename_len ;TODO use cli arg

    mov rdi, filename;TODO use cli arg
    mov rsi, O_RDONLY    
    call open_file
    mov rax, [fd]
    mov [fd_in], rax

    mov rdi, out_filename
    mov rsi, O_CREAT | O_RDWR | O_TRUNC
    mov rdx, 644o     
    call open_file
    mov rax, [fd]
    mov [fd_out], rax
    
    mov rdi, [fd_out]
    mov rdx, filename_len
    mov rsi, filename
    call write_file
    
    mov rdx, 1
    mov rsi, null_byte
    call write_file
    
    mov rax, sys_time
    mov rdi, last_time
    syscall
    
    mov rdi, [fd_out]
    mov rdx, 8
    mov rsi, last_time
    call write_file

    mov rdi, [fd_in]
    mov rsi, header_buffer
    mov rdx, header_buffer_len
    call read_file
    cmp rax, header_buffer_len
    jnz invalid_in_file_header

    ;TODO move header_buffer to rbx - unnecessary

    ;number of channels    
    lea rax, [rsi + 22]
    movzx rax, WORD [rax]
    cmp rax, 1
    jnz invalid_in_file_header

    ;sampling rate
    lea rax, [rsi + 24]
    mov rax, [rax]
    cmp eax, 44100    

    lea rax, [rsi + 34]
    movzx rax, WORD [rax]
    cmp rax, 0x10
    jnz invalid_bit_depth

    ;apparently a comment containing sect1on (replace 1 with i) breaks the debugger?
    ;data size
    lea rax, [rsi + 40]
    mov rax, [rax]
    mov [data_len], eax
    cmp eax, 0
    jz invalid_in_file_header
    sar eax, 1
    mov [half_data_len], eax

    ;data_len is the size of all shorts -> 
    ;align signal_ptr_len size for optimized AVX
    xor rdx, rdx
    xor rax, rax
    mov eax, [data_len]
    mov rbx, 32
    div rbx
    ;remainder in rdx
    mov rax, 32
    sub eax, edx
    mov edx, eax
    ;add remainder to enable alignment
    xor rax, rax
    mov eax, [data_len]
    add eax, edx
    ;2x since we'll convert each short to a float
    shl rax, 1
    mov [signal_ptr_len], eax

    ;allocate aligned for AVX
    xor esi, esi
    mov esi, [signal_ptr_len]
    mov rdi, 32
    call aligned_alloc
    cmp rax, 0
    jz memory_allocation_err
    mov [signal_ptr], rax
    
    ;prepare counter for writing to signal_ptr
    xor rcx, rcx
    mov [signal_counter], rcx
    
    ;process .WAV data sect1on and write signal floats into signal_ptr
    call rsws
    
    ;start the FFT
    
    ;write results of FFT to [fd_out]
    
    ;free up resources
    mov rdi, [signal_ptr]
    call free

    mov rdi, [fd_out]
    call close_file

    mov rdi, [fd_in]
    call close_file 
    ;printl goodbye_str, goodbye_str_len
                            
    xor rax, rax
    ret
rsws:
    ;read fd_in to buffer_len
    mov rdi, [fd_in]
    mov rsi, buffer
    mov rdx, buffer_len
    call read_file
    cmp rax, 0
    jz _nop
    
    ;load buffer address into rax
    lea rax, [rsi]
    ;load first 256 bits from buffer (16 shorts = 32B)
    vmovdqa ymm0, [rax]
    ;save for after the shifting
    vmovdqa ymm15, ymm0

    ;extend lower 8 shorts as 8 ints
    vmovdqa ymm2, ymm0   
    vpmovsxwd ymm3, xmm2
    
    ;vpsrldq ymm2, ymm2, 8 - right byte shifting - useless here - doesn't cross boundary between upper and lower
    ;permute the register so that the upper 16B are moved down    
    ;0b01'00'11'10 (order of resulting quad words (32B = 4*8B = 4*QW)
    ;each of these pairs represents the index of each quad word in the result of the perm
    ;78 is the decimal representation of the binary string
    vpermq ymm2, ymm2, 78     
    
    ;repeat extension
    vpmovsxwd ymm4, xmm2
    
    ;convert 8 ints to floats
    vcvtdq2ps ymm5, ymm3
    vcvtdq2ps ymm6, ymm4
    
    ;write floats to [signal_ptr]
    mov rcx, [signal_counter]

    mov rax, [signal_ptr]
    vmovdqu [rax+rcx], ymm5
    add rcx, 32
    vmovdqu [rax+rcx], ymm6
    add rcx, 32
    
    mov [signal_counter], rcx
    
    ;repeat processing until end of file
    jmp rsws
    ret
_nop:
    ret
memory_allocation_err:
    PRINT_STRING memory_allocation_err_str
    NEWLINE
    call exit
invlid_in_file_read_err:
    PRINT_STRING invlid_in_file_read_str
    NEWLINE
    call exit
read_file:
    ;file descriptor in rdi
    ;buffer to read to in rsi
    ;max. number of characters to read into buffer in rdx
    mov rax, sys_read
    syscall    
    ret
invalid_in_file_header:
    PRINT_STRING invalid_in_file_header_str
    NEWLINE
    call exit
close_file:
    ;file descriptor in rbx
    mov rax, sys_close
    syscall
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
write_file:
    ;file descriptor in rdi
    ;buffer length in rsi
    mov rax, sys_write
    syscall
    ret
open_file:
    ;file path string in rdi
    ;open flags in rsi
    ;permission flags in rdx
    ;returns file descriptor in fd
    mov rax, sys_open
    syscall
    mov [fd], rax
    cmp rax, 0
    js failed_file_open
    ret
failed_file_open:
    ;file name str in rdi
    call cout_str
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
    cmp rcx,0
    jz _nop
    
    call get_filename_1
        
    dec rcx
    add rbx, 8
    jmp get_filename
    
    ret
get_filename_1:
    ;argv+i in rbx
    push rcx
    mov rdi, [rbx]
    call strlen_o
    
    mov rdx, rax
    mov rsi, rdi
    call cout_str_w_len
    NEWLINE

    pop rcx
    ret
strlen_o:
    ;string ptr in rdi
    push rbx
    push rcx

    mov rbx, rdi
    xor al, al
    
    mov rcx, [max_str_len];max iterations in repne
    repne scasb;compare each byte in string with al to find null/0 (while rdi ne al)
    
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