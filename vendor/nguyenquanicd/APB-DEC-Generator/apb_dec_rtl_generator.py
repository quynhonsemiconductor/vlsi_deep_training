#!/usr/bin/env python3
"""
APB Decoder RTL Generator
Reads configuration from Excel and generates RTL (SystemVerilog) for APB Decoder.
"""

import openpyxl
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
//Generated: {timestamp}
//--------------------------------------
'''
    
    # Add optional parameters
    if kwargs:
        for key, value in kwargs.items():
            header += f'//{key}: {value}\n'
        header += '//--------------------------------------\n'
    
    return header


def parse_excel(excel_path, sheet_name=None):
    """Parse Excel file and return structured data."""
    wb = openpyxl.load_workbook(excel_path, data_only=True)

    # Use specified sheet or first sheet if not specified
    if sheet_name:
        sheet_names = [sheet_name] if sheet_name in wb.sheetnames else wb.sheetnames
    else:
        sheet_names = [wb.sheetnames[0]] if wb.sheetnames else []

    result = {}
    for sheet_name in sheet_names:
        ws = wb[sheet_name]
        rows = list(ws.iter_rows(values_only=True))

        tables = []
        current_table = None
        header_row = None

        for row in rows:
            is_empty = all(cell is None for cell in row)

            if is_empty:
                if current_table is not None and current_table['name']:
                    tables.append(current_table)
                    current_table = None
                    header_row = None
                continue

            first_cell = row[0]
            if first_cell and isinstance(first_cell, str) and first_cell.startswith('Table -'):
                if current_table is not None and current_table['name']:
                    tables.append(current_table)

                current_table = {'name': first_cell, 'headers': None, 'data': []}
                header_row = None
                continue

            if current_table is not None:
                if header_row is None:
                    header_row = row
                    current_table['headers'] = [h for h in row if h is not None]
                else:
                    row_dict = {}
                    for i, cell in enumerate(row):
                        if i < len(header_row) and header_row[i] is not None:
                            row_dict[header_row[i]] = cell
                    if any(v is not None for v in row_dict.values()):
                        current_table['data'].append(row_dict)

        if current_table is not None and current_table['name']:
            tables.append(current_table)

        result[sheet_name] = tables

    return result


def extract_config(parsed_data):
    """Extract configuration from parsed Excel data."""
    config = {
        'module_name': None,
        'address_width': None,
        'data_width': None,
        'write_strobe': None,
        'pslverr_on_unmapped': 1,
        'slaves': []
    }

    for table in parsed_data.get('APB_DEC', []):
        if 'Configuration' in table['name'] and 'Master' not in table['name'] and 'Slaves' not in table['name']:
            for row in table['data']:
                if row.get('Config') == 'Module Name':
                    config['module_name'] = row.get('Value', 'apb_decoder')

        elif 'Master Configuration' in table['name']:
            for row in table['data']:
                cfg_name = row.get('Config')
                value = row.get('Value')
                if cfg_name == 'Address Width':
                    config['address_width'] = int(value)
                elif cfg_name == 'Data Width':
                    config['data_width'] = int(value)
                elif cfg_name == 'Write Strobe':
                    config['write_strobe'] = int(value)
                elif cfg_name == 'PSLVERR on Unmapped Access':
                    config['pslverr_on_unmapped'] = int(value) if value is not None else 1

        elif 'Slaves' in table['name']:
            for row in table['data']:
                if row.get('NAME'):
                    slave = {
                        'name': row['NAME'],
                        'address_width': int(row['ADDRESS WIDTH']) if row.get('ADDRESS WIDTH') else 0,
                        'offset': row.get('OFFSET', '0x0000'),
                        'size': row.get('SIZE', ''),
                        'end_address': row.get('END ADDRESS', ''),
                        'description': row.get('DESCRIPTION')
                    }
                    config['slaves'].append(slave)

    return config


def generate_json(config, output_path):
    """Generate JSON file for debugging."""
    with open(output_path, 'w') as f:
        json.dump(config, f, indent=2)
    print(f"Generated: {output_path}")


def generate_sv(config, output_path):
    """Generate SystemVerilog RTL for APB Decoder."""
    module_name = config['module_name'] or 'apb_decoder'
    addr_width = config['address_width'] or 16
    data_width = config['data_width'] or 32
    write_strobe = config['write_strobe'] or 4
    pslverr_on_unmapped = config.get('pslverr_on_unmapped', 1)
    slaves = config['slaves']

    num_slaves = len(slaves)

    header = generate_header(
        module_name,
        'APB Decoder',
        **{
            'Address Width': addr_width,
            'Data Width': data_width,
            'Write Strobe': write_strobe,
            'Number of Slaves': num_slaves
        }
    )
    sv = header + f'''
