// testbench for traffic_light
// checks:
//  1. state order is S5 -> S0 -> S1 -> S2 -> S3 -> S4 -> S5 ...
//  2. each state lasts the right time (seconds x clocks per second)
//  3. NS and EW are never both not-red at the same time (safety)

`timescale 1ns/1ps

module tb_traffic_light;

reg clk, rst;
wire [2:0] ns_light, ew_light;

integer cycles, fail, changes;
reg [2:0] prev_state, exp_next;
integer exp_len;

// CLK_FREQ = 4 so one "second" is 4 clocks; keeps the simulation short
// on the board the default 125 MHz is used
traffic_light #(.CLK_FREQ(4)) dut(clk, rst, ns_light, ew_light);

always #5 clk = ~clk;

// expected time in each state, in clocks (seconds x 4)
function integer state_len;
input [2:0] s;
begin
    if (s == 3'd0 || s == 3'd3)
        state_len = 10 * 4;
    else if (s == 3'd1 || s == 3'd4)
        state_len = 3 * 4;
    else
        state_len = 2 * 4;
end
endfunction

// expected next state
function [2:0] next_of;
input [2:0] s;
begin
    if (s == 3'd5)
        next_of = 3'd0;
    else
        next_of = s + 1;
end
endfunction

initial begin
    $dumpfile("traffic.vcd");
    $dumpvars(0, tb_traffic_light);

    clk = 0;
    rst = 1;
    fail = 0;
    changes = 0;
    #20;
    rst = 0;

    prev_state = dut.state;
    cycles = 0;

    // run 3 full cycles of the lights (30 seconds = 120 clocks each)
    repeat (360) begin
        @(posedge clk);
        #1;

        // safety check: one road must always be red
        if (ns_light != 3'b100 && ew_light != 3'b100) begin
            fail = fail + 1;
            $display("FAIL at %0d ns: both roads not red, ns=%b ew=%b", $time, ns_light, ew_light);
        end

        cycles = cycles + 1;

        if (dut.state != prev_state) begin
            exp_len = state_len(prev_state);
            exp_next = next_of(prev_state);

            if (cycles != exp_len) begin
                fail = fail + 1;
                $display("FAIL: state S%0d lasted %0d cycles, expected %0d", prev_state, cycles, exp_len);
            end

            if (dut.state != exp_next) begin
                fail = fail + 1;
                $display("FAIL: S%0d went to S%0d, expected S%0d", prev_state, dut.state, exp_next);
            end

            $display("%0d ns: S%0d -> S%0d  ns=%b ew=%b", $time, prev_state, dut.state, ns_light, ew_light);
            changes = changes + 1;
            prev_state = dut.state;
            cycles = 0;
        end
    end

    $display("state changes checked: %0d, fails: %0d", changes, fail);
    if (fail == 0)
        $display("ALL TESTS PASSED");
    $finish;
end

endmodule