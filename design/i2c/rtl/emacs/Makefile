DESIGN = m_qnsc_wrap_i2c

SRC_FILE = ${DESIGN}.src.sv
DST_FILE = ${DESIGN}.sv

.PHONY: all

all: emacs_wrapper rtl_fix

emacs_wrapper:
	cp -rf ${SRC_FILE} ${DST_FILE}
	emacs --batch ${DST_FILE} -f verilog-batch-auto

rtl_fix:
	echo "Replace parameter"
	sed -i 's,\[APB_ADDR_WIDTH-1,\[11,g' ${DST_FILE}
	cp ${DST_FILE} ../
