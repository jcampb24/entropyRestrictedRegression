# Boolean Operators

The single-bit functions: fixed-arity, single-pass — the simplest programs on
the machine, predating the streaming idiom used for integers in
`arithmetic.md`. The conventions they establish (stack-agnostic,
stack-preserving, composable) carry over to the integer building blocks.

Two tape conventions govern this library:

- **Unary operators read one input tape.** Their single argument is on the
  active tape (tape 1); they read it with PEEK and never advance, since there
  is nothing after it to reach.
- **Binary operators read two input tapes.** Argument *a* is on tape 1, *b* on
  tape 2. A program reads *a* with PEEK while tape 1 is active, switches with
  NEXT-TAPE to read *b*, and switches back so that **tape 1 is the active tape
  after all input**. This restore-to-tape-1 discipline is what makes the
  building blocks compose uniformly: removing the final POP leaves the
  function's value on top of the stack with tape 1 active, ready for the next
  block to read its own *a*. The binary operators assume a configuration of
  exactly two input tapes — the cyclic restore (a second NEXT-TAPE returning to
  tape 1) is a two-tape fact.

An operator does not read an input it does not use: a function that depends only
on *a* never touches tape 2, one that depends only on *b* visits tape 2 and
returns, and the constant functions read nothing at all. "Binary" classifies the
function family (the sixteen functions of two arguments), not the number of
tapes a given program happens to touch.

## Unary Boolean operators

There are 2^(2^1) = 4 unary Boolean functions {0,1} → {0,1}. Each has a short
program, and all four below are *stack-agnostic* (they produce the correct
output regardless of stack state at program start) and *stack-preserving* (they
leave the stack as they found it). Removing the final POP yields a composable
building block that leaves the function's value on top of the stack.

| # | TT | Name     | Program                                      | Length |
|---|----|----------|----------------------------------------------|--------|
| 0 | 00 | FALSE    | DUP, DUP, DUP, NAND, NAND, DUP, NAND, POP    | 8      |
| 1 | 01 | IDENTITY | PEEK, POP                                    | 2      |
| 2 | 10 | NOT      | PEEK, DUP, NAND, POP                         | 4      |
| 3 | 11 | TRUE     | DUP, DUP, DUP, NAND, NAND, POP               | 6      |

(Truth-table convention: values listed as f(0), f(1).)

**IDENTITY** reads the input bit and writes it. PEEK places the input on top of
the stack; POP writes it to the output and removes it. Two instructions; the
stack ends as it started.

**NOT** reads the input, negates it via the DUP+NAND idiom (NAND(a, a) = NOT a),
writes the result. The input bit and its negation are introduced and consumed
within the program.

**TRUE** and **FALSE** are constant functions: they do not read their input at
all. Each produces a 1 or a 0 on top of the stack without assuming what is
already there. The core construction is

> DUP, DUP, DUP, NAND, NAND

which puts four copies of the unknown top value x on the stack, then NANDs two
of them to produce NOT x, then NANDs that with one more copy of x to produce
NAND(x, NOT x) = NOT(x AND NOT x) = NOT 0 = 1 — regardless of x. The original x
is preserved beneath the manufactured 1, which POP then writes and removes.

**FALSE** appends one more DUP, NAND to negate the manufactured 1 into a 0
before writing.

The TRUE and FALSE constructions are the most instructive entries in this small
library: they show that arbitrary constants can be produced on a stack of
unknown contents using only NAND and stack duplication, without leaning on stack
initialization or input values.

## Binary Boolean operators

There are 2^(2^2) = 16 binary Boolean functions {0,1}² → {0,1}. The programs
below are all stack-agnostic and stack-preserving, and all follow the
restore-to-tape-1 input discipline: the active tape after input is always tape
1. Removing the final POP yields a composable building block.

The recurring input prefixes are: for a function of both arguments,
PEEK, NEXT-TAPE, PEEK, NEXT-TAPE reads *a* from tape 1 and *b* from tape 2 and
restores tape 1, leaving [a, b] on the stack — the same stack picture two reads
on one tape used to give, so each operator's *computation* is unchanged from the
single-tape version. A function of *a* alone reads PEEK; a function of *b* alone
reads NEXT-TAPE, PEEK, NEXT-TAPE; a constant reads nothing.

