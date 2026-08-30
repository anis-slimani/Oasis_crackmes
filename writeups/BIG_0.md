# Write-up — BIG_0

## Objectif

Le but est de retrouver l’entrée de 16 caractères acceptée par le binaire `BIG_0`.

Si l’entrée est correcte, le programme affiche :

```text
Good Job!
```

Sinon :

```text
Bad Password!
```

## 1. Identification du binaire

Je commence par regarder le type du fichier :

```bash
file 'BIG_0'
```

Résultat :

```text
BIG_0: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, stripped
```

Le binaire est `stripped`, donc les noms de fonctions ne sont pas présents.

```bash
nm 'BIG_0'
```

Résultat :

```text
nm: BIG_0: no symbols
```

Il faut donc regarder directement le désassemblage.

```bash
objdump -d -M intel 'BIG_0'
```

## 2. Vérifications au début du programme

Au début du programme, on retrouve :

```asm
mov eax, 0x65
xor rdi, rdi
xor rsi, rsi
xor rdx, rdx
xor r10, r10
syscall
```

Le syscall `0x65` correspond à `ptrace`.

Le programme utilise donc :

```c
ptrace(PTRACE_TRACEME, 0, NULL, NULL);
```

C’est une protection anti-debug simple.

Le programme utilise aussi `clock_gettime` avant et après la saisie et vérifie que trop de temps ne s’est pas écoulé.

On trouve notamment :

```asm
sub rax, r14
cmp rax, 0x3
ja  fail
```

L’entrée doit également faire exactement 16 caractères.

## 3. Recherche dans les données

Avec :

```bash
strings -a 'BIG_0'
```

on trouve plusieurs chaînes :

```text
AES_CTR_mode_key!
chacha20_stream!!
salsa20_nonce_ok!
```

Au début, elles peuvent faire penser que le programme utilise AES, ChaCha20 ou Salsa20.

En regardant le code, on voit finalement que ces chaînes ne sont pas utilisées pour vérifier le flag.

La vraie partie intéressante est une boucle qui initialise une table de 256 octets :

```asm
xor rcx, rcx

loop:
    mov BYTE PTR [rdi+rcx], cl
    inc rcx
    cmp rcx, 0x100
    jb loop
```

On obtient donc :

```text
S[0] = 0
S[1] = 1
...
S[255] = 255
```

Juste après, le programme mélange cette table avec une clé.

On retrouve une boucle du type :

```asm
movzx eax, BYTE PTR [rdi+rcx]
add r8d, eax

mov edx, ecx
and edx, 0x7
movzx edx, BYTE PTR [rsi+rdx]
add r8d, edx
and r8d, 0xff
```

Le `and edx, 0x7` montre que la clé fait 8 octets.

Cette partie correspond au KSA de RC4 :

```python
j = 0

for i in range(256):
    j = (j + S[i] + key[i % 8]) & 0xff
    S[i], S[j] = S[j], S[i]
```

Ensuite une deuxième boucle génère 16 octets de keystream avec le PRGA de RC4.

## 4. Extraction de la clé et de la cible

J’affiche la section `.data` :

```bash
objdump -s -j .data 'BIG_0'
```

On obtient au début :

```text
402000 7b3fa2e5 194c8df1 001eb780 e2396b1c
402010 571cabb1 0032adf8 c9e1e1ea aec4e1ec
```

La clé RC4 est constituée des 8 premiers octets :

```text
7b 3f a2 e5 19 4c 8d f1
```

La cible utilisée pour la comparaison est :

```text
00 1e b7 80 e2 39 6b 1c 57 1c ab b1 00 32 ad f8
```

Le programme génère le keystream RC4 puis fait :

```python
input[i] ^ keystream[i]
```

et compare le résultat avec la cible.

La vérification est donc :

```python
input[i] ^ keystream[i] == target[i]
```

## 5. Inversion

Le XOR est réversible.

On peut donc retrouver l’entrée avec :

```python
input[i] = target[i] ^ keystream[i]
```

J’ai utilisé ce script :

```python
key = bytes.fromhex(
    "7b 3f a2 e5 19 4c 8d f1"
)

target = bytes.fromhex(
    "00 1e b7 80 e2 39 6b 1c "
    "57 1c ab b1 00 32 ad f8"
)

S = list(range(256))
j = 0

for i in range(256):
    j = (j + S[i] + key[i % 8]) & 0xff
    S[i], S[j] = S[j], S[i]

stream = []
i = 0
j = 0

for _ in range(16):
    i = (i + 1) & 0xff
    j = (j + S[i]) & 0xff
    S[i], S[j] = S[j], S[i]
    stream.append(S[(S[i] + S[j]) & 0xff])

flag = bytes(
    target[i] ^ stream[i]
    for i in range(16)
)

print(flag.decode())
```

Résultat :

```text
Rc4_Str34m_K3y!!
```

## 6. Vérification

Je teste ensuite le flag directement :

```bash
printf '%s' 'Rc4_Str34m_K3y!!' | ./'BIG_0'
echo $?
```

Résultat :

```text
Good Job!
0
```

Le flag est donc :

```text
Rc4_Str34m_K3y!!
```

## Conclusion

Le plus important dans ce crackme était d’ignorer les fausses pistes présentes dans les chaînes et de reconnaître RC4 dans le désassemblage.

Une fois la clé et la cible récupérées dans `.data`, il suffit de reproduire RC4 puis d’annuler le XOR pour retrouver les 16 caractères.
