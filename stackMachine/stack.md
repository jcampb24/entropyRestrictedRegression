# The Stack Machine

A stack machine for evolving short bit-string programs over a
functionally complete instruction set.

## Architecture

Finite tapes, each arbitrarily long and each with a designated start
position; the tapes are read or written in a single forward pass and
are not joined into a cycle:

- **Program tape** — finite string over the four-bit instruction
  alphabet; 4m bits for a program of m instructions.
- **Input tapes** — zero or more, each supplying bits to be read by the
  program. A machine can be attached to arbitrarily many input tapes;
  the hardware places no limit on the number of input ports. How many
  are attached is a property of the configuration, not of the machine.
  With at least one tape, exactly one is *active* at a time (the first,
  initially); the input instructions PEEK, ADVANCE, RETREAT, and EOT
  all act on the active tape, and NEXT-TAPE switches which tape is
  active, cycling through them. Each input tape keeps its own head,
  which persists while the tape is inactive, so switching away and back
  resumes where it left off. A machine with no input tape attached is
  permitted: every input read returns 1, so the machine runs on a
  constant 1 and emits whatever its program computes from that bias —
  the array's bias unit. (Note the asymmetry with the stack, whose
  absent values read as 0; a 0 is then one NAND away.)
- **Output tape** — receives bits written by the program.

A single LIFO stack holds intermediate bits, initialized empty; the
machine tracks how deep it is. A read or removal below the bottom
returns 0 rather than erroring. The behavior of each operator on an
empty stack then follows from what kind of operator it is. The
producers — DUP, OVER, CMOV, and NAND — each compute a value and
deposit it, reading 0 for absent operands; on an empty stack they push
0, 0, 0, and 1 respectively (NAND alone is non-zero on all-zero inputs)
and grow the stack by one. The rearrangers SWAP and ROT and the reducer
DROP act only on elements already present, so on an empty stack they
have nothing to permute or remove and leave it empty. POP writes a 0;
HALT and POUR pop the 0 and do not fire. POP and NAND are thus
well-defined with nothing explicitly pushed, a program's state
variables start at 0 for free, and the init-0 idiom is just a producer
depositing the 0 it computed. The machine initializes with all tape
heads at their start positions.
All instructions are zero-argument; the input and output tape heads
advance automatically upon access.

The output tape is initialized empty: no cell is punched until written, and it
is unbounded — it never limits the run. The input tapes are finite. Execution
stops in one of two ways: a HALT instruction fires — which is data-dependent,
since HALT tests a bit computed from what the machine has read — or it runs
off the end of the program. Both are trivially terminating: the program is a
finite sequence of instructions with no jump-back, so each instruction runs at
most once and the run cannot fail to end. When execution stops a sensor rings
a *bell*.
The bell is not a diagnostic of how the machine stopped; it fires on
every termination and signals readiness — "this machine is done; the
machines downstream may begin." It is the synchronization primitive of
the array. The contents of the output tape at termination constitute
the program's output.

No input tape terminates the machine. Each tape's head *wraps* at its
boundaries, independently: ADVANCE past the last cell returns the head to
the first cell, and RETREAT past the first cell returns it to the last. The
tape is therefore a loop with a fixed start and end, traversed in either
direction. Reading is always well-defined because the head always rests on a
valid cell. (Each motion acts on the active tape; the others hold their
positions.) This makes a machine's runtime a property of its program alone —
bounded by the program length, with HALT able to end it
earlier — and fully decoupled from how long its input happens to be.

Because the program is a finite straight-line sequence with no jump-back, each
instruction executes at most once; the number of instructions a machine
executes is therefore bounded by the program length, so a single machine
cannot run forever, and the bell always eventually rings.

## Instruction set (4 bits per instruction)

| Opcode | Instruction | Effect                                                                       |
|--------|-------------|------------------------------------------------------------------------------|
| 0000   | EOT         | Push 1 if the active input head is at the last cell, else push 0.            |
| 0001   | POP         | Write the stack top to the current output position; advance the output tape. |
| 0010   | NAND        | Remove the top two stack elements; push their NAND onto the stack.           |
| 0011   | HALT        | Remove the top stack element; halt if it is 1, otherwise continue to the next instruction. |
| 0100   | ADVANCE     | Advance the active input tape by one position without reading; past the last cell, the head wraps to the first. |
| 0101   | DUP         | Duplicate the top element of the stack.                                      |
| 0110   | SWAP        | Swap the top two elements of the stack.                                      |
| 0111   | NEXT-TAPE   | Switch to the next input tape, cyclically; with a single input tape, a no-op.   |
| 1000   | DROP        | Discard the top element of the stack.                                        |
| 1001   | OVER        | Push a copy of the second-from-top element onto the stack.                   |
| 1010   | ROT         | Rotate the top three elements: x y z → y z x.                                |
| 1011   | POUR        | Remove the top element; if it is 1, write the rest of the stack to the output, top element first, as bare bits, emptying the stack; execution continues. |
| 1100   | NOOP        | Do nothing.                                                                  |
| 1101   | CMOV        | Pop the top three (c, a, b); push b if c is 1, push a if c is 0.             |
| 1110   | PEEK        | Read the current input bit onto the stack without advancing the active input tape.  |
| 1111   | RETREAT     | Move the active input tape's head back one position; past the first cell, the head wraps to the last. |

