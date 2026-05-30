* false.asm — constant 0 per position, up to 256 bits     *
* advances both tapes in lockstep; halts when either reaches last cell *

NOOP       * header *

START_LOOP 256
DUP        * [..., x, x]        — copy unknown top x *
DUP        * [..., x, x, x]     — copy again *
DUP        * [..., x, x, x, x]  — copy again *
NAND       * [..., x, x, NOT x] — NAND(x, x) = NOT x *
NAND       * [..., x, 1]        — NAND(x, NOT x) = 1 always *
DUP        * [..., x, 1, 1]     — copy the 1 *
NAND       * [..., x, 0]        — NAND(1, 1) = 0 *
POP        * [..., x]            — emit 0 *
EOT        * [..., x, eA]        — tape 1 at last cell? *
DUP        * [..., x, eA, eA]    *
NAND       * [..., x, NOT eA]    — negate *
NEXT-TAPE  *                     — active tape 2 *
EOT        * [..., x, NOT eA, eB] — tape 2 at last cell? *
DUP        * [..., x, NOT eA, eB, eB] *
NAND       * [..., x, NOT eA, NOT eB] — negate *
NAND       * [..., x, eA OR eB]  — OR via De Morgan *
HALT       *                     — halt if either tape ended *
ADVANCE    *                     — advance tape 2 *
NEXT-TAPE  *                     — active tape 1 *
ADVANCE    *                     — advance tape 1 *
END_LOOP

NOOP       * footer *
