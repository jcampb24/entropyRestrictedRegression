# The Primitive Library

Specifications for the primitive programs available as CGP function-set
entries (`cgp.md`). Each is a program on the machine of `stack.md`.

**Number encoding.** Bare bits, LSB-first, no framing. A number is its bits on
a tape; the width is the tape length. End-of-input is sensed in-band by EOT,
not by a terminator, so a single program serves an input of any width up to its
unroll depth — 256 body copies — and truncates a longer input to the first 256
bits.

**Modular standard.** The number of digits expressing an integer is its number
system: a width-*w* number lives in ℤ/2^*w*, and every operation is modular at
the width of its operands. Arithmetic neither grows nor shrinks the width to
chase a value — a carry off the top or a borrow past the bottom simply falls
away, so `increment(all-ones_w) = all-zeros_w` and
`decrement(all-zeros_w) = all-ones_w`, each the wrap of its own width. Width is
therefore a property the operand carries, not a global constant; the same
program serves every width, and the modulus rides in with the data.

**Presentation.** Each program is an optional header (runs once), a body shown
once between ellipses and unrolled up to N ≤ 256 times, and an optional footer.
Every program opens and closes with a NOOP, so the header and footer are never
empty. The unrolled artifact is the body repeated; the document shows it once.
No loops: the machine is straight-line (`stack.md`), every body copy is
physically present, and EOT→HALT ends the program in-band when the input is
exhausted.

## Boolean operators

The single-bit-output functions, applied position-by-position to a stream of up
to 255 input bits. Each program reads one position per body copy, emits the
function's value for that position, and stops when the input is exhausted.
Output length equals input length.

Three subsections follow, organised by arity. The nullary operators read no
input tape; the unary operators read one tape; the binary operators read two
tapes in lockstep, stopping when either tape reaches its last cell. All programs
are stack-agnostic and stack-preserving: the body pushes and consumes only the
values it introduces, leaving the stack as it found it between copies.

**Tape conventions.** Unary operators read tape 1. Binary operators read tape 1
(argument *a*) and tape 2 (argument *b*), restoring tape 1 as the active tape
after each read — the restore-to-tape-1 discipline that makes the building
blocks compose uniformly. An operator reads only the tapes its function depends
on: a function of *a* alone never touches tape 2; a function of *b* alone visits
tape 2 and returns; the nullary constants read nothing.

**Termination.** The end-test follows the emit. It senses the end of the
relevant input tape(s) with EOT, halts if the end is reached, and advances the
head(s) otherwise. For binary operators the end-test is the two-tape OR used
throughout the library: EOT on tape A and EOT on tape B are separately computed,
ORed, and fed to HALT — the scan stops as soon as either tape reaches its last
cell.

### Nullary Boolean operators

The two constant functions. They do not read any input tape and carry no state;
each body copy manufactures a fixed bit and emits it, stopping when tape 1
signals end-of-tape. Tape 1 is not read for its value — it is consulted only to
sense when the stream ends.

The constant-manufacturing core is the sequence DUP, DUP, DUP, NAND, NAND,
which produces 1 on top of the stack regardless of the unknown top value *x*:
three DUPs leave four copies of *x*; the first NAND yields NOT *x*; the second
yields NAND(*x*, NOT *x*) = 1. TRUE writes that 1 directly. FALSE appends a
further DUP, NAND to negate it to 0.

| # | TT | Name  | Program | Length |
|---|----|-------|---------|--------|
| 0 | 0  | FALSE | DUP, DUP, DUP, NAND, NAND, DUP, NAND, POP, EOT, HALT, ADVANCE | 11 |
| 1 | 1  | TRUE  | DUP, DUP, DUP, NAND, NAND, POP, EOT, HALT, ADVANCE | 9 |

```
NOOP       *header*
...
DUP, DUP, DUP, NAND, NAND [, DUP, NAND]   *manufacture 1 (TRUE) or 0 (FALSE)*
POP        *emit the constant bit*
EOT        *push 1 iff tape 1 is at its last cell*
HALT       *halt if so*
ADVANCE    *step tape 1*
...
NOOP       *footer*
```

### Unary Boolean operators

There are 2^(2^1) = 4 unary single-bit-output functions {0,1} → {0,1}. Each
body copy reads the current bit from tape 1, computes the function, emits the
result, and stops if that was the last bit.

| # | TT | Name     | Body | Body length |
|---|----|----------|------|-------------|
| 0 | 00 | FALSE    | *(see nullary)* | — |
| 1 | 01 | IDENTITY | PEEK, POP, EOT, HALT, ADVANCE | 5 |
| 2 | 10 | NOT      | PEEK, DUP, NAND, POP, EOT, HALT, ADVANCE | 7 |
| 3 | 11 | TRUE     | *(see nullary)* | — |

FALSE and TRUE are listed here for completeness of the truth-table numbering;
their programs are the nullary entries above, which consult tape 1 only for the
end signal.

**IDENTITY** reads the bit with PEEK, emits it with POP, tests for end, and
advances. No computation.

**NOT** reads the bit, negates it via the DUP+NAND idiom (NAND(*a*, *a*) = NOT
*a*), emits the result, tests for end, and advances.

```
NOOP       *header*
...
PEEK       *read the current bit*
[DUP, NAND]    *NOT only: negate*
POP        *emit*
EOT        *push 1 iff at the last cell*
HALT       *halt if so*
ADVANCE    *step to the next bit*
...
NOOP       *footer*
```

### Binary Boolean operators

There are 2^(2^2) = 16 binary single-bit-output functions {0,1}² → {0,1}. Each
body copy reads one bit from tape 1 (*a*) and one from tape 2 (*b*), computes
the function, emits the result, and stops when either tape signals end-of-tape.
The active tape is restored to tape 1 after each read pair.

(Truth-table convention: values listed as f(0,0), f(0,1), f(1,0), f(1,1).)

| #  | TT   | Name        | Compute block |
|----|------|-------------|---------------|
| 0  | 0000 | FALSE       | *(see nullary)* |
| 1  | 0001 | AND         | PEEK, NEXT-TAPE, PEEK, NEXT-TAPE, NAND, DUP, NAND |
| 2  | 0010 | a AND NOT b | PEEK, NEXT-TAPE, PEEK, NEXT-TAPE, DUP, NAND, NAND, DUP, NAND |
| 3  | 0011 | a           | PEEK |
| 4  | 0100 | NOT a AND b | PEEK, DUP, NAND, NEXT-TAPE, PEEK, NEXT-TAPE, NAND, DUP, NAND |
| 5  | 0101 | b           | NEXT-TAPE, PEEK, NEXT-TAPE |
| 6  | 0110 | XOR         | PEEK, DUP, DUP, NAND, SWAP, NEXT-TAPE, PEEK, NEXT-TAPE, CMOV |
| 7  | 0111 | OR          | PEEK, DUP, NAND, NEXT-TAPE, PEEK, NEXT-TAPE, DUP, NAND, NAND |
| 8  | 1000 | NOR         | PEEK, DUP, NAND, NEXT-TAPE, PEEK, NEXT-TAPE, DUP, NAND, NAND, DUP, NAND |
| 9  | 1001 | XNOR        | PEEK, DUP, DUP, NAND, NEXT-TAPE, PEEK, NEXT-TAPE, CMOV |
| 10 | 1010 | NOT b       | NEXT-TAPE, PEEK, NEXT-TAPE, DUP, NAND |
| 11 | 1011 | b → a       | PEEK, DUP, NAND, NEXT-TAPE, PEEK, NEXT-TAPE, NAND |
| 12 | 1100 | NOT a       | PEEK, DUP, NAND |
| 13 | 1101 | a → b       | PEEK, NEXT-TAPE, PEEK, NEXT-TAPE, DUP, NAND, NAND |
| 14 | 1110 | NAND        | PEEK, NEXT-TAPE, PEEK, NEXT-TAPE, NAND |
| 15 | 1111 | TRUE        | *(see nullary)* |

The table shows the compute block only — the instructions that produce the
function's value on top of the stack. Each body copy appends the common
emit-and-advance tail: POP, then the two-tape EOT-OR end-test, then HALT, then
ADVANCE on both tapes, leaving tape 1 active for the next copy. The full
structure is shown for AND below; every other entry follows the same pattern
with its compute block substituted.

**`AND` — full program.**

```
NOOP           *header*
...
PEEK           *read a (tape 1 active)*
NEXT-TAPE      *active tape 2*
PEEK           *read b*
NEXT-TAPE      *active tape 1 again*
NAND           *NAND(a, b)*
DUP
NAND           *negate → AND(a, b)*
POP            *emit*
EOT            *tape 1 at last cell?*
DUP
NAND           *→ NOT eA*
NEXT-TAPE      *active tape 2*
EOT            *tape 2 at last cell?*
DUP
NAND           *→ NOT eB*
NAND           *→ eA OR eB*
HALT           *halt if either tape ended*
ADVANCE        *advance tape 2*
NEXT-TAPE      *active tape 1*
ADVANCE        *advance tape 1*
...
NOOP           *footer*
```

**AND** reads *a* and *b*, NANDs them, and negates via DUP+NAND.

**a AND NOT b** reads *a* and *b*, negates *b* in place via DUP+NAND, then ANDs
with *a* via NAND-then-negate.

**a** is the projection onto *a*. It reads tape 1 and never touches tape 2.

