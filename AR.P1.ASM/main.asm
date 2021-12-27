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
    filename: db "/home/ubuntu/Documents/GitHub/AR.P1/AR.P1.ASM/output.wav", 0
    filename_len: equ $-filename

    ;running with f9 through SASM, output.bin will be in ~/
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
    
    sampling_rate: dd 44100
    
    pi: dd 3.141592653589793238462
    neg2pi: dd -6.28318530717959
    max_str_len: db 0xffffffffffffffff
    null_byte: db 0
    samples_const: dq 4096;window size
    
    _negTwoPi: times 8 dd -6.283185307179586476925286766559
    _indicesVector: dd 0.0, 1.0, 2.0, 3.0, 0.0, 1.0, 2.0, 3.0
    
    _fourDivPi: times 8 dd 1.2732395447351626861510701069801
    _negFourDivPiSq: times 8 dd -0.40528473456935108577551785283891
    _piHalf: times 8 dd 1.5707963267948966192313216916398
    _p: times 8 dd 0.225
    _positiveSignMask: times 8 dd 0x7fffffff
    _ones: times 8 dd 1.0
    
    %define s_signal_ptr 56
    %define s_signal_sample_count 48
    %define s_spec_comps_ptr 40
    %define s_half_sample_count 32
    %define s_even_signal_ptr 24
    %define s_odd_signal_ptr 16
    %define s_even_spec_comps_ptr 8
    %define s_odd_spec_comps_ptr 0
section .data
    last_time: dq 1
    signal_counter: dq 1
section .bss
    align 32
    avxBuffer: resd 8

    argc: resq 1
    argv: resq 1
    
    filename_arg: resq 1
    
    fd: resq 1
    fd_in: resq 1
    fd_out: resq 1
    
    data_len: resb 4
    padding_1: resb 4;unused, but needed for alignment
    signal_ptr: resq 1

    %define buffer_len 32;16 shorts
    align 32
    buffer: resb buffer_len
    %define header_buffer_len 44;WAV file header
    header_buffer: resb header_buffer_len
    
    signal_ptr_len: resq 1
    shortBuffer: resb 2
    
    realBuffer: resd 1
    imagBuffer: resd 1
    
    intBuffer: resd 1
    longBuffer: resq 1
    
    sample_count: resb 4    
    
section .text
global CMAIN ;CMAIN/_start
CMAIN:
    mov rbp, rsp;for correct debugging

    mov [argv], rsi
    mov [argc], rdi
    
    ;print welcome,welcome_len
    
    cmp byte [argc], 1
    jz missing_args

    mov rax, 2
    sub rax, [argc]
    js too_many_args

    mov rcx, [argc]
    mov rbx, rsi

    ;printl welcome, welcome_len

    call get_filename
    mov [filename_arg], rsi
    mov rdi, rsi
    call cout_str
    
    ;printl filename, filename_len ;TODO use cli arg

    ;mov rdi, filename
    mov rdi, [filename_arg]
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
    
    ; mov rdi, [fd_out]
    ; mov rdx, filename_len;TODO use cli arg
    ; mov rsi, filename;TODO use cli arg
    ; call write_file
    ; call write_delimiter
        
    mov rax, sys_time
    mov rdi, last_time
    syscall
    
    ; mov rdi, [fd_out]
    ; mov rdx, 8
    ; mov rsi, last_time
    ; call write_file
    ; call write_delimiter

    mov rdi, [fd_in]
    mov rsi, header_buffer
    mov rdx, header_buffer_len
    call read_file
    cmp rax, header_buffer_len
    jnz invalid_in_file_header

    ;number of channels    
    lea rax, [rsi + 22]
    movzx rax, WORD [rax]
    cmp rax, 1
    jnz invalid_in_file_header

    ;sampling rate
    lea rax, [rsi + 24]
    mov rax, [rax]
    cmp eax, [sampling_rate]   

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
    sar eax, 4;require a multiple of 16 for the algorithm to work optimized
    sal eax, 4
    sar eax, 1
    mov [sample_count], eax

    ;data_len is the size of all shorts -> 
    ;align signal_ptr and size for optimized AVX
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
    mov [signal_ptr_len], rax

    ;allocate aligned ptr for AVX
    mov rsi, [signal_ptr_len]
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
    ;call rsws_unoptimized

    ;write signal len to fd_out
    ; mov rdi, [fd_out]
    ; mov rdx, 8
    ; mov rsi, signal_ptr_len
    ; call write_file
    ;delimiter
    ; call write_delimiter
    
    ;write signal to fd_out
    ; mov rdi, [fd_out]
    ; mov rdx, [signal_ptr_len]
    ; mov rsi, [signal_ptr]
    ; call write_file
    ;delimiter
    ; call write_delimiter
    
    ;prepare for the windowed fft
    mov qword [signal_counter], 0
    xor rdx, rdx
    mov edx, [data_len]    
    call fft_windowed
    
    ;cleanup
    call finish
    
    xor rax, rax
    ret
