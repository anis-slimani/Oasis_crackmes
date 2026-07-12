# Writeup — TooEasy crackme

**Flag :** `M4y837034sy|:-/|`

---

## 1. Reconnaissance initiale

```bash
$ file TooEasy
TooEasy: ELF 64-bit LSB executable, x86-64, statically linked, stripped

$ echo "AAAAAAAAAAAAAAAA" | ./TooEasy
Hello Hackers ! Bad job!
```

Le binaire est **strippé** (pas de symboles), mais reste très court et lisible. Il attend 16 caractères et affiche `Good Job!` ou `Bad job!`.

---

## 2. Analyse statique — objdump

```bash
$ objdump -d -M intel TooEasy
$ objdump -s TooEasy
```

### 2.1 Flux d'exécution

```asm
401000:  write(1, "Hello Hackers ! ", 16)   ; affichage du prompt
401018:  read(0, buf@0x402034, 64)           ; lecture de l'entrée
40102c:  mov r8, rax                         ; r8 = nb bytes lus
; --- strip du '\n' final ---
401035:  dec rcx
401038:  cmp BYTE [rcx+0x402034], 0xa        ; dernier char == '\n' ?
40103f:  jne 0x40104b
401041:  mov BYTE [rcx+0x402034], 0x0        ; remplace '\n' par '\0'
401048:  mov r8, rcx                         ; r8 = longueur sans '\n'
; --- vérification longueur ---
40104b:  cmp r8, 0x10                        ; exactement 16 bytes ?
40104f:  jne bad
```

### 2.2 La boucle de vérification

```asm
401051:  xor  rcx, rcx          ; i = 0
401054:  mov  r9d, 0xa5         ; clé initiale = 0xa5

[boucle]
40105a:  movzx eax, BYTE [rcx+0x402034]  ; al = input[i]
401061:  xor   al, r9b                   ; al = input[i] XOR r9
401064:  cmp   al, BYTE [rcx+0x402010]   ; compare avec ciphertext[i]
40106a:  jne   bad
40106c:  add   r9d, 0x1f                 ; r9 += 0x1f
401070:  and   r9d, 0xff                 ; r9 &= 0xff  (reste sur 8 bits)
401077:  inc   rcx                       ; i++
40107a:  cmp   rcx, 0x10
40107e:  jb    boucle                    ; i < 16 -> continue
```

**Algorithme :** clé glissante (rolling key) initialisée à `0xa5`, incrémentée de `0x1f` à chaque tour :

```
input[i]  XOR  r9  ==  ciphertext[i]
r9  =  (r9 + 0x1f)  &  0xff
```

Inversion directe :

```
flag[i]  =  ciphertext[i]  XOR  r9
```

---

## 3. Extraction du ciphertext

Le ciphertext (16 bytes) se trouve à `0x402010` dans la section `.data` :

```bash
$ objdump -s TooEasy
402010  e8f09a3a 12776f4d a9cfa286 2315780a
```

Bytes : `E8 F0 9A 3A 12 77 6F 4D A9 CF A2 86 23 15 78 0A`

---

## 4. Inversion de l'algorithme

Script Python :

```python
ciphertext = [0xe8, 0xf0, 0x9a, 0x3a, 0x12, 0x77, 0x6f, 0x4d,
              0xa9, 0xcf, 0xa2, 0x86, 0x23, 0x15, 0x78, 0x0a]

key = 0xa5
flag = []
for c in ciphertext:
    flag.append(chr(c ^ key))
    key = (key + 0x1f) & 0xff

print(''.join(flag))   # M4y837034sy|:-/|
```

Calcul détaillé :

| i  | clé (r9) | ciphertext[i] | flag[i] = cipher XOR clé |
|----|----------|---------------|--------------------------|
|  0 | 0xA5     | 0xE8          | 0x4D = **'M'**           |
|  1 | 0xC4     | 0xF0          | 0x34 = **'4'**           |
|  2 | 0xE3     | 0x9A          | 0x79 = **'y'**           |
|  3 | 0x02     | 0x3A          | 0x38 = **'8'**           |
|  4 | 0x21     | 0x12          | 0x33 = **'3'**           |
|  5 | 0x40     | 0x77          | 0x37 = **'7'**           |
|  6 | 0x5F     | 0x6F          | 0x30 = **'0'**           |
|  7 | 0x7E     | 0x4D          | 0x33 = **'3'**           |
|  8 | 0x9D     | 0xA9          | 0x34 = **'4'**           |
|  9 | 0xBC     | 0xCF          | 0x73 = **'s'**           |
| 10 | 0xDB     | 0xA2          | 0x79 = **'y'**           |
| 11 | 0xFA     | 0x86          | 0x7C = **'\|'**          |
| 12 | 0x19     | 0x23          | 0x3A = **':'**           |
| 13 | 0x38     | 0x15          | 0x2D = **'-'**           |
| 14 | 0x57     | 0x78          | 0x2F = **'/'**           |
| 15 | 0x76     | 0x0A          | 0x7C = **'\|'**          |

**Résultat :** `M4y837034sy|:-/|`

---

## 5. Vérification

```bash
$ echo 'M4y837034sy|:-/|' | ./TooEasy
Hello Hackers ! Good Job!
$ echo $?
0
```

---

## 6. Résumé

| Caractéristique     | Détail                                        |
|---------------------|-----------------------------------------------|
| Type de protection  | XOR à clé glissante (rolling key)             |
| Clé initiale        | `0xa5`                                        |
| Mise à jour de clé  | `r9 = (r9 + 0x1f) & 0xff` à chaque position  |
| Longueur du flag    | 16 caractères                                 |
| Outil utilisé       | `objdump` uniquement (analyse statique)       |
| Complexité          | Triviale — invertible sans brute force        |

Le ciphertext et la formule de la clé sont directement lisibles dans le binaire. Une simple inversion suffit à retrouver le flag sans exécuter le programme.
