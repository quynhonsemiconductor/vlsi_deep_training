#!/usr/bin/env python3
"""Assemble the SCRC CRM ROM program and generate m_qnsc_scrc_crm_rom.sv.

QNSC_SCRC_MAS V3.5: MCPU (MRV-CPU) runs a program from its own ROM, read
combinationally, starting at PARA_RESET_VECTOR = 0x1000. MRV implements 13
RV32I instructions; this assembler accepts exactly those, so the program can
never contain an instruction MRV does not decode. No RISC-V toolchain needed.

    python3 util/gen_crm_rom.py design/scrc/crm/crm_rom.S util/gen/crm_rom

writes <out>/m_qnsc_scrc_crm_rom.sv, <out>/crm_rom.hex (one word per line) and
<out>/crm_rom.lst (address, word, source line), and fails on any error.

The module is a constant case over the word index, like m_qnsc_rom_image
(QNSC_ROM_MAS 7.2): no initial, no $readmemh, no memory array, so synthesis
maps it to logic. An address outside the program returns addi x0,x0,0.

Syntax: one instruction per line, optional "label:" prefix, "#" comments.
  R: add sub and or        rd, rs1, rs2
  I: addi andi ori         rd, rs1, imm      (imm -2048..2047)
     jalr                  rd, imm(rs1)
     lw                    rd, imm(rs1)
  S: sw                    rs2, imm(rs1)
  B: beq                   rs1, rs2, label
  J: jal                   rd, label
  U: lui                   rd, imm20         (0..0xFFFFF)
Registers: x0..x31 or ABI names.
"""
import os
import re
import sys

BASE = 0x1000
DEPTH = 64          # words; the program is a few dozen (QNSC_SCRC_MAS 7.6: 64 words, the program uses 52)
NOP = 0x00000013

ABI = {"zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4, "t0": 5, "t1": 6, "t2": 7,
       "s0": 8, "fp": 8, "s1": 9, "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14,
       "a5": 15, "a6": 16, "a7": 17, "s2": 18, "s3": 19, "s4": 20, "s5": 21,
       "s6": 22, "s7": 23, "s8": 24, "s9": 25, "s10": 26, "s11": 27, "t3": 28,
       "t4": 29, "t5": 30, "t6": 31}
R_OP = {"add": (0b000, 0b0000000), "sub": (0b000, 0b0100000),
        "or": (0b110, 0b0000000), "and": (0b111, 0b0000000)}
I_OP = {"addi": 0b000, "ori": 0b110, "andi": 0b111}


class AsmError(Exception):
    pass


def reg(tok):
    tok = tok.strip().lower()
    if tok in ABI:
        return ABI[tok]
    m = re.fullmatch(r"x(\d+)", tok)
    if m and int(m.group(1)) < 32:
        return int(m.group(1))
    raise AsmError(f"bad register '{tok}'")


def num(tok):
    try:
        return int(tok.strip(), 0)
    except ValueError:
        raise AsmError(f"bad number '{tok}'")


def imm12(v):
    if not -2048 <= v <= 2047:
        raise AsmError(f"immediate {v} out of 12-bit range")
    return v & 0xFFF


def memop(tok):
    m = re.fullmatch(r"\s*(-?\w+)\s*\(\s*(\w+)\s*\)\s*", tok)
    if not m:
        raise AsmError(f"bad memory operand '{tok}'")
    return num(m.group(1)), reg(m.group(2))


def parse(path):
    """-> list of (addr, mnemonic, operands, lineno, text), labels dict."""
    prog, labels = [], {}
    pc = BASE
    for n, raw in enumerate(open(path, encoding="utf-8"), 1):
        line = raw.split("#", 1)[0].strip()
        while True:
            m = re.match(r"^([A-Za-z_]\w*)\s*:\s*(.*)$", line)
            if not m:
                break
            if m.group(1) in labels:
                raise AsmError(f"line {n}: label '{m.group(1)}' defined twice")
            labels[m.group(1)] = pc
            line = m.group(2)
        if not line:
            continue
        mn, _, rest = line.partition(" ")
        ops = [o.strip() for o in rest.split(",")] if rest.strip() else []
        prog.append((pc, mn.lower(), ops, n, raw.rstrip()))
        pc += 4
    return prog, labels