fft_windowed:
    ;out of bounds check
    ;ensure enough data in window
    xor rax, rax
    mov eax, [sample_count]
    mov rcx, [signal_counter]
    mov rdx, rcx
    add rdx, [samples_const]
    cmp rdx, rax;signal_counter+window size < sample_count
    jge _nop
    
    ;fft
    ;move along signal ptr to the rcx-th sample
    mov rax, [signal_ptr]
    lea rax, [rax+rcx*4]
    mov rsi, rax
    mov rdx, [samples_const]
    call fft

    push rax
    ;write results of FFT to [fd_out]
    mov rdi, [fd_out]
    mov rax, [samples_const]
    mov rcx, 8
    mul rcx
    mov rdx, rax
    pop rax
    push rax
    mov rsi, rax
    call write_file
    
    ;free memory from rax
    pop rax
    mov rdi, rax
    call free
    
    ;next samples
    mov rcx, [signal_counter]
    add rcx, [samples_const]
    mov [signal_counter], rcx
    
    jmp fft_windowed
fft:
    ;signal pointer in rsi
    ;signal sample count in rdx

    ;return spec comps ptr in rax
    
    push rsi;signal ptr 56
    push rdx;signal sample count 48
    push r8;spec comps ptr 40
    push r9;half sample count 32
    push r10;even signal ptr 24
    push r11;odd signal ptr 16
    push r12;even spec comps ptr 8
    push r13;odd spec comps ptr 0
    
    ;each complex number is two floats - 8B
    mov rax, 8
    mul rdx
    
    ;allocate spec_comp_ptr
    mov rsi,rax;sample count * 8B for complex numbers
    mov rdi, 32
    call aligned_alloc
    cmp rax, 0
    jz memory_allocation_err
    
    mov [rsp+s_spec_comps_ptr], rax
    
    ;check recursion termination
    mov rdx, [rsp+s_signal_sample_count]
    cmp rdx, 1
    jz fft_term
    
    ;get half signal length
    mov r9, rdx
    shr r9, 1
    
    mov [rsp+s_half_sample_count], r9
    
    ;allocate even and odd signal ptr
    ;even signal
    mov rsi, r9;half signal length
    mov rdi, 4;float
    call calloc
    cmp rax, 0
    jz memory_allocation_err
    
    mov [rsp+s_even_signal_ptr], rax
    
    ;even signal ptr
    mov rsi, [rsp+s_half_sample_count]
    mov rdi, 4;float
    call calloc
    cmp rax, 0
    jz memory_allocation_err
    
    ;odd signal ptr
    mov [rsp+s_odd_signal_ptr], rax

    ;copy values to even and odd signal ptr
    ;even signal ptr
    mov rsi, [rsp+s_signal_ptr];signal_ptr in rsi
    mov rdx, [rsp+s_even_signal_ptr];dest ptr in rdx
    mov r9, [rsp+s_half_sample_count];half sample count in r9
    xor rcx, rcx;number of floats copied so far in rcx
    call fft_sig_cp_even
    
    ;odd signal ptr
    mov rsi, [rsp+s_signal_ptr];signal_ptr in rsi
    mov rdx, [rsp+s_odd_signal_ptr];dest ptr in rdx
    mov r9, [rsp+s_half_sample_count];half sample count in r9
    xor rcx, rcx;number of floats copied so far in rcx
    call fft_sig_cp_odd
   
    ;call fft recursively on even and odd signal ptr
    ;fft on even signal ptr
    mov rsi, [rsp+s_even_signal_ptr]
    mov rdx, [rsp+s_half_sample_count]
    call fft
    ;even spec comps ptr
    mov [rsp+s_even_spec_comps_ptr], rax
    
    ;fft on odd signal ptr
    mov rsi, [rsp+s_odd_signal_ptr]
    mov rdx, [rsp+s_half_sample_count]
    call fft
    ;odd spec comps ptr
    mov [rsp+s_odd_spec_comps_ptr], rax
    
    ;calculate spectral compnoents
    xor rcx, rcx;samples processed in rcx
    mov rdx, [rsp+s_half_sample_count];half sample count in rdx
    mov rdi, [rsp+s_signal_sample_count];signal sample count in rdi
    mov rsi, rsp;previous stack pointer in rsi
    
    ;prepare signal length vector for fft_calc
    mov [intBuffer], edi;NOTE: treating rdi as edi
    vpbroadcastd ymm0, [intBuffer]
    vcvtdq2ps ymm15, ymm0;signalLenVec - ymm15
    call fft_calc
    ;call fft_calc_unoptimized
    
    ;cleanup
    ;odd spec comps ptr
    mov rdi, [rsp+s_odd_spec_comps_ptr]
    call free
    
    ;even spec comps ptr
    mov rdi, [rsp+s_even_spec_comps_ptr]
    call free
    
    ;odd signal ptr
    mov rdi, [rsp+s_odd_signal_ptr]
    call free
    
    ;even signal ptr
    mov rdi, [rsp+s_even_signal_ptr]
    call free
    
    ;restore stack
    pop r13;odd spec comps ptr 0
    pop r12;even spec comps ptr 8
    pop r11;odd signal ptr 16
    pop r10;even signal ptr 24
    pop r9;half sample count 32
    pop r8;spec comps ptr 40
    pop rdx;signal sample count 48
    pop rsi;signal ptr 56
    
    mov rax, r8
    
    ret
