# Writeup — true_warrior crackme

**Flag :** `H4V3_N0_3N3M135_`

---

## 1. Reconnaissance initiale

```bash
$ file true_warrior
true_warrior: ELF 64-bit LSB executable, x86-64, statically linked, not stripped

$ echo "AAAAAAAAAAAAAAAA" | ./true_warrior
Bad Password!
```

Binaire **non strippé** (symboles présents), attend 16 caractères. Les noms de fonctions (`chk_debug`, `sanitize_buffer`, `verify_checksum`, `fake_success`) sont directement visibles — c'est un premier indice sur la structure du programme.

---

## 2. Vue d'ensemble — structure du programme

```bash
$ objdump -d -M intel true_warrior
```

Le flot d'exécution dans `_start` est le suivant :

```
_start
  │
  ├─► chk_debug()          ← détection de débogueur
  ├─► read() 17 bytes      ← lecture entrée + vérif '\n'
  ├─► init_cache()         ← calcul obfusqué des clés
  ├─► sanitize_buffer()    ← vérifie les indices PAIRS
  ├─► verify_checksum()    ← vérifie les indices IMPAIRS
  │
  ├─ r13 AND r14 == 1 ?
  │     ├─ oui ──► real_success  (Good Job! + exit 0)
  │     └─ non ──► fake_success  (Good Job! + exit 1)  ← piège !
  │
  └─ mauvaise longueur ──► bad (Bad Password! + exit 1)
```

---

## 3. Les pièges et techniques d'obfuscation

Ce crackme cumule plusieurs techniques pour tromper l'analyste.

### 3.1 Anti-debug — `chk_debug`

```asm
401000 <chk_debug>:
    xor  rdi, rdi
    xor  rsi, rsi
    xor  rdx, rdx
    xor  r10, r10
    mov  eax, 0x65       ; syscall 101 = ptrace
    syscall
    cmp  rax, 0x0
    jl   fake_success    ; si tracé -> piège !
    ret
```

Le syscall `ptrace(PTRACE_TRACEME, 0, 0, 0)` (numéro 101 = `0x65`) est utilisé comme **détecteur de débogueur**. Si le programme tourne sous `gdb` ou `strace`, `ptrace` retourne une valeur négative. Dans ce cas, le programme saute directement vers `fake_success` avant même de lire l'entrée — il est impossible de le déboguer normalement sans patcher ce saut.

### 3.2 `fake_success` vs `real_success` — le piège visuel

```asm
40111c <real_success>:
    ; affiche "Good Job!\n"
    ; exit(0)   ← code de retour 0

40113e <fake_success>:
    ; affiche "Good Job!\n"   ← MÊME message !
    ; exit(1)   ← code de retour 1 (échec)
```

Les deux fonctions affichent **exactement le même message** `Good Job!`. La seule différence est le code de retour (`exit(0)` vs `exit(1)`). Un analyste qui teste à la volée sans vérifier `echo $?` peut croire avoir trouvé le bon flag alors qu'il est tombé dans le piège.

Pour tester correctement :

```bash
$ echo 'montest' | ./true_warrior
Good Job!          # <- ne pas se fier à ça seul !
$ echo $?
1                  # 1 = fake_success (mauvais flag)
```

### 3.3 Instructions garbage dans `verify_checksum`

```asm
401070:  movzx  rax, BYTE [rdi+rcx]
401075:  xor    rax, r15
401079:  xor    rax, r12
...
4010c1:  push   rdx
4010c2:  mov    edx, 0xbeef    ← bruit
4010c7:  xor    rdx, rdx       ← bruit
4010ca:  pop    rdx            ← rdx restauré = aucun effet
4010cb:  cmp    rax, rbx
```

Le bloc `push rdx / mov edx,0xbeef / xor rdx,rdx / pop rdx` est un **leurre** : `rdx` est écrasé puis immédiatement restauré par le `pop`. Ces instructions n'ont aucun effet sur la logique. Elles servent à perturber la lecture du code.

### 3.4 Calcul obfusqué des clés dans `init_cache`

Les deux clés ne sont pas stockées en clair. Elles sont calculées par une série d'opérations :

```asm
; Calcul de r15 :
mov  r15d, 0x11     ; r15 = 0x11 = 17
add  r15, 0x0f      ; r15 = 0x20 = 32
shl  r15, 1         ; r15 = 0x40 = 64
add  r15, 0x02      ; r15 = 0x42 = 66
and  r15, 0xff      ; r15 = 0x42

; Calcul de r12 :
mov  r12d, 0x0a     ; r12 = 0x0a = 10
add  r12, 0x0d      ; r12 = 0x17 = 23
and  r12, 0xff      ; r12 = 0x17
```

On trace le calcul à la main :

