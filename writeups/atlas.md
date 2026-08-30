# Write-up — atlas

## Objectif

Le but est d’analyser le binaire `atlas` et de retrouver les 16 caractères acceptés par le programme.

Le programme affiche :

```text
Acces autorise.
```

si le mot de passe est correct.

## 1. Identification du binaire

Je commence par vérifier le type du fichier :

```bash
file 'atlas'
```

Résultat :

```text
atlas: ELF 64-bit LSB executable, x86-64, statically linked, stripped
```

Le binaire est `stripped`.

```bash
nm 'atlas'
```

Résultat :

```text
nm: atlas: no symbols
```

Il faut donc regarder le désassemblage :

```bash
objdump -d -M intel 'atlas'
```

## 2. Début du programme

Au début, on retrouve :

```asm
mov eax, 0x65
xor rdi, rdi
xor rsi, rsi
xor rdx, rdx
xor r10, r10
syscall
test rax, rax
js 0x401320
```

Le syscall `0x65` correspond à `ptrace`.

Le programme utilise donc un petit anti-debug avec :

```c
ptrace(PTRACE_TRACEME, 0, NULL, NULL);
```

Ensuite le programme demande :

```text
Saisir le mot de passe (16 caracteres):
```

Il accepte 16 caractères, avec éventuellement un retour à la ligne après.

Il vérifie aussi que tous les caractères sont imprimables :

```asm
cmp al, 0x21
jb  fail
cmp al, 0x7e
ja  fail
```

## 3. La partie intéressante : une petite VM

En continuant le désassemblage, on arrive sur une boucle qui lit les données 3 octets par 3 octets :

```asm
movzx r8d, BYTE PTR [r12+rbp]
movzx r9d, BYTE PTR [r12+rbp+1]
movzx r10d, BYTE PTR [r12+rbp+2]
add rbp, 3
```

Chaque instruction de la VM est donc composée de :

```text
opcode | argument 1 | argument 2
```

Le programme interprète ensuite l’opcode pour savoir quoi faire.

Je n’ai pas eu besoin de refaire toute la VM pour trouver le flag. Les instructions utiles permettent surtout de :

* lire un caractère de l’entrée ;
* lire une valeur dans une table ;
* faire un XOR ;
* faire une addition ;
* lire ou écrire dans un buffer ;
* comparer une valeur ;
* faire des sauts.

Le bytecode se trouve dans `.rodata`.

```bash
objdump -s -j .rodata 'atlas'
```

En suivant les instructions de la VM, la vérification peut être résumée en trois étapes.

## 4. Première transformation

La première boucle fait :

```python
for i in range(16):
    buffer[i] = input[i] ^ table1[i]
```

La première table vaut :

```text
aa 98 b9 82 c1 ce 62 2b 30 7f 96 ba a0 30 26 c7
```

## 5. Deuxième transformation

Ensuite, à partir de l’index 1, chaque octet dépend de l’octet précédent :

```python
for i in range(1, 16):
    buffer[i] = ((buffer[i] ^ buffer[i - 1]) + i) & 0xff
```

La transformation est faite directement dans le même buffer.

Donc au moment de calculer `buffer[i]`, la valeur `buffer[i - 1]` a déjà été modifiée.

## 6. Troisième transformation

Une dernière boucle fait un XOR avec une deuxième table :

```python
for i in range(16):
    buffer[i] ^= table2[i]
```

La table vaut :

```text
ee 7d d6 ce c6 2a e4 fa c2 4b 49 dd ac be eb 12
```

À la fin, le buffer est comparé avec :

```text
13 57 20 89 3d ae 51 06 03 bb 2e 4a e3 a6 8a c5
```

Donc le fonctionnement général est :

```python
for i in range(16):
    buffer[i] = input[i] ^ table1[i]

for i in range(1, 16):
    buffer[i] = ((buffer[i] ^ buffer[i - 1]) + i) & 0xff

for i in range(16):
    buffer[i] ^= table2[i]

if bytes(buffer) == target:
    success()
else:
    fail()
```

## 7. Inversion

Les opérations peuvent être faites dans l’ordre inverse.

On commence par retirer le dernier XOR :

```python
stage2[i] = target[i] ^ table2[i]
```

Ensuite on annule la deuxième transformation :

```python
stage1[0] = stage2[0]

for i in range(1, 16):
    stage1[i] = ((stage2[i] - i) & 0xff) ^ stage2[i - 1]
```

Et pour finir, on retire le premier XOR :

```python
input[i] = stage1[i] ^ table1[i]
```

## 8. Script de résolution

J’ai utilisé ce script :

```python
table1 = bytes.fromhex(
    "aa 98 b9 82 c1 ce 62 2b "
    "30 7f 96 ba a0 30 26 c7"
)

table2 = bytes.fromhex(
    "ee 7d d6 ce c6 2a e4 fa "
    "c2 4b 49 dd ac be eb 12"
)

target = bytes.fromhex(
    "13 57 20 89 3d ae 51 06 "
    "03 bb 2e 4a e3 a6 8a c5"
)

stage2 = [
    target[i] ^ table2[i]
    for i in range(16)
]

stage1 = [0] * 16
stage1[0] = stage2[0]

for i in range(1, 16):
    stage1[i] = (
        ((stage2[i] - i) & 0xff)
        ^ stage2[i - 1]
    )

flag = bytes(
    stage1[i] ^ table1[i]
    for i in range(16)
)

print(flag.decode())
```

Résultat :

```text
WLg0qJIkuY;Qttmn
```

## 9. Vérification

Je teste le flag dans le programme :

```bash
printf '%s' 'WLg0qJIkuY;Qttmn' | './atlas'
echo $?
```

Résultat :

```text
Saisir le mot de passe (16 caracteres): Acces autorise.
0
```

Le flag est donc :

```text
WLg0qJIkuY;Qttmn
```

## Conclusion

Le point principal de ce crackme est la petite machine virtuelle utilisée pour cacher la vérification.

Une fois le bytecode suivi, la logique réelle reste assez simple : deux XOR avec des tables et une transformation qui dépend de l’octet précédent.

Il suffit ensuite de refaire les opérations dans l’ordre inverse pour retrouver le flag.
