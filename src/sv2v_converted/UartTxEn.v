module UartTxEn (
	clk,
	nReset,
	en,
	data,
	valid,
	out,
	busy,
	done
);
	reg _sv2v_0;
	input clk;
	input nReset;
	input en;
	input wire [7:0] data;
	input valid;
	output reg out;
	output reg busy;
	output reg done;
	reg [1:0] curState;
	reg [1:0] nextState;
	reg hasData;
	reg enterStart;
	reg [7:0] writeBuf;
	reg [3:0] writeCount;
	always @(*) begin
		if (_sv2v_0)
			;
		done = en & (nextState == 2'd3);
		busy = nextState != 2'd0;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		if (nextState == 2'd2)
			out = writeBuf[0];
		else if (nextState == 2'd1)
			out = 0;
		else
			out = 1;
	end
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	always @(posedge clk or negedge nReset)
		if (!nReset) begin
			curState <= 2'd0;
			writeCount <= 8;
			writeBuf <= 0;
			hasData <= 0;
			enterStart <= 0;
		end
		else begin
			curState <= (en ? nextState : curState);
			if ((nextState == 2'd3) || (nextState == 2'd0)) begin
				if (valid) begin
					enterStart <= (en ? 1 : enterStart);
					hasData <= 1;
					writeCount <= 8;
					writeBuf <= data;
				end
				else if (hasData)
					enterStart <= (en ? 1 : enterStart);
			end
			if (nextState == 2'd1) begin
				hasData <= (en ? 0 : hasData);
				enterStart <= (en ? 0 : enterStart);
			end
			if (nextState == 2'd2) begin
				writeCount <= (en ? writeCount - 1 : writeCount);
				writeBuf <= (en ? sv2v_cast_8(writeBuf[7:1]) : writeBuf);
			end
		end
	always @(*) begin
		if (_sv2v_0)
			;
		case (curState)
			2'd0: nextState = (enterStart ? 2'd1 : curState);
			2'd1: nextState = 2'd2;
			2'd2: nextState = (|writeCount ? curState : 2'd3);
			2'd3: nextState = (enterStart ? 2'd1 : 2'd0);
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
