# The Array

An acyclic network of stack machines, arranged on a cylinder, that
grows its own interconnect and computes a fixed function of its sensors
— a combinational policy for decision-making and control. The single
machine of `stack.md` is the node; this document specifies how nodes
are placed, how they wire themselves together, and how the network is
judged.

The design holds one commitment above all others: the array is
*completely acyclic*. There is no feedback, no recurrence, no clock.
Every guarantee the single machine earned — trivial termination, the
Boolean-circuit characterization, closure under the encoding — lifts to
the whole network unamended, because an acyclic array of acyclic
machines is itself acyclic. Persistence across decision epochs, should
it ever be wanted, is supplied from outside the array by feeding one
epoch's outputs back as the next epoch's sensor values; the array
itself never contains a cycle.

## The cylinder

Machines occupy sites on a cylinder. A site has two coordinates: an
integer **layer** ℓ, counting from left to right, and an **angle** θ on
a grid around the circle. The layer is the axis of computation — data
enters on the left, at layer 0, and decisions emerge on the right — and
it is the axis along which the acyclic order runs. The angle is
orthogonal to that order: it does no sequencing work, because the circle
has no left or right. It is the coordinate over which structure is
imposed softly, by making some connections geometrically cheap and
others dear, never by forbidding them.

Two integer counts fix the *capacity* of the array, and two integer
spacings fix the *medium* its interconnect grows through. The counts are
the number of machines per layer — the circumference of the cylinder in
nodes, bounding how wide the computation can be at any depth — and the
number of layers — the length of the cylinder, bounding how deep the
composition between sensors and decision can run. The spacings are the
number of empty cells between machines on a layer and the number of
empty cells between layers; they set how much room the interconnect has
to route through, and so, as the growth process below makes clear, how
hard it is to wire the array up without collision. The counts fix what
the array can compute; the spacings fix how difficult the routing is.
All four are hyperparameters of the arena, fixed before any machine
grows a connection, and none of them is part of any genome. Concrete
values are deferred.

## The machine as a node

Each machine is a hexagon, drawn pointy-side-up so that it presents a
flat face to the left and a flat face to the right — along the axis of
time — with the four remaining faces slanting away above and below. The
six faces carry fixed roles:

- **Left face** — the **program port**. The program enters here, from
  directly upstream, flowing in the direction of time.
- **Right face** — the **output port**. The machine's output tape leaves
  here, heading downstream into later layers.
- **Two upper-left and lower-left faces** — the **two input ports**. The
  machine's data inputs arrive on the two upstream-facing diagonals.
  Two input ports is exactly the arity the binary Boolean operators of
  `boole.md` assume: argument *a* on one, *b* on the other.
- **Two upper-right and lower-right faces** — blank. The two
  downstream-facing diagonals carry nothing; a machine never feeds a
  neighbor by abutment.

A node therefore has three ports that may be fed — one program and two
input — and one port from which it emits. The program port and the input
ports are fed in exactly the same way: by an axon, grown from some
upstream machine, arriving adjacent to the face. What distinguishes a
program port from an input port is only what the arriving tape is *read
as* — as the four-bit instruction stream on the program tape, or as a
data tape the program reads with PEEK and its kin. The machine draws no
such distinction itself; it reads tapes and runs, knowing nothing of the
network. The distinction is one of destination, recorded in the
geometry of which face the axon reached, not in any mark on the signal.

### What rides on a connection

A connection delivers a whole output tape. The producing machine's
output tape — a finite bit string of program-determined length, any
length whatever — becomes, at the consuming port, an input tape of the
kind `stack.md` describes: the head wraps at both ends, so the consumer
may read it, re-read it, and reposition over it at will. There are no
length conventions and no negotiation between the two endpoints; the
producer writes whatever it writes, and the consumer reads it however
its program dictates. A port being fed makes a tape *available*; whether
the consuming program actually reads it is the program's affair. A
machine need not touch every tape it is handed, exactly as a unary
operator in `boole.md` never visits the second tape of a two-tape
configuration.

The program port is fed the same way and is subject to the same
indifference of the signal to its role: a machine can compute another
machine's program, because a machine can emit any bit string and every
bit string is a valid program. Code and data are the same substance on
the wire, told apart only by which face they reach.

### Unfed ports and the read-failure rule

An **unfed input port** reads a constant 1 — the bias unit of
`stack.md`, lifted from "no tape attached" to "this port has no incoming
axon." Every PEEK returns 1; the head rests forever at a position that is
at once the beginning and the end of an empty tape, so EOT is always
true and the wrap is trivial.