The sixteen instructions partition into six categories:

- *I/O and termination.* POP produces output and EOT senses the input
  boundary; ADVANCE and RETREAT move the input head, wrapping at the ends;
  POUR empties the stack to the output in one shot; NEXT-TAPE routes input
  by choosing which tape is active; HALT manages termination.
- *Computation.* NAND is the sole Boolean primitive and the source of
  functional completeness.
- *Basic stack manipulation.* DUP, SWAP, DROP, OVER, and ROT are the
  Forth-tradition stack-shuffling words.
- *Conditional selection.* CMOV provides data-dependent selection
  between two values — the bit-level multiplexer and the building
  block of decision-rule policies. It introduces no control flow:
  there is no jump and no risk of non-termination, only conditional
  data selection.
- *Extended tape access.* PEEK reads without advancing; RETREAT moves the
  input head backward. The head persists through execution — it is never
  reset — so a program re-reads its input by repositioning the head with
  RETREAT, making the active input tape random-access rather than a
  consume-once stream. Because the head wraps rather than clamps, a backward
  or forward walk never idles at a boundary; it circles the tape.
- *No-op.* NOOP does nothing, and is the only instruction neutral in
  every context and at every tape count.

A dedicated no-op. NOOP does nothing, in every context and at every
tape count. Neutrality an insertion mutation can rely on has to be
unconditional, and NOOP is the only instruction that supplies it. The
representation's mutation-absorbing "junk DNA" comes contextually as
well: NEXT-TAPE does nothing on a one-tape machine, a value pushed and
never popped never reaches the output. But each of those is neutral
only in its context, and none is neutral on an arbitrary multi-tape
machine. NOOP is the one symbol neutral everywhere — the clean
instruction an insertion can drop in anywhere, the slack that lets
variable-length genomes align for crossover, and the latent site a
later mutation can switch on.

**Conditional HALT and the halt tail.** HALT is conditional: it pops
the top of the stack and terminates only if that bit is 1, otherwise
execution falls through to the next instruction. Its role is a
data-dependent *early* stop: it ends execution before the program's
remaining instructions run — for example, an arithmetic program that
stops the moment it reads its terminator — and it expresses this without
any jump.

A program that never needs to stop early simply omits HALT and runs to
its final instruction, ending at the final POP that writes the result;
the one-bit passthrough below and the operator libraries in
`arithmetic.md` are of this form. The building-block forms used in
composition go one step further and omit the POP as well, leaving the
function's value on the stack.

The *halt tail* forces an unconditional early stop, for a program that
wants to end partway through regardless of data. Since HALT fires only
on a 1, the program first places a 1 on top of the stack; the canonical
tail is the four-instruction sequence DUP, DUP, NAND, NAND, which yields
NAND(x, NOT x) = 1 for the unknown top value x regardless of x — and
yields 1 from the underlying zeros on an empty stack — immediately
followed by HALT. A conditional stop instead feeds HALT the relevant
data bit directly.

**Conditional POUR.** POUR is the bulk-output counterpart of POP and
the third conditional action beside CMOV and HALT: it pops the top of
the stack and, only if that bit is 1, writes the entire remaining stack
to the output, top element first, as bare bits, emptying the stack;
execution then continues. Because the pour is top-first, pushing every
input bit and then POURing reverses the input.

## Structural properties

- **Closure under the encoding.** Every bit string of length divisible
  by four is a syntactically valid program: each group of four bits is
  an instruction, and the program is read straight through.
  There are no parse errors. The instruction set does not depend on the
  number of input tapes — that number is part of the configuration, not
  the encoding — so closure holds identically however many tapes are
  attached.
