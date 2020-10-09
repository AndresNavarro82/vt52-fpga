NAME = vga

# track verilog and hex files TODO
MDIR1 := font
MDIR2 := pantalla
MEMS := $(wildcard $(MDIR1)/*.hex) $(wildcard $(MDIR2)/*.hex)
SRCS := $(wildcard *.v)

.PHONY: all clean

all: $(NAME).bin

prog: $(NAME).bin
	tinyprog -p $<

$(NAME).bin: $(NAME).asc 
	icepack $< $@

$(NAME).asc: $(NAME).json $(NAME).pcf
	nextpnr-ice40 --lp8k --package cm81 --json $< --pcf $(NAME).pcf --asc $@

$(NAME).json: $(SRCS) $(MEMS)
	yosys -p 'synth_ice40 -top top -json $@' $(SRCS)

clean:
	rm -f $(NAME).bin
	rm -f $(NAME).asc
	rm -f $(NAME).json

