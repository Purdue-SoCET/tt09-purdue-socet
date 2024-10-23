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
*   Description:  Modification of AHB wrapper for PurdNyUart
*/


/* manually inserting the socetFIFO errors while this gets sorted out...*/
module socetlib_fifo #(
    parameter type T = logic [7:0], // total FIFO entries
    parameter DEPTH = 8,
    parameter ADDR_BITS = $clog2(DEPTH)
)(
    input CLK,
    input nRST,
    input WEN,
    input REN,
    input clear,
    input T wdata,
    output logic full,
    output logic empty,
    output logic underrun,
    output logic overrun,
    output logic [ADDR_BITS-1:0] count,
    output T rdata
);

    // Parameter checking
    //
    // Width can be any number of bits > 1, but depth must be a power-of-2 to accomodate addressing scheme
    // Address bits should not be changed by the user.
    /*generate
        if(DEPTH == 0 || (DEPTH != 0 && (DEPTH - 1) != 0)) begin
            $error("%m: DEPTH must be a power of 2 >= 1!");
        end

        if(ADDR_BITS != $clog2(DEPTH)) begin
            $error("%m: ADDR_BITS is automatically calculated, please do not override!");
        end
    endgenerate*/ //Note: the error statements is broken somehow, commented this just try to see if everything else works

    logic full_internal, full_next, empty_internal, empty_next;
    logic overrun_next, underrun_next;
    logic [ADDR_BITS-1:0] write_ptr, write_ptr_next, read_ptr, read_ptr_next;
    T [DEPTH-1:0] fifo, fifo_next;

    always_ff @(posedge CLK, negedge nRST) begin
        if(!nRST) begin
            fifo <= '{default: '0};
            write_ptr <= '0;
            read_ptr <= '0;
            full_internal <= 1'b0;
            empty_internal <= 1'b1;
            overrun <= 1'b0;
            underrun <= 1'b0;
        end else begin
            fifo <= fifo_next;
            write_ptr <= write_ptr_next;
            read_ptr <= read_ptr_next;
            full_internal <= full_next;
            empty_internal <= empty_next;
            overrun <= overrun_next;
            underrun <= underrun_next;
        end
    end

    always_comb begin
        fifo_next = fifo;
        full_next = full_internal;
        empty_next = empty_internal;
        write_ptr_next = write_ptr;
        read_ptr_next = read_ptr;
        overrun_next = overrun;
        underrun_next = underrun;

        if(clear) begin
            // No need to actually reset FIFO data,
            // changing pointers/flags to "empty" state is OK
            full_next = 1'b0;
            empty_next = 1'b1;
            write_ptr_next = '0;
            read_ptr_next = '0;
            overrun_next = 1'b0;
            underrun_next = 1'b0;
        end else begin
            if(REN && !empty) begin
                read_ptr_next = read_ptr + 1;
                full_next = 1'b0;
                empty_next = (read_ptr_next == write_ptr_next);
            end else if(REN && empty) begin
                underrun_next = 1'b1;
            end

            if(WEN && !full) begin
                write_ptr_next = write_ptr + 1;
                fifo_next[write_ptr] = wdata;
                empty_next = 1'b0;
                full_next = (write_ptr_next == read_ptr_next);
            end else if(WEN && full) begin
                overrun_next = 1'b1;
            end
        end
    end

    //assign count = (write_ptr > read_ptr) ? (write_ptr - read_ptr) : (ADDR_BITS - (read_ptr - write_ptr));
    assign count = write_ptr - read_ptr;
    assign rdata = fifo[read_ptr];

    assign full = full_internal;
    assign empty = empty_internal;


endmodule

//uart implementation

