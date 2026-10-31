# Traffic Light Controller (Verilog)

A traffic light controller for a 4-way junction, written in Verilog as a Moore FSM. There are two roads, north-south (NS) and east-west (EW), and the controller cycles their lights with fixed timings. It was implemented on the Digilent Arty A7-100T board, and it has a clock divider so the lights change at real-world timings (seconds, not clock cycles).

## Files

```
traffic-light/
├── rtl/traffic_light.v        design
├── tb/tb_traffic_light.v      testbench
├── docs/waveform.png          simulation waveform
└── README.md
```

## How it works

The junction goes through 6 states. Between the two greens there is always an all-red state, so the junction can clear before the other road starts moving.

| State | NS | EW | Time |
|---|---|---|---|
| S0 | green | red | 10 s |
| S1 | yellow | red | 3 s |
| S2 | red | red | 2 s |
| S3 | red | green | 10 s |
| S4 | red | yellow | 3 s |
| S5 | red | red | 2 s |

After S5 it goes back to S0, so one full cycle is 30 seconds.

```
S5 -> S0 -> S1 -> S2 -> S3 -> S4 -> S5 -> ...
```

On reset the controller goes to S5 (all red), since that is the safe state. State codes 6 and 7 are not used, and if the FSM ever lands in one of them it goes to S5.

Each light output is 3 bits, `{red, yellow, green}`:

- `100` = red
- `010` = yellow
- `001` = green

### Ports

| Port | Dir | Width | Description |
|---|---|---|---|
| clk | in | 1 | system clock (100 MHz on Arty A7-100T) |
| rst | in | 1 | synchronous, active high reset |
| ns_light | out | 3 | NS road lights |
| ew_light | out | 3 | EW road lights |

### Parameters

| Parameter | Default | Description |
|---|---|---|
| CLK_FREQ | 100000000 | input clock frequency in Hz |
| GREEN_TIME | 10 | green time in seconds |
| YELLOW_TIME | 3 | yellow time in seconds |
| RED_TIME | 2 | all-red time in seconds |

## Design

The code has five parts:

1. **Clock divider.** It counts from 0 to CLK_FREQ - 1 and raises `tick` for one clock at the last count, giving one tick per second. At 100 MHz this needs a 27-bit counter, because 2^26 = 67,108,864 is too small and 2^27 = 134,217,728 > 100,000,000.
2. **State register and timer.** This is the only other clocked block. On each tick, `count` goes up by one, and when it reaches the time for the current state, the FSM moves to the next state and `count` goes back to 0.
3. **Time limit.** A small combinational block picks how long the current state should last (green, yellow or red time).
4. **Next state logic.** This is combinational and simply steps through S0 to S5.
5. **Output logic.** This is combinational and depends only on the state, which makes it a Moore machine, so the lights cannot glitch on an input change.

`tick` is used as an enable and not as a new clock. The whole design runs on the single 100 MHz clock. If the divider output were used as a clock (`posedge slow_clk`), it would come out of normal logic instead of the FPGA's clock network, which gives skew, and timing analysis cannot check it properly.

## Testbench

The testbench sets `CLK_FREQ = 4`, so one "second" is 4 clocks. With the real 100 MHz value, a single 30 s cycle would be 3 billion clocks, which is far too long to simulate.

It runs 3 full light cycles (360 clocks) and checks three things:

1. The states come in the right order.
2. Each state lasts exactly its time (for example S0 should be 10 × 4 = 40 clocks).
3. NS and EW are never both non-red at the same time. This is checked on every clock, since it's the one thing a traffic controller must never get wrong.

Output:

```
96 ns: S5 -> S0  ns=001 ew=100
496 ns: S0 -> S1  ns=010 ew=100
616 ns: S1 -> S2  ns=100 ew=100
696 ns: S2 -> S3  ns=100 ew=001
...
state changes checked: 18, fails: 0
ALL TESTS PASSED
```

![waveform](docs/waveform.png)

### A bug the testbench caught

In my first version, `tick` came from a flip-flop. That delayed it by one clock, so the very first state after reset lasted 9 clocks instead of 8. The timing check flagged it. I changed `tick` to a direct compare (`assign tick = (div_count == CLK_FREQ - 1);`) and now every state is exact.

## Running it

### Vivado
1. Add `rtl/traffic_light.v` as a design source.
2. Add `tb/tb_traffic_light.v` as a simulation source and set it as top.
3. Run Simulation -> Run Behavioral Simulation.
4. The sim needs about 3.6 µs and Vivado stops at 1 µs by default, so type this in the Tcl console:
   ```
   restart
   run all
   ```
5. Set the radix of `ns_light` and `ew_light` to binary so the light codes are easy to read.

### Icarus Verilog
```
iverilog -g2005 -o sim rtl/traffic_light.v tb/tb_traffic_light.v
vvp sim
gtkwave traffic.vcd
```

## On the board (Arty A7-100T)

The design was implemented on the Digilent Arty A7-100T (xc7a100tcsg324-1).

- The 100 MHz on-board clock drives `clk`, with CLK_FREQ left at its default of 100000000.
- `rst` is mapped to a push button and goes through two flip-flops first, because the button is not in sync with the clock.
- Two of the board's RGB LEDs show the two roads, one LED per road. Yellow is shown as red and green on together.
- Pin numbers are from the Digilent Arty A7-100T master XDC file.

| Resource | Used |
|---|---|
| LUTs | _fill in_ |
| Flip-flops | _fill in_ |
| WNS | _fill in_ |

<img width="1908" height="1000" alt="image" src="https://github.com/user-attachments/assets/9738f5ea-2782-4714-bfc9-eb31e8d26a91" />


## Things I could add later

- a pedestrian crossing button
- a sensor on the EW road so it only gets green when a car is waiting
- a flashing yellow night mode

## Tools

- Xilinx Vivado 2025.2
- Icarus Verilog