fft_calc:
    ;spec comps processed in rcx
    ;half sample count in rdx
    ;signal sample count in rdi
    ;previous stack pointer in rsi
    ;signal length vector in ymm15 (8 floats)
    mov r8, rcx
    add r8, 4
    cmp r8, rdx
    jg fft_calc_unoptimized
    
    ;load current index as int, convert to floats
    mov [intBuffer], ecx;NOTE: treating rcx as ecx
    vpbroadcastd ymm0, [intBuffer]
    vcvtdq2ps ymm1, ymm0;i - ymm1
    
    vaddps ymm2, ymm1, [_indicesVector];currentIndicesVector - ymm2
    
    vmulps ymm3, ymm2, [_negTwoPi];constMultipliedVector - ymm3

    vdivps ymm14, ymm3, ymm15;thetaVector - ymm14
    
    ;calc cos
    vmovaps ymm0, ymm14
    call simd_cos
    vmovaps ymm13, ymm0;cosV - ymm13
    
    ;calc sin
    vmovaps ymm0, ymm14
    call simd_sin
    vmovaps ymm12, ymm0;sinV - ymm12
    
    ;store in vector as theta1, theta2, theta3, theta4, theta1, theta2, theta3, theta4,
    vmovaps [avxBuffer], xmm13
    vmovaps [avxBuffer+16], xmm12
    vmovaps ymm0, [avxBuffer];cosSinV - ymm0
    
    mov rax, [rsi+s_odd_spec_comps_ptr]
    lea rax, [rax+rcx*8]
    vmovups ymm1, [rax];oddSpecCompsV - ymm1    
    
    vshufps ymm2, ymm1, ymm1, 85;bSwap - ymm2

    vshufps ymm3, ymm0, ymm0, 255;aIm - ymm3
    
    vshufps ymm4, ymm0, ymm0, 0;aRe - ymm4

    vmulps ymm5, ymm3, ymm2;aImBSwap - ymm5
    
    ;NOTE vfmaddps doesn't work as written, for some reason
    ;https://www.amd.com/system/files/TechDocs/43479.pdf
    ;page 46
    ;apparently if the 256-bit version of the instruction is used, two of the arguments are double precision
    ;while one is single-precision
    ;vfmaddps ymm6, ymm4, ymm1, ymm5;oddOffsetSpecComp - ymm6
    vmulps ymm6, ymm4, ymm1
    vaddps ymm6, ymm6, ymm5
    
    mov rax, [rsi+s_even_spec_comps_ptr]
    lea rax, [rax+rcx*8]
    vmovups ymm7, [rax];evenSpecCompsV - ymm7
    
    vaddps ymm8, ymm7, ymm6;ithSpecComps - ymm8
    mov rax, [rsi+s_spec_comps_ptr]
    lea rax, [rax+rcx*8]
    vmovups [rax], ymm8
    
    vsubps ymm9, ymm7, ymm6;otherIthSpecComps - ymm9
    lea rax, [rax+rdx*8]
    vmovups [rax], ymm9
    
    add rcx, 4
    
    jmp fft_calc
