# Write-up — TooMedium

## Objectif

Le but était d’analyser le binaire `TooMedium` afin de retrouver le flag accepté par le programme.

Le binaire demande une entrée de 16 caractères et affiche :

```text
Good Job!
```

si le flag est correct, sinon :

```text
Bad Password!
```

## 1. Identification du binaire

J’ai d’abord vérifié le type du fichier :

```bash
file TooMedium
```

Résultat :

```text
TooMedium: ELF 64-bit LSB executable, x86-64, statically linked, not stripped
```

Le point important ici est que le binaire n’est pas `stripped`. Cela signifie que les symboles sont encore présents dans le fichier.

J’ai donc listé les symboles avec :

```bash
nm TooMedium
```

On retrouve directement des noms très utiles :

```text
000000000040102d t check
0000000000401041 t check.loop
000000000040106e t success
000000000040108f t fail
0000000000402000 d target
0000000000402028 b buf
```

Cela donne déjà une bonne indication : la fonction intéressante est `check`, et les données à comparer sont probablement dans `target`.

## 2. Analyse du désassemblage

J’ai ensuite désassemblé le programme :

```bash
objdump -d -M intel TooMedium
```

Dans `_start`, le programme lit l’entrée utilisateur avec le syscall `read`.

Il accepte :

* exactement 16 caractères ;
* ou 16 caractères suivis d’un retour à la ligne.

La partie intéressante commence dans la fonction `check`.

Le programme charge :

```asm
lea rsi, [rip+0xff4]    ; adresse du buffer utilisateur
lea rdi, [rip+0xfc5]    ; adresse de target
xor rbx, rbx            ; index i = 0
xor r8d, r8d            ; état précédent = 0
```

Puis il entre dans la boucle `check.loop`.

## 3. Compréhension de l’algorithme

Pour chaque caractère, le programme effectue les opérations suivantes :

```asm
movzx eax, BYTE PTR [rsi+rbx]
mov r9d, 0x5a
add r9d, ebx
xor al, r9b
mov ecx, ebx
and ecx, 0x7
inc ecx
rol al, cl
add al, r8b
cmp al, BYTE PTR [rdi+rbx]
jne fail
mov r8b, al
```

En pseudo-code, cela donne :

```python
previous = 0

for i in range(16):
    value = input[i]
    value = value ^ (0x5a + i)
    value = rol8(value, (i & 7) + 1)
    value = (value + previous) & 0xff

    if value != target[i]:
        fail()

    previous = value
```

La protection est donc une transformation caractère par caractère avec un état précédent.

Chaque caractère transformé est comparé avec une table `target`.

## 4. Extraction de la table target

J’ai extrait la section `.data` avec :

```bash
objdump -s -j .data TooMedium
```

On trouve la table `target` à l’adresse `0x402000` :

```text
2c 74 44 c5 a7 aa 3d 5d bb 63 b4 d6 59 d9 de de
```

Ces 16 octets correspondent aux valeurs attendues après transformation.

## 5. Inversion de l’algorithme

L’algorithme est réversible.

Comme la vérification fait :

```python
target[i] = rol8(input[i] ^ (0x5a + i), rotation) + previous
```

on peut inverser chaque étape :

```python
value = target[i] - previous
value = ror8(value, rotation)
input[i] = value ^ (0x5a + i)
```

J’ai donc écrit un petit script Python pour retrouver le flag.

```python
target = bytes.fromhex("2c7444c5a7aa3d5dbb63b4d659d9dede")

def ror8(x, n):
    return ((x >> n) | ((x << (8 - n)) & 0xff)) & 0xff

flag = []
previous = 0

for i, t in enumerate(target):
    rotation = (i & 7) + 1

    value = (t - previous) & 0xff
    value = ror8(value, rotation)
    char = value ^ ((0x5a + i) & 0xff)

    flag.append(char)
    previous = t

print(bytes(flag).decode())
```

Le script retourne :

```text
LIFEISGAMINGzebi
```

## 6. Vérification du flag

J’ai ensuite testé le flag dans le programme :

```bash
printf '%s' 'LIFEISGAMINGzebi' | ./TooMedium
echo $?
```

Résultat :

```text
Good Job!
0
```

Le flag est donc :

```text
LIFEISGAMINGzebi
```

## Conclusion

Le crackme est cassable assez rapidement car :

* le binaire n’est pas `stripped` ;
* les symboles `check`, `success`, `fail` et `target` sont visibles ;
* la table `target` est directement présente dans `.data` ;
* la vérification se fait caractère par caractère ;
* l’algorithme est entièrement réversible.

Une fois la table `target` extraite et la boucle comprise, il suffit d’inverser les opérations pour retrouver le flag.

