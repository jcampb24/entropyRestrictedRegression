* true.asm — constant 1 per input bit, up to 256 bits, LSB-first *

NOOP    * header *

START_LOOP 256
DUP     * [..., x, x]        — copy unknown top x *
DUP     * [..., x, x, x]     — copy again *
DUP     * [..., x, x, x, x]  — copy again *
NAND    * [..., x, x, NOT x] — NAND(x, x) = NOT x *
NAND    * [..., x, 1]        — NAND(x, NOT x) = 1 always *
POP     * [..., x]            — write 1 to output *
EOT     * [..., x, e]        — push 1 if at last cell, 0 otherwise *
HALT    * [..., x]            — halt if at last cell *
ADVANCE *                     — step tape 1 *
END_LOOP

NOOP    * footer *
