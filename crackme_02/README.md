# StateHydra

`StateHydra` is an x86-64 Linux crackme written in NASM assembly.

## Build

```bash
nasm -f elf64 StateHydra.s -o StateHydra.o
ld -s -o StateHydra StateHydra.o
```

## Usage

```bash
./StateHydra
```

The program reads a flag from standard input.

Expected behavior:

- valid flag: prints `Good Job!` and exits with status code `0`;
- invalid flag: prints `Bad Password!` and exits with status code `1`.

The flag must contain exactly 16 characters. The program also accepts the usual terminal newline after the 16 characters.

## Design notes

This crackme does not use MD5, SHA, or any standard hash algorithm. It also does not use a custom bytecode VM.

The validation is based on an input-dependent state machine:

1. the 16 input bytes initialize a 256-bit internal state;
2. the state is transformed through 96 rounds;
3. each round selects one of eight arithmetic/boolean transformations depending on the current state;
4. the final state is compared against reconstructed constants;
5. the comparison is accumulated without an early exit.

The goal is to make direct flag recovery difficult while keeping the binary patchable for the universal crack flag required by the contest.
