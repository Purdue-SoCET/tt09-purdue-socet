/*Copyright 2023 Purdue University
*   uodated
*   Licensed under the Apache License, Version 2.0 (the "License");
*   you may not use this file except in compliance with the License.
*   You may obtain a copy of the License at
*
*       http://www.apache.org/licenses/LICENSE-2.0
*
*   Unless required by applicable law or agreed to in writing, software
*   distributed under the License is distributed on an "AS IS" BASIS,
*   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*   See the License for the specific language governing permissions and
*   limitations under the License.
*
*
*   Filename:     AHBUart.sv
*
*   Created by:   Vito Gamberini
*   Email:        vito@gamberini.email
*   Modified by:  Michael Li (li4601@purdue.edu), Yash Singh (sing1018@purdue.edu) 
*   Date Created: 9/21/2024
*   Description:  Modification of AHB wrapper for Tape out Nov 10 testing.
*/

//uart implementation

module AHBUart_tapeout #(
	logic [19:0] DefaultRate = 5207  // value for 9600 baudrate
) (
    input clk, 
    input nReset, 
    input logic [3:0] control, 
    input logic [7:0] tx_data,
    output logic [7:0] rx_data,
    
    input  rx, 
    output tx,

    input cts, 
    output rts,
    output err,

	output tx_buffer_full,
	output rx_buffer_empty

    //note to self: should we add pins for buffer count?

);
	assign tx_buffer_full = fifoTx_full;
	assign rx_buffer_empty = fifoRx_empty;

    logic [1:0] rate_control, ren_wen;
    logic [19:0] rate, new_rate;
    logic [1:0]  ren_wen_nidle, prev_ren_wen; // act as the direction
	assign ren_wen = control[3:2];
    assign rate_control = control[1:0];
    // tristate logic handling...

    logic buffer_clear;
    
    //configurations for ren_wen and derivatives
    typedef enum logic [1:0] {
        IDLE = 0,
        to_TX = 1,
        from_RX = 2,
        BUFFER_CLEAR = 3
    } data_state_t;

    always_ff@(posedge clk, negedge nReset) begin
        if (!nReset) begin
            prev_ren_wen <= IDLE;
            ren_wen_nidle <= IDLE;
        end else begin
            if (ren_wen != IDLE && prev_ren_wen == IDLE) begin
                ren_wen_nidle <= ren_wen;
            end else begin
                ren_wen_nidle <= IDLE;
            end
            prev_ren_wen <= ren_wen;
        end 
    end

  always_comb begin
	  //"rate" is defined as the amount of clock cycles between each bit send/received by UART
	  //calculation is clock cycle/baudrate 
        case(rate_control)
            2'b01: new_rate = 2604;			//value for 19200 baudrate
            2'b10: new_rate = 1302;			//value for 38400 baudrate
            2'b11: new_rate = 434;			//value for 115200 baudrate
            default: new_rate = DefaultRate;
        endcase
    end
    
    always_ff @(posedge clk, negedge nReset) begin
        if(!nReset) begin
            rate <= DefaultRate;
        end else begin
            rate <= new_rate;
        end
    end
            
	//always_ff  @(posedge clk, negedge nReset) begin //trying as a comb for now
	always_comb begin
		// if (!nReset) begin //removing nRest b/c not syntheziable
            // buffer_clear = 1'b0;
        // end else begin
            if(ren_wen_nidle == BUFFER_CLEAR) begin 
                buffer_clear = 1'b1;
            end else begin
                buffer_clear = 1'b0; // else the buffer is not clear 
            end
        // end
    end

    // UART signal
    logic [7:0] rxData;
    logic [7:0] txData;
    logic rxErr, rxClk, rxDone;
    logic txValid, txClk, txBusy, txDone;
    logic syncReset;

    always_ff @(posedge clk, negedge nReset) begin
        if (!nReset) begin
            syncReset <= 1;
        end else begin
            syncReset <= 0;
        end
    end

    BaudRateGen #(2 ** 20, 1) bg (
        .phase(1'b0),
        .*
    );

    UartRxEn uartRx (
        .en  (rxClk),
        .in  (rx),
        .data(rxData),
        .done(rxDone),
        .err (rxErr),
        .*
    );

    UartTxEn uartTx (
        .en   (txClk),
        .data (txData),
        .valid(txValid),
        .out  (tx),  // verilator lint_off PINCONNECTEMPTY
        .busy (txBusy),  // verilator lint_on PINCONNECTEMPTY
        .done (txDone),
        .*
    );

    //fifoRx signals
    logic fifoRx_WEN, fifoRx_REN, fifoRx_clear;
    logic [7:0] fifoRx_wdata;
    logic fifoRx_full, fifoRx_empty, fifoRx_underrun, fifoRx_overrun;
            logic [$clog2(8):0] fifoRx_count; //current buffer capacity is 8, Note to self: might reduce if chip too big
    logic [7:0] fifoRx_rdata;

    socetlib_fifo fifoRx (
      .CLK(clk),
      .nRST(nReset),
      .WEN(fifoRx_WEN), //input
      .REN(fifoRx_REN), //input
      .clear(fifoRx_clear), //input
      .wdata(fifoRx_wdata), //input
      .full(fifoRx_full), //output
      .empty(fifoRx_empty), //output
      .underrun(fifoRx_underrun), //ouput
      .overrun(fifoRx_overrun), //output
      .count(fifoRx_count), //output
      .rdata(fifoRx_rdata) //output
    );

    //fifoTx signals
    logic fifoTx_WEN, fifoTx_REN, fifoTx_clear;
    logic [7:0] fifoTx_wdata;
    logic fifoTx_full, fifoTx_empty, fifoTx_underrun, fifoTx_overrun;
    logic [$clog2(8):0] fifoTx_count; //current buffer capacity is 8
    logic [7:0] fifoTx_rdata;

    socetlib_fifo fifoTx (
      .CLK(clk),
      .nRST(nReset),
      .WEN(fifoTx_WEN), //input
      .REN(fifoTx_REN), //input
      .clear(fifoTx_clear), //input
      .wdata(fifoTx_wdata), //input
      .full(fifoTx_full), //output
      .empty(fifoTx_empty), //output
      .underrun(fifoTx_underrun), //ouput
      .overrun(fifoTx_overrun), //output
      .count(fifoTx_count), //output
      .rdata(fifoTx_rdata) //output
    );

    //buffer clearing
    assign fifoRx_clear = buffer_clear;
    assign fifoTx_clear = buffer_clear;

    assign rts = fifoRx_full;

	//logic for UartRx to fifoRx // FLAG
	always_ff @(posedge clk, negedge nReset) begin
	// always_comb begin
		if (!nReset) begin
            fifoRx_wdata = 8'b0;
            fifoRx_WEN = 1'b0;
        end else
		if(rxDone && !rxErr) begin
			if (fifoRx_overrun) begin //m - probably better to just check if fifoRx is full/empty maybe
                fifoRx_wdata = 8'b0;
                fifoRx_WEN = 1'b0;
            end else begin
                fifoRx_wdata = rxData; 
                fifoRx_WEN = 1'b1;
            end
        end else begin
            fifoRx_wdata = 8'b0; 
            fifoRx_WEN = 1'b0;
        end
    end

	//logic for fifoTx to UartTx // FLAG
	//YASH: you might be able to move the combinational logic into the always_ff one; check the immediate prev_txClk 
	// logic prev_txClk;
	// always_ff @(posedge clk, negedge nReset) begin
	// 	if(!nReset) begin
	// 		prev_txClk <= 1'b0;
	// 	end else begin
	// 		prev_txClk <= txClk;
	// 	end
	// end
	always_ff @(posedge clk, negedge nReset) begin
		if(!nReset) begin
			txData = 8'b0;
			txValid = 1'b0;
			fifoTx_REN = 1'b0;
			end else if(fifoTx_empty || !cts) begin
			txData = 8'b0;
			txValid = 1'b0;
			fifoTx_REN = 1'b0;
		end else begin
			if(txClk) begin
				if(!txBusy) begin
					txData = fifoTx_rdata;
					txValid = 1'b1;
					fifoTx_REN = 1'b1;
				end else begin
					txData = 8'b0;
					txValid = 1'b0;
					fifoTx_REN = 1'b0;
				end
			end else begin
				txData = 8'b0;
				txValid = 1'b0;
				fifoTx_REN = 1'b0;
			end
		end
    end


	//buffer "bus" logic 
	// FLAG; just whatever you had below this
    // always_comb begin
    //     // "bus" to tx_buffer
    //     fifoTx_wdata = 8'b0;
    //     fifoTx_WEN = 1'b0;
    //     if(ren_wen_nidle == to_TX) begin
    //         fifoTx_wdata = tx_data; // assume we r sending it through the first byte at a time right now
    //         fifoTx_WEN = 1'b1;
    //     end else begin
    //         fifoTx_wdata = 8'b0; // else writing nothing into the TX from the bus
    //         fifoTx_WEN = 1'b0; // write signal is disabled
    //     end
        
    //     // Rx buffer to "bus"
    //     rx_data = 8'b0;
    //     fifoRx_REN = 1'b0;
    //     if(ren_wen_nidle == from_RX) begin // checking if theres only 0's in the rx_data line...
    //         rx_data = fifoRx_rdata;
    //         fifoRx_REN = 1'b1;
    //     end else begin
    //         rx_data = 8'b0;
    //         fifoRx_REN = 1'b0;
    //     end
    // end
    
    // "bus signal" mechanics
    always_comb begin
        // "bus" to tx_buffer
        fifoTx_wdata = 8'b0;
        fifoTx_WEN = 1'b0;
        if(ren_wen_nidle == to_TX) begin
            fifoTx_wdata = tx_data; // assume we r sending it through the first byte at a time right now
            fifoTx_WEN = 1'b1;
        end else begin
            fifoTx_wdata = 8'b0; // else writing nothing into the TX from the bus
            fifoTx_WEN = 1'b0; // write signal is disabled
        end
        
        // Rx buffer to "bus"
        rx_data = 8'b0;
        fifoRx_REN = 1'b0;
        if(ren_wen_nidle == from_RX) begin // checking if theres only 0's in the rx_data line...
            rx_data = fifoRx_rdata;
            fifoRx_REN = 1'b1;
        end else begin
            rx_data = 8'b0;
            fifoRx_REN = 1'b0;
        end
    end
    
    //logic to make sure err persists
    always_ff @(posedge clk, negedge nReset) begin
        if (!nReset) begin
            err   <= 0;
        end else begin
            err <= rxErr || err; //maybe add on overrun underrun errors
        end
     end 

endmodule
