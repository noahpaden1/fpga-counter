`timescale 1ns / 1ps

// Basys 3 - Up/Down Counter on the 4-digit 7-segment display
//   btnU (Up)     : +1
//   btnD (Down)   : -1
//   btnC (Center) : reset to 0000
// Counts 0000..9999 in decimal and wraps around in both directions.

module counter_top (
    input  wire       clk,     // 100 MHz on-board clock
    input  wire       btnU,    // +1
    input  wire       btnD,    // -1
    input  wire       btnC,    // reset
    output reg  [6:0] seg,     // segments {g,f,e,d,c,b,a}, active low
    output wire       dp,      // decimal point - active low
    output reg  [3:0] an       // digit anode - active low (an[0] = rightmost)
);

    // Button debouncing + single-pulse generation

    wire up_pulse, down_pulse, rst_level;

    debounce db_up   (.clk(clk), .btn_in(btnU), .level(),          .pulse(up_pulse));
    debounce db_down (.clk(clk), .btn_in(btnD), .level(),          .pulse(down_pulse));
    debounce db_rst  (.clk(clk), .btn_in(btnC), .level(rst_level), .pulse());

    // 4-digit BCD up/down counter (d3 = thousands .. d0 = ones)
    
    reg [3:0] d0 = 0, d1 = 0, d2 = 0, d3 = 0;

    always @(posedge clk) begin
        if (rst_level) begin
            d0 <= 0; d1 <= 0; d2 <= 0; d3 <= 0;
        end
        else if (up_pulse) begin
            if (d0 == 9) begin
                d0 <= 0;
                if (d1 == 9) begin
                    d1 <= 0;
                    if (d2 == 9) begin
                        d2 <= 0;
                        d3 <= (d3 == 9) ? 4'd0 : d3 + 1;   // 9999 -> 0000
                    end else d2 <= d2 + 1;
                end else d1 <= d1 + 1;
            end else d0 <= d0 + 1;
        end
        else if (down_pulse) begin
            if (d0 == 0) begin
                d0 <= 9;
                if (d1 == 0) begin
                    d1 <= 9;
                    if (d2 == 0) begin
                        d2 <= 9;
                        d3 <= (d3 == 0) ? 4'd9 : d3 - 1;   // 0000 -> 9999
                    end else d2 <= d2 - 1;
                end else d1 <= d1 - 1;
            end else d0 <= d0 - 1;
        end
    end

    // Display multiplexing
    
    reg  [19:0] refresh = 0;
    wire [1:0]  digit_sel = refresh[19:18];
    reg  [3:0]  digit_val;

    always @(posedge clk)
        refresh <= refresh + 1;

    always @(*) begin
        case (digit_sel)
            2'b00: begin an = 4'b1110; digit_val = d0; end  // rightmost
            2'b01: begin an = 4'b1101; digit_val = d1; end
            2'b10: begin an = 4'b1011; digit_val = d2; end
            2'b11: begin an = 4'b0111; digit_val = d3; end  // leftmost
        endcase
    end

    // BCD to 7-segment decoder (active low, seg = {g,f,e,d,c,b,a})
    
    always @(*) begin
        case (digit_val)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111;
        endcase
    end

    assign dp = 1'b1;   // decimal point off

endmodule

// Debouncer: synchronizes the button, waits ~10 ms of stable input,
// then outputs a clean level and a one-clock pulse on the rising edge.

module debounce (
    input  wire clk,
    input  wire btn_in,
    output reg  level = 0,
    output wire pulse
);
    reg [1:0]  sync = 0;
    reg [19:0] cnt  = 0;          // 2^20 cycles @ 100 MHz ~ 10.5 ms
    reg        level_d = 0;

    always @(posedge clk) begin
        sync <= {sync[0], btn_in};               // 2-FF synchronizer

        if (sync[1] == level)
            cnt <= 0;                            // input matches state
        else begin
            cnt <= cnt + 1;
            if (&cnt) level <= sync[1];          // stable long enough
        end

        level_d <= level;
    end

    assign pulse = level & ~level_d;             // rising-edge pulse
endmodule