| # | TT   | Name        | Program                                                                | Length |
|---|------|-------------|------------------------------------------------------------------------|--------|
| 0 | 0000 | FALSE       | DUP, DUP, DUP, NAND, NAND, DUP, NAND, POP                              | 8      |
| 1 | 0001 | AND         | PEEK, NEXT-TAPE, PEEK, NEXT-TAPE, NAND, DUP, NAND, POP                 | 8      |
| 2 | 0010 | a AND NOT b | PEEK, NEXT-TAPE, PEEK, NEXT-TAPE, DUP, NAND, NAND, DUP, NAND, POP      | 10     |
| 3 | 0011 | a           | PEEK, POP                                                              | 2      |
| 4 | 0100 | NOT a AND b | PEEK, DUP, NAND, NEXT-TAPE, PEEK, NEXT-TAPE, NAND, DUP, NAND, POP      | 10     |
| 5 | 0101 | b           | NEXT-TAPE, PEEK, NEXT-TAPE, POP                                        | 4      |
| 6 | 0110 | XOR         | PEEK, DUP, DUP, NAND, SWAP, NEXT-TAPE, PEEK, NEXT-TAPE, CMOV, POP      | 10     |
| 7 | 0111 | OR          | PEEK, DUP, NAND, NEXT-TAPE, PEEK, NEXT-TAPE, DUP, NAND, NAND, POP      | 10     |
| 8 | 1000 | NOR         | PEEK, DUP, NAND, NEXT-TAPE, PEEK, NEXT-TAPE, DUP, NAND, NAND, DUP, NAND, POP | 12 |
| 9 | 1001 | XNOR        | PEEK, DUP, DUP, NAND, NEXT-TAPE, PEEK, NEXT-TAPE, CMOV, POP            | 9      |
| 10| 1010 | NOT b       | NEXT-TAPE, PEEK, NEXT-TAPE, DUP, NAND, POP                            | 6      |
| 11| 1011 | b → a       | PEEK, DUP, NAND, NEXT-TAPE, PEEK, NEXT-TAPE, NAND, POP                | 8      |
| 12| 1100 | NOT a       | PEEK, DUP, NAND, POP                                                   | 4      |
| 13| 1101 | a → b       | PEEK, NEXT-TAPE, PEEK, NEXT-TAPE, DUP, NAND, NAND, POP                | 8      |
| 14| 1110 | NAND        | PEEK, NEXT-TAPE, PEEK, NEXT-TAPE, NAND, POP                           | 6      |
| 15| 1111 | TRUE        | DUP, DUP, DUP, NAND, NAND, POP                                         | 6      |

(Truth-table convention: values listed as f(0,0), f(0,1), f(1,0), f(1,1).)

**FALSE** does not depend on its inputs and reads neither tape. It manufactures
a 1 on top of the stack via the DUP-cubed pattern (three DUPs add copies of the
unknown top value x, leaving four instances; the first NAND produces NOT x, the
second produces NAND(x, NOT x) = 1, regardless of x), negates that 1 to a 0 with
one more DUP, NAND, then writes the 0. The original top of the stack is
preserved beneath the manufactured value, which POP removes.

**AND** reads a from tape 1 and b from tape 2, NANDs them, and negates the
result via DUP+NAND to produce a AND b. Stack-preserving by construction; every
operation acts only on values introduced by the program.

**a AND NOT b** reads a and b, negates b in place via DUP+NAND on top, then ANDs
the result with the a sitting beneath via NAND-then-negate. Net stack effect
zero, all operations on freshly-introduced values.

**a** is the projection onto a. It depends only on the first input, so it reads
tape 1 and never touches tape 2: PEEK places a on the stack, POP writes it.
Two instructions — the shortest program in the binary library, tied with the
unary IDENTITY it mirrors.

**NOT a AND b** reads a from tape 1 and negates it via DUP+NAND while tape 1 is
active, then switches to read b and switches back, then ANDs the negation with b
via NAND-then-negate. The a-side negation is done before the tape switch so the
computation order matches the single-tape original.

