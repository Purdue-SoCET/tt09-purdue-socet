module BaudRateGen (
	clk,
	nReset,
	syncReset,
	phase,
	rate,
	rxClk,
	txClk
);
	reg _sv2v_0;
	parameter signed [31:0] MaxClockRate = 100000000;
	parameter signed [31:0] MinBaudRate = 9600;
	parameter signed [31:0] Oversample = 16;
	input clk;
	input nReset;
	input syncReset;
	input phase;
	localparam signed [31:0] txWidth = $clog2(MaxClockRate / MinBaudRate);
	input [txWidth - 1:0] rate;
	output reg rxClk;
	output reg txClk;
	localparam signed [31:0] rxShift = $clog2(Oversample);
	localparam signed [31:0] rxWidth = txWidth - rxShift;
	reg [txWidth - 1:0] totalWait;
	reg [txWidth - 1:0] postWait;
	reg [txWidth - 1:0] preWait;
	reg inWait;
	reg [rxWidth - 1:0] rxRate;
	reg [rxWidth - 1:0] offset;
	reg [rxWidth - 1:0] rxCount;
	reg [txWidth - 1:0] txCount;
	function automatic [txWidth - 1:0] sv2v_cast_C9358;
		input reg [txWidth - 1:0] inp;
		sv2v_cast_C9358 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		rxRate = rate[txWidth - 1:rxShift];
		offset = rxRate - ((rxRate >> 1) + 1);
		totalWait = rate - {rxRate, 4'b0000};
		preWait = rate - (totalWait >> 1);
		postWait = ((rate - preWait) + sv2v_cast_C9358(rate[0])) + sv2v_cast_C9358(offset);
		inWait = (txCount > preWait) || (txCount < postWait);
		rxClk = (rxRate > 1 ? (!inWait && (rxCount == 0)) ^ phase : phase);
		txClk = (rate > 1 ? (txCount == 0) ^ phase : phase);
	end
	always @(posedge clk or negedge nReset)
		if (!nReset)
			rxCount <= 0;
		else if (rxCount == 0)
			rxCount <= rxRate - 1;
		else if (!inWait)
			rxCount <= rxCount - 1;
	always @(posedge clk or negedge nReset)
		if (!nReset)
			txCount <= 0;
		else if (txCount == 0)
			txCount <= rate - 1;
		else
			txCount <= txCount - 1;
	initial _sv2v_0 = 0;
endmodule