**NOT a AND b** negates *a* while tape 1 is still active, then reads *b*, then
ANDs via NAND-then-negate.

**b** is the projection onto *b*. It switches to tape 2, reads, and switches
back.

**XOR** returns 1 iff *a* ≠ *b*, expressed as: output *a* if *b* = 0, else NOT
*a*. After reading *a*, DUP, DUP, NAND yields [*a*, NOT *a*]; SWAP gives [NOT
*a*, *a*]; reading *b* gives [NOT *a*, *a*, *b*]; CMOV selects *a* when *b* = 0
and NOT *a* when *b* = 1.

**OR** = NAND(NOT *a*, NOT *b*) by De Morgan. Read *a*, negate, read *b*,
negate, NAND the two negations.

**NOR** is OR followed by a trailing DUP, NAND negation.

**XNOR** returns 1 iff *a* = *b*: output NOT *a* if *b* = 0, else *a*. After
reading *a*, DUP, DUP, NAND yields [*a*, NOT *a*]; reading *b* gives [*a*, NOT
*a*, *b*]; CMOV selects NOT *a* when *b* = 0 and *a* when *b* = 1. One
instruction shorter than XOR because XNOR's natural stack arrangement is what
CMOV consumes directly, whereas XOR needs a SWAP first.

**NOT b** switches to tape 2, reads *b*, switches back, and negates via
DUP+NAND.

**b → a** = NAND(NOT *a*, *b*). Reads *a*, negates it, reads *b*, NANDs.

**NOT a** reads *a* and negates via DUP+NAND. Does not touch tape 2.

**a → b** = NAND(*a*, NOT *b*). Reads both inputs, then negates *b* in place,
then NANDs.

**NAND** reads *a* and *b* and NANDs. No negation step — the machine's native
binary operation.

**TRUE** is the nullary entry above.

## `wire` (add zero / identity)

The identity on a number: emit each input bit unchanged, stopping when the
input is exhausted. No state, no carry — the simplest multi-bit operator.
Output width equals input width.

```
NOOP       *header — no setup required*
...
PEEK       *read the current input bit*
POP        *write it to the output*
EOT        *push 1 iff the head is at the last cell*
HALT       *halt if so — the input is exhausted*
           *if HALT did not fire, the stack is empty here*
ADVANCE    *otherwise step to the next bit*
...
NOOP       *footer — reached only if the input is longer than 256 bits*
```

Body copy k reads input bit k−1 and emits it, so over a width-w input the
output is bits 0…w−1 in order — the input verbatim. EOT is tested while the
head still rests on the last cell, before the ADVANCE that would wrap it to
cell 0, so the end is detected exactly: copy w emits bit w−1 and then halts,
giving output equal to input with no spurious trailing bit. If the input is
longer than 256 bits, EOT never fires within the 256 body copies; the body runs
to its full count, emits the first 256 bits, and falls through to the footer
and off the end, truncating to 256 bits. The body pushes and consumes only its
own bits, never touching the incoming stack, so `wire` is stack-agnostic and
stack-preserving and correct on any starting stack, including empty.

## `nibble` (drop a high-order zero)

Pass the number through unchanged, except remove its high-order bit — the last
bit read, LSB-first — when that bit is zero. A droppable leading zero is
trimmed; a high 1 is kept. The inverse of unconditional carry-out growth: where
a growing operator may append a high 0, `nibble` removes one. Output width
equals input width, or one less when the high bit is a dropped zero.

```
NOOP       *header*
...
PEEK       *read the current bit — the payload to maybe emit*
DUP
DUP
NAND       *top two → ¬bit, leaving ¬bit above the payload bit*
EOT        *push 1 iff the head is at the last cell*
NAND       *NAND(EOT, ¬bit) = ¬EOT ∨ bit — the emit trigger*
POUR       *emit the bit iff the trigger is 1; empties the stack when it fires*
EOT        *push 1 iff the head is at the last cell, again*
HALT       *halt if so*
ADVANCE    *otherwise step to the next bit*
...
NOOP       *footer — reached only if the input is longer than 256 bits*
```

The emit trigger ¬EOT ∨ bit reads as the rule directly: emit the bit unless it
is the last one and it is zero. On an interior bit EOT = 0, so the trigger is 1
and POUR always fires, draining the single payload bit and emptying the stack;
the second EOT pushes 0, HALT does not fire, and ADVANCE steps on. On the last
bit EOT = 1, so the trigger equals the bit: a 1 fires POUR and is emitted, a 0
leaves POUR inert and is discarded at termination, after which the second EOT
pushes 1 and HALT stops. The stack is empty between body copies, so `nibble` is
memoryless — the property that keeps the conditional emit clean, as in `screen`.

Edge case: a single-bit input [0] is a last bit of zero, so it is dropped and
the output is empty — a zero-width number. This does not arise downstream of a
growing operator, whose output is at least two bits wide, but it is the honest
behavior on a bare [0].

`nibble` is the one-bit case of a more general `chomp` that would strip *all*
trailing high-order zeros; `chomp` is noted here only for context and is not
developed.

## `reversebits` (bit-reversal)

Reads the input stream onto the stack one bit at a time, then pours the stack
to the output at end-of-input. Because the stack is LIFO, the last bit read is
the first bit poured, so the output is the input reversed. Output length equals
input length.

```
NOOP       *header*
...
PEEK       *read the current bit onto the stack*
EOT        *push 1 iff at the last cell*
POUR       *if so, pour the entire stack to output; else inert*
EOT        *push 1 iff at the last cell*
HALT       *halt if so*
ADVANCE    *step to the next bit*
...
NOOP       *footer — reached only if the input exceeds 256 bits*
```

Body copy *k* reads bit *k*−1 and pushes it. On an interior copy EOT pushes 0,
POUR is inert, the second EOT pushes 0, HALT does not fire, and ADVANCE steps
on, leaving the stack one bit taller. On the last copy EOT pushes 1, POUR drains
the entire stack — all *w* bits — to the output in LIFO order, the second EOT
pushes 1, and HALT stops. The stack grows by one bit per copy and is emptied in
a single POUR at termination, so the program is stack-agnostic only at entry,
not between copies; it is however stack-preserving overall — the stack at exit
equals the stack at entry.

## `increment` (add one)

Adding one to a number is the first piece of arithmetic anyone learns. It is
worth recalling how you do it by hand, because the machine does exactly the same
thing. You start at the low end — the least-significant digit — and try to add
one there. If that digit has room, it ticks up and you are finished; nothing
else changes. If it has no room, it rolls over to zero and sends a carry into
the next digit to its left, where you try again. For example, in adding one to
1399, the last 9 has no room: it becomes 0 and carries. The next 9 also has no
room: it too becomes 0 and carries. The 3 has room, ticks up to 4, and the carry
stops — 1400. The carry propagates left through the run of 9s and is killed at
the first digit with room.

Binary is the same procedure with only two digits, where a zero has room and a
one does not. If the least-significant digit is a zero, it flips to a one and
the carry dies; copying all the remaining digits completes the operation. If
instead the least-significant digit is a one, that digit flips to a zero and the
carry propagates to the next position, where the same question is asked again.
The effect over the whole number is to flip the low run of ones to zeros, flip
the first zero into a one, and leave every digit above it untouched.

The machine works through the bits from the lowest upward, the same order the
carry propagates, settling each output bit as it reads the matching input bit.
It holds one fact as it goes: whether the carry is still alive. While the carry
is alive it writes the opposite of each bit it reads — a 1 becomes 0, a 0
becomes 1 — and the first time that opposite is a 1, the carry is killed; from
there it copies the remaining bits unchanged. Write the opposite while the carry
is alive, watch for the 1 that kills it, then copy: that rule is the whole of
the addition.

That one fact — is the carry dead — is the only thing the machine must store and
update, and there is a choice in how to record it. The carry is alive from the
very first bit, since that is what adding one means, so a flag reading "the carry
is alive" would have to be switched on before any bit is read. The program
records the opposite instead, "the carry is dead," which is false at the start.
Its working memory begins empty and reads as false, so recording the fact in
this direction makes the correct starting condition cost nothing — no flag need
be set before the first bit. With the fact kept this way, each bit does just two
things: the output is the read bit's opposite while the carry is alive and the
read bit itself once it is dead, and the carry counts as dead the moment an
output 1 appears.

After the last input bit the carry might still be alive, which happens only when
every input bit equalled one. Increment appends nothing — its output is the same
width as its input — so a surviving carry simply falls off the end, and an
all-ones input emerges as all zeros: the wrap of `(2^w − 1) + 1` back to 0,
mod 2^w at the input's own width. This is the exact mirror of `decrement`, whose
borrow falls off to wrap 0 to all ones; the digit count of a number is its
number system, and increment respects that count rather than widening past it.
Increment can still leave a leading zero, a genuine one rather than a
manufactured one: `increment([0,0])` is `[1,0]`, the value 1 in two bits, which
the companion operator `nibble` trims when a tight width is wanted.

```
NOOP        *header*
DUP         *empty stack pushes 0 — seed d = 0 (the carry starts alive)*
...
DUP         *bank a spare d for the state update*
PEEK        *read the current input bit*
DUP
DUP
NAND        *top two → ¬data, above data*
ROT         *arrange [d, ¬data, data, d] for the multiplexer*
CMOV        *out = data if d = 1 else ¬data = XNOR(d, data)*
DUP
POP         *emit out*
DUP
NAND
SWAP
DUP
NAND
NAND        *new_d = OR(d, out) — the carry-state for the next bit*
EOT         *push 1 iff at the last cell*
HALT        *halt if so*
ADVANCE     *otherwise step to the next bit*
...
NOOP        *footer — reached only if the input is longer than 256 bits*
```

