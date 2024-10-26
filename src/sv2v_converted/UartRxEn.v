module UartRxEn (
	clk,
	nReset,
	en,
	in,
	data,
	done,
	err
);
	reg _sv2v_0;
	parameter signed [31:0] Oversample = 16;
	input clk;
	input nReset;
	input en;
	input in;
	output reg [7:0] data;
	output reg done;
	output reg err;
	localparam sampleWidth = $clog2(Oversample);
	function automatic signed [sampleWidth - 1:0] sv2v_cast_EC27E_signed;
		input reg signed [sampleWidth - 1:0] inp;
		sv2v_cast_EC27E_signed = inp;
	endfunction
	localparam fullSampleCount = sv2v_cast_EC27E_signed(Oversample - 1);
	localparam halfSampleCount = sv2v_cast_EC27E_signed(Oversample / 2);
	reg [2:0] curState;
	reg [2:0] nextState;
	reg rise;
	reg fall;
	reg cmp;
	always @(posedge clk or negedge nReset)
		if (!nReset)
			cmp <= 1;
		else if (en)
			cmp <= in;
	always @(*) begin
		if (_sv2v_0)
			;
		rise = in & ~cmp;
		fall = ~in & cmp;
	end
	reg edgeDetect;
	reg badSync;
	reg reSync;
	reg advance;
	reg badStop;
	reg fastStart;
	reg [sampleWidth - 1:0] sampleCount;
	reg [3:0] readCount;
	reg edgeCmp;
	always @(*) begin
		if (_sv2v_0)
			;
		edgeDetect = (en ? fall || rise : 0);
		badSync = (edgeDetect && edgeCmp) && (sampleCount >= halfSampleCount);
		reSync = edgeDetect && (sampleCount < halfSampleCount);
		advance = reSync || (en && (sampleCount == 0));
		done = advance && (readCount == 0);
		badStop = (en && (in == 0)) && (sampleCount == halfSampleCount);
		fastStart = (en && fall) && (sampleCount < halfSampleCount);
		err = nextState == 3'd5;
	end
	always @(posedge clk or negedge nReset)
		if (!nReset) begin
			sampleCount <= fullSampleCount;
			edgeCmp <= 0;
			curState <= 3'd0;
		end
		else begin
			curState <= (en ? nextState : curState);
			if (curState != nextState) begin
				edgeCmp <= (en ? edgeDetect : edgeCmp);
				sampleCount <= (en ? fullSampleCount : sampleCount);
			end
			else begin
				edgeCmp <= (en && edgeDetect ? edgeDetect : edgeCmp);
				sampleCount <= (en ? sampleCount - 1 : sampleCount);
			end
		end
	reg [7:0] readBuf;
	always @(posedge clk or negedge nReset)
		if (!nReset) begin
			readCount <= 8;
			data <= 0;
			readBuf <= 0;
		end
		else begin
			if (readCount == 0)
				data <= (en ? readBuf : data);
			if ((nextState != 3'd2) && (nextState != 3'd3))
				readCount <= (en ? 8 : readCount);
			else if (sampleCount == halfSampleCount) begin
				readCount <= (en ? readCount - 1 : readCount);
				readBuf <= (en ? {in, readBuf[7:1]} : readBuf);
			end
		end
	always @(*) begin
		if (_sv2v_0)
			;
		nextState = curState;
		case (curState)
			3'd0:
				if (fall)
					nextState = 3'd1;
			3'd1:
				if (badSync)
					nextState = 3'd5;
				else if (advance)
					nextState = 3'd2;
			3'd2:
				if (badSync)
					nextState = 3'd5;
				else if (advance)
					nextState = (readCount > 0 ? 3'd3 : 3'd4);
			3'd3:
				if (badSync)
					nextState = 3'd5;
				else if (advance)
					nextState = (readCount > 0 ? 3'd2 : 3'd4);
			3'd4:
				if (badSync || badStop)
					nextState = 3'd5;
				else if (fastStart)
					nextState = 3'd1;
				else if (advance)
					nextState = 3'd0;
			default: nextState = 3'd0;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
