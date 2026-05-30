* b-implies-a.asm — bitwise b → a: NAND(NOT a, b), stop when either tape ends *
* false only when b=1 and a=0                                                  *

NOOP       * header *

START_LOOP 256
PEEK       * [..., a]              — read a from tape 1 *
DUP        * [..., a, a]           — copy a *
NAND       * [..., NOT a]          — NAND(a, a) = NOT a *
NEXT-TAPE  *                       — active tape 2 *
PEEK       * [..., NOT a, b]       — read b *
NEXT-TAPE  *                       — active tape 1 *
NAND       * [..., b → a]          — NAND(NOT a, b) = b → a *
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
