# The Primitive Library

Specifications for the primitive programs available as CGP function-set
entries (`cgp.md`). Each is a program on the machine of `stack.md`. The
Boolean operators of `boole.md` will eventually be folded into this file; for
now this collects the multi-bit operators.

**Number encoding.** Bare bits, LSB-first, no framing. A number is its bits on
a tape; the width is the tape length. End-of-input is sensed in-band by EOT,
not by a terminator, so a single program serves an input of any width up to its
unroll depth — 256 body copies — and truncates a longer input to the first 256
bits.

**Presentation.** Each program is an optional header (runs once), a body shown
once between ellipses and unrolled up to N ≤ 256 times, and an optional footer.
Every program opens and closes with a NOOP, so the header and footer are never
empty. The unrolled artifact is the body repeated; the document shows it once.
No loops: the machine is straight-line (`stack.md`), every body copy is
physically present, and EOT→HALT ends the program in-band when the input is
exhausted.

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
every input bit equalled one. The operator always writes this final carry as one
more bit, so its output is always one bit longer than its input. When the carry
had already been killed, that last bit is a 0 — a leading zero that leaves the
value unchanged, which the companion operator `nibble` removes when a tight
width is wanted. Only when the carry was still alive at the end is the last bit
a 1: the new top place value of a number that has just rolled over, one digit
wider than before.

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
DUP
NAND        *carry-out = ¬new_d — the bit to append at the end*
EOT         *push 1 iff at the last cell*
POUR        *at the last cell, emit the carry-out and empty the stack*
EOT         *push 1 iff at the last cell, again*
HALT        *halt if so*
DUP
NAND        *interior: recover new_d from the carry-out*
ADVANCE     *step to the next bit*
...
NOOP        *footer — reached only if the input is longer than 256 bits*
```

The header's DUP seeds d = 0 for the first copy; a column entering with d = 1 is
therefore a later copy. The walkthrough below traces eight cases. Legend: `i` =
interior bit (EOT = 0); `L` = the 256th / last bit (EOT = 1); the two digits are
(d, x), the carry-state and the data bit. Stacks are top-cell-first (top row =
top of stack).

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

**16. DUP** — copy new_d.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| new_d | 1 | 0 | 1 | 1 | 1 | 0 | 1 | 1 |
| new_d | 1 | 0 | 1 | 1 | 1 | 0 | 1 | 1 |

**17. NAND** — NAND the two copies → ¬new_d = carry-out.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| carry-out | 0 | 1 | 0 | 0 | 0 | 1 | 0 | 0 |

**18. EOT** — push 1 iff the head is at the last cell.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| EOT | 0 | 0 | 0 | 0 | 1 | 1 | 1 | 1 |
| carry-out | 0 | 1 | 0 | 0 | 0 | 1 | 0 | 0 |

**19. POUR** — pop the top; if 1, drain the rest (the carry-out) to the output and empty; else inert. The L columns emit their carry-out here: 0, 1, 0, 0.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| carry-out | 0 | 1 | 0 | 0 | — | — | — | — |

**20. EOT** — push 1 iff at the last cell, again.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| EOT | 0 | 0 | 0 | 0 | 1 | 1 | 1 | 1 |
| carry-out | 0 | 1 | 0 | 0 | — | — | — | — |

**21. HALT** — pop the top; halt iff 1. The L columns stop here, having emitted out then the carry-out.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| carry-out | 0 | 1 | 0 | 0 | halts | halts | halts | halts |

**22. DUP** — (interior) copy the carry-out.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| carry-out | 0 | 1 | 0 | 0 | — | — | — | — |
| carry-out | 0 | 1 | 0 | 0 | — | — | — | — |

**23. NAND** — (interior) NAND the two copies, recovering new_d.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| new_d | 1 | 0 | 1 | 1 | — | — | — | — |

**24. ADVANCE** — step to the next bit; the stack carries new_d into the next copy.

| stack | i00 | i01 | i10 | i11 | L00 | L01 | L10 | L11 |
|---|---|---|---|---|---|---|---|---|
| new_d | 1 | 0 | 1 | 1 | — | — | — | — |

Every last-bit column halts after emitting out and then a carry-out bit, so each
produces a 257th bit. Only L01 — carry alive, last bit one, the full 256 ones —
makes that bit a 1, the genuine overflow to 2^256; L00, L10, and L11 each emit a
high 0 that `nibble` would trim.

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
