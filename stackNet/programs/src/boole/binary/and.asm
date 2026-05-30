* and.asm — bitwise AND of two input tapes, up to 256 bits *
* halts when either tape reaches its last cell                         *

NOOP       * header *

START_LOOP 256
PEEK       * [..., a]              — read a from tape 1 *
NEXT-TAPE  *                       — active tape 2 *
PEEK       * [..., a, b]           — read b *
NEXT-TAPE  *                       — active tape 1 *
NAND       * [..., NAND(a,b)]      — NAND(a, b) *
DUP        * [..., NAND(a,b), NAND(a,b)] *
NAND       * [..., AND(a,b)]       — negate → AND(a, b) *
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
