module Assembler

export assemble, assemble_file

# ---------------------------------------------------------------------------
# Opcode table — follows the instruction table in stack.md exactly.
# ---------------------------------------------------------------------------

const OPCODES = Dict{String, UInt8}(
    "EOT"       => 0x00,
    "POP"       => 0x01,
    "NAND"      => 0x02,
    "HALT"      => 0x03,
    "ADVANCE"   => 0x04,
    "DUP"       => 0x05,
    "SWAP"      => 0x06,
    "NEXT-TAPE" => 0x07,
    "DROP"      => 0x08,
    "OVER"      => 0x09,
    "ROT"       => 0x0A,
    "POUR"      => 0x0B,
    "NOOP"      => 0x0C,
    "CMOV"      => 0x0D,
    "PEEK"      => 0x0E,
    "RETREAT"   => 0x0F,
)

# ---------------------------------------------------------------------------
# Pass 1: strip comments.
# Removes everything between each pair of * delimiters, inclusive.
# An unclosed * is an error.
# ---------------------------------------------------------------------------

function strip_comments(source::String)::String
    buf = IOBuffer()
    i = firstindex(source)
    while i <= lastindex(source)
        c = source[i]
        if c == '*'
            # scan forward for the closing *
            j = findnext('*', source, nextind(source, i))
            if j === nothing
                error("Assembler: unclosed comment starting at character $i")
            end
            i = nextind(source, j)   # skip past the closing *
        else
            write(buf, c)
            i = nextind(source, i)
        end
    end
    return String(take!(buf))
end

# ---------------------------------------------------------------------------
# Pass 2: expand loops.
# Replaces each START_LOOP x / END_LOOP block with x copies of its body.
# Loops may not be nested.
# ---------------------------------------------------------------------------

function expand_loops(source::String)::String
    buf = IOBuffer()
    lines = split(source, '\n')
    i = 1
    while i <= length(lines)
        line = strip(lines[i])
        if startswith(line, "START_LOOP")
            # parse the count
            parts = split(line)
            if length(parts) != 2
                error("Assembler: malformed START_LOOP at line $i — " *
                      "expected START_LOOP <count>")
            end
            count = tryparse(Int, parts[2])
            if count === nothing || count < 1
                error("Assembler: START_LOOP count must be a positive " *
                      "integer at line $i, got \"$(parts[2])\"")
            end
            # collect body lines up to END_LOOP
            body_lines = String[]
            i += 1
            found_end = false
            while i <= length(lines)
                inner = strip(lines[i])
                if inner == "END_LOOP"
                    found_end = true
                    break
                elseif startswith(inner, "START_LOOP")
                    error("Assembler: nested START_LOOP at line $i — " *
                          "loops may not be nested")
                end
                push!(body_lines, lines[i])
                i += 1
            end
            if !found_end
                error("Assembler: START_LOOP at line $(i - length(body_lines) - 1) " *
                      "has no matching END_LOOP")
            end
            body = join(body_lines, '\n')
            for _ in 1:count
                write(buf, body)
                write(buf, '\n')
            end
        elseif line == "END_LOOP"
            error("Assembler: END_LOOP at line $i has no matching START_LOOP")
        else
            write(buf, lines[i])
            write(buf, '\n')
        end
        i += 1
    end
    return String(take!(buf))
end

# ---------------------------------------------------------------------------
# Pass 3 & 4: tokenise and assemble.
# Splits on whitespace, maps each token to its opcode byte.
# ---------------------------------------------------------------------------

function assemble_tokens(source::String)::Vector{UInt8}
    tokens = split(source)
    bytecode = Vector{UInt8}(undef, length(tokens))
    for (i, tok) in enumerate(tokens)
        op = get(OPCODES, tok, nothing)
        if op === nothing
            error("Assembler: unrecognised mnemonic \"$tok\"")
        end
        bytecode[i] = op
    end
    return bytecode
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

"""
    assemble(source::String) -> Vector{UInt8}

Compile an assembly language program to bytecode. The source string may
contain `*...*` comments and `START_LOOP x` / `END_LOOP` directives.
Returns a flat byte vector, one byte per instruction.
"""
function assemble(source::String)::Vector{UInt8}
    s = strip_comments(source)
    s = expand_loops(s)
    return assemble_tokens(s)
end

"""
    assemble_file(path::String) -> Vector{UInt8}

Read an assembly source file and compile it to bytecode.
"""
function assemble_file(path::String)::Vector{UInt8}
    source = read(path, String)
    return assemble(source)
end

end # module Assembler
