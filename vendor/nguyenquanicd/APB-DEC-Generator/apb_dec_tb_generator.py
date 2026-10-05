#!/usr/bin/env python3
"""
APB Decoder Testbench Generator
Reads JSON config from RTL generation and generates SystemVerilog testbench.
"""

import json
import os
import sys
from datetime import datetime
import subprocess


def get_author():
    """Get current system username."""
    try:
        return subprocess.check_output(['whoami'], text=True).strip()
    except Exception:
        return 'unknown'


def generate_header(module_name, description='', **kwargs):
    """Generate file header."""
    author = get_author()
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    header = f'''//--------------------------------------
//Project: APB Decoder Generator
//Module:  {module_name}
//Function: {description}
//Author:  {author}
//Script Author: Thang Luong (superzeldalink)
//Page:    VLSI Technology
//--------------------------------------
// Generated: {timestamp}
//--------------------------------------
'''
    
    # Add optional parameters
    if kwargs:
        for key, value in kwargs.items():
            header += f'// {key}: {value}\n'
        header += '//--------------------------------------\n'
    
    return header


def load_json_config(json_path):
    """Load configuration from JSON file."""
    with open(json_path, 'r') as f:
        return json.load(f)


def generate_tb_sv(config, output_path):
    """Generate a SystemVerilog testbench template using APB BFM."""
    module_name = config['module_name'] or 'apb_decoder'
    addr_width = config['address_width'] or 16
    data_width = config['data_width'] or 32
    write_strobe = config['write_strobe'] or 4
    pslverr_on_unmapped = config.get('pslverr_on_unmapped', 1)
    slaves = config['slaves']
    num_slaves = len(slaves)

    # Build slave instantiation connections
    slave_inst_ports = ""
    for slave in slaves:
        slave_lower = slave['name'].lower()
        slave_inst_ports += f'''    .o_psel_{slave_lower}(o_psel_{slave_lower}),
    .o_penable_{slave_lower}(o_penable_{slave_lower}),
    .o_pwrite_{slave_lower}(o_pwrite_{slave_lower}),
    .o_paddr_{slave_lower}(o_paddr_{slave_lower}),
    .o_pwdata_{slave_lower}(o_pwdata_{slave_lower}),
    .o_pstrb_{slave_lower}(o_pstrb_{slave_lower}),
    .i_pready_{slave_lower}(i_pready_{slave_lower}),
    .i_pslverr_{slave_lower}(i_pslverr_{slave_lower}),
    .i_prdata_{slave_lower}(i_prdata_{slave_lower}),
'''

    # Build slave BFM instantiations
    slave_bfm_insts = ""
    for i, slave in enumerate(slaves):
        slave_lower = slave['name'].lower()
        slave_addr_width = slave['address_width']
        slave_bfm_insts += f'''
  // Slave {i+1}: {slave['name']}
  apb_slave_bfm #(
    .PARA_ADDR_WIDTH({slave_addr_width}),
    .PARA_DATA_WIDTH({data_width}),
    .PARA_APB_WAIT_STATES(0)
  ) u_{slave_lower}_slave_bfm (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_paddr(o_paddr_{slave_lower}),
    .i_pwdata(o_pwdata_{slave_lower}),
    .o_prdata(i_prdata_{slave_lower}),
    .i_pwrite(o_pwrite_{slave_lower}),
    .i_psel(o_psel_{slave_lower}),
    .i_penable(o_penable_{slave_lower}),
    .o_pready(i_pready_{slave_lower}),
    .o_pslverr(i_pslverr_{slave_lower}),
    .i_pstrb(o_pstrb_{slave_lower}),
    .i_pprot(3'b000)
  );
'''

    header = generate_header(
        module_name, 
        'APB Decoder Testbench',
        **{
            'Address Width': addr_width,
            'Data Width': data_width,
            'Write Strobe': write_strobe,
            'Number of Slaves': num_slaves
        }
    )
    tb = header + f'''
// ============================================================================
// Testbench for {module_name}
// Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
// ============================================================================

`timescale 1ns/1ps

module {module_name}_tb;

// Parameters
localparam int ADDR_WIDTH = {addr_width};
localparam int DATA_WIDTH = {data_width};
localparam int WRITE_STROBE = {write_strobe};

// Clock and Reset
logic i_clk;
logic i_rst_n;

// Master Signals (connected to master BFM)
logic [ADDR_WIDTH-1:0]  m_paddr;
logic [DATA_WIDTH-1:0]  m_pwdata;
logic [DATA_WIDTH-1:0]  m_prdata;  // From DUT (read data)
logic                   m_pwrite;
logic                   m_psel;
logic                   m_penable;
logic                   m_pready;
logic                   m_pslverr;
logic [WRITE_STROBE-1:0] m_pstrb;
logic [2:0]              m_pprot;

// Slave Signals (connected to DUT and slave BFMs)
'''

    # Slave signals - use slave-specific address widths
    for slave in slaves:
        slave_lower = slave['name'].lower()
        slave_addr_width = slave['address_width']
        tb += f'''// Slave: {slave['name']}
logic                   o_psel_{slave_lower};
logic                   o_penable_{slave_lower};
logic                   o_pwrite_{slave_lower};
logic [{slave_addr_width-1}:0]  o_paddr_{slave_lower};
logic [DATA_WIDTH-1:0]  o_pwdata_{slave_lower};
logic [WRITE_STROBE-1:0] o_pstrb_{slave_lower};
logic                   i_pready_{slave_lower};
logic                   i_pslverr_{slave_lower};
logic [DATA_WIDTH-1:0]  i_prdata_{slave_lower};

'''

    tb += f'''// Instantiate DUT
{module_name} u_{module_name} (
    .i_paddr(m_paddr),
    .i_pwrite(m_pwrite),
    .i_psel(m_psel),
    .i_penable(m_penable),
    .i_pwdata(m_pwdata),
    .i_pstrb(m_pstrb),
    .o_pready(m_pready),
    .o_pslverr(m_pslverr),
    .o_prdata(m_prdata),
'''

    tb += slave_inst_ports.rstrip(',\n') + '\n);\n\n'

    # Clock generation
    tb += f'''// Clock generation (10ns period = 100MHz)
initial begin
  i_clk = 0;
  forever #5 i_clk = ~i_clk;
end

// Reset generation
initial begin
  i_rst_n = 1'b0;
  #50;
  i_rst_n = 1'b1;
end

// Master BFM
apb_master_bfm #(
  .PARA_ADDR_WIDTH({addr_width}),
  .PARA_DATA_WIDTH({data_width}),
  .PARA_APB_WAIT_STATES(0)
) u_master_bfm (
  .i_clk(i_clk),
  .i_rst_n(i_rst_n),
  .o_paddr(m_paddr),
  .o_pwdata(m_pwdata),
  .i_prdata(m_prdata),  // Connected to DUT output
  .o_pwrite(m_pwrite),
  .o_psel(m_psel),
  .o_penable(m_penable),
  .i_pready(m_pready),
  .o_pstrb(m_pstrb),
  .o_pprot(m_pprot)
);
'''

    # Slave BFM instantiations
    tb += slave_bfm_insts

    # Waveform dump
    tb += f'''
// Waveform dump
initial begin
`ifdef VCS
  $fsdbDumpfile("wave.fsdb");
  $fsdbDumpvars(0, m_vlsit_apbdec_tb, "+mda");
`else
  $dumpfile("wave.vcd");
  $dumpvars(0, m_vlsit_apbdec_tb);
`endif
end

// Test sequence
initial begin
  logic [DATA_WIDTH-1:0] v_rdata;  // Temporary variable for BFM reads
  localparam logic PSLVERR_VAL = {pslverr_on_unmapped}'b1;
  integer test_num;
  integer test_pass;
  integer test_fail;
  test_num = 0;
  test_pass = 0;
  test_fail = 0;

  // Wait for reset to complete
  @(posedge i_rst_n);

  $display("");
  $display("========================================");
  $display("APB Decoder Testbench");
  $display("========================================");
  $display("");

'''

    # Dynamically generate tests for each slave
    for i, slave in enumerate(slaves):
        slave_name = slave['name']
        offset = slave['offset']
        offset_val = offset.replace('0x', f"{addr_width}'h") if offset.startswith('0x') else f"{addr_width}'h{offset}"
        test_data = f"32'h{i:02X}{i:02X}{i:02X}{i:02X}"

        tb += f'''  // ============================================================================
  // Test {i+1}: Basic read from {slave_name} at {offset}
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Read from {slave_name} (offset {offset})", test_num);
  u_master_bfm.read({offset_val}, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0x00000000 - cleared memory)", v_rdata);
  test_pass++;

  // ============================================================================
  // Test {i+2}: Write to {slave_name}
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Write to {slave_name} (offset {offset})", test_num);
  u_master_bfm.write({offset_val}, {test_data});
  $display("[TB] Wrote: {test_data}");
  test_pass++;

  // ============================================================================
  // Test {i+3}: Read back to verify write
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Read back from {slave_name} to verify", test_num);
  u_master_bfm.read({offset_val}, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: {test_data})", v_rdata);
  if (v_rdata === {test_data}) begin
    $display("[TB] ✓ PASS: {slave_name} data match!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: {slave_name} data mismatch!");
    test_fail++;
  end

'''

    # Byte-lane tests on first slave
    if len(slaves) > 0:
        first_slave = slaves[0]
        first_offset = first_slave['offset']
        first_offset_val = first_offset.replace('0x', f"{addr_width}'h") if first_offset.startswith('0x') else f"{addr_width}'h{first_offset}"
        tb += f'''  // ============================================================================
  // Test {len(slaves)*3 + 1}: Byte-lane write test (lower byte) on {first_slave['name']}
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Byte-lane write to {first_slave['name']} (lower byte only)", test_num);
  // First clear the register
  u_master_bfm.write_strb({first_offset_val}, 32'h00000000, 4'b1111);
  // Write only lower byte
  u_master_bfm.write_strb({first_offset_val}, 32'h12345678, 4'b0001);
  u_master_bfm.read({first_offset_val}, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0x00000078)", v_rdata);
  if (v_rdata === 32'h00000078) begin
    $display("[TB] ✓ PASS: Lower byte write correct!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: Lower byte write incorrect!");
    test_fail++;
  end

  // ============================================================================
  // Test {len(slaves)*3 + 2}: Byte-lane write test (upper byte) on {first_slave['name']}
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Byte-lane write to {first_slave['name']} (upper byte only)", test_num);
  // First clear the register
  u_master_bfm.write_strb({first_offset_val}, 32'h00000000, 4'b1111);
  // Write only upper byte
  u_master_bfm.write_strb({first_offset_val}, 32'h12345678, 4'b1000);
  u_master_bfm.read({first_offset_val}, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0x12000000)", v_rdata);
  if (v_rdata === 32'h12000000) begin
    $display("[TB] ✓ PASS: Upper byte write correct!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: Upper byte write incorrect!");
    test_fail++;
  end

'''

    # Slave isolation test (write to first, read from second)
    if len(slaves) >= 2:
        first_slave = slaves[0]
        second_slave = slaves[1]
        first_offset = first_slave['offset']
        first_offset_val = first_offset.replace('0x', f"{addr_width}'h") if first_offset.startswith('0x') else f"{addr_width}'h{first_offset}"
        second_offset = second_slave['offset']
        second_offset_val = second_offset.replace('0x', f"{addr_width}'h") if second_offset.startswith('0x') else f"{addr_width}'h{second_offset}"
        tb += f'''  // ============================================================================
  // Test {len(slaves)*3 + 3}: Verify slave isolation ({first_slave['name']} vs {second_slave['name']})
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Verify slave isolation", test_num);
  u_master_bfm.write({second_offset_val}, 32'hFFFFFFFF);  // Write to {second_slave['name']}
  u_master_bfm.write({first_offset_val}, 32'h00000000);   // Write to {first_slave['name']}
  u_master_bfm.read({second_offset_val}, v_rdata);
  $display("[TB] {second_slave['name']} data after {first_slave['name']} write: 0x%08h (expected: 0xFFFFFFFF)", v_rdata);
  if (v_rdata === 32'hFFFFFFFF) begin
    $display("[TB] ✓ PASS: Slaves are isolated!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: Slave isolation broken!");
    test_fail++;
  end

'''

    # Boundary test on first slave
    if len(slaves) > 0:
        first_slave = slaves[0]
        first_offset = first_slave['offset']
        first_offset_val = first_offset.replace('0x', f"{addr_width}'h") if first_offset.startswith('0x') else f"{addr_width}'h{first_offset}"
        end_addr = first_slave.get('end_address', '')
        if end_addr:
            end_addr_val = end_addr.replace('0x', f"{addr_width}'h") if end_addr.startswith('0x') else f"{addr_width}'h{end_addr}"
            tb += f'''  // ============================================================================
  // Test {len(slaves)*3 + 4}: Access at {first_slave['name']} boundary ({end_addr})
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Access at {first_slave['name']} boundary ({end_addr})", test_num);
  u_master_bfm.write({end_addr_val}, 32'hFEDCBA98);
  u_master_bfm.read({end_addr_val}, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0xFEDCBA98)", v_rdata);
  if (v_rdata === 32'hFEDCBA98) begin
    $display("[TB] ✓ PASS: Boundary access correct!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: Boundary access incorrect!");
    test_fail++;
  end

'''

    # Unmapped address tests
    tb += f'''  // ============================================================================
  // Test {len(slaves)*3 + 5}: Unmapped address access (0xFFFF - outside all slaves)
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Unmapped address access (0xFFFF - outside all slaves)", test_num);
  $display("[TB] Expected: PSLVERR should be asserted, no hang");
  u_master_bfm.read({addr_width}'hFFFF, v_rdata);
  $display("[TB] Read from unmapped 0xFFFF: 0x%08h, PSLVERR = %b", v_rdata, m_pslverr);
  if (m_pslverr === PSLVERR_VAL) begin
    $display("[TB] ✓ PASS: PSLVERR correct for unmapped access!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: PSLVERR mismatch for unmapped access!");
    test_fail++;
  end

  // ============================================================================
  // Test {len(slaves)*3 + 6}: Verify PSLVERR deasserted for valid access
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Verify PSLVERR deasserted for valid access", test_num);
  u_master_bfm.write({first_offset_val}, {data_width}'hFACEFACE);
  u_master_bfm.read({first_offset_val}, v_rdata);
  $display("[TB] Valid {first_slave['name']} access: 0x%08h, PSLVERR = %b", v_rdata, m_pslverr);
  if (m_pslverr === 1'b0) begin
    $display("[TB] ✓ PASS: PSLVERR deasserted for valid access!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: PSLVERR asserted for valid access!");
    test_fail++;
  end

'''

    # Gap test (if there are gaps between slaves)
    if len(slaves) >= 2:
        gap_found = False
        for i in range(len(slaves) - 1):
            curr_end = slaves[i].get('end_address', '')
            next_offset = slaves[i+1].get('offset', '')
            if curr_end and next_offset and not gap_found:
                try:
                    curr_end_int = int(curr_end.replace('0x', ''), 16)
                    next_offset_int = int(next_offset.replace('0x', ''), 16)
                    if next_offset_int > curr_end_int + 1:
                        gap_addr = curr_end_int + 1
                        gap_addr_hex = f"{addr_width}'h{gap_addr:04X}"
                        gap_test_name = slaves[i]['name']
                        gap_test_name2 = slaves[i+1]['name']
                        gap_test_num = len(slaves)*3 + 7
                        tb += f'''  // ============================================================================
  // Test {gap_test_num}: Unmapped address in gap between {gap_test_name} and {gap_test_name2}
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Unmapped address in gap (0x{gap_addr:04X} - between {gap_test_name} and {gap_test_name2})", test_num);
  u_master_bfm.read({gap_addr_hex}, v_rdata);
  $display("[TB] Read from gap 0x{gap_addr:04X}: 0x%08h, PSLVERR = %b", v_rdata, m_pslverr);
  if (m_pslverr === PSLVERR_VAL) begin
    $display("[TB] ✓ PASS: PSLVERR correct for gap access!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: PSLVERR mismatch for gap access!");
    test_fail++;
  end

'''
                        gap_found = True
                except (ValueError, AttributeError):
                    pass

    # Back-to-back writes test
    tb += f'''  // ============================================================================
  // Test {len(slaves)*3 + 8}: Back-to-back writes to {first_slave['name']}
  // ============================================================================
  test_num++;
  $display("[TB] Test %0d: Back-to-back writes to {first_slave['name']}", test_num);
  u_master_bfm.write({first_offset_val}, {data_width}'h11111111);
  u_master_bfm.write({first_offset_val}, {data_width}'h22222222);
  u_master_bfm.write({first_offset_val}, {data_width}'h33333333);
  u_master_bfm.read({first_offset_val}, v_rdata);
  $display("[TB] Read data: 0x%08h (expected: 0x33333333)", v_rdata);
  if (v_rdata === {data_width}'h33333333) begin
    $display("[TB] ✓ PASS: Back-to-back writes correct!");
    test_pass++;
  end else begin
    $display("[TB] ✗ FAIL: Back-to-back writes incorrect!");
    test_fail++;
  end

  $display("");
  $display("========================================");
  $display("[TB] Test Summary");
  $display("========================================");
  $display("[TB] Total Tests: %0d", test_num);
  $display("[TB] Passed:      %0d", test_pass);
  $display("[TB] Failed:      %0d", test_fail);
  $display("========================================");
  if (test_fail > 0) begin
    $display("[TB] ✗ OVERALL RESULT: FAIL");
    $finish(1);
  end else begin
    $display("[TB] ✓ OVERALL RESULT: PASS");
    $finish(0);
  end
end

endmodule
'''

    with open(output_path, 'w') as f:
        f.write(tb)
    print(f"Generated: {output_path}")