The header's DUP seeds d = 0 for the first copy; a column entering with d = 1 is
therefore a later copy. The walkthrough below traces eight cases. Legend: `i` =
interior bit (EOT = 0); `L` = the 256th / last bit (EOT = 1); the two digits are
(d, x), the carry-state and the data bit. Through the core the matched `i` and
`L` columns coincide — nothing reads EOT until step 16 — so they part only at
the tail. Stacks are top-cell-first (top row = top of stack).

**Entry.** The body begins carrying d.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**1. DUP** — bank a spare d for the update.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**2. PEEK** — read the current input bit; the head does not move.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**3. DUP** — copy the data bit.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**4. DUP** — copy it again, leaving three.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**5. NAND** — NAND the top two, producing ¬data above a surviving data.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| ¬data | 1 | 0 | 1 | 0 | 1 | 0 | 1 | 0 |
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**6. ROT** — rotate the top three so the selector d is on top, in CMOV's order.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| ¬data | 1 | 0 | 1 | 0 | 1 | 0 | 1 | 0 |
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**7. CMOV** — select data if d = 1, else ¬data: out = XNOR(d, data).

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| out | 1 | 0 | 0 | 1 | 1 | 0 | 0 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**8. DUP** — copy out, one to emit and one to keep.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| out | 1 | 0 | 0 | 1 | 1 | 0 | 0 | 1 |
| out | 1 | 0 | 0 | 1 | 1 | 0 | 0 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**9. POP** — emit out (the bits emitted: 1, 0, 0, 1, 1, 0, 0, 1).

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| out | 1 | 0 | 0 | 1 | 1 | 0 | 0 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**10. DUP** — copy out for the update.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| out | 1 | 0 | 0 | 1 | 1 | 0 | 0 | 1 |
| out | 1 | 0 | 0 | 1 | 1 | 0 | 0 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**11. NAND** — NAND the two copies → ¬out.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| ¬out | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 0 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**12. SWAP** — bring the spare d above ¬out.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| ¬out | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 0 |

**13. DUP** — copy d.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| d | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| ¬out | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 0 |

**14. NAND** — NAND the two copies → ¬d.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| ¬d | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 0 |
| ¬out | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 0 |

**15. NAND** — NAND ¬d with ¬out → d OR out = new_d.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| new_d | 1 | 0 | 1 | 1 | 1 | 0 | 1 | 1 |

**16. EOT** — push 1 iff the head is at the last cell.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| EOT | 0 | 0 | 0 | 0 | 1 | 1 | 1 | 1 |
| new_d | 1 | 0 | 1 | 1 | 1 | 0 | 1 | 1 |

**17. HALT** — pop the top; halt iff 1. The L columns stop here, having emitted only out.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| new_d | 1 | 0 | 1 | 1 | halts | halts | halts | halts |

**18. ADVANCE** — step to the next bit; the stack carries new_d into the next copy.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| new_d | 1 | 0 | 1 | 1 | — | — | — | — |

Every last-bit column emits its single output bit at step 9 and then halts — no
carry-out, nothing appended. Column L01 is the telling one: the carry is still
alive after the last bit (new_d = 0), the all-ones case, and it simply falls off
the end — which is why an all-ones input emerges as all zeros, the wrap of
`(2^w − 1) + 1` mod 2^w. The mirror of `decrement`'s column L00.

## `increment2`, `increment4`, … (add a power of two)

Adding 2^k is adding one with the carry injected k places up. The low k bits
have nothing added to them, so they pass through verbatim; at bit k the ordinary
`increment` carry begins, alive, and runs to the top. So `increment2^k` is k
copies of the `wire` body — the carry-dead regime made literal — followed by the
`increment` body for every bit from k upward. Nothing is re-derived: both pieces
are the verified operators above, laid end to end in the unrolled stream.

`increment2` (k = 1) shown in full; `increment4` is the same with two `wire`
copies, and the family continues `increment8`, `increment16`, … with k copies.

```
NOOP                          *header*
DUP                           *empty stack pushes 0 — seed d = 0 (carry alive)*
PEEK, POP, EOT, HALT, ADVANCE *wire × k — copy bits 0..k−1 verbatim (here k = 1)*
...
DUP                           *the increment body, bits k upward*
PEEK
DUP
DUP
NAND
ROT
CMOV
DUP
POP
DUP
NAND
SWAP
DUP
NAND
NAND
EOT
HALT
ADVANCE
...
NOOP                          *footer*
```

The seed survives the prefix: the header's DUP leaves a physical d = 0, and the
`wire` body is stack-preserving, so the k passthrough copies hand the increment
body exactly the `[0]` (carry alive, spare-d present) that plain `increment`
sees on its own first copy. The handoff therefore needs no special instruction —
the first increment copy runs identically to increment's copy 1.

Termination and wrap are inherited. Each `wire` copy halts at EOT, so an input of
width w ≤ k is pure passthrough and the addition vanishes — correct, since
2^k ≡ 0 mod 2^w when w ≤ k (e.g. `increment2` on a one-bit number is the
identity, 2 ≡ 0 mod 2). For wider inputs the `increment` body supplies the same
mod-2^w wrap as `increment` itself: a carry surviving the top bit falls off.

## `decrement` (subtract one)

Subtracting one from a number runs the same way as adding one, from the low end,
with a borrow in place of the carry. You start at the least-significant digit and
try to take one away. If that digit has something to give, it ticks down and you
are finished; nothing else changes. If it is already zero, it has nothing to
give, so it rolls down to a nine and borrows from the next digit to its left,
where you try again. For example, in subtracting one from 1400, the last 0 has
nothing to give: it becomes 9 and borrows. The next 0 also has nothing to give:
it too becomes 9 and borrows. The 4 has something to give, ticks down to 3, and
the borrow stops — 1399. The borrow propagates left through the run of zeros and
is killed at the first digit with something to give.

Binary is the same with only two digits, where a one has something to give and a
zero does not. If the least-significant digit is a one, it flips to a zero and
the borrow dies; copying the remaining digits completes the operation. If instead
it is a zero, that digit flips to a one and the borrow propagates to the next
position, where the same question is asked again. The effect over the whole
number is to flip the low run of zeros to ones, flip the first one into a zero,
and leave every digit above it untouched.

The machine works through the bits from the lowest upward, the same order the
borrow propagates, settling each output bit as it reads the matching input bit.
It holds one fact as it goes: whether the borrow is still alive. While the borrow
is alive it writes the opposite of each bit it reads — a 0 becomes 1, a 1 becomes
0 — and the first time it reads a 1, which it writes out as a 0, the borrow is
killed; from there it copies the remaining bits unchanged. Write the opposite
while the borrow is alive, watch for the one that kills it, then copy: that rule
is the whole of the subtraction.

That one fact — is the borrow dead — is the only thing the program must store and
update, and the same choice of polarity arises as for adding one. The borrow is
alive from the very first bit, since that is what subtracting one means, so a flag
reading "the borrow is alive" would have to be switched on before any bit is read.
The program records the opposite, "the borrow is dead," which is false at the
start, so the empty working memory already holds the correct initial condition at
no cost. Each bit then does just two things: the output is the read bit's opposite
while the borrow is alive and the read bit itself once it is dead, and the borrow
counts as dead the moment a one is read.

After the last input bit the borrow might still be alive, which happens only when
every input bit equalled zero. Here decrement parts company with increment: it
appends nothing, because subtracting one can never widen a number, so a surviving
borrow simply falls off the end and an all-zeros input emerges as all ones — the
wrap of 0 − 1. Decrement can still leave a leading zero, but a genuine one rather
than a manufactured one: decrementing a power of two clears its top bit, and the
companion operator `nibble` trims that zero when a tight width is wanted.

The body is increment's core with one change at the emit and a lighter tail. The
read, the multiplexer, and the CMOV that produces out are identical; so is the
six-instruction OR idiom that does the update. Where increment does DUP, POP —
keeping out as the update's operand, so it computes OR(d, out) — decrement does
POP, PEEK: it emits out bare, then re-reads the same data bit (the head has not
advanced), so the update computes OR(e, data). The tail is the plain `wire` tail,
since decrement never grows.

```
NOOP        *header*
DUP         *empty stack pushes 0 — seed e = 0 (the borrow starts alive)*
...
DUP         *bank a spare e for the state update*
PEEK        *read the current input bit*
DUP
DUP
NAND        *top two → ¬data, above data*
ROT         *arrange [e, ¬data, data, e] for the multiplexer*
CMOV        *out = data if e = 1 else ¬data = XNOR(e, data)*
POP         *emit out*
PEEK        *re-read the same data bit for the update*
DUP
NAND
SWAP
DUP
NAND
NAND        *new_e = OR(e, data) — the borrow-state for the next bit*
EOT         *push 1 iff at the last cell*
HALT        *halt if so*
ADVANCE     *otherwise step to the next bit*
...
NOOP        *footer — reached only if the input is longer than 256 bits*
```

