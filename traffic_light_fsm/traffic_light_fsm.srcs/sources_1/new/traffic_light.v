// Traffic light controller for a 4-way junction
// two roads: NS (north-south) and EW (east-west)
//
// state  NS      EW      time
// S0     green   red     GREEN_TIME
// S1     yellow  red     YELLOW_TIME
// S2     red     red     RED_TIME     (all red, junction clears)
// S3     red     green   GREEN_TIME
// S4     red     yellow  YELLOW_TIME
// S5     red     red     RED_TIME     (all red, junction clears)
// then back to S0
//
// lights are {red, yellow, green}
// times are in seconds
// CLK_FREQ is the input clock in Hz (125 MHz on PYNQ-Z2)
// reset is synchronous, active high, and goes to S5 (all red)

module traffic_light(clk, rst, ns_light, ew_light);
input clk, rst;
output reg [2:0] ns_light;
output reg [2:0] ew_light;

parameter CLK_FREQ    = 125000000;
parameter GREEN_TIME  = 10;
parameter YELLOW_TIME = 3;
parameter RED_TIME    = 2;

parameter S0 = 3'd0,
          S1 = 3'd1,
          S2 = 3'd2,
          S3 = 3'd3,
          S4 = 3'd4,
          S5 = 3'd5;

reg [2:0] state, next_state;
reg [7:0] count;          // counts seconds in the current state
reg [7:0] limit;
reg [26:0] div_count;     // counts clocks up to 1 second (2^27 > 125,000,000)
wire tick;                // high for one clock, once every second

// clock divider: counts 0 to CLK_FREQ-1, so one full count is 1 second
// tick is high on the last count, for one clock
// the whole design still runs on clk, tick is only an enable
always @(posedge clk) begin
    if (rst)
        div_count <= 27'd0;
    else if (div_count == CLK_FREQ - 1)
        div_count <= 27'd0;
    else
        div_count <= div_count + 1;
end

assign tick = (div_count == CLK_FREQ - 1);

// how long to stay in the current state
always @(*) begin
    case (state)
    S0, S3:  limit = GREEN_TIME;
    S1, S4:  limit = YELLOW_TIME;
    default: limit = RED_TIME;
    endcase
end

// state register and timer, moves only on tick
always @(posedge clk) begin
    if (rst) begin
        state <= S5;
        count <= 8'd0;
    end
    else if (tick) begin
        if (count == limit - 1) begin
            state <= next_state;
            count <= 8'd0;
        end
        else begin
            count <= count + 1;
        end
    end
end

// next state
always @(*) begin
    case (state)
    S0: next_state = S1;
    S1: next_state = S2;
    S2: next_state = S3;
    S3: next_state = S4;
    S4: next_state = S5;
    S5: next_state = S0;
    default: next_state = S5;   // unused codes 6, 7 go to all red
    endcase
end

// outputs depend only on state (Moore)
always @(*) begin
    case (state)
    S0: begin ns_light = 3'b001; ew_light = 3'b100; end
    S1: begin ns_light = 3'b010; ew_light = 3'b100; end
    S2: begin ns_light = 3'b100; ew_light = 3'b100; end
    S3: begin ns_light = 3'b100; ew_light = 3'b001; end
    S4: begin ns_light = 3'b100; ew_light = 3'b010; end
    S5: begin ns_light = 3'b100; ew_light = 3'b100; end
    default: begin ns_light = 3'b100; ew_light = 3'b100; end
    endcase
end

endmodule