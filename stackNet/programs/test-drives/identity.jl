using Pkg
Pkg.activate(joinpath(@__DIR__, "../.."))
using StackMachine

program = read(joinpath(@__DIR__, "../bin/identity.bc"))
input   = BitVector([0, 1, 0, 1, 1, 0, 0, 1])

println("input:  ", Int.(input))
println("output: ", Int.(StackMachine.run(program, [input])))