module AHBUart #(
    logic [15:0] DefaultRate = 5207  // Chosen by fair dice roll
) (
    input clk,
    input nReset,

    input  rx,
    output tx,

    input cts,
    output rts,

    bus_protocol_if.peripheral_vital bp
);
    // bp address types
    typedef enum logic [31:0] {
      RX_DATA = 0,             // address to read Rx data // Question: would it be better to merge Rx and Tx data addresses?
      TX_DATA  = 4,            // address to write Tx data
      RX_STATE = 8,            // address to see Rx buffer state
      TX_STATE  = 12,          // address to see Tx buffer state
      BAUD_RATE = 16,          // address to change baud rate
      BUFFER_CLEAR = 20,       // address to clear Rx and Tx buffers
      USE_FLOW_CONTROL = 24    // address to turn flow control on or off
      //PAUSE = , //consider implementing later
      //ERROR_STATE =  //consider implementing later
    } ADDRS;

    // configuration bits
    logic [15:0] rate;
    logic use_flow_control;
    logic buffer_clear;
    //logic [?:?] error_state; // might implement later
    always_ff @(posedge clk) begin
        if(!nReset) begin
            rate <= DefaultRate;
            use_flow_control <= 1'b1;
            buffer_clear <= 1'b1;
        end else begin
            // set value for rate
            if(bp.addr == BAUD_RATE && bp.wen) begin
                rate <= bp.wdata[15:0]; // setting the bus protocol write data = first 16 bits? 0x0F ex.
            end else begin
                rate <= 16'b0;
            end
            // set value for use_flow_control
            if(bp.addr == USE_FLOW_CONTROL && bp.wen) begin
                use_flow_control <= |bp.wdata;
            end else begin
                use_flow_control <= use_flow_control;
            end

            // set value for buffer_clear
            if(bp.addr == BUFFER_CLEAR && bp.wen && |bp.wdata) begin
                buffer_clear <= 1'b1;
            end else begin
                //only hold buffer clear for one cycle if possible
                buffer_clear <= 1'b0;
            end
        end
    end



    // UART signal
    logic [7:0] rxData;
    logic [7:0] txData;
    logic rxErr, rxClk, rxDone;
    logic txValid, txClk, txBusy, txDone;
    logic syncReset;

    always_ff @(posedge clk) begin
    if (!nReset) begin
      syncReset <= 1;
    end else if (bp.wen) begin
      case (bp.addr)
        RX_STATE, TX_STATE: syncReset <= 1;
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
  always_ff @(posedge clk) begin
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
      if((cts || !use_flow_control) && !txBusy && txDone) begin //is txDone or txBusy for this spot?? A: either signal should be fine, they are the converse of each other and I don't think its meaningful when
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
    always_ff @(posedge clk) begin
        // bus to Tx buffer
        if(bp.addr == TX_DATA && bp.wen) begin
            fifoTx_wdata <= bp.wdata[7:0]; // assume we r sending it through the first byte at a time right now
            fifoTx_WEN <= 1'b1;
        end
        else begin
            fifoTx_wdata <= 8'b0; // else writing nothing into the TX from the bus
            fifoTx_WEN <= 1'b0; // write signal is disabled
        end
        // Rx buffer to bus
        if(bp.addr == RX_DATA && bp.ren) begin
            bp.rdata <= {24'b0, fifoRx_rdata};
            fifoRx_REN <= 1'b1;
        // Rx state to bus
        end else if (bp.addr == RX_STATE && bp.ren) begin
            bp.rdata <= {27'b0, err, avail, fifoRx_count}; // include rr signal to state whether its a receiver error explicitly or not
        // Tx state to bus
        end else if (bp.addr == TX_STATE && bp.ren) begin
            bp.rdata <= {12'b0, rate, txDone, fifoTx_count}; //note to self: check that formatting is right
        end else begin
            bp.rdata <= 32'b0;
        end
    end

 assign bp.error = fifoRx_overrun || fifoTx_underrun;
 logic err, avail;

 always_ff @(posedge clk) begin
    if (!nReset) begin
      err   <= 0;
      avail <= 0;
    end else if (bp.ren) begin
      err   <= rxErr || ((bp.addr != RX_STATE) && err);
      avail <= rxDone || ((bp.addr != RX_DATA) && avail);
    end else begin
      err   <= rxErr || err; // if there is an exisiting error it persists
      avail <= rxDone || avail;
    end
  end
endmodule


//temporarily adding files here until i figure out what going on
module BaudRateGen #(
    int MaxClockRate = 100 * 10 ** 6,
    int MinBaudRate  = 9600,
    int Oversample   = 16
) (
    input clk,
    input nReset,
    input syncReset,

    input phase,
    input [txWidth-1:0] rate,

    output logic rxClk,
    output logic txClk
);

  localparam int txWidth = $clog2(MaxClockRate / MinBaudRate);
  localparam int rxShift = $clog2(Oversample);
  localparam int rxWidth = txWidth - rxShift;

  // Unreasonable to test these full-width
  /* verilator coverage_off */
  logic [txWidth-1:0] totalWait;
  logic [txWidth-1:0] postWait;
  logic [txWidth-1:0] preWait;
  /* verilator coverage_on */
  logic inWait;

  logic [rxWidth-1:0] rxRate;
  logic [rxWidth-1:0] offset;

  logic [rxWidth-1:0] rxCount;
  logic [txWidth-1:0] txCount;

  always_comb begin
    rxRate    = rate[txWidth-1:rxShift];
    offset    = rxRate - ((rxRate >> 1) + 1);

    totalWait = rate - {rxRate, 4'b0};
    preWait   = rate - (totalWait >> 1);
    postWait  = rate - preWait + txWidth'(rate[0]) + txWidth'(offset);
    inWait    = txCount > preWait || txCount < postWait;

    rxClk     = (rxRate > 1) ? (!inWait && rxCount == 0) ^ phase : phase;
    txClk     = (rate > 1) ? (txCount == 0) ^ phase : phase;
  end

  always @(posedge clk, negedge nReset) begin
    if (!nReset || syncReset || (txCount == 0)) begin
      rxCount <= rxRate - offset - 1;
    end else if (rxCount == 0) begin
      rxCount <= rxRate - 1;
    end else if (!inWait) begin
      rxCount <= rxCount - 1;
    end

    if (!nReset || syncReset || (txCount == 0)) begin
      txCount <= rate - 1;
    end else begin
      txCount <= txCount - 1;
    end
  end
endmodule

module UartRxEn #(
    int Oversample = 16
) (
    input clk,
    input nReset,

    input en,
    input in,

    output logic [7:0] data,

    output logic done,
    output logic err
);

  localparam sampleWidth = $clog2(Oversample);
  localparam fullSampleCount = sampleWidth'(Oversample - 1);
  localparam halfSampleCount = sampleWidth'(Oversample / 2);

  // verilog_format: off
  enum logic [2:0] {
    IDLE,
    START,
    DATA_A,
    DATA_B,
    STOP,
    ERROR
  } curState , nextState;
  // verilog_format: on

  logic rise, fall, cmp;

  always_ff @(posedge clk, negedge nReset) begin
    cmp <= !nReset ? 1 : en ? in : cmp;
  end

  always_comb begin
    rise = in & ~cmp;
    fall = ~in & cmp;
  end

  logic edgeDetect;
  logic badSync;
  logic reSync;
  logic advance;
  logic badStop;
  logic fastStart;

  logic [sampleWidth-1:0] sampleCount;
  logic [3:0] readCount;
  logic edgeCmp;

  always_comb begin
    edgeDetect = en ? fall || rise : 0;
    badSync = edgeDetect && edgeCmp && (sampleCount >= halfSampleCount);
    reSync = edgeDetect && (sampleCount < halfSampleCount);
    advance = reSync || (en && (sampleCount == 0));
    done = advance && (readCount == 0);
    badStop = en && in == 0 && sampleCount == halfSampleCount;
    fastStart = en && fall && sampleCount < halfSampleCount;
    err = nextState == ERROR;
  end

  always_ff @(posedge clk, negedge nReset) begin
    if (!nReset) begin
      sampleCount <= fullSampleCount;
      edgeCmp     <= 0;
      curState    <= IDLE;
    end else begin
      curState <= en ? nextState : curState;

      if (curState != nextState) begin
        edgeCmp     <= en ? edgeDetect : edgeCmp;
        sampleCount <= en ? fullSampleCount : sampleCount;
      end else begin
        edgeCmp     <= (en && edgeDetect) ? edgeDetect : edgeCmp;
        sampleCount <= en ? sampleCount - 1 : sampleCount;
      end
    end
  end

  logic [7:0] readBuf;

  always_ff @(posedge clk, negedge nReset) begin
    if (!nReset) begin
      readCount <= 8;
      data <= 0;
    end else begin

      if (readCount == 0) begin
        data <= en ? readBuf : data;
      end

      if (nextState != DATA_A && nextState != DATA_B) begin
        readCount <= en ? 8 : readCount;
      end else if (sampleCount == halfSampleCount) begin
        readCount <= en ? readCount - 1 : readCount;
        readBuf   <= en ? {in, readBuf[7:1]} : readBuf;
      end

    end
  end

  always_comb begin

    nextState = curState;

    case (curState)

      IDLE:
      if (fall) begin
        nextState = START;
      end

      START:
      if (badSync) begin
        nextState = ERROR;
      end else if (advance) begin
        nextState = DATA_A;
      end

      DATA_A:
      if (badSync) begin
        nextState = ERROR;
      end else if (advance) begin
        nextState = readCount > 0 ? DATA_B : STOP;
      end

      DATA_B:
      if (badSync) begin
        nextState = ERROR;
      end else if (advance) begin
        nextState = readCount > 0 ? DATA_A : STOP;
      end

      STOP:
      if (badSync || badStop) begin
        nextState = ERROR;
      end else if (fastStart) begin
        nextState = START;
      end else if (advance) begin
        nextState = IDLE;
      end

      // ERROR
      default: nextState = IDLE;

    endcase
  end

endmodule

module UartTxEn (
    input clk,
    input nReset,

    input en,
    input logic [7:0] data,
    input valid,

    output logic out,

    output logic busy,
    output logic done
);

  // verilog_format: off
  enum logic [1:0] {
    IDLE,
    START,
    DATA,
    STOP
  } curState, nextState;
  // verilog_format: on

  logic hasData;
  logic enterStart;

  logic [7:0] writeBuf;
  logic [3:0] writeCount;

  always_comb begin
    done = en & (nextState == STOP);
    busy = nextState != IDLE;
  end

  always_comb begin
    if (nextState == DATA) begin
      out = writeBuf[0];
    end else if (nextState == START) begin
      out = 0;
    end else begin
      out = 1;
    end
  end

  always_ff @(posedge clk, negedge nReset) begin
    if (!nReset) begin
      curState   <= IDLE;
      writeCount <= 8;
      writeBuf   <= 0;
      hasData    <= 0;
      enterStart <= 0;
    end else begin
      curState <= en ? nextState : curState;

      if (nextState == STOP || nextState == IDLE) begin
        if (valid) begin
          enterStart <= en ? 1 : enterStart;
          hasData    <= 1;
          writeCount <= 8;
          writeBuf   <= data;
        end else if (hasData) begin
          enterStart <= en ? 1 : enterStart;
        end
      end

      if (nextState == START) begin
        hasData <= en ? 0 : hasData;
        enterStart <= en ? 0 : enterStart;
      end

      if (nextState == DATA) begin
        writeCount <= en ? writeCount - 1 : writeCount;
        writeBuf   <= en ? 8'(writeBuf[7:1]) : writeBuf;
      end

    end
  end

  always_comb begin
    case (curState)
      IDLE: nextState = enterStart ? START : curState;

      START: nextState = DATA;

      DATA: nextState = |writeCount ? curState : STOP;

      STOP: nextState = enterStart ? START : IDLE;
    endcase
  end

endmodule
