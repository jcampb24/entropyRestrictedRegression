* not.asm — bitwise NOT, up to 256 bits, LSB-first *

START_LOOP 256
PEEK
DUP
NAND
POP
EOT
HALT
ADVANCE
END_LOOP
