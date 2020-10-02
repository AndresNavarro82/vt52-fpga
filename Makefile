NAME = vga

# track verilog and hex files TODO
MDIR1 := font
MDIR2 := pantalla
MEMS := $(wildcard $(MDIR1)/*.hex) $(wildcard $(MDIR2)/*.hex)
SRCS := $(wildcard *.c)

.PHONY: all
all: $(NAME).bin

prog: $(NAME).bin
	iceprog $<

$(NAME).bin: $(NAME).asc 
	icepack $< $@

$(NAME).asc: $(NAME).json
	nextpnr-ice40 --hx1k --package tq144 --json $< --pcf $(NAME).pcf --asc $@

$(NAME).json: $(SRCS) $(MEMS)
	yosys -p 'synth_ice40 -top top -json $@' $(NAME).v

clean:
	rm -f $(NAME).bin
	rm -f $(NAME).asc
	rm -f $(NAME).json

