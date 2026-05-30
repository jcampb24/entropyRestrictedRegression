* not-b.asm — bitwise NOT b: negate tape 2, stop when either tape ends *

NOOP       * header *

START_LOOP 256
NEXT-TAPE  *                       — active tape 2 *
PEEK       * [..., b]              — read b *
NEXT-TAPE  *                       — active tape 1 *
DUP        * [..., b, b]           — copy b *
NAND       * [..., NOT b]          — NAND(b, b) = NOT b *
POP        *                       — emit NOT b *
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
