using Test
using StackMachine
using StackMachine.VM: run

bv(bits...) = BitVector(collect(Bool, bits))

# ---------------------------------------------------------------------------
# Assembler tests
# ---------------------------------------------------------------------------

@testset "Assembler" begin

    @testset "basic opcodes" begin
        @test assemble("EOT")       == [0x00]
        @test assemble("POP")       == [0x01]
        @test assemble("NAND")      == [0x02]
        @test assemble("HALT")      == [0x03]
        @test assemble("ADVANCE")   == [0x04]
        @test assemble("DUP")       == [0x05]
        @test assemble("SWAP")      == [0x06]
        @test assemble("NEXT-TAPE") == [0x07]
        @test assemble("DROP")      == [0x08]
        @test assemble("OVER")      == [0x09]
        @test assemble("ROT")       == [0x0A]
        @test assemble("POUR")      == [0x0B]
        @test assemble("NOOP")      == [0x0C]
        @test assemble("CMOV")      == [0x0D]
        @test assemble("PEEK")      == [0x0E]
        @test assemble("RETREAT")   == [0x0F]
    end

    @testset "comments stripped" begin
        @test assemble("PEEK *read a bit* POP") == [0x0E, 0x01]
        @test assemble("PEEK\n*this is\na comment*\nPOP") == [0x0E, 0x01]
        @test assemble("*header* NOOP *footer*") == [0x0C]
        @test assemble("*one**two* PEEK") == [0x0E]
    end

    @testset "blank lines ignored" begin
        @test assemble("PEEK\n\nPOP\n") == [0x0E, 0x01]
    end

    @testset "loop expansion" begin
        @test assemble("START_LOOP 1\nPEEK\nEND_LOOP") == [0x0E]
        @test assemble("START_LOOP 3\nNOOP\nEND_LOOP") == [0x0C, 0x0C, 0x0C]
        @test assemble("START_LOOP 2\nPEEK\nPOP\nEND_LOOP") == [0x0E, 0x01, 0x0E, 0x01]
        @test assemble("NOOP\nSTART_LOOP 2\nPEEK\nEND_LOOP\nNOOP") == [0x0C, 0x0E, 0x0E, 0x0C]
    end

    @testset "wire example" begin
        src = """
        NOOP  *header*
        START_LOOP 4
        PEEK       *read the current input bit*
        POP        *write it to the output*
        EOT        *push 1 iff the head is at the last cell*
        HALT       *halt if so*
        ADVANCE    *otherwise step to the next bit*
        END_LOOP
        NOOP  *footer*
        """
        expected = UInt8[
            0x0C,
            0x0E, 0x01, 0x00, 0x03, 0x04,
            0x0E, 0x01, 0x00, 0x03, 0x04,
            0x0E, 0x01, 0x00, 0x03, 0x04,
            0x0E, 0x01, 0x00, 0x03, 0x04,
            0x0C,
        ]
        @test assemble(src) == expected
    end

    @testset "error conditions" begin
        @test_throws ErrorException assemble("PEEK *unclosed")
        @test_throws ErrorException assemble("PEEK BADOP POP")
        @test_throws ErrorException assemble("END_LOOP")
        @test_throws ErrorException assemble("START_LOOP 3\nNOOP")
        @test_throws ErrorException assemble(
            "START_LOOP 2\nSTART_LOOP 2\nNOOP\nEND_LOOP\nEND_LOOP")
        @test_throws ErrorException assemble("START_LOOP x\nNOOP\nEND_LOOP")
        @test_throws ErrorException assemble("START_LOOP 0\nNOOP\nEND_LOOP")
    end

end

# ---------------------------------------------------------------------------
# VM tests
# ---------------------------------------------------------------------------

