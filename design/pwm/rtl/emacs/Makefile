DESIGN = m_qnsc_wrap_pwm

SRC_FILE = ${DESIGN}.src.sv
DST_FILE = ${DESIGN}.sv

.PHONY: all emacs_wrapper rtl_fix

all: emacs_wrapper rtl_fix

emacs_wrapper:
	cp -f ${SRC_FILE} ${DST_FILE}
	emacs --batch ${DST_FILE} -f verilog-batch-auto

# -i.bak works with both GNU sed (Linux server) and BSD sed (macOS).
rtl_fix:
	echo "Replace parameter"
	sed -i.bak 's,\[APB_ADDR_WIDTH-1,[C_APB_PADDR_WIDTH-1,g' ${DST_FILE} && rm -f ${DST_FILE}.bak
	cp ${DST_FILE} ../
