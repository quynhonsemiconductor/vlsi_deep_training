# GPIO verification

`tb_gpio.sv` is a self-checking testbench for one eight-pin
`m_qnsc_wrap_gpio` instance. Run it with:

```bash
make sim BLOCK=gpio
```

Covered behavior:

- reset values;
- full-word APB reads and writes;
- output direction, output data, SET and CLR;
- flattened pad configuration;
- documented address aliasing;
- input synchronisation;
- rising, falling and both-edge interrupts;
- `INTSTATUS` read-to-clear and set priority.

`PSTRB` and `PPROT` are not test inputs because they are intentionally absent
from this wrapper and from the upstream `apb_gpio` interface.