| Registre | Opération           | Résultat |
|----------|---------------------|----------|
| r15      | 0x11 + 0x0f         | 0x20     |
| r15      | 0x20 << 1           | 0x40     |
| r15      | 0x40 + 0x02         | **0x42** |
| r12      | 0x0a + 0x0d         | **0x17** |

---

## 4. Algorithme de vérification

Les deux fonctions `sanitize_buffer` et `verify_checksum` appliquent le **même algorithme XOR**, mais sur des indices différents.

```
input[i]  XOR  r15  XOR  r12  ==  encoded[i]
```

Puisque XOR est associatif et commutatif :

```
input[i]  XOR  (r15 XOR r12)  ==  encoded[i]
input[i]  XOR  0x55           ==  encoded[i]
```

La **clé combinée** est `0x42 XOR 0x17 = 0x55`.

| Fonction           | Indices traités | Registre résultat |
|--------------------|-----------------|-------------------|
| `sanitize_buffer`  | PAIRS 0,2,...14 | r13               |
| `verify_checksum`  | IMPAIRS 1,3,...15 | r14             |

Le résultat final : `r13 AND r14 == 1` (les deux moitiés doivent passer).

---

## 5. Extraction du ciphertext et inversion

Le ciphertext (16 bytes) est stocké dans `.data` à l'adresse `0x402000` :

```bash
$ objdump -s true_warrior
402000  1d610366 0a1b650a 661b6618 6466600a
```

| i  | encoded[i] | clé (0x55) | flag[i] = encoded XOR 0x55 | parité |
|----|------------|------------|----------------------------|--------|
|  0 | 0x1D       | 0x55       | 0x48 = **'H'**             | pair   |
|  1 | 0x61       | 0x55       | 0x34 = **'4'**             | impair |
|  2 | 0x03       | 0x55       | 0x56 = **'V'**             | pair   |
|  3 | 0x66       | 0x55       | 0x33 = **'3'**             | impair |
|  4 | 0x0A       | 0x55       | 0x5F = **'\_'**            | pair   |
|  5 | 0x1B       | 0x55       | 0x4E = **'N'**             | impair |
|  6 | 0x65       | 0x55       | 0x30 = **'0'**             | pair   |
|  7 | 0x0A       | 0x55       | 0x5F = **'\_'**            | impair |
|  8 | 0x66       | 0x55       | 0x33 = **'3'**             | pair   |
|  9 | 0x1B       | 0x55       | 0x4E = **'N'**             | impair |
| 10 | 0x66       | 0x55       | 0x33 = **'3'**             | pair   |
| 11 | 0x18       | 0x55       | 0x4D = **'M'**             | impair |
| 12 | 0x64       | 0x55       | 0x31 = **'1'**             | pair   |
| 13 | 0x66       | 0x55       | 0x33 = **'3'**             | impair |
| 14 | 0x60       | 0x55       | 0x35 = **'5'**             | pair   |
| 15 | 0x0A       | 0x55       | 0x5F = **'\_'**            | impair |

Script Python :

```python
encoded = [0x1d, 0x61, 0x03, 0x66, 0x0a, 0x1b, 0x65, 0x0a,
           0x66, 0x1b, 0x66, 0x18, 0x64, 0x66, 0x60, 0x0a]

r15 = ((0x11 + 0x0f) << 1) + 0x02  # = 0x42
r12 = (0x0a + 0x0d) & 0xff          # = 0x17
key = r15 ^ r12                      # = 0x55

flag = ''.join(chr(b ^ key) for b in encoded)
print(flag)   # H4V3_N0_3N3M135_
```

---

## 6. Vérification

```bash
$ echo 'H4V3_N0_3N3M135_' | ./true_warrior
Good Job!
$ echo $?
0              ← exit 0 = real_success (pas le piège !)
```

---

## 7. Résumé des protections

| Technique                     | Description                                              |
|-------------------------------|----------------------------------------------------------|
| Anti-debug `ptrace`           | Détecte `gdb`/`strace`, redirige vers `fake_success`     |
| `fake_success`                | Affiche `Good Job!` mais retourne `exit(1)` — piège      |
| Clés calculées à la volée     | `r15` et `r12` obfusquées par des opérations arithmétiques |
| Instructions garbage          | `push/mov/xor/pop` sans effet logique pour gêner la lecture |
| Vérification split pair/impair | Deux fonctions séparées pour chaque moitié du flag       |

Malgré les couches d'obfuscation, le crackme reste **invertible statiquement** : aucune primitive cryptographique n'est utilisée, et la clé XOR finale (`0x55`) est calculable à la main. Une analyse statique avec `objdump` est suffisante — pas besoin de brute force ni d'exécuter le binaire.
