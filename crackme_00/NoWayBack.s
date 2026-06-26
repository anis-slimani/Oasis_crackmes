; -----------------------------------------------------------------------------
; crackme.asm - Linux x86-64 / NASM / no libc
;
; Validation model:
;   - exactly 16 input bytes (a trailing LF from a terminal is accepted)
;   - SHA-256 is computed in-process, using a single padded 512-bit block
;   - only a split/XOR-masked digest is embedded; the plaintext flag is absent
;
; Build:
;   nasm -f elf64 crackme.asm -o crackme.o
;   ld -o crackme crackme.o
; -----------------------------------------------------------------------------

default rel

global _start

section .rodata
    prompt      db "Enter the 16-character flag: "
    prompt_len  equ $ - prompt

    good_msg    db "Good Job!", 10
    good_len    equ $ - good_msg

    bad_msg     db "Bad Password!", 10
    bad_len     equ $ - bad_msg

    ; SHA-256 round constants.
    align 16
k256:
    dd 0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5
    dd 0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5
    dd 0xd807aa98,0x12835b01,0x243185be,0x550c7dc3
    dd 0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174
    dd 0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc
    dd 0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da
    dd 0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7
    dd 0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967
    dd 0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13
    dd 0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85
    dd 0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3
    dd 0xd192e819,0xd6990624,0xf40e3585,0x106aa070
    dd 0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5
    dd 0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3
    dd 0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208
    dd 0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2

    ; SHA-256("<private 16-byte flag>") is not stored directly.
    ; expected_word[i] = digest_a[i] XOR digest_b[i]
    ; Keeping the digest split does not make SHA-256 stronger; it only avoids an
    ; immediately visible contiguous 32-byte signature in the binary.
    align 16
digest_a:
    dd 0x23c96d43,0x5f29e219,0x97a8252d,0xc816dfea
    dd 0xc11e6e68,0x1df947b5,0xb5d93774,0xaeaa356c

digest_b:
    dd 0x61c78e7f,0xbac70bf3,0xe7296ad3,0x619a905d
    dd 0x287077b6,0x1b860e28,0x551823b0,0x72d811b6

section .bss
    align 16
input_buf   resb 32
block_buf   resb 64
schedule    resd 64
hash_out    resd 8

section .text

_start:
    ; write(1, prompt, prompt_len)
    mov eax, 1
    mov edi, 1
    lea rsi, [rel prompt]
    mov edx, prompt_len
    syscall

    ; read(0, input_buf, 32)
    xor eax, eax
    xor edi, edi
    lea rsi, [rel input_buf]
    mov edx, 32
    syscall

    test rax, rax
    jle .fail

    ; Accept exactly 16 raw bytes, or 16 bytes followed by one LF.
    lea rbx, [rel input_buf]
    cmp rax, 16
    je .length_ok
    cmp rax, 17
    jne .fail
    cmp byte [rbx + 16], 10
    jne .fail

.length_ok:
    ; Restrict to printable non-space ASCII. This preserves a large search space
    ; while preventing invisible/control-byte flags.
    xor ecx, ecx
.check_printable:
    movzx eax, byte [rbx + rcx]
    cmp eax, 0x21
    jb .fail
    cmp eax, 0x7e
    ja .fail
    inc ecx
    cmp ecx, 16
    jb .check_printable

    ; Build the one-block SHA-256 message:
    ; bytes 0..15 = input, byte 16 = 0x80, bytes 17..62 = 0,
    ; byte 63 = 0x80 (128-bit message length, big-endian).
    lea rdi, [rel block_buf]
    xor eax, eax
    mov ecx, 8
    rep stosq

    lea rsi, [rel input_buf]
    lea rdi, [rel block_buf]
    mov ecx, 16
    rep movsb
    lea rbx, [rel block_buf]
    mov byte [rbx + 16], 0x80
    mov byte [rbx + 63], 0x80

    ; W[0..15] = big-endian words from the input block.
    lea rbx, [rel block_buf]
    lea rbp, [rel schedule]
    xor ecx, ecx
.load_words:
    mov eax, dword [rbx + rcx*4]
    bswap eax
    mov dword [rbp + rcx*4], eax
    inc ecx
    cmp ecx, 16
    jb .load_words

    ; Expand W[16..63].
    mov ecx, 16
