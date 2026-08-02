`timescale 1ns / 1ps

module tb_AMBA_APB;

    // ---- Inputs (reg because testbench drives them) ----
    reg         PCLK;
    reg         PRESET;
    reg         PSEL;
    reg         PENABLE;
    reg         PWRITE;
    reg  [15:0] PADDR;
    reg  [15:0] PWDATA;
    reg  [1:0]  PSTRB;

    // ---- Outputs (wire because DUT drives them) ----
    wire        PREADY;
    wire [15:0] PRDATA;
    wire        PSLVERR;

    // ---- Connect testbench to UUT ----
    AMBA_APB UUT (
        .PCLK    (PCLK),
        .PRESET  (PRESET),
        .PSEL    (PSEL),
        .PENABLE (PENABLE),
        .PWRITE  (PWRITE),
        .PADDR   (PADDR),
        .PWDATA  (PWDATA),
        .PSTRB   (PSTRB),
        .PREADY  (PREADY),
        .PRDATA  (PRDATA),
        .PSLVERR (PSLVERR)
    );

    // ---- Clock: starts at 0, toggles every 5ns = 10ns period ----
    initial PCLK = 0;
    always #5 PCLK = ~PCLK;

    initial begin

        // -------------------------------------------------------
        // RESET
        // PRESET is active-low: drive 0 to reset, then 1 to run
        // -------------------------------------------------------
        PRESET  = 0;
        PSEL    = 0;
        PENABLE = 0;
        PWRITE  = 0;
        PADDR   = 16'h0000;
        PWDATA  = 16'h0000;
        PSTRB   = 2'b00;
        #20;            // hold reset for 2 clock cycles
        PRESET  = 1;    // release reset - DUT is now running
        #10;            // wait one more cycle before starting transactions

        // -------------------------------------------------------
        // TC1: Write 16'hABCD to register at address 0x0000
        //
        // APB write = 2 clock cycles:
        //   Cycle 1 (SETUP) : PSEL=1, PENABLE=0, put address+data on bus
        //   Cycle 2 (ACCESS): PSEL=1, PENABLE=1, slave sees the transfer
        // -------------------------------------------------------
        $display("TC1: Write 16hABCD to address 0x0000");

        // SETUP phase
        @(posedge PCLK);
        PSEL    = 1;
        PENABLE = 0;
        PWRITE  = 1;
        PADDR   = 16'h0000;
        PWDATA  = 16'hABCD;
        PSTRB   = 2'b11;   // both bytes enabled

        // ACCESS phase
        @(posedge PCLK);
        PENABLE = 1;

        // End of transaction - deassert bus
        @(posedge PCLK);
        PSEL    = 0;
        PENABLE = 0;
        PWRITE  = 0;
        #10;

        // -------------------------------------------------------
        // TC2: Read back from address 0x0000
        //      We expect PRDATA to show 16'hABCD
        // -------------------------------------------------------
        $display("TC2: Read from address 0x0000 - expect ABCD");

        // SETUP phase
        @(posedge PCLK);
        PSEL    = 1;
        PENABLE = 0;
        PWRITE  = 0;        // read
        PADDR   = 16'h0000;

        // ACCESS phase
        @(posedge PCLK);
        PENABLE = 1;

        // End of transaction
        @(posedge PCLK);
        $display("TC2 result: PRDATA = %h", PRDATA);
        PSEL    = 0;
        PENABLE = 0;
        #10;

        // -------------------------------------------------------
        // TC3: Partial write using PSTRB
        //      Write 16'h1234 with PSTRB=2'b01 (lower byte only)
        //      Upper byte (AB) should stay from TC1
        //      After this, reg[0] should be 16'hAB34
        // -------------------------------------------------------
        $display("TC3: Partial write 16h1234 to address 0x0000 with PSTRB=01");

        @(posedge PCLK);
        PSEL    = 1;
        PENABLE = 0;
        PWRITE  = 1;
        PADDR   = 16'h0000;
        PWDATA  = 16'h1234;
        PSTRB   = 2'b01;   // only lower byte

        @(posedge PCLK);
        PENABLE = 1;

        @(posedge PCLK);
        PSEL    = 0;
        PENABLE = 0;
        PWRITE  = 0;
        #10;

        // Read back to confirm byte merge
        $display("TC3 readback: should be AB34 (upper byte preserved)");
        @(posedge PCLK);
        PSEL    = 1;
        PENABLE = 0;
        PWRITE  = 0;
        PADDR   = 16'h0000;

        @(posedge PCLK);
        PENABLE = 1;

        @(posedge PCLK);
        $display("TC3 result: PRDATA = %h", PRDATA);
        PSEL    = 0;
        PENABLE = 0;
        #10;

        // -------------------------------------------------------
        // TC4: Invalid address - should assert PSLVERR
        //      word_index = PADDR[15:1] for PADDR=0xFFFE
        //      = 0x7FFF = 32767, which is >= NUM_REG (8)
        //      So PSLVERR should go 1
        // -------------------------------------------------------
        $display("TC4: Invalid address 0xFFFE - expect PSLVERR=1");

        @(posedge PCLK);
        PSEL    = 1;
        PENABLE = 0;
        PWRITE  = 1;
        PADDR   = 16'hFFFE;
        PWDATA  = 16'hDEAD;
        PSTRB   = 2'b11;

        @(posedge PCLK);
        PENABLE = 1;

        @(posedge PCLK);
        $display("TC4 result: PSLVERR = %b (expect 1)", PSLVERR);
        PSEL    = 0;
        PENABLE = 0;
        #10;

        $display("All test cases done.");
        $finish;
    end

endmodule
