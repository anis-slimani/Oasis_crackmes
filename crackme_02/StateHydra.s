; StateHydra.s
; x86-64 Linux NASM crackme
; Build: nasm -f elf64 StateHydra.s -o StateHydra.o && ld -s -o StateHydra StateHydra.o
;
; Technique: input-dependent state machine with mixed boolean/arithmetic transformations.
; No libc, no external libraries, no standard hash, no custom VM/bytecode.

BITS 64

%define SYS_read  0
%define SYS_write 1
%define SYS_exit  60
%define STDIN     0
%define STDOUT    1

section .text
global _start

_start:
    mov eax, SYS_write
    mov edi, STDOUT
    lea rsi, [rel msg_prompt]
    mov edx, msg_prompt_len
    syscall

    mov eax, SYS_read
    xor edi, edi
    lea rsi, [rel input_buf]
    mov edx, 64
    syscall

    cmp rax, 1
    jl .bad_exit

    mov rcx, rax
    lea rbx, [rel input_buf]
    mov dl, byte [rbx + rcx - 1]
    cmp dl, 10
    jne .len_ready
    dec rcx

.len_ready:
    cmp rcx, 16
    jne .bad_exit

    ; Load 16 user bytes into a 256-bit internal state.
    mov r12, [rbx]
    mov r13, [rbx + 8]
    mov rax, 0x7D9A1F0B3C5E8A42
    xor r12, rax
    mov rax, 0xC13FA9E274B06D58
    xor r13, rax

    mov r14, r12
    rol r14, 17
    xor r14, r13
    mov rax, 0xA5A5C3C35A5A3C3C
    xor r14, rax

    mov r15, r13
    ror r15, 11
    add r15, r12
    mov rax, 0x1F2E3D4C5B6A7988
    add r15, rax

    xor ebp, ebp
    lea r11, [rel round_keys]

.round_loop:
    mov r8, [r11 + rbp*8]

    mov r10, r12
    xor r10, r13
    xor r10, r8
    xor r10, rbp
    and r10, 7

    cmp r10, 0
    je .case0
    cmp r10, 1
    je .case1
    cmp r10, 2
    je .case2
    cmp r10, 3
    je .case3
    cmp r10, 4
    je .case4
    cmp r10, 5
    je .case5
    cmp r10, 6
    je .case6
    jmp .case7

.case0:
    mov rax, r13
    xor rax, r8
    rol rax, 7
    add rax, r14
    xor r12, rax

    add r15, r12
    add r15, r8
    ror r15, 13

    mov rax, 0x9E3779B185EBCA87
    imul r13, rax
    add r13, r15
    jmp .next_round

.case1:
    mov rax, r12
    add rax, r8
    rol rax, 19
    xor r14, rax

    xor r13, r14
    ror r13, 11

    mov rax, r13
    xor rax, r8
    add r15, rax
    mov rax, 0xC2B2AE3D27D4EB4F
    imul r15, rax
    jmp .next_round

.case2:
    mov rax, r15
    xor rax, r8
    add r12, rax
    mov rax, 0x165667B19E3779F9
    imul r12, rax

    add r14, r12
    rol r14, 23

    mov rax, r15
    ror rax, 17
    xor r13, rax
    jmp .next_round

.case3:
    mov rax, r14
    add rax, r8
    rol rax, 31
    xor r15, rax

    xor r12, r15
    ror r12, 5

    add r14, r13
    add r14, r8
    mov rax, 0xD6E8FEB86659FD93
    imul r14, rax
    jmp .next_round

.case4:
    mov rax, r12
    xor rax, r14
    xor rax, r8
    rol rax, 3
    add r13, rax

    add r15, r13
    ror r15, 29

    mov rax, r15
    add rax, r8
    xor r12, rax
    jmp .next_round

.case5:
    mov rax, r13
    xor rax, r8
    ror rax, 37
    add r14, rax

    add r12, r14
    rol r12, 7

    mov rax, r12
    mov rdx, 0xA24BAED4963EE407
    imul rax, rdx
    xor r15, rax
    jmp .next_round

.case6:
    mov rax, r8
    rol rax, 11
    xor rax, r13
    add r12, rax

    mov rax, r14
    add rax, r8
    ror rax, 17
    xor r13, rax

    xor r14, r15
    rol r14, 13

    add r15, r12
    jmp .next_round

.case7:
    mov rax, r12
    xor rax, r8
    rol rax, 41
    add r15, rax
    mov rax, 0x9FB21C651E98DF25
    imul r15, rax

    mov rax, r15
    add rax, r13
    ror rax, 23
    xor r14, rax

    mov rax, r14
    xor rax, r8
    add r13, rax

.next_round:
    inc ebp
    cmp ebp, 96
    jb .round_loop

    ; Reconstruct the expected final state and compare without early exit.
    mov rax, [rel target_a + 0]
    xor rax, [rel target_b + 0]
    xor r12, rax

    mov rax, [rel target_a + 8]
    xor rax, [rel target_b + 8]
    xor r13, rax

    mov rax, [rel target_a + 16]
    xor rax, [rel target_b + 16]
    xor r14, rax

    mov rax, [rel target_a + 24]
    xor rax, [rel target_b + 24]
    xor r15, rax

    mov rax, r12
    or rax, r13
    or rax, r14
    or rax, r15
    test rax, rax
    jz .good_exit

