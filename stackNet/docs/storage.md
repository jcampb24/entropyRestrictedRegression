# Network Storage

Specification for the in-process Julia representation and the on-disk
HDF5 format for networks as defined in `network-specification.md`. The
two representations are in direct correspondence; loading a file
constructs a `Network` struct, and saving one writes the struct's
fields back to file.

## Julia struct

```julia
struct Network
    d::UInt32                          # depth: number of columns
    n::UInt32                          # circle size: nodes per column
    arity::UInt8                       # number of input tapes per node
    max_path_len::UInt8                # maximum connection gene path length
    input_nodes::Vector{UInt32}        # positions in column 0 that are inputs
    input_lengths::Vector{UInt32}      # expected bit-length of each input tape
    output_nodes::Vector{UInt32}       # positions in column d-1 that are outputs
    function_genes::Matrix{UInt16}     # shape (n, d)
    connection_paths::Array{UInt32, 3} # shape (n, d, arity)
    connection_lengths::Array{UInt8, 3}# shape (n, d, arity)
end
```

**Scalar fields.**

- `d` and `n` give the cylinder dimensions (`network-specification.md`).
- `arity` is the number of input tapes per computational node, and
  therefore the number of connection genes per node. For virtual
  programs (`vp.md`) this is always 3; for general networks it is a
  machine parameter.
- `max_path_len` is the maximum number of steps in any connection gene
  path, enforced at runtime. It is a named implementation parameter
  rather than a property of the network spec, which imposes no bound
  on path length.

**Vector fields.**

- `input_nodes` lists the positions (within column 0) that are
  designated primary inputs, in order. `input_lengths[i]` gives the
  expected bit-length of the input tape presented to `input_nodes[i]`.
  The two vectors are parallel and must have the same length.
- `output_nodes` lists the positions within column *d*−1 that are
  designated outputs. The wiring of output tapes to the external
  interface is outside the scope of this specification.

**Array fields.**

- `function_genes[p, c]` is the 16-bit library address of the
  primitive at position *p*, column *c*. Columns are 1-indexed in
  Julia; column 1 corresponds to column 0 (the input column) in the
  network specification, and its entries are ignored by the evaluator.
- `connection_paths[p, c, k]` is the `UInt32` encoding of connection
  gene *k* at node (*p*, *c*). Bits are read from LSB to MSB; 0 =
  backward-up, 1 = backward-down. Only the low `connection_lengths[p,
  c, k]` bits are significant.
- `connection_lengths[p, c, k]` is the number of significant bits in
  `connection_paths[p, c, k]`, in the range 0 to `max_path_len`. A
  length of 0 means the path has no steps; the source is the node
  immediately to the left at the same position.

## HDF5 file format

A network is stored as a single HDF5 file, conventionally with the
extension `.network.h5`. The file has one root group containing
metadata as attributes and bulk data as datasets.

### Root attributes

All scalar and vector metadata is stored as attributes on the root
group. A reader can inspect the network's dimensions and interface
without loading any large array.

| Attribute        | HDF5 type         | Description |
|------------------|-------------------|-------------|
| `d`              | `UInt32`          | Depth |
| `n`              | `UInt32`          | Circle size |
| `arity`          | `UInt8`           | Input tapes per node |
| `max_path_len`   | `UInt8`           | Maximum path length |
| `input_nodes`    | `Vector{UInt32}`  | Input node positions |
| `input_lengths`  | `Vector{UInt32}`  | Input tape bit-lengths |
| `output_nodes`   | `Vector{UInt32}`  | Output node positions |

### Datasets

The three large arrays are stored as HDF5 datasets in the root group.

| Dataset              | HDF5 type   | Shape            |
|----------------------|-------------|------------------|
| `function_genes`     | `UInt16`    | (*n*, *d*)       |
| `connection_paths`   | `UInt32`    | (*n*, *d*, arity)|
| `connection_lengths` | `UInt8`     | (*n*, *d*, arity)|

Arrays are stored in column-major order, matching Julia's native array
layout, so that memory-mapped access (`Mmap.jl`) requires no
transposition.

### File layout summary

```
network.h5
├── (root attributes)
│   ├── d                UInt32
│   ├── n                UInt32
│   ├── arity            UInt8
│   ├── max_path_len     UInt8
│   ├── input_nodes      Vector{UInt32}
│   ├── input_lengths    Vector{UInt32}
│   └── output_nodes     Vector{UInt32}
├── function_genes       UInt16  (n × d)
├── connection_paths     UInt32  (n × d × arity)
└── connection_lengths   UInt8   (n × d × arity)
```

## Round-trip invariant

Loading a file and immediately saving it must produce a bit-identical
file. All fields are exact integer types with no floating-point
representation; there is no precision loss in the round-trip. This
invariant should be verified by any implementation's test suite.

## Conventions and constraints

- `length(input_nodes) == length(input_lengths)` must hold; a file
  violating this is malformed.
- `input_nodes` and `output_nodes` contain positions in the range
  0 to *n*−1.
- `connection_lengths[p, c, k] ≤ max_path_len` for all (*p*, *c*, *k*).
- The genes of input-column nodes (column index 1 in Julia, column 0
  in the network spec) are present in the arrays but ignored by the
  evaluator. They may be zero-initialised.
