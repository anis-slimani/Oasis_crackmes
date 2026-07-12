# Writeup — xor_rolling crackme

**Flag :** `R3v3rs3_4SI_2026`

---

## 1. Reconnaissance initiale

On commence par identifier le binaire :

```bash
$ file xor_rolling
xor_rolling: ELF 64-bit LSB executable, x86-64, statically linked, not stripped
```

Le binaire est **non strippé** (symboles présents), ce qui facilite l'analyse. On le teste :

```bash
$ echo "AAAAAAAAAAAAAAAA" | ./xor_rolling
Bad Password!
```

Il attend une entrée de 16 caractères et retourne `Good Job!` ou `Bad Password!`.

---

## 2. Analyse statique — objdump

On désassemble avec `objdump` :

```bash
$ objdump -d -M intel xor_rolling
```

Les symboles nous donnent directement les blocs importants : `_start`, `check_loop`, `success`, `fail`.

### 2.1 Vérification de la longueur

```asm
401000:  mov  eax, 0x0          ; syscall read
401005:  mov  edi, 0x0
40100a:  movabs rsi, 0x402028   ; buffer d'entrée
401014:  mov  edx, 0x12         ; lit jusqu'à 18 bytes
401019:  syscall
40101b:  cmp  rax, 0x11         ; vérifie que 17 bytes ont été lus
40101f:  jne  fail
401021:  cmp  BYTE [0x402038], 0xa  ; vérifie que le 17e byte est '\n'
401029:  jne  fail
```

Le programme attend **exactement 16 caractères suivis d'un `\n`** (17 bytes au total).

### 2.2 La boucle de vérification

```asm
40102e <check_loop>:
    cmp  rcx, 0x10          ; 16 itérations (i = 0..15)
    je   success

    mov  al, [rcx+0x402028] ; al  = input[i]
    mov  bl, cl             ; bl  = i
    add  bl, 0x42           ; bl  = i + 0x42  (clé glissante)
    xor  al, bl             ; al  = input[i] XOR (i + 0x42)
    cmp  al, [rcx+0x402018] ; compare avec ciphertext[i]
    jne  fail

    inc  rcx
    jmp  check_loop
```

**Algorithme :** pour chaque octet `i` (0 à 15) :

```
input[i]  XOR  (i + 0x42)  ==  ciphertext[i]
```

La clé est **glissante (rolling)** : elle vaut `i + 0x42`, donc elle change à chaque position.

---

## 3. Extraction du ciphertext

On dump la section `.data` :

```bash
$ objdump -s xor_rolling
```

```
402000  476f6f64 204a6f62 210a4261 64205061  Good Job!.Bad Pa
402010  7373776f 7264210a 10703276 34347b16  ssword!..p2v44{.
402020  7e180512 7c7f6267                    ~...|.bg
```

Les données pertinentes :

| Adresse    | Contenu                           | Rôle              |
|------------|-----------------------------------|-------------------|
| `0x402000` | `Good Job!\n`                     | Message succès    |
| `0x40200a` | `Bad Password!\n`                 | Message échec     |
| `0x402018` | `10 70 32 76 34 34 7b 16 7e 18 05 12 7c 7f 62 67` | Ciphertext (16 bytes) |
| `0x402028` | buffer d'entrée (18 bytes)        | Input utilisateur |

---

## 4. Inversion de l'algorithme

Puisque XOR est **symétrique** (`A XOR B XOR B = A`), on inverse directement :

```
flag[i] = ciphertext[i]  XOR  (i + 0x42)
```

Script Python :

```python
ciphertext = [0x10, 0x70, 0x32, 0x76, 0x34, 0x34, 0x7b, 0x16,
              0x7e, 0x18, 0x05, 0x12, 0x7c, 0x7f, 0x62, 0x67]

flag = ''.join(chr(b ^ (i + 0x42)) for i, b in enumerate(ciphertext))
print(flag)
```

Calcul détaillé par position :

| i  | clé = i+0x42 | ciphertext[i] | flag[i] = ciphertext XOR clé |
|----|--------------|---------------|-------------------------------|
|  0 | 0x42 ('B')   | 0x10          | 0x52 = **'R'**                |
|  1 | 0x43 ('C')   | 0x70          | 0x33 = **'3'**                |
|  2 | 0x44 ('D')   | 0x32          | 0x76 = **'v'**                |
|  3 | 0x45 ('E')   | 0x76          | 0x33 = **'3'**                |
|  4 | 0x46 ('F')   | 0x34          | 0x72 = **'r'**                |
|  5 | 0x47 ('G')   | 0x34          | 0x73 = **'s'**                |
|  6 | 0x48 ('H')   | 0x7B          | 0x33 = **'3'**                |
|  7 | 0x49 ('I')   | 0x16          | 0x5F = **'\_'**               |
|  8 | 0x4A ('J')   | 0x7E          | 0x34 = **'4'**                |
|  9 | 0x4B ('K')   | 0x18          | 0x53 = **'S'**                |
| 10 | 0x4C ('L')   | 0x05          | 0x49 = **'I'**                |
| 11 | 0x4D ('M')   | 0x12          | 0x5F = **'\_'**               |
| 12 | 0x4E ('N')   | 0x7C          | 0x32 = **'2'**                |
| 13 | 0x4F ('O')   | 0x7F          | 0x30 = **'0'**                |
| 14 | 0x50 ('P')   | 0x62          | 0x32 = **'2'**                |
| 15 | 0x51 ('Q')   | 0x67          | 0x36 = **'6'**                |

**Résultat :** `R3v3rs3_4SI_2026`

---

## 5. Vérification

```bash
$ echo 'R3v3rs3_4SI_2026' | ./xor_rolling
Good Job!
$ echo $?
0
```

---

## 6. Résumé de la protection

| Caractéristique       | Détail                                      |
|-----------------------|---------------------------------------------|
| Type de chiffrement   | XOR à clé glissante (rolling XOR)           |
| Clé à la position i   | `i + 0x42`                                  |
| Longueur du flag      | 16 caractères                               |
| Complexité            | Triviale — invertible sans brute force      |
| Outil utilisé         | `objdump` uniquement (analyse statique)     |

Le flag n'est **pas protégé cryptographiquement** : le ciphertext et la formule de clé sont directement lisibles dans le binaire. Une simple inversion algébrique suffit à retrouver le flag, sans exécuter le programme ni tester de combinaisons.
