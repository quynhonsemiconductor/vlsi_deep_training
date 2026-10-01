# APB Decoder Generator Makefile

PYTHON := python3
RTL_GEN := apb_dec_rtl_generator.py
TB_GEN := apb_dec_tb_generator.py

EXCEL := APB_DEC_Example.xlsx
SHEET :=
OUTPUT_DIR := output

# Module name extracted from Excel (default: m_vlsit_apbdec)
# The RTL generator will create <module_name>.json
MODULE_NAME := m_vlsit_apbdec
JSON_CONFIG := $(OUTPUT_DIR)/$(MODULE_NAME).json

.PHONY: all rtl tb clean help

all: rtl tb

rtl:
	@$(PYTHON) $(RTL_GEN) $(EXCEL) $(SHEET) $(OUTPUT_DIR)

tb: rtl
	@$(PYTHON) $(TB_GEN) $(JSON_CONFIG) $(OUTPUT_DIR)

clean:
	rm -rf $(OUTPUT_DIR)/*

help:
	@echo "APB Decoder Generator Targets:"
	@echo "  make all   - Generate both RTL and TB"
	@echo "  make rtl   - Generate RTL only (decoder + JSON config)"
	@echo "  make tb    - Generate TB only (testbench + filelist)"
	@echo "  make clean - Remove all generated files"
	@echo ""
	@echo "Variables:"
	@echo "  EXCEL=<file>  - Specify Excel file (default: APB_DEC_Example.xlsx)"
	@echo "  SHEET=<name>  - Specify sheet name (default: first sheet)"
	@echo ""
	@echo "Examples:"
	@echo "  make rtl EXCEL=my_config.xlsx"
	@echo "  make all EXCEL=my_config.xlsx SHEET=APB_DEC"
