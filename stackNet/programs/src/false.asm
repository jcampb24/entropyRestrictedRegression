* false.asm — constant 0, regardless of input *

DUP   * [..., x, x]        — copy unknown top x *
DUP   * [..., x, x, x]     — copy again *
DUP   * [..., x, x, x, x]  — copy again *
NAND  * [..., x, x, NOT x] — NAND(x, x) = NOT x *
NAND  * [..., x, 1]        — NAND(x, NOT x) = 1 always *
DUP   * [..., x, 1, 1]     — copy the 1 *
NAND  * [..., x, 0]        — NAND(1, 1) = 0 *
POP   * [..., x]            — write 0 to output *