`timescale 1ns/1ps

module {module_name} (
  // APB Master Interface
  input  logic [{addr_width-1:2d}:0]   i_paddr,
  input  logic [{data_width-1:2d}:0]   i_pwdata,
  input  logic [{write_strobe-1:2d}:0]   i_pstrb,
  input  logic          i_pwrite,
  input  logic          i_psel,
  input  logic          i_penable,
  output logic          o_pready,
  output logic          o_pslverr,
  output logic [{data_width-1:2d}:0]   o_prdata,

  // APB Slave Interfaces
'''

    # Generate slave interface ports
    for i, slave in enumerate(slaves):
        slave_lower = slave['name'].lower()
        slave_addr_width = slave['address_width']
        desc = slave.get('description')
        desc_str = f" ({desc})" if desc else ""
        sv += f'''  // Slave {i+1}: {slave['name']}{desc_str}
  output logic [{slave_addr_width-1:2d}:0]   o_paddr_{slave_lower},
  output logic [{data_width-1:2d}:0]   o_pwdata_{slave_lower},
  output logic [{write_strobe-1:2d}:0]   o_pstrb_{slave_lower},
  output logic          o_psel_{slave_lower},
  output logic          o_penable_{slave_lower},
  output logic          o_pwrite_{slave_lower},
  input  logic          i_pready_{slave_lower},
  input  logic          i_pslverr_{slave_lower},
  input  logic [{data_width-1:2d}:0]   i_prdata_{slave_lower},
'''

    sv = sv.rstrip(',\n') + '\n);\n\n'

    # Internal signals
    sv += '''  // Internal signals
'''
    for i, slave in enumerate(slaves):
        slave_lower = slave['name'].lower()
        sv += f'''  logic w_slave_{slave_lower}_sel;
'''

    # Address decode logic
    sv += '''  // ============================================================================
  // Address Decode Logic
  // ============================================================================
'''
    for i, slave in enumerate(slaves):
        slave_lower = slave['name'].lower()
        offset = slave['offset']
        end_addr = slave['end_address']
        offset_val = int(offset[2:], 16)
        sv += f'''  assign w_slave_{slave_lower}_sel = (i_paddr >= {addr_width}'h{offset[2:]} & i_paddr <= {addr_width}'h{end_addr[2:]});
'''
    sv += '\n'

    # PREADY, PSLVERR and PRDATA logic
    sv += '''  // ============================================================================
  // PREADY, PSLVERR and PRDATA Generation
  // ============================================================================
  always_comb begin
    casez ({
'''
    for i in range(len(slaves) - 1, -1, -1):
        slave_lower = slaves[i]['name'].lower()
        if i == 0:
            sv += f'''      w_slave_{slave_lower}_sel
'''
        else:
            sv += f'''      w_slave_{slave_lower}_sel,
'''
    sv += '''    })
'''
    for i, slave in enumerate(slaves):
        slave_lower = slave['name'].lower()
        z_pattern = '?' * (len(slaves) - 1 - i) + '1' + '0' * i
        sv += f'''      {len(slaves)}'b{z_pattern}: begin
        o_pready  = i_pready_{slave_lower};
        o_pslverr = i_pslverr_{slave_lower};
        o_prdata  = i_prdata_{slave_lower};
      end
'''
    sv += f'''      default: begin
        o_pready  = 1'b1;
        o_pslverr = 1'b{pslverr_on_unmapped};
        o_prdata  = {data_width}'d0;
      end
    endcase
  end

'''

    # Slave select generation
    sv += '''  // ============================================================================
  // Slave Select Generation
  // ============================================================================
'''
    for i, slave in enumerate(slaves):
        slave_lower = slave['name'].lower()
        slave_addr_width = slave['address_width']
        sv += f'''  assign o_psel_{slave_lower}    = w_slave_{slave_lower}_sel & i_psel;
  assign o_penable_{slave_lower} = i_penable;
  assign o_pwrite_{slave_lower}  = i_pwrite;
  assign o_paddr_{slave_lower}   = i_paddr[{slave_addr_width-1}:0];
  assign o_pwdata_{slave_lower}  = i_pwdata;
  assign o_pstrb_{slave_lower}   = i_pstrb;

'''

    sv += '''endmodule
'''

    with open(output_path, 'w') as f:
        f.write(sv)
    print(f"Generated: {output_path}")


def generate_filelist(output_dir, module_name, include_tb=False):
    """Generate filelist.f with $APB_DEC_GEN_HOME variable."""
    filelist_path = os.path.join(output_dir, 'filelist.f')

    files = [
        f'$APB_DEC_GEN_HOME/output/{module_name}.sv',
    ]
    if include_tb:
        files.append(f'$APB_DEC_GEN_HOME/output/{module_name}_tb.sv')

    with open(filelist_path, 'w') as f:
        for file_path in files:
            f.write(f'{file_path}\n')

    print(f"Generated: {filelist_path}")


def main():
    excel_path = 'APB_DEC_Example.xlsx'
    sheet_name = None
    output_dir = 'output'

    # Allow command-line override
    if len(sys.argv) > 1:
        excel_path = sys.argv[1]
    if len(sys.argv) > 2:
        sheet_name = sys.argv[2] if sys.argv[2] else None
    if len(sys.argv) > 3:
        output_dir = sys.argv[3]

    os.makedirs(output_dir, exist_ok=True)

    print("=" * 60)
    print("APB Decoder RTL Generator")
    print("=" * 60)

    # Parse Excel
    print("\n[1/3] Parsing Excel file...")
    parsed_data = parse_excel(excel_path, sheet_name)

    # Extract configuration
    print("[2/3] Extracting configuration...")
    config = extract_config(parsed_data)
    print(f"  Module Name:     {config['module_name']}")
    print(f"  Address Width:   {config['address_width']}")
    print(f"  Data Width:      {config['data_width']}")
    print(f"  Write Strobe:    {config['write_strobe']}")
    print(f"  Number of Slaves: {len(config['slaves'])}")
    for slave in config['slaves']:
        print(f"    - {slave['name']}: {slave['offset']} - {slave['end_address']} ({slave['size']})")

    # Generate JSON
    print("\n[3/3] Generating output files...")
    json_path = os.path.join(output_dir, f"{config['module_name']}.json")
    generate_json(config, json_path)

    # Generate SystemVerilog RTL
    sv_path = os.path.join(output_dir, f"{config['module_name']}.sv")
    generate_sv(config, sv_path)

    # Generate filelist (RTL only)
    generate_filelist(output_dir, config['module_name'], include_tb=False)

    print("\n" + "=" * 60)
    print("RTL Generation complete!")
    print("=" * 60)
    print(f"\nOutput files:")
    print(f"  - {json_path}")
    print(f"  - {sv_path}")
    print(f"  - {os.path.abspath(output_dir)}/filelist.f")


if __name__ == '__main__':
    main()
