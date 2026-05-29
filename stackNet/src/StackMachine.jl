module StackMachine

include("Assembler.jl")
include("VM.jl")

using .Assembler: assemble, assemble_file
using .VM: run
export assemble, assemble_file, run

end # module StackMachine