.bad_exit:
    mov eax, SYS_write
    mov edi, STDOUT
    lea rsi, [rel msg_bad]
    mov edx, msg_bad_len
    syscall

    mov edi, 1
    jmp .exit_now

.good_exit:
    mov eax, SYS_write
    mov edi, STDOUT
    lea rsi, [rel msg_ok]
    mov edx, msg_ok_len
    syscall

    xor edi, edi

.exit_now:
    mov eax, SYS_exit
    syscall

section .rodata
msg_prompt: db "Enter the 16-character flag: "
msg_prompt_len equ $ - msg_prompt
msg_ok:     db "Good Job!", 10
msg_ok_len  equ $ - msg_ok
msg_bad:    db "Bad Password!", 10
msg_bad_len equ $ - msg_bad

align 8
round_keys:
    dq 0x63CFC62A2B097592, 0xDC0746B419466AEC, 0x08264674F98AA19E, 0x3CA4EB47B26DE7AC
    dq 0xA5B384AD339CFCC3, 0x08F720D059892BC4, 0xFE6675C92D60F3DF, 0x1D59C7B9C3A56969
    dq 0xEA5685B6014A22C9, 0x3935C47EC47E016D, 0xF72314EF3D87AE57, 0xE2C2311BA18CFD93
    dq 0x509D7011D7BC72C9, 0x4CD89B9538C27512, 0xA4E38806108A16A3, 0x5A469FB3420A4216
    dq 0x5087CFEA06CFAE9E, 0x76EFEB82D49FAD30, 0xA21F990415830CDD, 0xD3CF31C5DD26C237
    dq 0xB956E4E473A0297F, 0xE297A7E448A0894C, 0x779DA6821D493912, 0xD71574055724395D
    dq 0x797E22F607982BAE, 0xFEC040B03A7F1E41, 0x1F258FAD67F64E49, 0x4EDCDDD434469277
    dq 0xA2053EBD77CB8B08, 0x77BF226305265856, 0x6DE7291EAAA3D085, 0x96D7536EA745DFFE
    dq 0xF9C6680E94247B49, 0xC88219FC9CF0493E, 0x1E31F2C96F41C928, 0x6CFA87EDE9C1F270
    dq 0xA86D434537F8A23A, 0xA15F376D2BEF48D9, 0x056617E9F8F42D36, 0xF24B9093554CD786
    dq 0x62D56DAFE2BB1E59, 0xB06DE4502F883955, 0xBE4C8D8146C0D0AB, 0x83E66C7205D6AF78
    dq 0x78005FA8D605DED0, 0x4B211F6233E98863, 0x10451D9D286AB638, 0x5BBD90AEA8B4B277
    dq 0x7F7AAEEA56D1839A, 0x65D4894ED4243013, 0x6DD3AA78170E9AF1, 0xD46A9444D3799968
    dq 0x659A245A5B481F0D, 0x15652888D3BBC8DF, 0x8B73FDDBCE64BEFA, 0x0BFCA26E4C5FB77A
    dq 0xC4849A2EAE8581B2, 0xC22DD397E260CD58, 0x92F0919F78F49D90, 0xECDD8449D5E796DF
    dq 0x7A094A53DA9A2011, 0x64FF8E701AC6665E, 0x9A2718AC8690427A, 0x03FEA5F1FFC6CDE0
    dq 0x19B6560A01AD4034, 0x896A2EE68EDB277A, 0x6E8E7574571E76E7, 0x4F248C2C5923DFB3
    dq 0xC6A7195479D02D29, 0xB78C342F689ED1CD, 0x3FA86FBC793BCD5C, 0xC47C1E8411E1296D
    dq 0x5F461BDE38862E3C, 0x15AA1C31A6D3E5D1, 0xB59FFEAC43EB9BCF, 0xB33797B80682FB8E
    dq 0x824247E1303DF497, 0xBDA0B7E1A9BD1089, 0xA3158AB71D99CD18, 0xC25741ECD2AC9FB2
    dq 0x7173B3D306F6481F, 0x5FF080F221B0EC33, 0xB80D9936EF1A2177, 0x5BCF5EE0AFED6941
    dq 0x3367CDFC6E91746F, 0x628F06DC67CD8D10, 0x9B5D29D3387D8FE0, 0x411333C0F55727A3
    dq 0xE4F21DEF307BD64A, 0x654F7E53D53EC6A0, 0x6D1C6352B72B2DC1, 0xAB6B2E6636AB6A4B
    dq 0xB8AC5A495D67C6BA, 0x508634631E16ACB4, 0xA85BAF8D6401DFC2, 0x56543E941681858E

target_a:
    dq 0x2D0F28C7E7E786B2, 0x75856F745165F252, 0x8674BBC2735955AF, 0x5C1D49A70D26949A
target_b:
    dq 0xFD967D7F5F09716A, 0x84A56BA110D55D6A, 0xCFA5C5E379FF99B4, 0xD387EB917D9B5A4F

section .bss
input_buf: resb 64
