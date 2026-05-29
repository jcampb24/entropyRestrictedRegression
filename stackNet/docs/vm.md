# Virtual Machine

Specification for the stack machine interpreter (`vm.md`). The virtual
machine executes bytecode produced by the assembler (`asm.md`) against
up to three input tapes and writes the result to an output tape.

## Interface

```julia
run(program::Vector{UInt8}, inputs::Vector{BitVector}) -> BitVector
```

`program` is a flat byte vector, one byte per instruction, as produced
by the assembler. `inputs` is a vector of zero to three `BitVector`
values, one per input tape in order. The return value is the output
tape at termination.

It is an error if `length(inputs) > 3` or if any byte in `program` has
its high nibble nonzero (invalid opcode).

## State

The machine state during execution consists of:

- **Stack.** A LIFO bit stack, pre-allocated to `length(program)` cells
  and managed via a stack pointer. A read below the bottom returns 0.
- **Tape heads.** One integer index per input tape, each initialised to
  1 (the first cell, 1-indexed). Heads wrap on ADVANCE and RETREAT.
- **Active tape.** An integer index into `inputs`, initialised to 1.
  NEXT-TAPE increments it cyclically.
- **Output tape.** A `BitVector`, initially empty, grown by POP and
  POUR.

## Execution

The interpreter iterates over the program bytes in order. For each
byte, the low nibble is the opcode; the high nibble must be zero. Each
opcode is executed as specified in `stack.md`. Execution stops when
a HALT fires or the program is exhausted.

### No-input convention

If `inputs` is empty, every input read (PEEK, EOT) returns 1, and
ADVANCE, RETREAT, and NEXT-TAPE are no-ops. This implements the bias
unit of `stack.md`.

An empty tape (a `BitVector` of length zero) is treated identically to
an absent tape: EOT fires immediately (returns 1), PEEK returns 1, and
ADVANCE and RETREAT are no-ops on that tape.

### Wrapping

ADVANCE past the last cell of the active tape wraps to cell 1.
RETREAT past cell 1 wraps to the last cell. Both are modular
arithmetic on the head index.

### POUR

POUR pops the top of the stack. If it is 1, the remaining stack
contents are written to the output tape top-first (LIFO order),
emptying the stack. Execution then continues with the next
instruction.

## Error conditions

- `length(inputs) > 3`: error before execution begins.
- Any program byte with a nonzero high nibble: error at that
  instruction.

All other machine states are well-defined by `stack.md`; the VM
performs no further error checking.