The header's DUP seeds e = 0 for the first copy; a column entering with e = 1 is
therefore a later copy. The walkthrough below traces eight cases. Legend: `i` =
interior bit (EOT = 0); `L` = the 256th / last bit (EOT = 1); the two digits are
(e, data), the borrow-state and the data bit. Through the core the matched `i`
and `L` columns coincide; they part only at the tail. Stacks are top-cell-first
(top row = top of stack).

**Entry.** The body begins carrying e.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**1. DUP** — bank a spare e for the update.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**2. PEEK** — read the current input bit; the head does not move.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**3. DUP** — copy the data bit.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**4. DUP** — copy it again, leaving three.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**5. NAND** — NAND the top two, producing ¬data above a surviving data.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| ¬data | 1 | 0 | 1 | 0 | 1 | 0 | 1 | 0 |
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**6. ROT** — rotate the top three so the selector e is on top, in CMOV's order.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| ¬data | 1 | 0 | 1 | 0 | 1 | 0 | 1 | 0 |
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**7. CMOV** — select data if e = 1, else ¬data: out = XNOR(e, data).

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| out | 1 | 0 | 0 | 1 | 1 | 0 | 0 | 1 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**8. POP** — emit out, bare (the bits emitted: 1, 0, 0, 1, 1, 0, 0, 1). The spare e is left.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**9. PEEK** — re-read the same data bit for the update.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**10. DUP** — copy the data bit.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| data | 0 | 1 | 0 | 1 | 0 | 1 | 0 | 1 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**11. NAND** — NAND the two copies → ¬data.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| ¬data | 1 | 0 | 1 | 0 | 1 | 0 | 1 | 0 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |

**12. SWAP** — bring the spare e above ¬data.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| ¬data | 1 | 0 | 1 | 0 | 1 | 0 | 1 | 0 |

**13. DUP** — copy e.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| e | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 |
| ¬data | 1 | 0 | 1 | 0 | 1 | 0 | 1 | 0 |

**14. NAND** — NAND the two copies → ¬e.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| ¬e | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 0 |
| ¬data | 1 | 0 | 1 | 0 | 1 | 0 | 1 | 0 |

**15. NAND** — NAND ¬e with ¬data → e OR data = new_e.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| new_e | 0 | 1 | 1 | 1 | 0 | 1 | 1 | 1 |

**16. EOT** — push 1 iff the head is at the last cell.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| EOT | 0 | 0 | 0 | 0 | 1 | 1 | 1 | 1 |
| new_e | 0 | 1 | 1 | 1 | 0 | 1 | 1 | 1 |

**17. HALT** — pop the top; halt iff 1. The L columns stop here, having emitted only out.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| new_e | 0 | 1 | 1 | 1 | halts | halts | halts | halts |

**18. ADVANCE** — step to the next bit; the stack carries new_e into the next copy.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| new_e | 0 | 1 | 1 | 1 | — | — | — | — |

Every last-bit column emits its single output bit at step 8 and then halts — no
carry-out, no second emission, nothing appended; that is the whole of decrement's
lighter tail. Column L00 is the telling one: after the last bit the borrow is
still alive (new_e = 0), the all-zeros case, and it simply falls off the end —
which is why an all-zeros input emerges as all ones, the wrap of 0 − 1.

## `decrement2`, `decrement4`, … (subtract a power of two)

The mirror of `increment2^k`. Subtracting 2^k is subtracting one with the borrow
injected k places up: the low k bits have nothing taken from them and pass
through verbatim, and at bit k the ordinary `decrement` borrow begins, alive, and
runs to the top. So `decrement2^k` is k copies of the `wire` body followed by the
`decrement` body for every bit from k upward — the same construction as
`increment2^k` with `decrement` in place of `increment`. Nothing is re-derived.

`decrement2` (k = 1) shown in full; `decrement4` is the same with two `wire`
copies, and the family continues `decrement8`, `decrement16`, … with k copies.

```
NOOP                          *header*
DUP                           *empty stack pushes 0 — seed e = 0 (borrow alive)*
PEEK, POP, EOT, HALT, ADVANCE *wire × k — copy bits 0..k−1 verbatim (here k = 1)*
...
DUP                           *the decrement body, bits k upward*
PEEK
DUP
DUP
NAND
ROT
CMOV
POP
PEEK
DUP
NAND
SWAP
DUP
NAND
NAND
EOT
HALT
ADVANCE
...
NOOP                          *footer*
```

The seed survives the prefix exactly as in `increment2^k`: the header's DUP
leaves a physical e = 0, the stack-preserving `wire` copies carry it through, and
the first decrement copy receives the `[0]` (borrow alive, spare-e present) that
plain `decrement` sees on its own first copy. Termination and wrap are inherited:
an input of width w ≤ k is pure passthrough, since 2^k ≡ 0 mod 2^w when w ≤ k,
and for wider inputs the `decrement` body supplies the same mod-2^w wrap — a
borrow surviving the top bit falls off, so `decrement2(all-zeros_w)` wraps to
`2^w − 2`.

## `mul2`, `mul4`, `mul8`, … (multiply by a power of two, modular)

Multiplying by `2^k` shifts every digit up `k` places and writes zeros into the
`k` vacated low places. Under the library's modular standard the width does not
grow: a width-*w* number stays width *w*, so the top `k` digits are dropped and
the result is `2^k · x mod 2^w`. Doubling 5 = `[1,0,1]` in three bits gives 10;
the result is `10 mod 8 = 2 = [0,1,0]`. When the input is no wider than `k` the
shift swallows it whole and the result is all zeros, which is correct since
`2^k ≡ 0 (mod 2^w)` for every `w ≤ k`.

The output is `k` zeros followed by the input bits in order, stopping `k` short
because the top `k` bits shift off and are dropped — *w* bits out for *w* bits
in. The program reaches the surviving bits by random access. After the `k` low
zeros, each output bit is emitted by probing `k` cells ahead to ask whether the
number reaches that far, and if it does, falling back to the bit now due and
reading it. The `k` forward steps are the shift distance, the `EOT, HALT` is the
width guard, and the fall-back read is the emission; together they advance the
read head by one cell per output bit.

The low zeros are free: written onto an empty stack, `POP` emits the `0` that the
read-below-bottom rule supplies, with nothing pushed. The `k` leading-zero
sections walk the head outward one cell at a time, each guarding one more width,
so that an input of width `w ≤ k` emits exactly `w` zeros and stops. After them
the head rests on cell `b_{k-1}`, and the first surviving bit `b0` is reached by
retreating `k − 1` cells.

`mul2` is the case `k = 1`, shown in full below; `mul4` is `k = 2`, `mul8` is
`k = 3`, and the family continues with one more leading-zero section and one more
forward probe per output bit at each step. Enough steady blocks are unrolled to
emit up to 256 output bits.

```
NOOP           *header*
POP            *c0: low zero (empty-stack read)*
...
EOT
HALT           *width 1: stop, output [0]*
PEEK
POP            *c1: emit b0*
...
ADVANCE
EOT
HALT           *the number ended here: stop*
PEEK
POP            *steady block: emit the next bit*
...
NOOP           *footer*
```

For `mul2` the head sits on `b0` after the seed zero — already where reading
begins — so no retreat appears; the steady block is a single probe `ADVANCE`, the
width guard, and the read. At `k ≥ 2` the leading-zero sections carry the head
out to `b_{k-1}`, so both the first-bit section and the steady block retreat
`k − 1` cells after probing `k` ahead.

**Walkthrough — `mul2`, width 1.** Input `[1]`, value 1; expected
`2 · 1 mod 2 = 0`. The head column shows the resting cell. (Input `[0]` follows
the identical path and likewise outputs `[0]`.)

| step | head | output |
|---|---|---|
| POP | b0 | 0 |
| EOT | b0 | 0 |
| HALT | b0 | 0 |

`EOT` finds b0 is the only cell, so `HALT` fires before any bit is read. Output
`[0]`, value 0. ✓

**Walkthrough — `mul2`, width 3.** Input `[1,0,1]`, value 5; expected
`2 · 5 mod 8 = 2 = [0,1,0]`. Bits b0 = 1, b1 = 0, b2 = 1.

| step | head | output |
|---|---|---|
| POP | b0 | 0 |
| EOT | b0 | 0 |
| HALT | b0 | 0 |
| PEEK | b0 | 0 |
| POP | b0 | 0 1 |
| ADVANCE | b1 | 0 1 |
| EOT | b1 | 0 1 |
| HALT | b1 | 0 1 |
| PEEK | b1 | 0 1 |
| POP | b1 | 0 1 0 |
| ADVANCE | b2 | 0 1 0 |
| EOT | b2 | 0 1 0 |
| HALT | b2 | 0 1 0 |

The seed zero is `c0`; `c1` emits b0 = 1 with the head still on b0; the steady
block then probes to b1 (not the last cell), reads b1 = 0 as `c2`, and the next
probe reaches b2, the last cell, where `HALT` fires. b2 = 1 is dropped — the top
bit. Output `[0,1,0]`, value 2. ✓

**`mul4` (k = 2), in full.** Two leading-zero sections, then `c2 = b0` reached by
one retreat, then steady blocks that probe two ahead and fall back one.

```
NOOP           *header*
POP            *c0: low zero*
...
EOT
HALT           *width 1: stop, output [0]*
ADVANCE
POP            *c1: low zero*
EOT
HALT           *width 2: stop, output [0,0]*
RETREAT
PEEK
POP            *c2: emit b0*
...
ADVANCE
ADVANCE
EOT
HALT           *the number ended here: stop*
RETREAT
PEEK
POP            *steady block: emit the next bit*
...
NOOP           *footer*
```

