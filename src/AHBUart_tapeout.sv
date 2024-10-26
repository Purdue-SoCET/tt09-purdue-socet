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
*   Modified by:  Michael Li, Yash Singh 
*   Date Created: 9/21/2024
*   Description:  Modification of AHB wrapper for Tape out Nov 10 testing.
*/

//uart implementation

module AHBUart_tapeout_wrapper #(
    logic [15:0] DefaultRate = 5207  // Chosen by fair dice roll
) (
    input clk, // 1
    input nReset, // 1
    input [3:0] control, // 4
    input [7:0] tx_data, // input to the fifo, and then the transceiver..which is then sent out again by tx
    output [7:0] rx_data, // received from rx, output from the reciever, to the fifo..which is then sent out by the data line
    
    input  rx, // 1
    output tx,

    input cts, // 1
    output rts,
    output err 

    // PIN COUNT:
    // rx_data, tx_data 8/8 bidirectional (bidirectional lines are handled in the tapeout wrapper file)
    // clk-1, nReset-1, control-4, rx-1, cts-4, 8/8 in 
    // tx, rts, err, 3/8 out
);

  logic [1:0] rate_control, ren_wen;
  logic [15:0] new_rate;
  logic [1:0]  ren_wen_nidle, prev_ren_wen; // act as the direction
  assign ren_wen = control[3:2];
  assign rate_control = control[1:0];
  // tristate logic handling...
  
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
        if (ren_wen == IDLE) begin
            ren_wen_nidle <= prev_ren_wen;
        end else begin
            ren_wen_nidle <= IDLE;
        end
        prev_ren_wen <= ren_wen;
    end 
    end

  always_comb begin
        case(rate_control)
            2'b01: new_rate = 9600;
            2'b10: new_rate = 50000;
            2'b11: new_rate = 115200;
            default: new_rate = DefaultRate;
        endcase
    end
    
    always_ff @(posedge clk, negedge nReset) begin
        if(!nReset) begin
            rate <= DefaultRate;
            new_rate <= DefaultRate;
        end else begin
            if(|rate_control) begin
              rate <= new_rate;
            end else begin
              rate <= DefaultRate;
            end
             ///   
            if(ren_wen_nidle == BUFFER_CLEAR) begin // if the read and write direction pin is enabled simultaneously, and non-zero data exists on the rx_data and tx_data
                buffer_clear <= 1'b1;
            end else begin
                buffer_clear <= 1'b0; // else the buffer is not clear 
            end
        end
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
    end else if (ren_wen_nidle) begin // check if ren_wen is beyond idle..
        case (ren_wen_nidle)
        to_TX, from_RX: syncReset <= 1; // if in read or write enable...
      endcase
    end else begin
      syncReset <= 0;
    end
    end

    // Params set "clock rate" to 2**16, and "min baud rate" to 1
    // This is equivalent to "please give me 16-bit counters"
    BaudRateGen #(2 ** 16, 1) bg (
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
    logic [$clog2(8)-1:0] fifoRx_count; //current buffer capacity is 8
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
    logic [$clog2(8)-1:0] fifoTx_count; //current buffer capacity is 8
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

  // UART - buffer signal mechanics
  assign rts = fifoRx_full;
  always_ff @(posedge clk, negedge nReset) begin
    //UART Rx to buffer Rx
    if(rxDone && !rxErr) begin
        if (fifoRx_overrun) begin
         fifoRx_wdata <= fifoRx_wdata;
         fifoRx_WEN <= 1'b0;
        // do we want to keep or flush out the old data in the fifo register if its full and the rx wants to send in more data?
        end else begin
        // alt, check with fifo clear
      fifoRx_wdata <= rxData; //do i need to account for overflow, probably not?
      fifoRx_WEN <= 1'b1;
        end
    end else begin
      fifoRx_wdata <= 8'b0; // clear out the data in the fifo and disable writing into it
      fifoRx_WEN <= 1'b0;
    end

    //buffer Tx to UART Tx
      if(cts && !txBusy && txDone) begin //is txDone or txBusy for this spot?? A: either signal should be fine, they are the converse of each other and I don't think its meaningful when
                                                                  //both are high
        if (fifoTx_underrun) begin
        txData <= fifoTx_rdata;
        txValid <= 1'b0;
        fifoRx_REN <= 1'b1;
        end else begin
        txData <= fifoTx_rdata; //should i account for buffer capacity, maybe not? // should be fine, both are 8 bits...
        txValid <= 1'b1; // the ts signal is valid
        fifoTx_REN <= 1'b1;
        end
    end else begin
      txData <= 8'b0;
      txValid <= 1'b0;
      fifoTx_REN <= 1'b0;
    end
  end

    // bus signal mechanics
        always_ff @(posedge clk, negedge nReset) begin
        if (!nReset) begin
            fifoTx_wdata <= 8'b0;
            fifoTx_WEN <= 1'b0;
            rx_data <= 8'b0;
            fifoRx_REN <= 1'b0;
        end else begin
            if((ren_wen_nidle == to_TX) && |tx_data ) begin
            fifoTx_wdata <= tx_data; // assume we r sending it through the first byte at a time right now
            fifoTx_WEN <= 1'b1;
        end
        else begin
            fifoTx_wdata <= 8'b0; // else writing nothing into the TX from the bus
            fifoTx_WEN <= 1'b0; // write signal is disabled
        end
        // Rx buffer to bus
            if((ren_wen_nidle == from_RX) && ~|rx_data) begin // checking if theres only 0's in the rx_data line...
            rx_data <= fifoRx_rdata;
            fifoRx_REN <= 1'b1;
        end else begin
            rx_data <= 8'b0;
            fifoRx_REN <= 1'b0;
        end
        end
      end

    logic err;
    always_ff @(posedge clk, negedge nReset) begin
    if (!nReset) begin
        err   <= 0;
    end else if (ren_wen_nidle) begin
        err   <= rxErr || ((ren_wen_nidle != from_RX) && err); // checks for a mismatch between errors 
    end else begin
        err   <= rxErr || err; // if there is an exisiting error it persists, 
    end
    end   

endmodule