.expand_words:
    ; s0 = ROR7(x) XOR ROR18(x) XOR (x >> 3), x = W[i-15]
    mov eax, dword [rbp + rcx*4 - 60]
    mov edx, eax
    ror eax, 7
    ror edx, 18
    xor eax, edx
    mov edx, dword [rbp + rcx*4 - 60]
    shr edx, 3
    xor eax, edx
    mov esi, eax

    ; s1 = ROR17(x) XOR ROR19(x) XOR (x >> 10), x = W[i-2]
    mov eax, dword [rbp + rcx*4 - 8]
    mov edx, eax
    ror eax, 17
    ror edx, 19
    xor eax, edx
    mov edx, dword [rbp + rcx*4 - 8]
    shr edx, 10
    xor eax, edx

    add eax, dword [rbp + rcx*4 - 28] ; W[i-7]
    add eax, esi                             ; s0
    add eax, dword [rbp + rcx*4 - 64] ; W[i-16]
    mov dword [rbp + rcx*4], eax

    inc ecx
    cmp ecx, 64
    jb .expand_words

    ; Initial SHA-256 state: a..h in r8d..r15d.
    mov r8d,  0x6a09e667
    mov r9d,  0xbb67ae85
    mov r10d, 0x3c6ef372
    mov r11d, 0xa54ff53a
    mov r12d, 0x510e527f
    mov r13d, 0x9b05688c
    mov r14d, 0x1f83d9ab
    mov r15d, 0x5be0cd19

    lea rsi, [rel k256]
    xor ecx, ecx
.sha_round:
    ; Sigma1(e) = ROR6(e) XOR ROR11(e) XOR ROR25(e)
    mov eax, r12d
    ror eax, 6
    mov edx, r12d
    ror edx, 11
    xor eax, edx
    mov edx, r12d
    ror edx, 25
    xor eax, edx

    ; Ch(e,f,g) = (e & f) XOR (~e & g)
    ; Equivalent: ((f XOR g) & e) XOR g
    mov ebx, r13d
    xor ebx, r14d
    and ebx, r12d
    xor ebx, r14d

    ; T1 = h + Sigma1(e) + Ch + K[i] + W[i]
    add ebx, r15d
    add ebx, eax
    add ebx, dword [rsi + rcx*4]
    add ebx, dword [rbp + rcx*4]

    ; Sigma0(a) = ROR2(a) XOR ROR13(a) XOR ROR22(a)
    mov edi, r8d
    ror edi, 2
    mov edx, r8d
    ror edx, 13
    xor edi, edx
    mov edx, r8d
    ror edx, 22
    xor edi, edx

    ; Maj(a,b,c) = ((a XOR b) & c) XOR (a & b)
    mov edx, r8d
    xor edx, r9d
    and edx, r10d
    mov eax, r8d
    and eax, r9d
    xor edx, eax
    add edi, edx                 ; T2

    ; Rotate working variables.
    mov r15d, r14d               ; h = g
    mov r14d, r13d               ; g = f
    mov r13d, r12d               ; f = e
    mov eax, r11d
    add eax, ebx
    mov r12d, eax                ; e = d + T1
    mov r11d, r10d               ; d = c
    mov r10d, r9d                ; c = b
    mov r9d, r8d                 ; b = a
    add ebx, edi
    mov r8d, ebx                 ; a = T1 + T2

    inc ecx
    cmp ecx, 64
    jb .sha_round

    ; Add the initial state to the compressed state.
    add r8d,  0x6a09e667
    add r9d,  0xbb67ae85
    add r10d, 0x3c6ef372
    add r11d, 0xa54ff53a
    add r12d, 0x510e527f
    add r13d, 0x9b05688c
    add r14d, 0x1f83d9ab
    add r15d, 0x5be0cd19

    lea rbx, [rel hash_out]
    mov dword [rbx +  0], r8d
    mov dword [rbx +  4], r9d
    mov dword [rbx +  8], r10d
    mov dword [rbx + 12], r11d
    mov dword [rbx + 16], r12d
    mov dword [rbx + 20], r13d
    mov dword [rbx + 24], r14d
    mov dword [rbx + 28], r15d

    ; Constant-time-ish full digest comparison: accumulate every difference.
    ; No early exit reveals which word first differs.
    lea rbx, [rel digest_a]
    lea rdx, [rel digest_b]
    lea rsi, [rel hash_out]
    xor r15d, r15d
    xor ecx, ecx
.compare_digest:
    mov eax, dword [rbx + rcx*4]
    xor eax, dword [rdx + rcx*4]
    xor eax, dword [rsi + rcx*4]
    or r15d, eax
    inc ecx
    cmp ecx, 8
    jb .compare_digest

    ; Indirect final dispatch. It is deliberately still patchable: the contest
    ; requires a crack that can modify this binary to accept a universal flag.
    lea rax, [rel .success]
    lea rdx, [rel .fail]
    test r15d, r15d
    cmovne rax, rdx
    jmp rax

.success:
    mov eax, 1
    mov edi, 1
    lea rsi, [rel good_msg]
    mov edx, good_len
    syscall

    ; Keep the successful sys_exit(0) sequence simple and stable.
    mov eax, 60
    xor edi, edi
    syscall

.fail:
    mov eax, 1
    mov edi, 1
    lea rsi, [rel bad_msg]
    mov edx, bad_len
    syscall

    mov eax, 60
    mov edi, 1
    syscall
