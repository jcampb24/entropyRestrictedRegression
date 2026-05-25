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

The output tape is initialized empty: no cell is punched until written. Each tape is finite but
arbitrarily long. Execution stops in exactly three ways, all
independent of the input's length: a HALT instruction fires (HALT is
conditional; see the instruction set below); the program tape is
exhausted on an instruction fetch; or the output tape is exhausted on
a write. In every case, when execution stops a sensor rings a *bell*.
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
bounded by the program length and the header count, with HALT able to end it
earlier — and fully decoupled from how long its input happens to be.

Because the body is re-entered at most N times — the header count,
fixed in the genome — the number of instructions a machine executes is
bounded by N times the program length; a single machine cannot run
forever, so the bell always eventually rings.

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
  input head backward. Together they make the active input tape random-access
  rather than a consume-once stream, supporting functions that re-read their
  input. Because the head wraps rather than clamps, a backward or forward walk
  never idles at a boundary — it circles the tape; termination is guaranteed
  not by the head but by the header count N, which bounds every machine to at
  most N passes (see Architecture).
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
execution falls through to the next instruction. Its role is
data-dependent *early* exit from a looping body (header N > 1) — for
example, an arithmetic program that breaks out the moment it reads its
terminator frame — and it expresses this without any jump.

Single-shot programs do not need it. A program with header N = 1 runs
its body once and then terminates structurally, when the substrate
exhausts the loop count; the bell rings on that exhaustion. Such a
program ends at its final POP — the instruction that writes the result —
with no HALT and no halt tail; the one-bit passthrough below and the
operator libraries in `arithmetic.md` are all of this form. The
building-block forms used in composition go one step
further and omit the POP as well, leaving the function's value on the
stack.

The *halt tail* survives for the one case that still needs it: an
unconditional break partway through a looping body. Since HALT fires
only on a 1, a program forces termination by first placing a 1 on top
of the stack; the canonical tail is the four-instruction sequence DUP,
DUP, NAND, NAND, which yields NAND(x, NOT x) = 1 for the unknown top
value x regardless of x — and yields 1 from the underlying zeros on an
empty stack — immediately followed by HALT. A conditional break instead
feeds HALT the relevant data bit directly.

**Conditional POUR.** POUR is the bulk-output counterpart of POP and
the third conditional action beside CMOV and HALT: it pops the top of
the stack and, only if that bit is 1, writes the entire remaining stack
to the output, top element first, as bare bits, emptying the stack;
execution then continues. Because the pour is top-first, pushing every
input bit and then POURing reverses the input.

## Program header and bounded iteration

The first eight bits of the program tape are not instructions but a
header: an unsigned loop count N in plain binary, 0 through 255. The
remaining bits are the body. The substrate runs the body as a forward
pass and repeats it up to N times — wrapping the program counter from
the end of the tape back to the start of the body and decrementing an
internal counter each pass, then terminating and ringing the bell when
the counter reaches zero. Conditional HALT may end the run earlier, so
the body executes min(data-driven HALT, N) times.

The input head persists across iterations; it is not reset at the start
of each pass. A body that reads one frame per pass therefore streams
through successive frames over successive iterations, and a program that
wants to re-scan re-positions the head itself with RETREAT.
Over-reads past the end of the input wrap to the start, so a body
that runs more passes than the input has frames re-reads from the
beginning.

Because N is fixed in the genome — compile-time, not data-time — the
bounded loop is a compact unrolling of the body: it adds no
computational power and leaves the machine combinational and
always-terminating (see Structural properties). The gain is purely
representational — depth tuned by an eight-bit count rather than by
physically copying the body — and the count is an ordinary,
high-leverage locus of the genome. No execution budget is needed; the
header bound is the termination guarantee.

## Structural properties

- **Closure under the encoding.** Every bit string of length divisible
  by four is a syntactically valid program: the first eight bits read
  as the loop count, the remaining groups of four as instructions.
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
  depth. The header may repeat the body a fixed
  number of times N (see Program header and bounded iteration), but N
  is compile-time, not data-time, so this is exactly a compact
  unrolling — the computation it expresses is still straight-line and
  acyclic when written out. A program therefore computes a fixed finite
  function of a bounded number of input bits, drawn across its input
  tapes, writing a bounded number of output bits — a Boolean circuit (the unbounded stack does not
  change this, since the program touches it a bounded number of times).
  The functional completeness above is thus expressiveness over
  *bounded* inputs, not Turing universality; only unbounded,
  data-dependent iteration would leave this class, and that would
  require recurrence across the array, with time as the unrolled
  dimension. A corollary is that halting is trivial: the executed
  instruction count is bounded by N times the program length, so every
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
- *Mutation* — substitute a single instruction at a random position
  (equivalent to flipping one to four bits in the program tape).
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

## Variable-length operators

Conditional HALT inside a header loop permits programs whose execution
length depends on the data rather than being fixed in advance: the body
repeats up to N times and HALT breaks out early when the data warrants.
The simplest entry below is the single-bit passthrough — degenerate, in
that its length does not depend on the data; genuinely length-dependent
operators (arithmetic on arbitrary-length integers) build on the same
conventions and are developed in `arithmetic.md`.

**One-bit passthrough**: PUSH, POP — length 2, header N = 1.

Read one input bit, write it to the output, then terminate. PUSH reads
the bit and places it on the stack; POP writes it to the output and
removes it. The single pass then completes, the substrate exhausts the
loop count, and the machine terminates, ringing the bell. The output
tape holds exactly the one bit that was read. This is the unary
IDENTITY function, and the minimal validation of the
architecture: one read, one write, structural termination, the bell.

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
