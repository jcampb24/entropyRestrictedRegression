* true.asm — constant 1, regardless of input *

DUP   * [..., x, x]        — copy unknown top x *
DUP   * [..., x, x, x]     — copy again *
DUP   * [..., x, x, x, x]  — copy again *
NAND  * [..., x, x, NOT x] — NAND(x, x) = NOT x *
NAND  * [..., x, 1]        — NAND(x, NOT x) = 1 always *
POP   * [..., x]            — write 1 to output *
