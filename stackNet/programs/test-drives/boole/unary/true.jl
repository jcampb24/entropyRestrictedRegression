using Pkg
Pkg.activate(joinpath(@__DIR__, "../../../.."))
using StackMachine

program = read(joinpath(@__DIR__, "../../../bin/boole/unary/true.bc"))

for input in [
    BitVector([]),
    BitVector([0]),
    BitVector([1]),
    BitVector([0, 1, 0, 1, 1, 0, 0, 1]),
    BitVector([1, 1, 1, 1, 0, 0, 0, 0]),
]
    println("input:  ", Int.(input))
    println("output: ", Int.(StackMachine.run(program, [input])))
    println()
end
