# `i2c` — I2C controller

**Owner:** @Vinh-OngBao   **Spec:** [`QNSC_I2C_MAS.md`](../../doc/specs/QNSC_I2C_MAS.md)   **DV:** [`../../dv/i2c`](../../dv/i2c)

## What this block is

An I2C master on `APB_M11`, one command per byte. Upstream `apb_i2c` wrapped
unmodified by `m_qnsc_wrap_i2c`; open drain as output enables to the IO MUX.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| `pulp-platform/apb_i2c` | `apb_i2c`, `i2c_master_byte_ctrl`, `i2c_master_bit_ctrl` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

## The wrapper is the boundary

`rtl/` holds **only code written here**. Upstream IP is listed in
[`i2c.f`](./i2c.f), never copied into `rtl/`. Reading this one directory answers
what is ours and what is borrowed.

## Instances

One.
