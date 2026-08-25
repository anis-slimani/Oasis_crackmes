# TableLabyrinth

## Description

`TableLabyrinth` est un crackme Linux x86-64 écrit en assembleur NASM.

Il attend un flag de 16 caractères exactement. Le programme affiche `Good Job!` et quitte avec le code `0` si le flag est correct. Sinon, il affiche `Bad Password!` et quitte avec le code `1`.

## Compilation

```bash
nasm -f elf64 TableLabyrinth.s -o TableLabyrinth.o
ld -s -o TableLabyrinth TableLabyrinth.o
```

## Test rapide

```bash
printf '%s' 'CR4CK1NG5NOTCR1M' | ./TableLabyrinth
echo $?
```

Le flag universel doit être refusé par la version originale.

## Technique

Ce crackme n'utilise pas de hash standard et n'utilise pas de machine virtuelle personnalisée.

La validation repose sur un réseau de 32 contraintes globales. Chaque contrainte lit les 16 caractères dans un ordre différent, applique des clés, des rotations, des additions, des XOR et une S-box 4 bits. Les résultats sont accumulés jusqu'à la fin afin d'éviter un arrêt immédiat au premier caractère incorrect.

Le flag n'est pas stocké en clair dans le source ni dans le binaire.
