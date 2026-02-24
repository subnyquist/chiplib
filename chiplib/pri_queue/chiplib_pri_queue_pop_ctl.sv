// Copyright (c) 2025 subnyquist
//
// Use is permitted for non-commercial purposes only. See the accompanying
// LICENSE file for terms of use.

module chiplib_pri_queue_pop_ctl #(
    parameter int unsigned DataWidth     = 64,
    parameter int unsigned PriorityWidth = 16
) (
    input logic clk,
    input logic rst,

    output logic [    DataWidth-1:0] pop_data,
    output logic [PriorityWidth-1:0] pop_pri,
    output logic                     pop_valid,
    input  logic                     pop_ready,

    output logic                     queue_pop_valid,
    input  logic [    DataWidth-1:0] queue_pop_data,
    input  logic [PriorityWidth-1:0] queue_pop_pri,

    input logic empty
);

  logic [    DataWidth-1:0] buf_data;
  logic [PriorityWidth-1:0] buf_pri;
  logic                     buf_valid;
  logic                     buf_valid_next;

  // Drive outputs from buffer if occupied, otherwise from queue
  assign pop_data        = buf_valid ? buf_data : queue_pop_data;
  assign pop_pri         = buf_valid ? buf_pri : queue_pop_pri;
  assign pop_valid       = buf_valid | ~empty;

  // Pop queue if not empty, and either receiver or buffer can accept data
  assign queue_pop_valid = ~empty & (pop_ready | ~buf_valid);

  always_comb begin
    unique case ({
      empty, pop_ready, buf_valid
    })
      // Buffer is occupied if queue is not empty and pop_ready is deasserted
      3'b000: buf_valid_next = 1;

      // Buffer is released when queue is empty and pop_ready is asserted
      3'b111: buf_valid_next = 0;

      default: buf_valid_next = buf_valid;
    endcase
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      buf_valid <= 0;
    end else begin
      buf_valid <= buf_valid_next;
    end
  end

  // Always load the popped data into the buffer
  always_ff @(posedge clk) begin
    if (queue_pop_valid) begin
      buf_data <= queue_pop_data;
      buf_pri  <= queue_pop_pri;
    end
  end

endmodule