fft_calc_unoptimized:
    ;spec comps processed in rcx
    ;half sample count in rdx
    ;signal sample count in rdi
    ;previous stack pointer in rsi
    cmp rdx, rcx
    jle _nop

    ;calculate odd offset
    ;oddOffset = polar(1, -2pi*i/signalLength) * oddSpectralComponent[i]
    ;(x+yi)(u+vi)=(xu - yv) + (xv + yu)i
    
    ;polar real
    ;i
    mov [longBuffer], rcx
    fild qword [longBuffer]
    ;/signalLength
    mov [longBuffer], rdi
    fidiv dword [longBuffer] ;NOTE: loading longBuffer as qword, but reading as dword
    ;*-2pi
    fmul dword [neg2pi]
    
    ;copy the angle
    fld st0
    ;cos(-2pi*i/signalLength)
    fcos
    fstp dword [realBuffer];x
    
    ;sin(-2pi*i/signalLength)
    fsin
    fstp dword [imagBuffer];y
    
    ;oddOffset real component = xu - yv
    fld dword [realBuffer];x
    fld st0;keep a copy of x for one more multiplication
    
    mov rax, [rsi+s_odd_spec_comps_ptr]
    lea rax, [rax+rcx*8];address to load u and v from
    fmul dword [rax];u => xu, x
    
    fld dword [imagBuffer];y => y, xu, x
    fmul dword[rax+4];v => yv, xu, x
    fchs; => -yv, xu, x
            
    fadd st1; => xu-yv, xu, x
    fstp dword [realBuffer];xu-yv => xu, x
            
    ;oddOffset imag component = xv + yu
    fstp st0; => x
    fmul dword[rax+4];v => xv
    fld dword [imagBuffer];y => y, xv
    fmul dword [rax];u => yu, xv
    
    fadd st1;xv+yu, xv
    fstp dword [imagBuffer];xv+yu => xv
    fstp st0;clear
    
    ;spec comps[i] = even spec comps[i] + odd offset spec comp
    ;(x+yi)+(u+vi) = (x+u)+(y+v)i
    mov rax, [rsi+s_even_spec_comps_ptr]
    lea rax, [rax+rcx*8];even spec comps[i]
    mov r8, rax;temp save
    fld dword [realBuffer];x => x
    fadd dword [rax];u => x+u
    fld dword [imagBuffer];y => y, x+u
    fadd dword[rax+4];v => y+v, x+u
    
    fstp dword [longBuffer+4];y+v
    fstp dword [longBuffer];x+u
    
    mov rax, [rsi+s_spec_comps_ptr]
    lea rax, [rax+rcx*8];spec comps[i]
    mov r9, [longBuffer]
    mov [rax], r9;
    
    ;spec comps[half sample count + i] = even spec comps [i] - odd offset spec comp
    ;(x+yi)-(u+vi) = (x-u)+(y-v)i
    mov rax, r8;temp restore
    fld dword [rax];x => x
    fsub dword [realBuffer];u => x-u
    fld dword [rax+4];y => y, x-u
    fsub dword[imagBuffer];v => y-v, x-u

    fstp dword [longBuffer+4];y-v
    fstp dword [longBuffer];x-u
    
    mov rax, [rsi+s_spec_comps_ptr]
    lea rax, [rax+rdx*8]
    lea rax, [rax+rcx*8];spec comps [half sample count + i]
    mov r9, [longBuffer]
    mov [rax], r9
    
    inc rcx
    
    jmp fft_calc_unoptimized