**Walkthrough — `mul4`, width 3.** Input `[1,0,1]`, value 5; expected
`4 · 5 mod 8 = 20 mod 8 = 4 = [0,0,1]`. Bits b0 = 1, b1 = 0, b2 = 1.

| step | head | output |
|---|---|---|
| POP | b0 | 0 |
| EOT | b0 | 0 |
| HALT | b0 | 0 |
| ADVANCE | b1 | 0 |
| POP | b1 | 0 0 |
| EOT | b1 | 0 0 |
| HALT | b1 | 0 0 |
| RETREAT | b0 | 0 0 |
| PEEK | b0 | 0 0 |
| POP | b0 | 0 0 1 |
| ADVANCE | b1 | 0 0 1 |
| ADVANCE | b2 | 0 0 1 |
| EOT | b2 | 0 0 1 |
| HALT | b2 | 0 0 1 |

Two zeros are laid down (`c0`, `c1`), the head walking to b1 to guard width 2;
`c2` retreats to b0 and emits b0 = 1; the steady block probes to b2, the last
cell, and `HALT` fires. b1 and b2 are dropped. Output `[0,0,1]`, value 4. ✓

**Walkthrough — `mul4`, width 4.** Input `[1,0,0,1]`, value 9; expected
`4 · 9 mod 16 = 36 mod 16 = 4 = [0,0,1,0]`. Bits b0 = 1, b1 = 0, b2 = 0, b3 = 1.

| step | head | output |
|---|---|---|
| POP | b0 | 0 |
| EOT | b0 | 0 |
| HALT | b0 | 0 |
| ADVANCE | b1 | 0 |
| POP | b1 | 0 0 |
| EOT | b1 | 0 0 |
| HALT | b1 | 0 0 |
| RETREAT | b0 | 0 0 |
| PEEK | b0 | 0 0 |
| POP | b0 | 0 0 1 |
| ADVANCE | b1 | 0 0 1 |
| ADVANCE | b2 | 0 0 1 |
| EOT | b2 | 0 0 1 |
| HALT | b2 | 0 0 1 |
| RETREAT | b1 | 0 0 1 |
| PEEK | b1 | 0 0 1 |
| POP | b1 | 0 0 1 0 |
| ADVANCE | b2 | 0 0 1 0 |
| ADVANCE | b3 | 0 0 1 0 |
| EOT | b3 | 0 0 1 0 |
| HALT | b3 | 0 0 1 0 |

After `c2 = b0`, the first steady block probes to b2 (not last), retreats to b1,
and emits b1 = 0 as `c3`; the next block probes to b3, the last cell, and halts.
b2 and b3 are dropped. Output `[0,0,1,0]`, value 4. ✓

**`mul8` (k = 3), in full.** Three leading-zero sections, then `c3 = b0` reached
by two retreats, then steady blocks that probe three ahead and fall back two.

```
NOOP           *header*
POP            *c0: low zero*
...
EOT
HALT           *width 1: stop, output [0]*
ADVANCE
POP            *c1: low zero*
EOT
HALT           *width 2: stop, output [0,0]*
ADVANCE
POP            *c2: low zero*
EOT
HALT           *width 3: stop, output [0,0,0]*
RETREAT
RETREAT
PEEK
POP            *c3: emit b0*
...
ADVANCE
ADVANCE
ADVANCE
EOT
HALT           *the number ended here: stop*
RETREAT
RETREAT
PEEK
POP            *steady block: emit the next bit*
...
NOOP           *footer*
```

**Walkthrough — `mul8`, width 4.** Input `[1,0,0,1]`, value 9; expected
`8 · 9 mod 16 = 72 mod 16 = 8 = [0,0,0,1]`. Bits b0 = 1, b1 = 0, b2 = 0, b3 = 1.

| step | head | output |
|---|---|---|
| POP | b0 | 0 |
| EOT | b0 | 0 |
| HALT | b0 | 0 |
| ADVANCE | b1 | 0 |
| POP | b1 | 0 0 |
| EOT | b1 | 0 0 |
| HALT | b1 | 0 0 |
| ADVANCE | b2 | 0 0 |
| POP | b2 | 0 0 0 |
| EOT | b2 | 0 0 0 |
| HALT | b2 | 0 0 0 |
| RETREAT | b1 | 0 0 0 |
| RETREAT | b0 | 0 0 0 |
| PEEK | b0 | 0 0 0 |
| POP | b0 | 0 0 0 1 |
| ADVANCE | b1 | 0 0 0 1 |
| ADVANCE | b2 | 0 0 0 1 |
| ADVANCE | b3 | 0 0 0 1 |
| EOT | b3 | 0 0 0 1 |
| HALT | b3 | 0 0 0 1 |

Three zeros are laid down, the head walking to b2 to guard width 3; `c3` retreats
two cells to b0 and emits b0 = 1; the steady block probes to b3, the last cell,
and halts. b1, b2, b3 are dropped — the top three bits. Output `[0,0,0,1]`,
value 8. ✓

**Walkthrough — `mul8`, width 5.** Input `[1,0,0,0,1]`, value 17; expected
`8 · 17 mod 32 = 136 mod 32 = 8 = [0,0,0,1,0]`. Bits b0 = 1, b1 = b2 = b3 = 0,
b4 = 1. Abbreviating the verified three-zero prefix (identical to width 4 through
`c3`), the run resumes with the head on b0 and output `0 0 0 1`:

| step | head | output |
|---|---|---|
| (after c3) | b0 | 0 0 0 1 |
| ADVANCE | b1 | 0 0 0 1 |
| ADVANCE | b2 | 0 0 0 1 |
| ADVANCE | b3 | 0 0 0 1 |
| EOT | b3 | 0 0 0 1 |
| HALT | b3 | 0 0 0 1 |
| RETREAT | b2 | 0 0 0 1 |
| RETREAT | b1 | 0 0 0 1 |
| PEEK | b1 | 0 0 0 1 |
| POP | b1 | 0 0 0 1 0 |
| ADVANCE | b2 | 0 0 0 1 0 |
| ADVANCE | b3 | 0 0 0 1 0 |
| ADVANCE | b4 | 0 0 0 1 0 |
| EOT | b4 | 0 0 0 1 0 |
| HALT | b4 | 0 0 0 1 0 |

The first steady block probes to b3 (not last), retreats two cells to b1, and
emits b1 = 0 as `c4`; the second steady block probes to b4, the last cell, and
halts. The head returning to the just-emitted cell after each block is what keeps
every steady copy identical. Output `[0,0,0,1,0]`, value 8. ✓

**Higher powers (`k ≥ 3`).** Beyond `mul8`, the program is mechanical in the
depth `k = log₂` of the multiplier; `mul8` is its smallest instance. To write
`mul2^k`, emit in order:

1. *Header.* `NOOP`.
2. *Zero section 0.* `POP, EOT, HALT`.
3. *Zero sections 1 through k − 1*, each `ADVANCE, POP, EOT, HALT`. After all `k`
   zero sections the head rests on `b_{k-1}`, and an input of width `w ≤ k` has
   already halted with `w` zeros emitted.
4. *First-bit section* (`c_k = b0`): `RETREAT × (k − 1), PEEK, POP`.
5. *Steady block*, `ADVANCE × k, EOT, HALT, RETREAT × (k − 1), PEEK, POP`,
   repeated `256 − k − 1` times — enough to fill the 256-bit output once the `k`
   zeros and the first bit are counted.
6. *Footer.* `NOOP`.

Each steady block is `2k + 4` instructions, the zero prefix is `3 + 4(k − 1)`,
and the first-bit section is `k + 1`; the whole program's length follows from `k`
alone.

## `div2` (divide by two, modular)

Halving a binary number shifts every digit down one place, discards the low bit,
and writes a zero into the vacated top place. Under the library's modular
standard the width holds at *w*, but division never overflows — `⌊x/2⌋` is always
smaller than `x` — so the high zero is the honest leading zero of a smaller
number, not a wraparound. Halving 5 = `[1,0,1]` gives `⌊5/2⌋ = 2 = [0,1,0]`: the
low bit b0 = 1 is dropped, b1 and b2 slide down, and a zero fills the top.

The output is the input bits from b1 upward, in order, followed by one high
zero — *w* bits out for *w* bits in. The shift is realized by skipping the low
bit and walking the head forward, emitting each bit as the new bit one place
down. The high zero is the elegant part: a single zero is manufactured on the
stack at the very start and carried along untouched, and `POUR` writes it to the
output only when the read head reaches the last cell.

The manufactured zero is made by `DUP` on the empty stack — the read-below-bottom
rule supplies a 0, and `DUP` pushes a copy, leaving one genuine 0 on the stack.
From then on every section begins by testing the end: `EOT` then `POUR` writes
that zero and empties the stack if the head is on the last cell, and is inert
otherwise, so the zero survives every interior step and is poured exactly once,
as the top output bit, at whatever width the input turns out to be. A second
`EOT, HALT` stops the run at that same last cell. A width-1 input is the
degenerate case — a one-digit number lives in ℤ/2, where `⌊x/2⌋ = 0` for both
values — and the opening section handles it alone: the lone cell is the last, so
the zero is poured as the whole output `[0]` and the input bit is never read.

