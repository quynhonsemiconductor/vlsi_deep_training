# =============================================================================
# CRM ROM program of the SCRC MCPU (MRV-CPU) -- QNSC_SCRC_MAS V3.4, 7.5 and 7.6
#
# Assembled by util/gen_crm_rom.py into util/gen/crm_rom/m_qnsc_scrc_crm_rom.sv.
# Only the 13 MRV instructions are accepted:
#   add sub and or addi andi ori lw sw jal jalr beq lui
# (no xor, no shift, no bne:  NOT x = (-1) - x;  "branch if != 0" = beq + jal)
#
# Runs from 0x1000 after EVERY release of w_rst_n_sys (POR, WDT bite, SW_RST).
# Changing the release order changes this file only, never the RTL.
#
# Registers kept for the whole program:
#   s0 = 0            base of SCRC CSR on the internal APB BUS
#   s1 = CLK_EN value already applied
#   s3 = copy of ICG_EN,  s4 = copy of RST_REL,  s5 = copy of APB_BLK
#   s6 = 0x0003_87F8  gateable mask (MAS Table 6-3)
#   t1 = 0xFFFF_FFFF  (in the runtime loop)
#
# SCRC CSR offsets (MAS Table 6-2): 0x04 CLK_EN, 0x0C ICG_EN, 0x10 RST_REL,
# 0x14 APB_BLK, 0x18 APB_BUSY. MCPU writes to 0x00/0x04/0x18 are dropped by its
# write filter; this program never makes one.
#
# Timing: MRV is single-cycle; every lw/sw takes >= 3 cycles (BIU IDLE, SETUP,
# ACCESS, DONE). A wait loop iteration (addi, beq, jal) is 3 cycles.
# =============================================================================

_start:
        addi s0, x0, 0
        lui  s6, 0x38                 # 0x0003_8000
        addi s6, s6, 0x7F8            # s6 = 0x0003_87F8
        lw   s1, 0x04(s0)             # CLK_EN, reset value 0x0003_87E8
        and  s3, s1, s6
        sw   s3, 0x0C(s0)             # 1. ICG_EN <- CLK_EN

        addi t6, x0, 1                # 2. wait >= 3 cycles (the sw already took >= 3)
W3A:    addi t6, t6, -1
        beq  t6, x0, REL
        jal  x0, W3A

REL:    lui  s4, 0x40                 # 0x0004_0000
        addi s4, s4, -1               # 0x0003_FFFF
        lui  t0, 0x6                  # 0x0000_6000 = bits 13, 14 (reserved, sysdbg)
        sub  s4, s4, t0               # 0x0003_9FFF
        sw   s4, 0x10(s0)             # 3. RST_REL: every domain except the CPU

        addi t6, x0, 6                # 4. wait >= 16 cycles (6 x 3)
W16:    addi t6, t6, -1
        beq  t6, x0, GUARD
        jal  x0, W16

GUARD:  addi t0, x0, -1
        sub  t0, t0, s1               # NOT CLK_EN
        and  s5, t0, s6
        sw   s5, 0x14(s0)             # 5. APB_BLK <- NOT CLK_EN AND mask: guards open FIRST

        lui  t0, 0x80000              # 0x8000_0000
        or   s4, s4, t0               # 0x8003_9FFF
        sw   s4, 0x10(s0)             # 6. RST_REL[31]: the CPU is released LAST

# ---- 7.6 runtime: poll CLK_EN, apply only what changed ----------------------
IDLE:   lw   t0, 0x04(s0)             # requested clock state
        beq  t0, s1, IDLE             # unchanged: keep polling
        addi t1, x0, -1
        sub  t2, t1, t0
        and  t2, t2, s1               # off = applied & ~requested
        sub  t3, t1, s1
        and  t3, t3, t0               # on  = requested & ~applied
        beq  t2, x0, START

STOP:   or   s5, s5, t2
        sw   s5, 0x14(s0)             # APB_BLK |= off     (guard closes first)
WBUSY:  lw   t4, 0x18(s0)
        and  t4, t4, t2
        beq  t4, x0, GATE             # APB_BUSY & off == 0: last transfer done
        jal  x0, WBUSY
GATE:   sub  t4, t1, t2
        and  s3, s3, t4
        sw   s3, 0x0C(s0)             # ICG_EN &= ~off     (then the clock stops)

START:  beq  t3, x0, DONE
        or   s3, s3, t3
        sw   s3, 0x0C(s0)             # ICG_EN |= on       (clock runs first)
        addi t6, x0, 1                # wait >= 3 cycles
W3B:    addi t6, t6, -1
        beq  t6, x0, OPEN
        jal  x0, W3B
OPEN:   sub  t4, t1, t3
        and  s5, s5, t4
        sw   s5, 0x14(s0)             # APB_BLK &= ~on     (then the guard opens)

DONE:   add  s1, t0, x0               # applied = requested
        jal  x0, IDLE