An **unfed program port** delivers no program. The machine, reading
four-bit instructions off an empty program tape, cannot read its first
instruction, and so it terminates at once — running zero instructions,
emitting whatever its output tape initially holds, and ringing its bell.
This is not a special inert state; it is the ordinary read-failure
termination reached immediately. (See the note below, which extends the
single-machine termination account of `stack.md` to cover it.)

## Layer 0: sensors and programs

The leftmost layer has nothing upstream of it, so its machines cannot be
fed by axons. Layer 0 is therefore a layer of **constant-output source
nodes**: each emits a fixed bit string, supplied by the configuration,
rather than computing one. They run, ring, and present their constant
tape to whatever their axons reach. They divide by role — but the role
is destination, not mechanism:

- A **sensor** is a layer-0 node whose constant output is a *datum* — an
  observation, the array's external input — read downstream as data.
  This is how the world enters the array.
- A **program** is a layer-0 node whose constant output is a *program* —
  a bit string meant to be read by some downstream machine's program
  port, supplying that machine its code. This is where the regress of
  "who programs the programmer" bottoms out: the seed programs are
  constants at layer 0, and every machine from layer 1 onward is
  programmed by an axon, whether that axon carries a layer-0 constant or
  a program computed by an intermediate machine.

A layer-0 program node does not *run* the program it carries; its output
tape simply *is* that program string, transmitted as data, valid code
for whoever reads it as such. Were it to run the program, it would need
a program of its own, and the regress would not terminate.

The same constant can, in principle, be routed to an input port of one
machine and a program port of another, and be data for the first and
code for the second. Nothing forbids it. It is the same indifference of
signal to role that runs through the whole design.

## Growth: how axons wire the array

The machines are placed on the cylinder by G-d. Then they grow their
connections. Each machine grows exactly one **axon** — a path that
carries the machine's output tape outward from its right face — and a
machine may be reached by up to three axons, one at each of its fed
ports. One axon out, carrying the one output a machine has; up to three
signals in.

Growth runs in discrete, synchronous time. Each axon is a single **tip**
walking the empty cells between the hexagons, and every axon is given a
finite, fixed budget of moves. At each tick, every tip scores the cells
it could step to and steps to the most attractive; all tips step
together, each scoring the field as it stood at the end of the previous
tick. An axon that exhausts its budget stops where it is.

### The magnetic field

Attraction and repulsion are magnetic, and the two poles do the two jobs
the wiring needs. **Ports carry south polarity; axons carry north.**

- North is drawn to south, so an axon tip is pulled toward ports. This
  is *targeting*: the tip seeks faces to feed.
- North repels north, so two axon tips push each other apart. This is
  *exclusion*: a tip is steered away from a port already occupied by
  another axon, and away from the company of other tips.

The strengths are set by the genome — each machine specifies the
**attractive strength** of its ports and the **repulsive strength** of
its axon. Strength, not direction: the genome says how loudly a node's
ports call and how hard its axon shoves, and the *path* follows from
those strengths playing out in the field that every machine's emissions
jointly create. Direction is never encoded; it emerges.

Occupancy is written back into the field by two complementary effects,
so that a tip far away can tell a taken port from a free one. When an
axon feeds a port, that **port's south field is cancelled, at least in
part** — a fed port stops calling, and so drops out of the competition
for tips still approaching from a distance. And the feeding axon's own
north pole now sits at that port, repelling any latecomer that arrives
nearby. Cancellation removes a taken port from the long-range
competition; residual repulsion handles the short-range business of
turning away a tip that was already close. The scarcity a tip cannot see
directly is thus made visible as chemistry-of-the-field: a taken port
goes quiet.

### Admissible moves

The tip moves through the empty cells between hexagons. Movement is
independent of which faces bear ports: a port's role governs only whether
a passing tip *feeds* there, never whether the tip may pass. A face may
be crossed whether it is an input port, the program port, the output
port, or blank.

Motion is **strictly forward in time**. The layer index ℓ may never
decrease. On the pointy-up hexagonal lattice this leaves a tip three
admissible moves from any cell — one straight downstream and two
downstream-and-around-the-circle, one each way — every one of which
advances ℓ. There is no purely lateral step and no step backward; the
walk is a strictly monotone march into later layers, and an axon's reach
in depth is bounded directly by its move budget.

