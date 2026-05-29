ASM := ./asm

SOURCES := $(shell find src -name '*.asm')
TARGETS := $(patsubst src/%.asm,bin/%.bc,$(SOURCES))

.PHONY: all clean

all: $(TARGETS)

bin/%.bc: src/%.asm
	@mkdir -p $(dir $@)
	$(ASM) $< $@

clean:
	find bin -name '*.bc' -delete
