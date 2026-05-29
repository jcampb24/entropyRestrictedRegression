module VM

export run

# ---------------------------------------------------------------------------
# Machine state
# ---------------------------------------------------------------------------

mutable struct VMState
    stack::Vector{Bool}
    sp::Int                  # index of top element; 0 means empty
    tapes::Vector{BitVector}
    heads::Vector{Int}       # 1-indexed head position per tape
    active::Int              # index of active tape (1-indexed)
    output::BitVector
end

function VMState(program_len::Int, inputs::Vector{BitVector})
    VMState(
        Vector{Bool}(undef, program_len),  # pre-allocate; never needs to grow
        0,
        inputs,
        fill(1, length(inputs)),
        isempty(inputs) ? 1 : 1,
        BitVector(),
    )
end

# ---------------------------------------------------------------------------
# Stack helpers — reads below the bottom return 0
# ---------------------------------------------------------------------------

@inline function stack_push!(s::VMState, bit::Bool)
    s.sp += 1
    s.stack[s.sp] = bit
end

@inline function stack_pop!(s::VMState)::Bool
    s.sp == 0 && return false
    bit = s.stack[s.sp]
    s.sp -= 1
    return bit
end

@inline function stack_top(s::VMState)::Bool
    s.sp == 0 && return false
    return s.stack[s.sp]
end

@inline function stack_second(s::VMState)::Bool
    s.sp < 2 && return false
    return s.stack[s.sp - 1]
end

@inline function stack_third(s::VMState)::Bool
    s.sp < 3 && return false
    return s.stack[s.sp - 2]
end

# ---------------------------------------------------------------------------
# Tape helpers
# ---------------------------------------------------------------------------

@inline function tape_read(s::VMState)::Bool
    isempty(s.tapes) && return true   # bias unit: no tape returns 1
    tape = s.tapes[s.active]
    isempty(tape) && return true      # empty tape reads as 1
    return tape[s.heads[s.active]]
end

@inline function tape_eot(s::VMState)::Bool
    isempty(s.tapes) && return true
    tape = s.tapes[s.active]
    isempty(tape) && return true      # empty tape is always at EOT
    return s.heads[s.active] == length(tape)
end

@inline function tape_advance!(s::VMState)
    isempty(s.tapes) && return
    tape = s.tapes[s.active]
    n = length(tape)
    s.heads[s.active] = s.heads[s.active] == n ? 1 : s.heads[s.active] + 1
end

@inline function tape_retreat!(s::VMState)
    isempty(s.tapes) && return
    tape = s.tapes[s.active]
    n = length(tape)
    s.heads[s.active] = s.heads[s.active] == 1 ? n : s.heads[s.active] - 1
end

@inline function tape_next!(s::VMState)
    isempty(s.tapes) && return
    n = length(s.tapes)
    s.active = s.active == n ? 1 : s.active + 1
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

"""
    run(program::Vector{UInt8}, inputs::Vector{BitVector}) -> BitVector

Execute a compiled stack-machine program against up to three input tapes.
Returns the output tape at termination.
"""
function run(program::Vector{UInt8}, inputs::Vector{BitVector})::BitVector
    length(inputs) > 3 && error("VM: at most 3 input tapes permitted, " *
                                "got $(length(inputs))")

    s = VMState(length(program), inputs)

    for byte in program
        # validate opcode
        (byte & 0xF0) != 0x00 && error("VM: invalid opcode byte 0x$(string(byte, base=16, pad=2))")

        op = byte & 0x0F

        if op == 0x00        # EOT — push 1 iff active head is at last cell
            stack_push!(s, tape_eot(s))

        elseif op == 0x01    # POP — write top to output; advance output
            push!(s.output, stack_pop!(s))

        elseif op == 0x02    # NAND — pop two, push their NAND
            a = stack_pop!(s)
            b = stack_pop!(s)
            stack_push!(s, !(a & b))

        elseif op == 0x03    # HALT — pop top; halt if 1
            stack_pop!(s) && return s.output

        elseif op == 0x04    # ADVANCE — advance active tape head (wrapping)
            tape_advance!(s)

        elseif op == 0x05    # DUP — duplicate top
            stack_push!(s, stack_top(s))

        elseif op == 0x06    # SWAP — swap top two
            s.sp >= 2 || continue
            s.stack[s.sp], s.stack[s.sp-1] = s.stack[s.sp-1], s.stack[s.sp]

        elseif op == 0x07    # NEXT-TAPE — cycle to next input tape
            tape_next!(s)

        elseif op == 0x08    # DROP — discard top
            stack_pop!(s)

        elseif op == 0x09    # OVER — push copy of second-from-top
            stack_push!(s, stack_second(s))

        elseif op == 0x0A    # ROT — x y z → y z x
            s.sp >= 3 || continue
            x = s.stack[s.sp-2]
            s.stack[s.sp-2] = s.stack[s.sp-1]
            s.stack[s.sp-1] = s.stack[s.sp]
            s.stack[s.sp]   = x

        elseif op == 0x0B    # POUR — pop top; if 1, write stack to output
            trigger = stack_pop!(s)
            if trigger
                for i in s.sp:-1:1
                    push!(s.output, s.stack[i])
                end
                s.sp = 0
            end

        elseif op == 0x0C    # NOOP — do nothing
            continue

        elseif op == 0x0D    # CMOV — pop c, a, b; push b if c=1 else a
            c = stack_pop!(s)
            a = stack_pop!(s)
            b = stack_pop!(s)
            stack_push!(s, c ? b : a)

        elseif op == 0x0E    # PEEK — read active tape without advancing
            stack_push!(s, tape_read(s))

        else                 # op == 0x0F: RETREAT — move head back (wrapping)
            tape_retreat!(s)
        end
    end

    return s.output
end

end # module VM