This is where acyclicity is enforced, and it is enforced by
*construction of the walk* rather than by any check at the moment of
connection. Because a tip's layer never decreases, every port it ever
reaches sits at a layer no earlier than its source, and in fact strictly
later, since every move advances ℓ. A back-edge cannot be expressed. The
DAG is structural: it is a property of which moves exist, in the same way
that closure under the encoding is a property of which bit strings parse.

### Feeding, and why the tip moves on

When a tip occupies a cell adjacent to an unoccupied port, it **feeds**
that port: the axon's output tape becomes that port's input (or program)
tape, and the connection is made. Feeding does not end the walk. The tip
continues, free to reach further downstream and feed more ports on later
machines, until its budget is spent. A single axon may thus fan out to
several consumers — exactly those ports its one walk passes and docks —
with the fan-out bounded geometrically, by the budget and by what lies
along the route.

The tip moves on because feeding quiets the port it just fed: the
cancellation of that port's south field removes the very attraction that
drew the tip in, so the next live port downstream becomes the most
attractive direction and the march resumes. The same cancellation that
keeps a second axon off a taken port is what unsticks the first axon and
sends it onward; one effect serves both ends.

### The tie-break

A tip steps to the most attractive admissible cell. When two or more
admissible cells score exactly equal — as exact symmetry of placement
and strength will occasionally force — the tie is broken by a rule the
genome carries: each machine specifies its own fixed priority over the
admissible moves, consulted only when the field leaves the choice
genuinely tied. The tie-break is thus selection-tunable and imposes no
global convention from outside, yet it keeps the grown network a
deterministic function of the genome and the arrangement. The rule lives
in the growth layer, consulted by the tip; the machine, blind to the
network, never computes it.

### Collision: the judgment of Solomon

Two tips may choose to step into the same cell on the same tick. The
field discourages it — two norths repel — but exact symmetry can drive
two tips to the same destination, and the model does not prevent it. It
*punishes* it. When two or more tips select the same cell on the same
tick, **all of them die.** A dead axon is annihilated: it retracts every
connection it had made, so each port it had fed loses that signal
entirely. And the machine that grew it grows no replacement — it is left
permanently without an axon, its computed output reaching no one for the
remainder of construction.

The cruelty is in what the dead axon leaves behind. A port that the dead
axon had fed does **not** revert to free. Its occupancy persists — the
machinery of the contact remains, fooling the receiving machine into
treating the port as connected — so no other axon may ever feed it,
while the signal that occupied it is gone. Such a port is occupied and
silent at once. To the machine it is indistinguishable from any unfed
port: it reads a constant 1, its head forever at the beginning and end
of an empty tape. The machine knows nothing of the network and so cannot
tell a poisoned port from one that was never reached; it computes,
silently and well-definedly, the wrong function of a dead input it has
no way to recognize as dead, and the corruption propagates down its
forward cone.

This is a calamity for the array, and it is meant to be. The cost of a
collision is not the loss of two axons but the silent poisoning of
everything downstream of the ports they had touched — a large,
forward-propagating penalty that selection feels through fitness and
learns to avoid. Genomes whose axons collide are pruned; genomes whose
axons route through uncontested space are kept. Spatial discipline —
growing an interconnect that does not contend for the same cells — is
therefore among the first things any fit lineage must discover, before
the computation it carries can matter at all. The lethal boundary is
collision; within it, among the genomes that grow cleanly, the
smooth dynamics of survival-of-the-flattest govern as before.

A collision is a developmental outcome of one construction, not a change
to the genome. The genotype is untouched; an offspring, mutated and
grown afresh on its own arrangement, may not collide at all.

## The payoff node: how a run is judged

One node is distinguished and fixed: the **payoff node**, the unique
sink, at the right of the array. It is not a stack machine and is not
evolved — it is given, the same across every genome in a population,
and it *is* the problem. It has a finite, predefined set of input ports,
of two kinds:

- **Sensor ports**, wired directly and automatically to the layer-0
  sensors. The payoff node sees the true state of the world, reliably,
  without any axon having to grow to it. The environment's access to
  ground truth is guaranteed.
- **Choice ports**, fed by the array's interior in the ordinary way — by
  axons grown through the field, subject to the budget, the
  tie-break, and the lethal collision rule. A choice is whatever feeds a
  choice port; getting a decision to the payoff is itself something the
  growth must accomplish, and a genome whose axons fail to arrive, or
  collide on the way, leaves choice ports unfed. An unfed choice port
  reads a constant 1, like any other, and the payoff is computed on that
  default. Closure runs all the way to the verdict: every genome
  produces *some* fitness.

