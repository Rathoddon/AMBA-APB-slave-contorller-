Protocol Summary

Every APB transaction follows a fixed 3-phase sequence:

Phase	Condition	What happens
IDLE	PSEL = 0	Bus is idle, no slave selected
SETUP	PSEL = 1, PENABLE = 0	Master puts address/data/direction on the bus
ACCESS	PSEL = 1, PENABLE = 1	Transfer executes; slave drives PREADY when done

The FSM must always transition SETUP → ACCESS — it cannot skip ACCESS. The slave can insert wait states by holding PREADY low during ACCESS; the master waits until PREADY asserts before completing the transfer.

Signal Description
Signal	Direction	Width	Description
PCLK	Input	1	Bus clock — all signals sampled on rising edge
PRESET	Input	1	Active-low synchronous reset
PSEL	Input	1	Master selects this slave
PENABLE	Input	1	Master enters ACCESS phase
PWRITE	Input	1	1 = write, 0 = read
PADDR	Input	16	Byte address of target register
PWDATA	Input	16	Data to write
PSTRB	Input	2	Byte-lane write strobes (bit 0 = lower byte, bit 1 = upper byte)
PRDATA	Output	16	Data returned to master on a read
PREADY	Output	1	Slave signals transfer complete
PSLVERR	Output	1	Slave signals an error (invalid address)
Register Map

8 addressable 16-bit registers, word-addressed via PADDR[15:1]:

Word Index	Byte Address	Register
0	0x0000	REG0
1	0x0002	REG1
2	0x0004	REG2
3	0x0006	REG3
4	0x0008	REG4
5	0x000A	REG5
6	0x000C	REG6
7	0x000E	REG7

Any access where PADDR[15:1] >= 8 asserts PSLVERR.

Key Design Features

Wait states: a configurable WAIT_TARGET parameter controls how many ACCESS cycles the slave waits before asserting PREADY. Set to 0 for immediate response (no wait states), or higher values to model a slow peripheral.

Byte-lane write strobes (PSTRB): each bit of PSTRB independently gates whether the corresponding byte of PWDATA gets written into the target register. PSTRB=2'b01 updates only the lower byte; PSTRB=2'b10 updates only the upper byte; PSTRB=2'b11 updates the full 16-bit word. The unselected byte retains its previous value.

Error reporting: any access to a word index outside the valid register range asserts PSLVERR for that transfer.

Test Cases
TC	Scenario	What it verifies
TC1	Write 16'hABCD to REG0	Basic write path, FSM IDLE → SETUP → ACCESS
TC2	Read back from REG0	Basic read path, PRDATA driven correctly
TC3	Write lower byte only (PSTRB=01)	Byte-lane merge — upper byte preserved
TC4	Access invalid address (0xFFFE)	PSLVERR asserts for out-of-range address
Repository Structure
.
├── AMBA_APB.v          # APB slave RTL (synthesizable)
├── tb_AMBA_APB.v       # Testbench — 4 test cases
└── README.md
How to Simulate
Open Xilinx Vivado and create a new RTL project
Add AMBA_APB.v as a design source
Add tb_AMBA_APB.v as a simulation source
Run behavioral simulation
Check the transcript for TC1–TC4 results and open the waveform to verify PSEL/PENABLE/PREADY/PRDATA timing
