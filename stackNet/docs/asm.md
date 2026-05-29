# Assembler

Specification for the assembly language of the stack machine
(`stack.md`) and its compiler to bytecode. The compiler is the
translation layer between human-readable programs — as written in
`library.md` — and the byte strings the virtual machine (`vm.md`)
executes.

## Assembly language

An assembly program is a plain text file. Each instruction occupies
its own line. Blank lines are ignored. Comments are enclosed in
asterisks and may span multiple lines; everything between a `*` and
the next `*` is discarded before parsing. A comment may appear
anywhere: between instructions, on the same line as an instruction,
or spanning several lines.

The sixteen mnemonics are the instruction names from `stack.md`,
written in upper case:

```
EOT
POP
NAND
HALT
ADVANCE
DUP
SWAP
NEXT-TAPE
DROP
OVER
ROT
POUR
NOOP
CMOV
PEEK
RETREAT
```

No other tokens are valid instruction names. The assembler reports an
error on any unrecognised token that is not a comment, a blank line,
or a loop directive.

## Loop directive

The single compiler directive is the loop, which unrolls a block of
instructions a fixed number of times:

```
START_LOOP x
    ... instructions ...
END_LOOP
```

`x` is a positive integer. The assembler replaces the directive with
exactly `x` consecutive copies of the enclosed instructions, as if
they had been written out by hand. Loops may not be nested. The
assembled output contains no trace of the directive; it is purely a
text-level shorthand.

## Bytecode encoding

The compiler produces a flat sequence of bytes, one byte per
instruction. The 4-bit opcode occupies the low nibble; the high
nibble is zero. The opcode assignments follow the instruction table
of `stack.md` exactly:

| Mnemonic  | Opcode (binary) | Byte (hex) |
|-----------|-----------------|------------|
| EOT       | 0000            | 0x00       |
| POP       | 0001            | 0x01       |
| NAND      | 0010            | 0x02       |
| HALT      | 0011            | 0x03       |
| ADVANCE   | 0100            | 0x04       |
| DUP       | 0101            | 0x05       |
| SWAP      | 0110            | 0x06       |
| NEXT-TAPE | 0111            | 0x07       |
| DROP      | 1000            | 0x08       |
| OVER      | 1001            | 0x09       |
| ROT       | 1010            | 0x0A       |
| POUR      | 1011            | 0x0B       |
| NOOP      | 1100            | 0x0C       |
| CMOV      | 1101            | 0x0D       |
| PEEK      | 1110            | 0x0E       |
| RETREAT   | 1111            | 0x0F       |

The bytecode for a program of *m* instructions is exactly *m* bytes.
There is no header, no length prefix, and no terminator; the length
of the byte string is the length of the program.

## Compilation pipeline

1. **Strip comments.** Scan the source text and remove everything
   between each `*` and the next `*`, inclusive. It is an error if a
   `*` is opened but never closed.

2. **Expand loops.** Find each `START_LOOP x` / `END_LOOP` pair and
   replace it with `x` copies of the enclosed text. It is an error if
   a `START_LOOP` has no matching `END_LOOP`, if an `END_LOOP` appears
   without a preceding `START_LOOP`, or if loops are nested.

3. **Tokenise.** Split the remaining text on whitespace and blank
   lines, yielding a sequence of tokens.

4. **Assemble.** Map each token to its opcode byte using the table
   above. It is an error if any token is not a recognised mnemonic.

5. **Emit.** Write the resulting byte sequence to the output.

## Error conditions

The assembler reports an error and halts on:

- An unclosed comment delimiter (`*` with no matching closing `*`).
- A `START_LOOP` with no matching `END_LOOP`.
- An `END_LOOP` with no preceding `START_LOOP`.
- Nested loops.
- A `START_LOOP` whose argument `x` is not a positive integer.
- Any token that is not a recognised mnemonic.

## Example

The following assembly source for the `wire` operator (`library.md`):

```
NOOP  *header*
START_LOOP 4
PEEK       *read the current input bit*
POP        *write it to the output*
EOT        *push 1 iff the head is at the last cell*
HALT       *halt if so*
ADVANCE    *otherwise step to the next bit*
END_LOOP
NOOP  *footer*
```

compiles to the byte sequence (hex):

```
0C 0E 01 00 03 04 0E 01 00 03 04 0E 01 00 03 04 0E 01 00 03 04 0C
```

That is: NOOP, then four copies of (PEEK, POP, EOT, HALT, ADVANCE),
then NOOP — 22 bytes total for a loop count of 4.
