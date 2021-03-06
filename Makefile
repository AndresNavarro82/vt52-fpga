NAME := vt52

MEM_DIR := mem
RTL_USB_DIR := tinyfpga_bx_usbserial/usb

MEMS := $(MEM_DIR)/empty.hex $(MEM_DIR)/test.hex \
	$(MEM_DIR)/terminus_816_latin1.hex $(MEM_DIR)/terminus_816_bold_latin1.hex \
	$(MEM_DIR)/keymap.hex
SRCS := char_buffer.v char_rom.v clock_generator.v command_handler.v cursor.v \
	cursor_blinker.v keyboard.v keymap_rom.v pll.v simple_register.v \
	video_generator.v vt52.v
USB_SRCS := \
	$(RTL_USB_DIR)/edge_detect.v \
	$(RTL_USB_DIR)/serial.v \
	$(RTL_USB_DIR)/usb_fs_in_arb.v \
	$(RTL_USB_DIR)/usb_fs_in_pe.v \
	$(RTL_USB_DIR)/usb_fs_out_arb.v \
	$(RTL_USB_DIR)/usb_fs_out_pe.v \
	$(RTL_USB_DIR)/usb_fs_pe.v \
	$(RTL_USB_DIR)/usb_fs_rx.v \
	$(RTL_USB_DIR)/usb_fs_tx_mux.v \
	$(RTL_USB_DIR)/usb_fs_tx.v \
	$(RTL_USB_DIR)/usb_reset_det.v \
	$(RTL_USB_DIR)/usb_serial_ctrl_ep.v \
	$(RTL_USB_DIR)/usb_uart_bridge_ep.v \
	$(RTL_USB_DIR)/usb_uart_core.v \
	$(RTL_USB_DIR)/usb_uart_i40.v

PIN_DEF := $(NAME).pcf

DEVICE := lp8k
PACKAGE := cm81

CLK_MHZ := 48
CLK_CONSTRAINTS := clock_constraints.py

.PHONY: all clean

all: $(NAME).bin

pll.v:
	icepll -i 16 -o $(CLK_MHZ) -m -f $@

prog: $(NAME).bin
	tinyprog -p $<

$(NAME).bin: $(NAME).asc
	icepack $< $@

$(NAME).asc: $(NAME).json $(PIN_DEF)
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --freq $(CLK_MHZ) --pre-pack $(CLK_CONSTRAINTS) --json $< --pcf $(NAME).pcf --asc $@

$(NAME).json: $(SRCS) $(USB_SRCS) $(MEMS)
	yosys -p 'synth_ice40 -top top -json $@' $(SRCS) $(USB_SRCS)

clean:
	rm -f $(NAME).bin $(NAME).asc $(NAME).json pll.v
