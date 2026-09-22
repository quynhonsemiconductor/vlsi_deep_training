#!/usr/bin/env python3
import sys
import apb_bus_generator


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 apb_tb_generator.py <input.xlsx> <sheet>")
        return 1
    return apb_bus_generator.main([sys.argv[1], sys.argv[2], "tb"])


if __name__ == "__main__":
    sys.exit(main())