```
NOOP           *header*
DUP            *manufacture a real 0 on the stack — the high bit, carried along*
...
EOT
POUR           *at the last cell, write the high zero and empty the stack*
EOT
HALT           *at the last cell, stop*
ADVANCE
PEEK
POP            *c0: skip b0, emit b1 as the new low bit*
...
EOT
POUR           *steady block: pour the carried zero iff this is the last cell*
EOT
HALT
ADVANCE
PEEK
POP            *emit the next bit, shifted one place down*
...
NOOP           *footer*
```

The opening section, after manufacturing the zero, is the `c0` block: pour-and-
stop if the input is width 1, otherwise step to b1 and emit it. Each steady block
thereafter emits one more shifted bit, or — when its `EOT` finds the last cell —
pours the carried zero as the high output bit and halts. The head rests on the
just-emitted cell after each block, so the next block's `EOT` tests the next
candidate for the end.

**Walkthrough — width 1.** Input `[1]`, value 1; expected `⌊1/2⌋ = 0`. The head
column shows the resting cell; the stack is top-cell-first. (Input `[0]` follows
the identical path and likewise outputs `[0]`.)

| step | head | stack | output |
|---|---|---|---|
| DUP | b0 | 0 | — |
| EOT | b0 | 1, 0 | — |
| POUR | b0 | empty | 0 |
| EOT | b0 | 1 | 0 |
| HALT | b0 | empty | 0 |

b0 is the only cell, so the first `POUR` writes the carried zero and the
following `HALT` fires — the input bit is never read. Output `[0]`, value 0. ✓

**Walkthrough — width 3.** Input `[1,0,1]`, value 5; expected
`⌊5/2⌋ = 2 = [0,1,0]`. Bits b0 = 1, b1 = 0, b2 = 1.

| step | head | stack | output |
|---|---|---|---|
| DUP | b0 | 0 | — |
| EOT | b0 | 0, 0 | — |
| POUR | b0 | 0 | — |
| EOT | b0 | 0, 0 | — |
| HALT | b0 | 0 | — |
| ADVANCE | b1 | 0 | — |
| PEEK | b1 | 0, 0 | — |
| POP | b1 | 0 | 0 |
| EOT | b1 | 0, 0 | 0 |
| POUR | b1 | 0 | 0 |
| EOT | b1 | 0, 0 | 0 |
| HALT | b1 | 0 | 0 |
| ADVANCE | b2 | 0 | 0 |
| PEEK | b2 | 1, 0 | 0 |
| POP | b2 | 0 | 0 1 |
| EOT | b2 | 1, 0 | 0 1 |
| POUR | b2 | empty | 0 1 0 |
| EOT | b2 | 1 | 0 1 0 |
| HALT | b2 | empty | 0 1 0 |

`c0` skips b0 and emits b1 = 0; the first steady block emits b2 = 1 as `c1`; the
second steady block finds b2 is the last cell, pours the carried zero as `c2`,
and halts. The low bit b0 = 1 is discarded, the high zero fills the top. Output
`[0,1,0]`, value 2. ✓

## `div4`, `div8`, … (divide by a higher power of two, modular)

`div2^k` is `⌊x / 2^k⌋`: drop the low `k` bits, shift the rest down, and fill the
top `k` places with zeros. Division never overflows, so the high zeros are honest
leading zeros of a smaller number. The output is the input bits from `b_k`
upward, in order, followed by `k` high zeros — *w* bits out for *w* bits in. When
the input is no wider than `k` the result is all zeros, since `⌊x / 2^k⌋ = 0` for
`w ≤ k`.

The high zeros are manufactured during the skip, one per low bit passed over.
Each of the first `k` cells contributes a zero to the stack, so the pile of
parked zeros always equals the number of low cells visited. If the input ends
during the skip — a width `w ≤ k` input — exactly `w` zeros are parked, and they
are poured as the whole output. If the input runs past the skip, `k` zeros are
parked, the bits from `b_k` up are emitted shifted down, and the parked `k` zeros
are poured as the high bits when the end is reached. The width-dependent count of
trailing zeros falls out of manufacturing them one per skipped cell, rather than
all at once.

The program is two block types sharing a common tail `EOT, POUR, EOT, HALT,
ADVANCE` — pour the parked zeros and stop if this is the last cell, else step on:

- **Skip block** (`k` of them, one per low bit): `DUP` then the tail. `DUP`
  pushes a fresh zero — copying the zero below, or reading `0` on the empty stack
  at `b0`.
- **Bit block** (steady, one per surviving bit): `PEEK, POP` then the tail. The
  current bit is emitted, shifted down into the output, while the parked zeros
  ride the stack bottom untouched.

A terminal `POUR` is reached from whichever phase the input ends in: the skip
phase for a short input, the bit phase for a long one, with no special-casing.

`div4` is `k = 2`, `div8` is `k = 3`, and the family continues with one more skip
block per step.

**`div4` (k = 2).**

```
NOOP           *header*
DUP            *skip b0: park a zero*
...
EOT
POUR           *if last cell, pour the parked zeros and finish*
EOT
HALT
ADVANCE
DUP            *skip b1: park a second zero*
EOT
POUR
EOT
HALT
ADVANCE
PEEK
POP            *c0: emit b2, shifted down*
...
EOT
POUR           *steady bit block: emit a bit, or pour the two high zeros at the end*
EOT
HALT
ADVANCE
PEEK
POP
...
NOOP           *footer*
```

**Walkthrough — `div4`, width 2.** Input `[1,1]`, value 3; expected
`⌊3/4⌋ = 0 = [0,0]`. Stack top-cell-first.

| step | head | stack | output |
|---|---|---|---|
| DUP | b0 | 0 | — |
| EOT | b0 | 0, 0 | — |
| POUR | b0 | 0 | — |
| EOT | b0 | 0, 0 | — |
| HALT | b0 | 0 | — |
| ADVANCE | b1 | 0 | — |
| DUP | b1 | 0, 0 | — |
| EOT | b1 | 1, 0, 0 | — |
| POUR | b1 | empty | 0 0 |
| EOT | b1 | 1 | 0 0 |
| HALT | b1 | empty | 0 0 |

The skip parks one zero at `b0`, a second at `b1`; `b1` is the last cell, so
`POUR` drains both as the output. No input bit is read. Output `[0,0]`,
value 0. ✓

**Walkthrough — `div4`, width 4.** Input `[1,1,0,1]`, value 11; expected
`⌊11/4⌋ = 2 = [0,1,0,0]`. Bits b0=1, b1=1, b2=0, b3=1.

| step | head | stack | output |
|---|---|---|---|
| DUP | b0 | 0 | — |
| EOT | b0 | 0, 0 | — |
| POUR | b0 | 0 | — |
| EOT | b0 | 0, 0 | — |
| HALT | b0 | 0 | — |
| ADVANCE | b1 | 0 | — |
| DUP | b1 | 0, 0 | — |
| EOT | b1 | 0, 0, 0 | — |
| POUR | b1 | 0, 0 | — |
| EOT | b1 | 0, 0, 0 | — |
| HALT | b1 | 0, 0 | — |
| ADVANCE | b2 | 0, 0 | — |
| PEEK | b2 | 0, 0, 0 | — |
| POP | b2 | 0, 0 | 0 |
| EOT | b2 | 0, 0, 0 | 0 |
| POUR | b2 | 0, 0 | 0 |
| EOT | b2 | 0, 0, 0 | 0 |
| HALT | b2 | 0, 0 | 0 |
| ADVANCE | b3 | 0, 0 | 0 |
| PEEK | b3 | 1, 0, 0 | 0 |
| POP | b3 | 0, 0 | 0 1 |
| EOT | b3 | 1, 0, 0 | 0 1 |
| POUR | b3 | empty | 0 1 0 0 |
| EOT | b3 | 1 | 0 1 0 0 |
| HALT | b3 | empty | 0 1 0 0 |

Two zeros are parked over the skip of b0, b1; the bit phase emits b2 = 0 then
b3 = 1, shifted down; at the last cell the two parked zeros pour as the high
bits. Output `[0,1,0,0]`, value 2. ✓

**`div8` (k = 3)** is the same with a third skip block (`DUP, EOT, POUR, EOT,
HALT, ADVANCE`) before the bit phase, parking three zeros. Verified at widths
2 → `[0,0]`, 3 → `[0,0,0]`, 4 → `⌊15/8⌋ = 1 = [1,0,0,0]`, and
5 → `⌊21/8⌋ = 2 = [0,1,0,0,0]`.

**Construction (`k ≥ 2`).** Header `NOOP`; then `k` skip blocks `DUP, EOT, POUR,
EOT, HALT, ADVANCE`; then bit blocks `PEEK, POP, EOT, POUR, EOT, HALT, ADVANCE`
repeated enough to carry the output to 256 bits; then footer `NOOP`. The skip and
bit blocks differ only in their head — `DUP` to manufacture a high zero, or
`PEEK, POP` to emit a shifted bit — over the shared tail `EOT, POUR, EOT, HALT,
ADVANCE`.

## `add` (ripple adder, two tapes, modular)

Adds two numbers, one on each of two input tapes, both least-significant-bit
first, and writes their sum least-significant-bit first. The sum is taken to the
width of the *shorter* tape: the sweep stops as soon as either tape reaches its
last cell, and the carry out of that final position falls off, so the result is
`(A + B)` reduced to the shorter operand's width. Two width-*w* operands give
`(A + B) mod 2^w`; `[1,1] + [1,0]` (3 + 1 in two bits) is `[0,0]`, the wrap of
4 mod 4. Unequal widths are handled rather than forbidden — the operator is total,
as a genetic-programming substrate requires — and a caller that wants the high
bits of the longer operand pads the shorter one with leading zeros first, which
does not change its value.