fft_sig_cp_even:
    ;signal_ptr in rsi
    ;dest ptr in rdx
    ;half sample count in r9
    ;number of floats copied so far in rcx
    cmp r9, rcx
    jle _nop
    
    mov rdi, rcx
    shl rdi, 1
    
    mov eax, [rsi+rdi*4]
    lea rdi, [rdx + rcx*4]
    mov [rdi], eax
    inc rcx
    
    jmp fft_sig_cp_even
fft_sig_cp_odd:
    ;signal_ptr in rsi
    ;dest ptr in rdx
    ;half sample count in r9
    ;number of floats copied so far in rcx
    cmp r9, rcx
    jle _nop

    mov rdi, rcx
    shl rdi, 1
    inc rdi
    
    mov eax, [rsi + rdi*4]
    lea rdi, [rdx + rcx*4]
    mov [rdi], eax
    inc rcx

    jmp fft_sig_cp_odd
fft_term:
    ;clean up stack
    pop r13;odd spec comps ptr 0
    pop r12;even spec comps ptr 8
    pop r11;odd signal ptr 16
    pop r10;even signal ptr 24
    pop r9;half sample count 32
    pop r8;spec comps ptr 40
    pop rdx;signal sample count 48
    pop rsi;signal ptr 56
    
    mov rax, r8;spec comps ptr
    ;spec comps ptr in rax
    ;signal ptr in rsi
    
    ;set spec comps ptr[0]=signal ptr[0]    
    mov esi, [rsi]
    mov [rax], esi;real
    mov dword [rax+4], 0;imag
    
    ;return spectral_component_ptr via rax

    ret
finish:
    ;free up resources
    mov rdi, [signal_ptr]
    call free

    mov rdi, [fd_out]
    call close_file

    mov rdi, [fd_in]
    call close_file 
    ;printl goodbye_str, goodbye_str_len
                
    ret
write_delimiter:
    mov rdx, 1
    mov rsi, null_byte
    call write_file
    ret
rsws:
    ;read fd_in to buffer_len
    mov rdi, [fd_in]
    mov rsi, buffer
    mov rdx, buffer_len
    call read_file
    cmp rax, 32
    jl _nop
    
    ;load buffer address into rax
    lea rax, [rsi]
    ;load first 256 bits from buffer (16 shorts = 32B)
    vmovdqa ymm0, [rax]

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
    vmovaps [rax+rcx], ymm5
    add rcx, 32
    vmovaps [rax+rcx], ymm6
    add rcx, 32
    
    mov [signal_counter], rcx
    
    ;repeat processing until end of file
    jmp rsws
rsws_unoptimized:
    ;ensure a multiple of 16 samples
    mov rax, [sample_count]
    mov rcx, [signal_counter]
    sub rax, rcx
    cmp rax, 0
    jle _nop
    
    ;read fd_in to buffer_len
    mov rdi, [fd_in]
    mov rsi, buffer
    mov rdx, 2;load one short at a time
    call read_file
    cmp rax, 2
    jl _nop
    
    ;take a short from the buffer and store in ST
    fild word [rsi]
    
    ;write floats to [signal_ptr]
    mov rcx, [signal_counter]
    mov rax, [signal_ptr]
    fstp dword [rax+rcx*4]

    inc rcx
    mov [signal_counter], rcx
    
    ;repeat processing until end of file
    jmp rsws_unoptimized
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
;NOTE for the sake of this problem, could be reduced to using xmm* registers
simd_cos:
    ;x in ymm0
    vaddps ymm0, ymm0, [_piHalf]
    jmp simd_sin
simd_sin:
    ;x in ymm0
    vmulps ymm1, ymm0, [_fourDivPi];bTimesX - ymm1
    
    vmulps ymm2, ymm0, [_negFourDivPiSq];cTimesX - ymm2

    vandps ymm3, ymm0, [_positiveSignMask];absX - ymm3
    
    vmulps ymm4, ymm2, ymm3;cTimesXTimesAbsX - ymm4
    
    vaddps ymm5, ymm1, ymm4;y - ymm5
    
    vandps ymm6, ymm5, [_positiveSignMask];absY - ymm6
    vmulps ymm7, ymm5, ymm6;yMultAbsY - ymm7
    vsubps ymm8, ymm7, ymm5;yMultAbsYSubY - ymm8
    vmulps ymm9, ymm8, [_p];pTimesYMultAbsYSubY - ymm9
    vaddps ymm0, ymm9, ymm5;pTimesYMultAbsYSubYAddY
    
    ret