- **Functional completeness.** NAND alone is functionally complete,
  so for any fixed p and r, every function {0,1}^p → {0,1}^r is
  representable by some program (Koza's sufficiency; Koza 1992).
- **Combinational, not Turing-complete.** There is no data-dependent
  jump; CMOV selects data rather than a target, and conditional HALT
  only stops execution early. NEXT-TAPE chooses which input tape
  supplies subsequent reads, but the choice is data-independent and
  adds no control flow. POUR transfers the stack to the tape and
  execution continues; the amount written is bounded by the stack
  depth. The program is a single straight-line pass with no jump-back,
  so the computation it expresses is acyclic when written out. A
  program therefore computes a fixed finite
  function of a bounded number of input bits, drawn across its input
  tapes, writing a bounded number of output bits — a Boolean circuit (the unbounded stack does not
  change this, since the program touches it a bounded number of times).
  The functional completeness above is thus expressiveness over
  *bounded* inputs, not Turing universality; only unbounded,
  data-dependent iteration would leave this class, and that would
  require recurrence across the array, with time as the unrolled
  dimension. A corollary is that halting is trivial: the executed
  instruction count is bounded by the program length, so every
  machine terminates, composed or not, with no execution budget
  required.
- **Linear, not tree-structured.** Programs are flat instruction
  sequences with no nesting or control flow. The representation
  belongs to linear genetic programming, not Koza's tree-based GP;
  there are no subtrees to swap, and the standard tree-crossover
  operator does not apply.

## Evolutionary search

A population of programs is searched stochastically over the space of
bit strings of varying length.

Genetic operators:
- *Mutation* — substitute a single instruction at a random position.
- *Crossover* — splice contiguous subsequences from two parents.
- *Insertion and deletion* — add or remove a single instruction,
  letting program length evolve.
- *Selection* — programs are ranked by fitness on a problem-specific
  objective.

Two dynamics worth keeping in view:
- *Survival-of-the-flattest* — once a program reaches a fitness
  plateau, selection favors neutral neighborhoods (programs robust to
  small mutations) over isolated peaks.
- *Population-level phrase reduction* — recurring subsequences across
  the population are identified and contracted, providing a
  bloat-fighting mechanism distinct from per-individual simplification.

## Validation

Agreed warm-up validation exercise: **evolve a program that computes
the AND of the first two bits of the input tape** and writes the
result to the first position of the output tape. One valid solution is
the single-shot (header N = 1) program of length six — PUSH, PUSH,
NAND, DUP, NAND, POP — exercising input reading, the NAND primitive,
stack duplication, and output writing; many other programs compute the
same function. A trivial prior sanity check is the same problem with
NAND in place of AND, for which PUSH, PUSH, NAND, POP is one solution.

## Example programs

Two short programs illustrate the instruction set. Both are straight-line:
they read, compute, write, and run off the end, with no HALT needed.

**One-bit passthrough**: PEEK, POP — length 2.

Read one input bit, write it to the output. PEEK places the current input
bit on the stack; POP writes it to the output and removes it. Execution then
runs off the end of the program and the machine terminates, ringing the bell.
The output holds exactly the one bit that was read — the unary IDENTITY
function, and the smallest exercise of the architecture: one read, one write,
the bell.

**Reverse three bits (via POUR)**: PEEK, ADVANCE, PEEK, ADVANCE, PEEK,
ADVANCE, PEEK, PEEK, NAND, PEEK, NAND, POUR — length 12.

Read three input bits, then emit them in reverse. The three PEEK, ADVANCE
pairs read b₀, b₁, b₂ onto the stack, leaving b₂ on top. The next five
instructions, PEEK, PEEK, NAND, PEEK, NAND, place a 1 on top of the stack
without disturbing the three data bits: reading the current cell as b, the
first NAND yields ¬b and the second yields ¬(¬b ∧ b) = 1, which holds whatever
b is. POUR then pops that 1, fires, and drains the rest of the stack top-first
— b₂, b₁, b₀ — the reversal. The bulk drain is what makes POUR a reversal: it
empties the stack in last-in-first-out order in a single instruction. The
width is fixed at three here; arbitrary-length reversal and the operators that
build on it are developed in `arithmetic.md`.

## References

Brameier, M., and Banzhaf, W. (2007). *Linear Genetic Programming*. Springer.
— The canonical textbook on linear GP. Chapters 1–3 give the model,
algorithm, and basic representation; the bias is toward register-based
LGP with arithmetic primitives, so the general framework transfers but
implementation details do not.

Brodie, L. (1987). *Starting Forth* (online edition, FORTH, Inc.). Available
at https://www.forth.com/starting-forth/. — The classic beginner's tutorial;
Chapter 2, "Stack Manipulation Operators," introduces DUP, SWAP, OVER, DROP,
and ROT with worked examples. The accessible companion to the standard for
the stack-shuffling words.

Forth Standard Committee. *Forth Standard* (the ongoing community standard,
successor to ANS Forth X3.215-1994). Available at https://forth-standard.org.
— Defines the core stack-manipulation words DUP, SWAP, DROP, OVER, and ROT,
with the stack-effect notation `( before -- after )`; the source for the
Forth tradition the basic stack-shuffling words follow.

Koza, J. R. (1992). *Genetic Programming: On the Programming of
Computers by Means of Natural Selection*. MIT Press.
— The canonical reference for tree-based GP and the source of the
sufficiency notion.

Nordin, P. (1994). A compiling genetic programming system that
directly manipulates the machine code. In Kinnear, K. E. (ed.),
*Advances in Genetic Programming*, MIT Press, pp. 311–331.
— Historical foundation for machine-code-style LGP; closer in spirit
to the machine described here than to mainstream register-based LGP.

Poli, R., Langdon, W. B., and McPhee, N. F. (2008). *A Field Guide
to Genetic Programming*. Self-published; freely available online.
— A ~200-page tutorial covering GP broadly, with a chapter on linear
and other non-tree representations. The fastest path to the
vocabulary and the standard tradeoffs.

Spector, L., Klein, J., and Keijzer, M. (2005). The Push3 execution
stack and the evolution of control. In *Proceedings of GECCO 2005*.
— Representative entry into the PushGP literature on stack-based GP;
the more direct analogue when register-based LGP feels too far afield.