@testset "VM" begin

    @testset "passthrough (PEEK POP)" begin
        prog = assemble("PEEK POP")
        @test run(prog, [bv(1)]) == bv(1)
        @test run(prog, [bv(0)]) == bv(0)
    end

    @testset "NAND truth table" begin
        prog = assemble("PEEK NEXT-TAPE PEEK NEXT-TAPE NAND POP")
        @test run(prog, [bv(0), bv(0)]) == bv(1)
        @test run(prog, [bv(0), bv(1)]) == bv(1)
        @test run(prog, [bv(1), bv(0)]) == bv(1)
        @test run(prog, [bv(1), bv(1)]) == bv(0)
    end

    @testset "NOT via DUP NAND" begin
        prog = assemble("PEEK DUP NAND POP")
        @test run(prog, [bv(0)]) == bv(1)
        @test run(prog, [bv(1)]) == bv(0)
    end

    @testset "AND via NAND+negate" begin
        prog = assemble("PEEK NEXT-TAPE PEEK NEXT-TAPE NAND DUP NAND POP")
        @test run(prog, [bv(0), bv(0)]) == bv(0)
        @test run(prog, [bv(0), bv(1)]) == bv(0)
        @test run(prog, [bv(1), bv(0)]) == bv(0)
        @test run(prog, [bv(1), bv(1)]) == bv(1)
    end

    @testset "wire (identity stream)" begin
        src = """
        NOOP
        START_LOOP 8
        PEEK POP EOT HALT ADVANCE
        END_LOOP
        NOOP
        """
        prog = assemble(src)
        input = bv(1,0,1,1,0,0,1,0)
        @test run(prog, [input]) == input
    end

    @testset "HALT fires on 1, not 0" begin
        # manufacture 1 on empty stack, then HALT — halts immediately
        prog = assemble("DUP DUP NAND NAND HALT")
        @test run(prog, BitVector[]) == bv()
        # DUP on empty stack pushes 0; HALT on 0 does not fire; POP writes 0
        prog2 = assemble("DUP HALT POP")
        @test run(prog2, BitVector[]) == bv(0)
    end

    @testset "SWAP" begin
        # push 0, push 1, SWAP → stack [1,0] top; POP→0, POP→1
        prog = assemble("PEEK ADVANCE PEEK SWAP POP POP")
        @test run(prog, [bv(0, 1)]) == bv(0, 1)
    end

    @testset "OVER" begin
        # push 1, push 0; OVER pushes copy of second = 1
        # POP→1, POP→0, POP→1
        prog = assemble("PEEK ADVANCE PEEK OVER POP POP POP")
        @test run(prog, [bv(1, 0)]) == bv(1, 0, 1)
    end

    @testset "ROT" begin
        # push 1(x), push 0(y), push 1(z); ROT: x y z → y z x = [0,1,1]
        # POP→1, POP→1, POP→0
        prog = assemble("PEEK ADVANCE PEEK ADVANCE PEEK ROT POP POP POP")
        @test run(prog, [bv(1, 0, 1)]) == bv(1, 1, 0)
    end

    @testset "POUR" begin
        # push 0(b0), push 1(b1), push 0(b2) from input
        # stack bottom→top: [0, 1, 0]
        # DUP DUP DUP NAND NAND manufactures 1 on top of any stack
        # POUR: pops trigger 1, drains remaining stack top-first → [0, 1, 0]
        prog = assemble("""
            PEEK ADVANCE
            PEEK ADVANCE
            PEEK
            DUP DUP DUP NAND NAND
            POUR
        """)
        @test run(prog, [bv(0, 1, 0)]) == bv(0, 1, 0)
    end

    @testset "EOT fires on last cell only" begin
        prog = assemble("EOT POP ADVANCE EOT POP")
        @test run(prog, [bv(0, 1)]) == bv(0, 1)
    end

    @testset "ADVANCE wraps" begin
        # single-cell tape: advance wraps back to cell 1; second PEEK reads same cell
        prog = assemble("PEEK ADVANCE PEEK POP POP")
        @test run(prog, [bv(1)]) == bv(1, 1)
    end

    @testset "RETREAT wraps" begin
        # two-cell tape [1,0]: retreat from cell 1 wraps to cell 2 (value 0)
        prog = assemble("RETREAT PEEK POP")
        @test run(prog, [bv(1, 0)]) == bv(0)
    end

    @testset "bias unit (no inputs)" begin
        prog = assemble("PEEK POP PEEK POP")
        @test run(prog, BitVector[]) == bv(1, 1)
    end

    @testset "CMOV" begin
        # input [b, a, c]: stack bottom→top = b, a, c
        # CMOV: pop c, pop a, pop b; push b if c=1, else push a
        prog = assemble("PEEK ADVANCE PEEK ADVANCE PEEK CMOV POP")
        @test run(prog, [bv(0, 1, 1)]) == bv(0)  # c=1 → b=0
        @test run(prog, [bv(0, 1, 0)]) == bv(1)  # c=0 → a=1
        @test run(prog, [bv(1, 0, 1)]) == bv(1)  # c=1 → b=1
        @test run(prog, [bv(1, 0, 0)]) == bv(0)  # c=0 → a=0
    end

    @testset "NEXT-TAPE cycles" begin
        # tape1=[1], tape2=[0]; read tape1, switch, read tape2
        prog = assemble("PEEK NEXT-TAPE PEEK POP POP")
        @test run(prog, [bv(1), bv(0)]) == bv(0, 1)
    end

    @testset "DROP" begin
        prog = assemble("PEEK PEEK DROP POP")
        @test run(prog, [bv(1)]) == bv(1)
    end

    @testset "invalid opcode" begin
        @test_throws ErrorException run(UInt8[0x10], BitVector[])
    end

    @testset "too many inputs" begin
        @test_throws ErrorException run(
            UInt8[0x0C],
            [BitVector(), BitVector(), BitVector(), BitVector()])
    end

end
