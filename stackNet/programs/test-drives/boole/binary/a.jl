using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../.."))
using StackMachine

program = read(joinpath(@__DIR__, "../../../bin/boole/binary/a.bc"))

for (a, b) in [
    (BitVector([0, 0, 1, 1]),
     BitVector([0, 1, 0, 1])),
    (BitVector([1, 0, 1]),
     BitVector([1, 0, 1, 1, 1])),         # b longer than a
    (BitVector([0, 1, 0, 1, 1, 0, 0, 1]),
     BitVector([1, 1, 1])),               # a longer than b
    (BitVector([]),
     BitVector([0, 1, 0, 1])),            # a empty
    (BitVector([0, 1, 0, 1]),
     BitVector([])),                      # b empty
    (BitVector([]),
     BitVector([])),                      # both empty
]
    println("a:      ", Int.(a))
    println("b:      ", Int.(b))
    println("output: ", Int.(StackMachine.run(program, [a, b])))
    println()
end
