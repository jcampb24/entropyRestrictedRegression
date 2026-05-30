* xnor.asm — bitwise XNOR of two input tapes, up to 256 bits *
* halts when either tape reaches its last cell                          *
* XNOR(a,b) = 1 iff a = b: output NOT a if b=0, else a                 *

NOOP       * header *

START_LOOP 256
PEEK       * [..., a]              — read a from tape 1 *
DUP        * [..., a, a]           — copy a *
DUP        * [..., a, a, a]        — copy again *
NAND       * [..., a, NOT a]       — NAND(a, a) = NOT a *
NEXT-TAPE  *                       — active tape 2 *
PEEK       * [..., a, NOT a, b]    — read b *
NEXT-TAPE  *                       — active tape 1 *
CMOV       * [..., result]         — b=0: select NOT a; b=1: select a *
POP        *                       — emit result *
EOT        * [..., eA]             — tape 1 at last cell? *
DUP        * [..., eA, eA]         *
NAND       * [..., NOT eA]         — negate *
NEXT-TAPE  *                       — active tape 2 *
EOT        * [..., NOT eA, eB]     — tape 2 at last cell? *
DUP        * [..., NOT eA, eB, eB] *
NAND       * [..., NOT eA, NOT eB] — negate *
NAND       * [..., eA OR eB]       — OR via De Morgan *
HALT       *                       — halt if either tape ended *
ADVANCE    *                       — advance tape 2 *
NEXT-TAPE  *                       — active tape 1 *
ADVANCE    *                       — advance tape 1 *
END_LOOP

NOOP       * footer *