def encode(pc, mn, ops, labels):
    def target(lbl):
        if lbl not in labels:
            raise AsmError(f"undefined label '{lbl}'")
        return labels[lbl] - pc

    if mn in R_OP:
        f3, f7 = R_OP[mn]
        rd, rs1, rs2 = (reg(o) for o in ops)
        return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0b0110011
    if mn in I_OP:
        rd, rs1, imm = reg(ops[0]), reg(ops[1]), num(ops[2])
        return (imm12(imm) << 20) | (rs1 << 15) | (I_OP[mn] << 12) | (rd << 7) | 0b0010011
    if mn in ("lw", "jalr"):
        rd = reg(ops[0])
        imm, rs1 = memop(ops[1])
        f3, opc = (0b010, 0b0000011) if mn == "lw" else (0b000, 0b1100111)
        return (imm12(imm) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opc
    if mn == "sw":
        rs2 = reg(ops[0])
        imm, rs1 = memop(ops[1])
        i = imm12(imm)
        return ((i >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (0b010 << 12) | ((i & 0x1F) << 7) | 0b0100011
    if mn == "beq":
        rs1, rs2, off = reg(ops[0]), reg(ops[1]), target(ops[2])
        if off % 2 or not -4096 <= off <= 4094:
            raise AsmError(f"beq offset {off} out of range")
        o = off & 0x1FFF
        return (((o >> 12) & 1) << 31) | (((o >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | \
               (((o >> 1) & 0xF) << 8) | (((o >> 11) & 1) << 7) | 0b1100011
    if mn == "jal":
        rd, off = reg(ops[0]), target(ops[1])
        if off % 2 or not -(1 << 20) <= off < (1 << 20):
            raise AsmError(f"jal offset {off} out of range")
        o = off & 0x1FFFFF
        return (((o >> 20) & 1) << 31) | (((o >> 1) & 0x3FF) << 21) | (((o >> 11) & 1) << 20) | \
               (((o >> 12) & 0xFF) << 12) | (rd << 7) | 0b1101111
    if mn == "lui":
        rd, imm = reg(ops[0]), num(ops[1])
        if not 0 <= imm <= 0xFFFFF:
            raise AsmError(f"lui immediate {imm:#x} out of 20-bit range")
        return (imm << 12) | (rd << 7) | 0b0110111
    raise AsmError(f"'{mn}' is not one of the 13 MRV instructions")


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, out = sys.argv[1], sys.argv[2]
    try:
        prog, labels = parse(src)
        words = []
        for pc, mn, ops, n, _ in prog:
            try:
                words.append(encode(pc, mn, ops, labels))
            except (AsmError, IndexError, ValueError) as e:
                raise AsmError(f"{src}:{n}: {e}")
    except AsmError as e:
        sys.exit(f"gen_crm_rom: {e}")
    if len(words) > DEPTH:
        sys.exit(f"gen_crm_rom: {len(words)} words > DEPTH {DEPTH}")

    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "crm_rom.hex"), "w", newline="\n") as f:
        f.writelines(f"{w:08x}\n" for w in words)
    with open(os.path.join(out, "crm_rom.lst"), "w", encoding="utf-8", newline="\n") as f:
        for (pc, _, _, n, text), w in zip(prog, words):
            f.write(f"{pc:08x}  {w:08x}  {n:4d}  {text.strip()}\n")

    aw = (DEPTH - 1).bit_length()
    arms = "\n".join(f"      {aw}'d{i:<3}: o_imem_data = 32'h{w:08X};  // {prog[i][4].strip()}"
                     for i, w in enumerate(words))
    sv = f"""// =============================================================================
// GENERATED by util/gen_crm_rom.py from {src.replace(os.sep, '/')} -- DO NOT EDIT.
//
// m_qnsc_scrc_crm_rom -- program ROM of the SCRC MCPU (QNSC_SCRC_MAS V3.5, 3, 7.5, 7.6)
// Combinational read, as MRV-CPU requires. Program at 0x{BASE:04X}, {len(words)} of {DEPTH} words.
// Constant case: no initial, no array, synthesises to logic.
// =============================================================================
module m_qnsc_scrc_crm_rom (
  input  logic [31:0] i_imem_addr,   // MCPU o_imem_addr (byte address)
  output logic [31:0] o_imem_data    // MCPU i_imem_data
);
  logic [31:0]   w_offset;
  logic [{aw - 1}:0]    w_index;
  logic          w_in_image;

  assign w_offset   = i_imem_addr - 32'h{BASE:08X};
  assign w_index    = w_offset[{aw + 1}:2];
  assign w_in_image = (w_offset[31:{aw + 2}] == '0);

  always_comb begin
    o_imem_data = 32'h{NOP:08X};                   // addi x0, x0, 0
    if (w_in_image) begin
      case (w_index)
{arms}
      default: o_imem_data = 32'h{NOP:08X};
      endcase
    end
  end
endmodule
"""
    open(os.path.join(out, "m_qnsc_scrc_crm_rom.sv"), "w", encoding="utf-8", newline="\n").write(sv)
    print(f"gen_crm_rom: {len(words)} words, {len(labels)} labels -> {out}")


if __name__ == "__main__":
    main()
