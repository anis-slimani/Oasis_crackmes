# SHA-256 NoWayBack — x86-64 Linux

NoWayBack écrit exclusivement en assembleur NASM x86-64, sans libc ni bibliothèque externe.

## Propriétés

- entrée de **16 caractères exactement** ;
- SHA-256 calculé directement dans le binaire ;
- le flag en clair n'est jamais présent dans le code source ni dans le binaire ;
- le digest attendu est séparé en deux tableaux XOR ;
- comparaison complète sans arrêt au premier octet différent ;
- sortie finale indirecte, mais volontairement patchable pour le concours ;
- succès : code de retour `0` ; échec : code de retour `1`.

## Compilation

```bash
make
```

Équivalent manuel :

```bash
nasm -f elf64 -Wall -Werror NoWayBack.s -o NoWayBack.o
ld -o NoWayBack NoWayBack.o
```

## Utilisation

```bash
./NoWayBack
```

Ou par pipe :

```bash
printf '%s' '0123456789ABCDEF' | ./NoWayBack
echo $?
```

## Limite fondamentale

Aucun crackme local n'est « incassable » : un adversaire peut toujours modifier le chemin de succès ou remplacer la comparaison. En revanche, avec un flag aléatoire de 16 caractères et seulement son SHA-256 dans le binaire, retrouver le flag original par inversion ou brute force est irréaliste en pratique.

