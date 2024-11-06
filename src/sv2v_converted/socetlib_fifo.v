module socetlib_fifo (
	CLK,
	nRST,
	WEN,
	REN,
	clear,
	wdata,
	full,
	empty,
	underrun,
	overrun,
	count,
	rdata
);
	reg _sv2v_0;
	parameter DEPTH = 8;
	input CLK;
	input nRST;
	input WEN;
	input REN;
	input clear;
	input wire [7:0] wdata;
	output wire full;
	output wire empty;
	output reg underrun;
	output reg overrun;
	output reg [$clog2(DEPTH + 1) - 1:0] count;
	output wire [7:0] rdata;
	generate
		if ((DEPTH == 0) || ((DEPTH & (DEPTH - 1)) != 0)) begin : genblk1
			initial $display("Error [elaboration] src/AHBUart_dependencies.sv:25:13 - socetlib_fifo.genblk1\n msg: ", "%m: DEPTH must be a power of 2 >= 1!");
		end
	endgenerate
	localparam signed [31:0] ADDR_BITS = $clog2(DEPTH);
	reg overrun_next;
	reg underrun_next;
	reg [ADDR_BITS - 1:0] write_ptr;
	reg [ADDR_BITS - 1:0] write_ptr_next;
	reg [ADDR_BITS - 1:0] read_ptr;
	reg [ADDR_BITS - 1:0] read_ptr_next;
	reg [$clog2(DEPTH + 1) - 1:0] count_next;
	reg [(DEPTH * 8) - 1:0] fifo;
	reg [(DEPTH * 8) - 1:0] fifo_next;
	always @(posedge CLK or negedge nRST)
		if (!nRST) begin
			fifo <= {DEPTH {8'b00000000}};
			write_ptr <= 1'sb0;
			read_ptr <= 1'sb0;
			overrun <= 1'b0;
			underrun <= 1'b0;
			count <= 1'sb0;
		end
		else begin
			fifo <= fifo_next;
			write_ptr <= write_ptr_next;
			read_ptr <= read_ptr_next;
			overrun <= overrun_next;
			underrun <= underrun_next;
			count <= count_next;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		fifo_next = fifo;
		write_ptr_next = write_ptr;
		read_ptr_next = read_ptr;
		overrun_next = overrun;
		underrun_next = underrun;
		count_next = count;
		if (clear) begin
			write_ptr_next = 1'sb0;
			read_ptr_next = 1'sb0;
			overrun_next = 1'b0;
			underrun_next = 1'b0;
			count_next = 1'sb0;
		end
		else begin
			if ((REN && !empty) && !(full && WEN))
				read_ptr_next = read_ptr + 1;
			else if (REN && empty)
				underrun_next = 1'b1;
			if ((WEN && !full) && !(empty && REN)) begin
				write_ptr_next = write_ptr + 1;
				fifo_next[write_ptr * 8+:8] = wdata;
			end
			else if (WEN && full)
				overrun_next = 1'b1;
			if (count == DEPTH)
				count_next = (count - (REN ? 1 : 0)) + (REN && WEN ? 1 : 0);
			else if (count == 0)
				count_next = (count + (WEN ? 1 : 0)) - (REN && WEN ? 1 : 0);
			else
				count_next = (count + (WEN ? 1 : 0)) - (REN ? 1 : 0);
		end
	end
	assign full = count == DEPTH;
	assign empty = count == 0;
	assign rdata = fifo[read_ptr * 8+:8];
	initial _sv2v_0 = 0;
endmodule
