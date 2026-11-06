# =============================================================================
# Filelist for the scrc block (QNSC_SCRC_MAS V3.5).
#
# This is the single place that says which files build this block, and in what
# order. CI lints the block through this file, so a file not listed here is not
# compiled and not checked.
#
# Rules:
#   - Upstream IP is LISTED here, never copied into rtl/. Paths are relative to
#     this file, so they start with ../../vendor/...
#   - Order matters. Packages and `define files first, then leaf modules, then
#     the modules that instantiate them, then our wrapper last.
#   - Anything under rtl/ is code written here. Anything under ../../vendor/ is
#     not ours -- see vendor/manifest.yml for its pinned commit and licence.
#   - Generated RTL lives in ../../util/gen/<name>/ with the recipe that makes
#     it; never edit it, regenerate it (make gen IP=<name>).
#   - The technology cells (qnsc_clk_gate, qnsc_clk_buf, qnsc_rst_sync,
#     qnsc_sync_cell, qnsc_rst_filter) are not listed: every flow appends
#     design/common/tech/$(TECH).f as library files.
# =============================================================================

# ---- upstream IP: MRV-CPU (MCPU) --------------------------------------------
../../vendor/nguyenquanicd/MRV-CPU/rtl/m_vlsit_mrv_cpu_alu.sv
../../vendor/nguyenquanicd/MRV-CPU/rtl/m_vlsit_mrv_cpu_biu.sv
../../vendor/nguyenquanicd/MRV-CPU/rtl/m_vlsit_mrv_cpu_brcomp.sv
../../vendor/nguyenquanicd/MRV-CPU/rtl/m_vlsit_mrv_cpu_immgen.sv
../../vendor/nguyenquanicd/MRV-CPU/rtl/m_vlsit_mrv_cpu_ctrl.sv
../../vendor/nguyenquanicd/MRV-CPU/rtl/m_vlsit_mrv_cpu_regfile.sv
../../vendor/nguyenquanicd/MRV-CPU/rtl/m_vlsit_mrv_cpu.sv

# ---- generated: CRM ROM (util/gen/crm_rom, from crm/crm_rom.S) ----------------
../../util/gen/crm_rom/m_qnsc_scrc_crm_rom.sv

# ---- generated: internal APB BUS (util/gen/scrc_bus, APB-BUS-Generator) -------
../../util/gen/scrc_bus/m_qnsc_scrc_apb_bus_rr.v
../../util/gen/scrc_bus/m_qnsc_scrc_apb_bus_arb_csr.sv
../../util/gen/scrc_bus/m_qnsc_scrc_apb_bus_dec_mcpu.sv
../../util/gen/scrc_bus/m_qnsc_scrc_apb_bus_dec_ibex.sv
../../util/gen/scrc_bus/m_qnsc_scrc_apb_bus.sv

# ---- generated: SCRC CSR (util/gen/scrc_csr, APB-CSR-Generator) --------------
../../util/gen/scrc_csr/m_qnsc_scrc_csr.sv

# ---- ours: SCRC ---------------------------------------------------------------
rtl/m_qnsc_scrc_ctrl.sv
rtl/m_qnsc_scrc_rrc.sv
rtl/m_qnsc_scrc_apb_wfilter.sv

# ---- ours: delivered to design/top (instantiated there, not in m_qnsc_scrc) --
# m_qnsc_scrc_apb_guard: 11 instances, one per gateable APB slave
rtl/m_qnsc_scrc_apb_guard.sv

# ---- ours: the block top, last (make connectivity takes the last file as top) --
rtl/m_qnsc_scrc.sv
