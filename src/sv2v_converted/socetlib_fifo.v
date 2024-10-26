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
	parameter ADDR_BITS = $clog2(DEPTH);
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
	output wire [ADDR_BITS - 1:0] count;
	output wire [7:0] rdata;
	reg full_internal;
	reg full_next;
	reg empty_internal;
	reg empty_next;
	reg overrun_next;
	reg underrun_next;
	reg [ADDR_BITS - 1:0] write_ptr;
	reg [ADDR_BITS - 1:0] write_ptr_next;
	reg [ADDR_BITS - 1:0] read_ptr;
	reg [ADDR_BITS - 1:0] read_ptr_next;
	reg [(DEPTH * 8) - 1:0] fifo;
	reg [(DEPTH * 8) - 1:0] fifo_next;
	always @(posedge CLK or negedge nRST)
		if (!nRST) begin
			fifo <= {DEPTH {8'b00000000}};
			write_ptr <= 1'sb0;
			read_ptr <= 1'sb0;
			full_internal <= 1'b0;
			empty_internal <= 1'b1;
			overrun <= 1'b0;
			underrun <= 1'b0;
		end
		else begin
			fifo <= fifo_next;
			write_ptr <= write_ptr_next;
			read_ptr <= read_ptr_next;
			full_internal <= full_next;
			empty_internal <= empty_next;
			overrun <= overrun_next;
			underrun <= underrun_next;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		fifo_next = fifo;
		full_next = full_internal;
		empty_next = empty_internal;
		write_ptr_next = write_ptr;
		read_ptr_next = read_ptr;
		overrun_next = overrun;
		underrun_next = underrun;
		if (clear) begin
			full_next = 1'b0;
			empty_next = 1'b1;
			write_ptr_next = 1'sb0;
			read_ptr_next = 1'sb0;
			overrun_next = 1'b0;
			underrun_next = 1'b0;
		end
		else begin
			if (REN && !empty) begin
				read_ptr_next = read_ptr + 1;
				full_next = 1'b0;
				empty_next = read_ptr_next == write_ptr_next;
			end
			else if (REN && empty)
				underrun_next = 1'b1;
			if (WEN && !full) begin
				write_ptr_next = write_ptr + 1;
				fifo_next[write_ptr * 8+:8] = wdata;
				empty_next = 1'b0;
				full_next = write_ptr_next == read_ptr_next;
			end
			else if (WEN && full)
				overrun_next = 1'b1;
		end
	end
	assign count = write_ptr - read_ptr;
	assign rdata = fifo[read_ptr * 8+:8];
	assign full = full_internal;
	assign empty = empty_internal;
	initial _sv2v_0 = 0;
endmodule
