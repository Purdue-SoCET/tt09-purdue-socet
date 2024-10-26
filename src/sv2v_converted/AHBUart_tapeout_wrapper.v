module AHBUart_tapeout_wrapper (
	clk,
	nReset,
	control,
	tx_data,
	rx_data,
	rx,
	tx,
	cts,
	rts,
	err
);
	reg _sv2v_0;
	parameter [15:0] DefaultRate = 5207;
	input clk;
	input nReset;
	input [3:0] control;
	input [7:0] tx_data;
	output reg [7:0] rx_data;
	input rx;
	output wire tx;
	input cts;
	output wire rts;
	output reg err;
	wire [1:0] rate_control;
	wire [1:0] ren_wen;
	reg [15:0] new_rate;
	reg [1:0] ren_wen_nidle;
	reg [1:0] prev_ren_wen;
	assign ren_wen = control[3:2];
	assign rate_control = control[1:0];
	always @(posedge clk or negedge nReset)
		if (!nReset) begin
			prev_ren_wen <= 2'd0;
			ren_wen_nidle <= 2'd0;
		end
		else begin
			if (ren_wen == 2'd0)
				ren_wen_nidle <= prev_ren_wen;
			else
				ren_wen_nidle <= 2'd0;
			prev_ren_wen <= ren_wen;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		case (rate_control)
			2'b01: new_rate = 9600;
			2'b10: new_rate = 50000;
			2'b11: new_rate = 115200;
			default: new_rate = DefaultRate;
		endcase
	end
	always @(posedge clk or negedge nReset)
		if (!nReset) begin
			rate <= DefaultRate;
			new_rate <= DefaultRate;
		end
		else begin
			if (|rate_control)
				rate <= new_rate;
			else
				rate <= DefaultRate;
			if (ren_wen_nidle == 2'd3)
				buffer_clear <= 1'b1;
			else
				buffer_clear <= 1'b0;
		end
	wire [7:0] rxData;
	reg [7:0] txData;
	wire rxErr;
	wire rxClk;
	wire rxDone;
	reg txValid;
	wire txClk;
	wire txBusy;
	wire txDone;
	reg syncReset;
	always @(posedge clk or negedge nReset)
		if (!nReset)
			syncReset <= 1;
		else if (ren_wen_nidle)
			case (ren_wen_nidle)
				2'd1, 2'd2: syncReset <= 1;
			endcase
		else
			syncReset <= 0;
	wire rate;
	BaudRateGen #(
		.MaxClockRate(65536),
		.MinBaudRate(1)
	) bg(
		.phase(1'b0),
		.clk(clk),
		.nReset(nReset),
		.syncReset(syncReset),
		.rate(rate),
		.rxClk(rxClk),
		.txClk(txClk)
	);
	UartRxEn uartRx(
		.en(rxClk),
		.in(rx),
		.data(rxData),
		.done(rxDone),
		.err(rxErr),
		.clk(clk),
		.nReset(nReset)
	);
	UartTxEn uartTx(
		.en(txClk),
		.data(txData),
		.valid(txValid),
		.out(tx),
		.busy(txBusy),
		.done(txDone),
		.clk(clk),
		.nReset(nReset)
	);
	reg fifoRx_WEN;
	reg fifoRx_REN;
	wire fifoRx_clear;
	reg [7:0] fifoRx_wdata;
	wire fifoRx_full;
	wire fifoRx_empty;
	wire fifoRx_underrun;
	wire fifoRx_overrun;
	wire [2:0] fifoRx_count;
	wire [7:0] fifoRx_rdata;
	socetlib_fifo fifoRx(
		.CLK(clk),
		.nRST(nReset),
		.WEN(fifoRx_WEN),
		.REN(fifoRx_REN),
		.clear(fifoRx_clear),
		.wdata(fifoRx_wdata),
		.full(fifoRx_full),
		.empty(fifoRx_empty),
		.underrun(fifoRx_underrun),
		.overrun(fifoRx_overrun),
		.count(fifoRx_count),
		.rdata(fifoRx_rdata)
	);
	reg fifoTx_WEN;
	reg fifoTx_REN;
	wire fifoTx_clear;
	reg [7:0] fifoTx_wdata;
	wire fifoTx_full;
	wire fifoTx_empty;
	wire fifoTx_underrun;
	wire fifoTx_overrun;
	wire [2:0] fifoTx_count;
	wire [7:0] fifoTx_rdata;
	socetlib_fifo fifoTx(
		.CLK(clk),
		.nRST(nReset),
		.WEN(fifoTx_WEN),
		.REN(fifoTx_REN),
		.clear(fifoTx_clear),
		.wdata(fifoTx_wdata),
		.full(fifoTx_full),
		.empty(fifoTx_empty),
		.underrun(fifoTx_underrun),
		.overrun(fifoTx_overrun),
		.count(fifoTx_count),
		.rdata(fifoTx_rdata)
	);
	assign fifoRx_clear = buffer_clear;
	assign fifoTx_clear = buffer_clear;
	assign rts = fifoRx_full;
	always @(posedge clk or negedge nReset) begin
		if (rxDone && !rxErr) begin
			if (fifoRx_overrun) begin
				fifoRx_wdata <= fifoRx_wdata;
				fifoRx_WEN <= 1'b0;
			end
			else begin
				fifoRx_wdata <= rxData;
				fifoRx_WEN <= 1'b1;
			end
		end
		else begin
			fifoRx_wdata <= 8'b00000000;
			fifoRx_WEN <= 1'b0;
		end
		if ((cts && !txBusy) && txDone) begin
			if (fifoTx_underrun) begin
				txData <= fifoTx_rdata;
				txValid <= 1'b0;
				fifoRx_REN <= 1'b1;
			end
			else begin
				txData <= fifoTx_rdata;
				txValid <= 1'b1;
				fifoTx_REN <= 1'b1;
			end
		end
		else begin
			txData <= 8'b00000000;
			txValid <= 1'b0;
			fifoTx_REN <= 1'b0;
		end
	end
	always @(posedge clk or negedge nReset)
		if (!nReset) begin
			fifoTx_wdata <= 8'b00000000;
			fifoTx_WEN <= 1'b0;
			rx_data <= 8'b00000000;
			fifoRx_REN <= 1'b0;
		end
		else begin
			if ((ren_wen_nidle == 2'd1) && |tx_data) begin
				fifoTx_wdata <= tx_data;
				fifoTx_WEN <= 1'b1;
			end
			else begin
				fifoTx_wdata <= 8'b00000000;
				fifoTx_WEN <= 1'b0;
			end
			if ((ren_wen_nidle == 2'd2) && ~|rx_data) begin
				rx_data <= fifoRx_rdata;
				fifoRx_REN <= 1'b1;
			end
			else begin
				rx_data <= 8'b00000000;
				fifoRx_REN <= 1'b0;
			end
		end
	always @(posedge clk or negedge nReset)
		if (!nReset)
			err <= 0;
		else if (ren_wen_nidle)
			err <= rxErr || ((ren_wen_nidle != 2'd2) && err);
		else
			err <= rxErr || err;
	initial _sv2v_0 = 0;
endmodule
