* identity.asm — copy input to output, up to 256 bits *

START_LOOP 256
PEEK    * [..., x]  — read current bit *
POP     * [...]     — write x to output *
EOT     * [..., e]  — push 1 if at last bit, 0 otherwise *
HALT    * [...]     — halt if at last bit *
ADVANCE * advance to next bit *
END_LOOP
