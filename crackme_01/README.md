# MirageVM

Crackme Linux x86-64 en syntaxe NASM, sans libc ni bibliothèque externe.

## Compilation

```bash
nasm -f elf64 MirageVM.s -o MirageVM.o
ld -s -o MirageVM MirageVM.o
```

## Exécution

```bash
./MirageVM
```

Le programme lit un flag de **16 caractères exactement** depuis l'entrée standard.
Un retour `0` indique le succès et un retour `1` l'échec.

## Particularités techniques

- Ce crackme n'utilise aucun hash standard.
- Validation par machine virtuelle personnalisée et bytecode chiffré.
- Les instructions virtuelles exécutées sont effacées en mémoire.
- Transformation réversible afin qu'une seule entrée de 16 octets soit valide.
- Le binaire original refuse le flag universel du concours.

## Fichiers à déposer dans le dépôt privé

- `MirageVM.s`
- `README.md`

Le binaire compilé `MirageVM` est destiné à la plateforme de challenges.