From its sensor and choice bits the payoff node computes a single,
possibly random, real number. That number is the array's **fitness for
that run** — its policy's choices judged against the state of the world
the sensors reported. The payoff node is thus the loss function
internalized as the terminal node of the very graph being evolved: the
interior is the policy, the payoff is the environment's judgment of the
policy.

How per-run payoffs become a selection signal is left to the particular
genetic algorithm, not fixed by the architecture. One search may average
fitness over many runs against a distribution of sensor inputs; another
may take realized fitness on a finite set of test cases. The
architecture defines what a single run yields — one real number from the
payoff node; the search defines how runs accumulate into pressure.

## Structural properties

- **Acyclicity by construction.** No axon move decreases the layer index,
  so every connection runs from an earlier layer to a later one. The
  array is a DAG not by repair or rejection but because a back-edge is
  inexpressible. Sensors and the seed programs sit at layer 0; the payoff
  node sits at the right; everything between is computed strictly
  forward.
- **Combinational, not Turing-complete.** The array inherits the
  single machine's character. It is a feedforward composition of
  bounded Boolean circuits, so the whole network computes a fixed finite
  function of its sensors and writes a bounded decision, and it
  terminates trivially: each machine runs in time bounded by its program
  length, each axon grows in time bounded by its move budget, and the
  forward order means a machine runs only after the machines feeding it
  have rung. The bell is the synchronization primitive — "this machine
  is done; the machines downstream may begin" — and no clock or execution
  budget is needed.
- **Closure at every level.** The design is closed three times over, and
  the closures nest. *Every bit string of length divisible by four is a
  valid program* (the encoding, from `stack.md`); under the read-failure
  rule below, in fact every bit string whatever runs and rings. *Every
  genome specifies a valid growth process* — a well-defined field, a
  deterministic walk, some set of contacts — so there is no infeasible
  genotype to reject or repair; even a collision yields a definite, if
  ruinous, phenotype. *Every grown network is a valid acyclic array*,
  because forward-only motion makes the DAG structural. A random genotype
  is well-formed at the program level, the growth level, and the topology
  level alike.
- **Soft structure on a hard orientation.** The only hard constraint on
  the interior is the orientation: time runs left to right, ℓ never
  decreases. Everything else is soft. Angle imposes no order and gates no
  connection; it only makes some routes geometrically cheaper than
  others. Which ports a machine's one axon happens to feed, how far it
  reaches, whether a decision arrives at the payoff at all — these are
  outcomes of strengths and placement playing out in the field, shaped
  but never dictated.

## Note: termination of a single machine, revisited

The array's use of the program port sharpens a point in `stack.md`'s
account of how a single machine stops. That account names two ways:
a HALT fires, or execution runs off the end of the program. The second
should be read to cover every case in which the next four-bit
instruction cannot be read — the program tape exhausted at a clean
multiple of four, a remainder of one to three bits left over, or the
tape empty from the start. All three are the same event: an attempt to
read an instruction that cannot be satisfied, upon which the machine
terminates and rings its bell. The empty case is the unfed program port;
it rings immediately, having run nothing. So termination has one
mechanism with three faces — HALT fires, or the program is exhausted, or
a short or empty remainder cannot be read — and the bell rings on all of
them. This leaves closure total in the strongest form: any bit string at
all, presented at a program port, runs and rings, producing some output
tape.

## References

Miller, J. F. (ed.) (2011). *Cartesian Genetic Programming*. Springer.
— The reference for CGP: a grid of nodes with addressed interconnect, a
levels-back parameter, and output genes. The array departs from
classical CGP in three ways worth marking — the node is a whole evolved
machine rather than a single primitive, the interconnect is grown
through a field rather than addressed by genes, and the grid is a
cylinder with a soft angular coordinate rather than a plane with
levels-back — but the lineage is CGP, and this is where it starts.

Miller, J. F., and Thomson, P. (2000). Cartesian genetic programming.
In *Proceedings of EuroGP 2000*, LNCS 1802, pp. 121–132. — The original
statement of CGP; the source of the feedforward-grid representation and
the output-gene mechanism the payoff node's choice ports replace.

Sperber, G., et al., on axon guidance by gradient fields — standard
developmental-neuroscience background for growth cones following
diffusible attractant and repellent gradients. The magnetic field here
is a deliberate idealization of that picture: a single signed field
doing both the attraction (north to south, targeting) and the repulsion
(north to north, exclusion), in place of separate chemical species.

(See also the references of `stack.md` for the single-machine model and
the linear-GP tradition, and `boole.md` for the operator library that
furnishes node behaviors of the two-input-port arity the hexagon
provides.)
