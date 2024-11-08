module AHBUart_tapeout (
	clk,
	nReset,
	control,
	tx_data,
	rx_data,
	rx,
	tx,
	cts,
	rts,
	err,
	tx_buffer_full,
	rx_buffer_empty
);
	reg _sv2v_0;
	parameter [19:0] DefaultRate = 5207;
	input clk;
	input nReset;
	input wire [3:0] control;
	input wire [7:0] tx_data;
	output reg [7:0] rx_data;
	input rx;
	output wire tx;
	input cts;
	output wire rts;
	output reg err;
	output wire tx_buffer_full;
	output wire rx_buffer_empty;
	wire fifoTx_full;
	assign tx_buffer_full = fifoTx_full;
	wire fifoRx_empty;
	assign rx_buffer_empty = fifoRx_empty;
	wire [1:0] rate_control;
	wire [1:0] ren_wen;
	reg [19:0] rate;
	reg [19:0] new_rate;
	reg [1:0] ren_wen_nidle;
	reg [1:0] prev_ren_wen;
	assign ren_wen = control[3:2];
	assign rate_control = control[1:0];
	reg buffer_clear;
	always @(posedge clk or negedge nReset)
		if (!nReset) begin
			prev_ren_wen <= 2'd0;
			ren_wen_nidle <= 2'd0;
		end
		else begin
			if ((ren_wen != 2'd0) && (prev_ren_wen == 2'd0))
				ren_wen_nidle <= ren_wen;
			else
				ren_wen_nidle <= 2'd0;
			prev_ren_wen <= ren_wen;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		case (rate_control)
			2'b01: new_rate = 2604;
			2'b10: new_rate = 1302;
			2'b11: new_rate = 434;
			default: new_rate = DefaultRate;
		endcase
	end
	always @(posedge clk or negedge nReset)
		if (!nReset)
			rate <= DefaultRate;
		else
			rate <= new_rate;
	always @(*) begin
		if (_sv2v_0)
			;
		if (ren_wen_nidle == 2'd3)
			buffer_clear = 1'b1;
		else
			buffer_clear = 1'b0;
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
		else
			syncReset <= 0;
	BaudRateGen #(
		.MaxClockRate(1048576),
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
	wire fifoRx_underrun;
	wire fifoRx_overrun;
	wire [3:0] fifoRx_count;
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
	wire fifoTx_empty;
	wire fifoTx_underrun;
	wire fifoTx_overrun;
	wire [3:0] fifoTx_count;
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
	always @(posedge clk or negedge nReset)
		if (!nReset) begin
			fifoRx_wdata = 8'b00000000;
			fifoRx_WEN = 1'b0;
		end
		else if (rxDone && !rxErr) begin
			if (fifoRx_overrun) begin
				fifoRx_wdata = 8'b00000000;
				fifoRx_WEN = 1'b0;
			end
			else begin
				fifoRx_wdata = rxData;
				fifoRx_WEN = 1'b1;
			end
		end
		else begin
			fifoRx_wdata = 8'b00000000;
			fifoRx_WEN = 1'b0;
		end
	always @(posedge clk or negedge nReset)
		if (!nReset) begin
			txData = 8'b00000000;
			txValid = 1'b0;
			fifoTx_REN = 1'b0;
		end
		else if (fifoTx_empty || !cts) begin
			txData = 8'b00000000;
			txValid = 1'b0;
			fifoTx_REN = 1'b0;
		end
		else if (txClk) begin
			if (!txBusy) begin
				txData = fifoTx_rdata;
				txValid = 1'b1;
				fifoTx_REN = 1'b1;
			end
			else begin
				txData = 8'b00000000;
				txValid = 1'b0;
				fifoTx_REN = 1'b0;
			end
		end
		else begin
			txData = 8'b00000000;
			txValid = 1'b0;
			fifoTx_REN = 1'b0;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		fifoTx_wdata = 8'b00000000;
		fifoTx_WEN = 1'b0;
		if (ren_wen_nidle == 2'd1) begin
			fifoTx_wdata = tx_data;
			fifoTx_WEN = 1'b1;
		end
		else begin
			fifoTx_wdata = 8'b00000000;
			fifoTx_WEN = 1'b0;
		end
		rx_data = 8'b00000000;
		fifoRx_REN = 1'b0;
		if (ren_wen_nidle == 2'd2) begin
			rx_data = fifoRx_rdata;
			fifoRx_REN = 1'b1;
		end
		else begin
			rx_data = 8'b00000000;
			fifoRx_REN = 1'b0;
		end
	end
	always @(posedge clk or negedge nReset)
		if (!nReset)
			err <= 0;
		else
			err <= rxErr || err;
	initial _sv2v_0 = 0;
endmodule