def generate_filelist(output_dir, module_name):
    """Generate filelist.f for TB (includes BFM, RTL, and TB)."""
    filelist_path = os.path.join(output_dir, 'filelist.f')

    files = [
        f'$APB_DEC_GEN_HOME/output/{module_name}.sv',
        f'$APB_DEC_GEN_HOME/output/{module_name}_tb.sv',
    ]

    with open(filelist_path, 'w') as f:
        for file_path in files:
            f.write(f'{file_path}\n')

    print(f"Generated: {filelist_path}")


def main():
    json_path = 'output/m_vlsit_apbdec.json'
    output_dir = 'output'

    # Allow command-line override
    if len(sys.argv) > 1:
        json_path = sys.argv[1]
    if len(sys.argv) > 2:
        output_dir = sys.argv[2]

    os.makedirs(output_dir, exist_ok=True)

    print("=" * 60)
    print("APB Decoder Testbench Generator")
    print("=" * 60)

    # Load JSON config
    print("\n[1/2] Loading JSON config...")
    config = load_json_config(json_path)
    print(f"  Module Name:     {config['module_name']}")
    print(f"  Address Width:   {config['address_width']}")
    print(f"  Data Width:      {config['data_width']}")
    print(f"  Write Strobe:    {config['write_strobe']}")
    print(f"  Number of Slaves: {len(config['slaves'])}")
    for slave in config['slaves']:
        print(f"    - {slave['name']}: {slave['offset']} - {slave['end_address']} ({slave['size']})")

    # Generate SystemVerilog TB
    print("\n[2/2] Generating testbench...")
    tb_path = os.path.join(output_dir, f"{config['module_name']}_tb.sv")
    generate_tb_sv(config, tb_path)

    # Generate filelist (includes TB)
    generate_filelist(output_dir, config['module_name'])

    print("\n" + "=" * 60)
    print("TB Generation complete!")
    print("=" * 60)
    print(f"\nOutput files:")
    print(f"  - {tb_path}")
    print(f"  - {os.path.abspath(output_dir)}/filelist.f")


if __name__ == '__main__':
    main()