**The algorithm.** Addition runs from the low end up, carrying. At each position
three one-bit quantities meet: the bit `a` from tape A, the bit `b` from tape B,
and the running `carry` from the position below, which starts at 0. Their total
is a number from 0 to 3; its low bit is the `sum` digit written out, and its high
bit is the `carry` passed up. The carry is the only state threaded between
positions.

**The full adder as two half-adders.** A half-adder adds two bits, taking their
XOR for the sum and their AND for the carry. A position has three inputs, so it
is done in two stages. First, half-add `a` and `b`, giving a `partial` sum and a
carry `carryAB`. Second, half-add `partial` with the incoming `carry`, giving the
final `sum` bit and a carry `carryPC`. Then take the OR of the two stage carries,
`carryAB OR carryPC`, which is the `carryOut` to the next position — the two
stages never both carry at once, so the OR combines them safely.

**The half-adder block** is the verified twelve-instruction sequence

```
OVER, OVER, DUP, DUP, NAND, SWAP, ROT, CMOV, SWAP, ROT, DUP, CMOV
```

with stack effect `[.., q, p] → [.., p XOR q, p AND q]` — the two top operands
replaced by their sum below and their carry on top, everything beneath restored.

**Two tapes, read in lockstep.** Each position reads `a` from tape A, switches
with `NEXT-TAPE` to read `b` from tape B, and switches back, so tape A is active
between positions. The carry rides the stack bottom throughout, seeded as a
physical 0 by a `DUP` on the empty stack in the header — the same seeding the
increment family uses, needed here because the position's `ROT` steps require the
carry to be a real stack cell, not the implicit below-bottom zero.

**Order within a position: add, then test, then advance.** The end test comes
*after* the sum bit is emitted, not before, so the final position — the one
holding a last cell — is actually added before the machine stops. The test senses
both tapes' ends with `EOT` (which reads without moving the head), ORs them, and
halts if either is set; only if neither is set do the heads advance to the next
position. Putting the test first would skip the top bit.

```
NOOP           *header*
DUP            *seed carry = 0 (empty-stack read), as a physical cell*
...
PEEK           *read a (tape A active)*
NEXT-TAPE
PEEK           *read b (tape B)*
NEXT-TAPE      *tape A active again*
OVER           *half-add a and b …*
OVER
DUP
DUP
NAND
SWAP
ROT
CMOV
SWAP
ROT
DUP
CMOV           *… → carryAB on top, partial below, carry beneath*
ROT            *tuck carryAB under: → carry, carryAB, partial*
ROT            *→ partial, carry, carryAB*
OVER           *half-add partial and carry …*
OVER
DUP
DUP
NAND
SWAP
ROT
CMOV
SWAP
ROT
DUP
CMOV           *… → carryPC on top, sum below, carryAB beneath*
SWAP           *→ sum, carryPC, carryAB*
POP            *emit sum*
DUP            *OR the two carries: carryAB OR carryPC …*
NAND
SWAP
DUP
NAND
NAND           *… → carryOut, the carry for the next position*
EOT            *end test: tape A at last cell?*
DUP
NAND
NEXT-TAPE
EOT            *tape B at last cell?*
DUP
NAND
NAND           *→ (A ended) OR (B ended)*
HALT           *stop if either tape ended — sum bit already emitted*
NEXT-TAPE      *tape A active again*
ADVANCE        *advance tape A*
NEXT-TAPE
ADVANCE        *advance tape B*
NEXT-TAPE      *tape A active again*
...
NOOP           *footer*
```

Verified by hand at: `[1,1] + [1,0] = [0,0]` (wrap, 4 mod 4); `[1,1,0] + [1,0,0]
= [0,0,1]` (3 + 1 = 4, three-position ripple, no wrap); `[1,0,1] + [1] = [0]`
(unequal widths, stops at the shorter tape, (5 + 1) mod 2 = 0); and
`[1] + [1] = [0]` (1 + 1, carry off the top dropped).

## `subtract` (ripple subtractor, two tapes, modular)

Computes A − B, the number on tape A minus the number on tape B, both
least-significant-bit first, result least-significant-bit first. Like `add` it
runs to the shorter tape's width and drops the final state bit, so the result is
`(A − B)` reduced to that width. There are no negative numbers: when B exceeds A
the borrow runs off the top and the difference wraps, exactly as `decrement`
wraps `0 − 1` to all ones. So `[1,0] − [1,1]` (1 − 3 in two bits) is `[0,1]`, the
value 2, since `(1 − 3) mod 4 = 2`. Unequal widths are handled, not forbidden;
the caller pads the shorter operand with leading zeros to keep the high bits.

**The algorithm.** Subtraction runs from the low end up, borrowing. At each
position three one-bit quantities meet: the bit `a` from tape A, the bit `b` from
tape B, and the `borrow` owed from the position below, which starts at 0. The
difference bit written out is 1 when an odd number of the three are 1 — the same
parity that gives the adder its sum bit. The borrow passed up is owed when what
must be taken away, `b` together with the incoming `borrow`, exceeds what is
available, `a`: borrowing when `a` is 0 and either `b` or the `borrow` is 1, and
also when `a` is 1 but both `b` and the `borrow` are 1. The borrow is the only
state threaded between positions, and at the top it falls off — a borrow still
owed after the last position is the underflow, and discarding it is the modular
wrap.

**Subtraction is addition with the first operand complemented.** Borrowing in
`A − B` happens exactly where carrying would happen in `(NOT A) + B`, so the
ripple subtractor is the ripple adder with two surgical changes and nothing else
touched. First, the bit `a` read from tape A is negated before it enters the
position; this turns the adder's carry recurrence into the borrow recurrence, and
the carry-out the adder computes becomes the borrow-out. Second, negating `a`
also flips the difference bit the position would emit, so the emitted bit is
negated to restore it: the final difference is `a XOR b XOR borrow`, the same
form as the adder's sum. The half-adder block, the two-stage structure, the
tuck, the OR that combines the two stage-borrows, the seeded state, the
termination gate, and the head advance are all identical to `add`.

The borrow seeds at 0 — no borrow into the lowest position — supplied as a
physical cell by the header `DUP` on the empty stack, and the borrow out of the
final position falls off, which is the modular wrap.

```
NOOP           *header*
DUP            *seed borrow = 0 (empty-stack read), as a physical cell*
...
PEEK           *read a (tape A active)*
DUP
NAND           *negate a — subtraction is addition with a complemented*
NEXT-TAPE
PEEK           *read b (tape B)*
NEXT-TAPE      *tape A active again*
OVER           *half-add (not a) and b …*
OVER
DUP
DUP
NAND
SWAP
ROT
CMOV
SWAP
ROT
DUP
CMOV           *… → carryAB on top, partial below, borrow beneath*
ROT            *tuck carryAB under: → borrow, carryAB, partial*
ROT            *→ partial, borrow, carryAB*
OVER           *half-add partial and borrow …*
OVER
DUP
DUP
NAND
SWAP
ROT
CMOV
SWAP
ROT
DUP
CMOV           *… → carryPC on top, raw diff below, carryAB beneath*
SWAP           *→ raw diff, carryPC, carryAB*
DUP
NAND           *negate the difference bit — restores a XOR b XOR borrow*
POP            *emit the difference bit*
DUP            *OR the two stage borrows: carryAB OR carryPC …*
NAND
SWAP
DUP
NAND
NAND           *… → borrowOut, the borrow for the next position*
EOT            *end test: tape A at last cell?*
DUP
NAND
NEXT-TAPE
EOT            *tape B at last cell?*
DUP
NAND
NAND           *→ (A ended) OR (B ended)*
HALT           *stop if either tape ended — difference bit already emitted*
NEXT-TAPE      *tape A active again*
ADVANCE        *advance tape A*
NEXT-TAPE
ADVANCE        *advance tape B*
NEXT-TAPE      *tape A active again*
...
NOOP           *footer*
```

Verified by hand at: `[1,0] − [1,1] = [0,1]` (1 − 3, underflow wraps to 2 mod 4);
`[1,0,1] − [1,0,0] = [0,0,1]` (5 − 1 = 4, no underflow); `[0,1] − [1,0] = [1,0]`
(2 − 1 = 1, borrow rippling one position); and `[1,0,1] − [1] = [0]` (unequal
widths, stops at the shorter tape, (5 − 1) mod 2 = 0).

## `lt` (less-than verdict, two tapes)

Compares two numbers, one on each input tape, both least-significant-bit first,
and emits a single bit: 1 if A < B, else 0. The comparison runs to the shorter
tape's width — the scan stops as soon as either tape reaches its last cell — so
`lt` reports whether A is less than B as read to the shorter width. Unequal
widths are handled rather than forbidden; a caller wanting a full-width
comparison pads the shorter operand with leading zeros first.

**The algorithm.** Scan the bits from low to high, carrying a one-bit verdict
`lt` = "A is less than B so far", initialized to 0. At each position, read `a`
and `b`. If they agree, the verdict carries forward unchanged — the tie is
broken, if at all, by a higher bit. If they differ, the verdict becomes `b`:
when the differing bit has B set, A is below B at the highest difference seen so
far, and a higher difference will overwrite this in turn. After the last
position, the surviving verdict is the answer.

