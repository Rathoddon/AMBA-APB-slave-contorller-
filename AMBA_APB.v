`timescale 1ns / 1ps
module AMBA_APB(
    input               PCLK,
    input               PRESET,     // active-low reset (used with negedge below)
    input               PSEL,
    input               PENABLE,
    input               PWRITE,
    input        [15:0] PADDR,
    input        [15:0] PWDATA,
    input        [1:0]  PSTRB,
    output reg          PREADY,
    output reg   [15:0] PRDATA,
    output reg          PSLVERR
);

    parameter IDLE   = 2'b00;
    parameter SETUP  = 2'b01;
    parameter ACCESS = 2'b10;
    parameter NUM_REG = 8;
    parameter WAIT_TARGET = 0;

    reg [1:0] current_state;
    reg [1:0] next_state;

    // ------------------------------------------------------------------
    // State register (FIX: reset check was `if(PRESET)` but sensitivity
    // list uses negedge PRESET -> active-low convention -> must be !PRESET)
    // ------------------------------------------------------------------
    always @(posedge PCLK or negedge PRESET) begin
        if (!PRESET)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // ------------------------------------------------------------------
    // Next-state logic (FIX: all assignments now blocking `=`, not a mix
    // of `=` and `<=` inside a combinational always @(*) block)
    // ------------------------------------------------------------------
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (PSEL == 0) next_state = IDLE;
                else            next_state = SETUP;
            end
            SETUP: begin
                next_state = ACCESS;
            end
            ACCESS: begin
                if (PSEL && PREADY == 1)
                    next_state = SETUP;
                else if (PSEL == 0 && PREADY == 1)
                    next_state = IDLE;
                // else: PREADY==0, stay in ACCESS (covered by default above)
            end
            default: next_state = IDLE;
        endcase
    end

    wire [14:0] word_index = PADDR[15:1];
    wire        addr_valid = (word_index < NUM_REG);

    // ------------------------------------------------------------------
    // Wait-state counter
    // FIX: original logic could never increment, because the first
    // `if (!PREADY)` branch already caught every !PREADY case before the
    // increment branch could ever be reached. Restructured so counting
    // and resetting are mutually exclusive and reachable.
    // ------------------------------------------------------------------
    reg [7:0] wait_cnt;
    always @(posedge PCLK or negedge PRESET) begin
        if (!PRESET)
            wait_cnt <= 8'b0;
        else if (current_state == ACCESS && !PREADY)
            wait_cnt <= wait_cnt + 1'b1;
        else
            wait_cnt <= 8'b0;
    end

    reg [15:0] regs [0:7];
    integer i;

    // ------------------------------------------------------------------
    // Output logic
    // FIX 1: PREADY had an extra `!` that inverted the ready condition,
    //   so with WAIT_TARGET=0 it was ALWAYS 0, deadlocking the FSM in
    //   ACCESS forever. Removed the `!`.
    // FIX 2: PRDATA now uses blocking `=` (was `<=`) to match the rest
    //   of this combinational block.
    // ------------------------------------------------------------------
    always @(*) begin
        case (current_state)
            IDLE: begin
                PREADY  = 1'b1;
                PSLVERR = 1'b0;
                PRDATA  = 16'b0;
            end
            SETUP: begin
                PREADY  = 1'b1;
                PSLVERR = 1'b0;
                PRDATA  = 16'b0;
            end
            ACCESS: begin
                PREADY  = (wait_cnt >= WAIT_TARGET);   // FIX: removed stray '!'
                PSLVERR = PREADY && !addr_valid;

                if (PREADY && !PWRITE && addr_valid)
                    PRDATA = regs[word_index];          // FIX: blocking, not <=
                else
                    PRDATA = 16'b0;
            end
            default: begin
                PREADY  = 1'b1;
                PSLVERR = 1'b1;
                PRDATA  = 16'b0;
            end
        endcase
    end

    always @(posedge PCLK or negedge PRESET) begin
        if (!PRESET) begin
            for (i = 0; i < NUM_REG; i = i + 1) begin
                regs[i] <= 16'b0;
            end
        end
        else if (current_state == ACCESS && PREADY && PWRITE && addr_valid) begin
            for (i = 0; i < 2; i = i + 1) begin
                if (PSTRB[i])
                    regs[word_index][i*8 +: 8] <= PWDATA[i*8 +: 8];
            end
        end
    end

endmodule