**b** is the projection onto b. It depends only on the second input: NEXT-TAPE
switches to tape 2, PEEK reads b, NEXT-TAPE restores tape 1, POP writes b. Four
instructions — two more than the projection onto a, the cost of reaching tape 2
and returning.

**XOR** is the first function in this library to use CMOV. XOR(a, b) returns 1
iff a ≠ b, expressed as: if b=0, output a; if b=1, output NOT a. PEEK reads a;
DUP, DUP, NAND yields [a, NOT a] (top is NOT a, with a below); SWAP exchanges
them to [NOT a, a]; the tape switch then reads b, giving [NOT a, a, b]. CMOV
pops b as c, a as the a-arg (chosen when c=0), and NOT a as the b-arg (chosen
when c=1). When b=0 the result is a; when b=1 the result is NOT a — exactly XOR.

**OR** = NAND(NOT a, NOT b) by De Morgan. Read a, negate via DUP+NAND, read b,
negate via DUP+NAND, then NAND the two negations. The final NAND yields a OR b.
Same length as XOR but a different structure: OR uses two negations and a final
NAND, where XOR uses one negation and a CMOV.

**NOR** is OR followed by negation. The first instructions are the OR
construction (yielding a OR b on top of the stack); the additional DUP, NAND
negates that result to give NOR. Two more instructions than OR — the cost of the
trailing negation, paid for by the same DUP+NAND idiom used everywhere else for
negation on the stack.

**XNOR** returns 1 iff a = b, expressed as: if b=0 output NOT a; if b=1 output
a. PEEK reads a; DUP, DUP, NAND yields [a, NOT a]; the tape switch reads b,
giving [a, NOT a, b]. CMOV pops b as c, NOT a as the a-arg (chosen when c=0),
and a as the b-arg (chosen when c=1). When b=0 the result is NOT a; when b=1 the
result is a — exactly XNOR. One instruction shorter than XOR: XNOR's natural
stack arrangement [a, NOT a, b] is what CMOV consumes directly, while XOR needs
a SWAP to flip [a, NOT a] to [NOT a, a] before reading b. The asymmetry comes
from the asymmetry of CMOV's argument ordering (a-arg below b-arg in the stack,
chosen when c=0).

**NOT b** depends only on the second input. NEXT-TAPE switches to tape 2, PEEK
reads b, NEXT-TAPE restores tape 1, then DUP+NAND negates b and POP writes it.
Six instructions.

**b → a** = NAND(NOT a, b) by Boolean algebra (since b → a is logically a OR
NOT b, equivalently NOT(NOT a AND b)). The program reads a, negates it via
DUP+NAND, reads b, then NANDs the negation of a with b. Eight instructions.

**NOT a** reads a from tape 1, negates it via DUP+NAND, and writes the result.
The function does not depend on b, so it never touches tape 2 — four
instructions. This breaks the old single-tape symmetry with NOT b (function 10):
on separate tapes, NOT a stays on tape 1 (four instructions) while NOT b must
switch to tape 2 and back (six), so the two now differ by the two NEXT-TAPEs
that reaching the second tape costs.

**a → b** = NAND(a, NOT b) by Boolean algebra (since a → b is logically NOT a OR
b, equivalently NOT(a AND NOT b)). The program reads a and b, negates b in place
via DUP+NAND, then NANDs the result with a. Eight instructions, the same length
as b → a (function 11), reflecting their symmetric structure; the difference is
where the negation happens: b → a negates a before the tape switch (a is read
first and negated before b enters the stack), while a → b reads both inputs
first and then negates b on top.

**NAND** is the machine's native binary operation, so producing it requires no
work beyond reading the inputs: read a, read b, NAND them, write the result. Six
instructions. The two-instruction gap with AND (function 1, eight instructions)
is exactly the cost of the extra DUP+NAND negation AND needs.

**TRUE** is a constant function and reads neither tape. It manufactures a 1 on
top of the stack via the DUP-cubed pattern (three DUPs followed by two NANDs
yields NAND(x, NOT x) = 1 regardless of x), then writes the 1. Two instructions
shorter than binary FALSE (function 0): TRUE stops at the manufactured 1, while
FALSE adds a trailing DUP, NAND to negate it to 0.