The per-position update is a single selection: `new_lt = CMOV(d; lt, b)` where
`d = a XOR b`. When the bits differ (`d = 1`) the verdict becomes `b`; when they
agree (`d = 0`) it stays `lt`. Because a higher differing bit overwrites a lower
one, the most significant difference always decides — which is the correct
unsigned comparison.

**State and output.** The verdict is the only state, seeded to 0 by the header
`DUP` on the empty stack, carried as a physical cell so the position's `ROT`
steps always have three real elements. Unlike `add`, `lt` emits nothing per
position — it accumulates a verdict over the whole scan and emits one bit at the
end. The single output bit is written at termination by a conditional `POUR`.

**The end-test.** `lt` terminates when either tape reaches its last cell, and it
must emit the verdict bit at that moment, before halting. The conditional emit
uses `POUR`, which drains the stack only when its trigger is 1 — but `POUR`
consumes its trigger, so the end signal `e_or` (= "tape A ended OR tape B
ended") is computed twice: once to gate the `POUR` that emits the verdict, and
again to gate the `HALT`. Between them, the verdict either drains to the output
(at end) or stays on the stack (otherwise), so a non-terminating position leaves
the verdict intact for the next position.

The header is `NOOP, DUP`; the body below is unrolled up to 256 times; the
footer is `NOOP`.

```
NOOP           *header*
DUP            *seed lt = 0 (empty-stack read), as a physical cell*
...
PEEK           *read a (tape A active)*
NEXT-TAPE      *active B*
PEEK           *read b (tape B)*
NEXT-TAPE      *active A again*
DUP            *copy b → [b, b, a, lt]*
ROT            *→ [a, b, b, lt]*
DUP            *compute d = a XOR b (preserving the lower b) …*
DUP
NAND
SWAP
ROT
CMOV           *… → [d, b, lt]*
ROT            *→ [lt, d, b]*
SWAP           *→ [d, lt, b]*
CMOV           *new_lt = CMOV(d; lt, b) → [new_lt]*
EOT            *first end signal: tape A at last cell?*
DUP
NAND           *→ NOT eA*
NEXT-TAPE      *active B*
EOT            *tape B at last cell?*
DUP
NAND           *→ NOT eB*
NAND           *→ e_or = (A ended) OR (B ended)*
POUR           *if e_or = 1, emit the verdict and empty the stack*
EOT            *second end signal, active B*
DUP
NAND           *→ NOT eB*
NEXT-TAPE      *active A*
EOT
DUP
NAND           *→ NOT eA*
NAND           *→ e_or*
HALT           *stop if either tape ended — verdict already emitted*
ADVANCE        *advance tape A*
NEXT-TAPE
ADVANCE        *advance tape B*
NEXT-TAPE      *active A again*
...
NOOP           *footer*
```

Verified by hand at `[0,1] < [1,1]` (2 < 3, emits 1) and `[1,1] < [0,1]`
(3 < 2 is false, emits 0), exercising the verdict-carries-forward case (equal
high bits) and the verdict-replaced case (differing bits), and the conditional
emit firing exactly once at termination.

## `ne` (not-equal verdict, two tapes)

Compares two numbers, one on each input tape, both least-significant-bit first,
and emits a single bit: 1 if A and B differ, 0 if they are equal. Like `lt` it
runs to the shorter tape's width and emits one verdict bit at termination.
Equality is the complement, `EQ = NOT ne`; `ne` is the primitive because it is
the verdict that initializes to 0, which the empty stack supplies for free.

**The algorithm.** Scan the bits from low to high, carrying a one-bit verdict
`ne` = "A and B have differed somewhere so far", initialized to 0. At each
position, read `a` and `b`; if they differ, the verdict latches to 1 and never
resets. The update is

  `new_ne = ne OR (a XOR b)`.

No selection is needed — the per-bit "differ" flag is `a XOR b`, and the verdict
is the running OR of these flags. After the last position the surviving verdict
is the answer.

**Structure shared with `lt`.** The verdict is the only state, seeded to 0 by
the header `DUP`, carried as a physical cell. `ne` emits nothing per position; it
accumulates the verdict and writes one bit at termination through the same
conditional-`POUR`-then-`HALT` end-test as `lt`, computing the end signal `e_or`
twice — once to gate the emit, once to gate the halt. The body is two
instructions shorter than `lt`'s: there is no operand to preserve and no final
selection, only the XOR of the two bits ORed into the verdict.

The header is `NOOP, DUP`; the body below is unrolled up to 256 times; the
footer is `NOOP`.

```
NOOP           *header*
DUP            *seed ne = 0 (empty-stack read), as a physical cell*
...
PEEK           *read a (tape A active)*
NEXT-TAPE      *active B*
PEEK           *read b (tape B)*
NEXT-TAPE      *active A again*
DUP            *compute d = a XOR b …*
DUP
NAND
SWAP
ROT
CMOV           *… → [d, ne]*
DUP            *OR: new_ne = ne OR d …*
NAND
SWAP
DUP
NAND
NAND           *… → [new_ne]*
EOT            *first end signal: tape A at last cell?*
DUP
NAND           *→ NOT eA*
NEXT-TAPE      *active B*
EOT            *tape B at last cell?*
DUP
NAND           *→ NOT eB*
NAND           *→ e_or = (A ended) OR (B ended)*
POUR           *if e_or = 1, emit the verdict and empty the stack*
EOT            *second end signal, active B*
DUP
NAND           *→ NOT eB*
NEXT-TAPE      *active A*
EOT
DUP
NAND           *→ NOT eA*
NAND           *→ e_or*
HALT           *stop if either tape ended — verdict already emitted*
ADVANCE        *advance tape A*
NEXT-TAPE
ADVANCE        *advance tape B*
NEXT-TAPE      *active A again*
...
NOOP           *footer*
```

Verified by hand at `[1,0] ≠ [1,1]` (1 ≠ 3, emits 1) and `[1,0] ≠ [1,0]`
(1 = 1, emits 0), exercising the latch (verdict reaching 1 and staying) and the
all-equal case, with the conditional emit firing once at termination.

## `select` (control-driven interleave, three tapes)

Merges two numbers bit by bit under the direction of a control tape. Tape 1
carries X, tape 2 carries Y, tape 3 carries the control C, all
least-significant-bit first. At each position the output bit is X's bit if the
current control bit is 1, else Y's bit. The output streams one bit per position,
same width as the data — an emit-as-you-go operator, not a verdict.

**The control tape wraps; the data tapes bound the scan.** X and Y are advanced
in lockstep and the scan stops when either reaches its last cell, so the output
width is the shorter of X and Y. C is advanced too, but its head wraps at its
last cell rather than ending the scan. This single fact makes `select` cover a
range of behaviors with one program:

- A length-1 C never moves off its cell (it wraps to itself), so the same
  control bit gates every position — a constant select, forwarding all of X or
  all of Y.
- A C as long as the data gives a one-shot custom interleave, each position
  routed independently.
- A C shorter than the data gives a periodic mask: `[1,0]` alternates X and Y,
  `[1,1,0]` takes two from X then one from Y repeating, and so on. The period is
  C's length; a final partial period is well defined.

**The per-position core.** Read x, y, and c by cycling the active tape
1 → 2 → 3 → 1, leaving the stack as `[c, y, x]` — exactly the order `CMOV`
consumes (selector on top, then the value chosen when the control is 0, then the
value chosen when it is 1). `CMOV` emits x when c is 1 and y when c is 0; `POP`
writes it. No state is carried between positions — the control is read fresh
each time — so there is no header seed.

**Termination and advance.** The end-test tests only X and Y (a two-`EOT` OR,
as in `lt` and `add`), halting after the bit is emitted if either data tape
ended. The advance then steps all three heads by one; C's `ADVANCE` is what
wraps it, and it is the whole mechanism behind the periodic behavior — at C's
last cell the head returns to the first.

The header is `NOOP`; the body below is unrolled up to 256 times; the footer is
`NOOP`.

```
NOOP           *header*
...
PEEK           *read x (tape 1)*
NEXT-TAPE      *active 2*
PEEK           *read y (tape 2)*
NEXT-TAPE      *active 3*
PEEK           *read c (tape 3)*
NEXT-TAPE      *active 1 again (3 → 1)*
CMOV           *[c, y, x] → x if c = 1 else y*
POP            *emit the selected bit*
EOT            *tape 1 = X at last cell?*
DUP
NAND           *→ NOT eX*
NEXT-TAPE      *active 2*
EOT            *tape 2 = Y at last cell?*
DUP
NAND           *→ NOT eY*
NAND           *→ eX OR eY*
HALT           *stop if either data tape ended — bit already emitted*
ADVANCE        *advance Y (active tape 2)*
NEXT-TAPE      *active 3*
ADVANCE        *advance C — wraps at its last cell*
NEXT-TAPE      *active 1*
ADVANCE        *advance X*
...
NOOP           *footer*
```

Verified by hand at X = `[1,1,1,1]`, Y = `[0,0,0,0]`, C = `[1,0]`, which emits
`[1,0,1,0]` — the alternating interleave, with C's head cycling 0, 1, 0, 1
across the four positions. A length-1 C recovers the constant-select case, and a
data-length C gives a one-shot interleave.
