// Copyright (c) 2025 subnyquist
//
// Use is permitted for non-commercial purposes only. See the accompanying
// LICENSE file for terms of use.

module chiplib_pri_queue #(
    parameter int unsigned DataWidth     = 64,
    parameter int unsigned PriorityWidth = 16,
    parameter int unsigned QueueDepth    = 1024
) (
    input logic clk,
    input logic rst,

    // Push interface
    input  logic [    DataWidth-1:0] push_data,
    input  logic [PriorityWidth-1:0] push_pri,
    input  logic                     push_valid,
    output logic                     push_ready,

    // Pop interface
    output logic [    DataWidth-1:0] pop_data,
    output logic [PriorityWidth-1:0] pop_pri,
    output logic                     pop_valid,
    input  logic                     pop_ready
);

  logic [    DataWidth-1:0] queue_push_data;
  logic [PriorityWidth-1:0] queue_push_pri;
  logic                     queue_push_valid;
  logic [    DataWidth-1:0] queue_pop_data;
  logic [PriorityWidth-1:0] queue_pop_pri;
  logic                     queue_pop_valid;
  logic                     full;
  logic                     empty;

  chiplib_pri_queue_push_ctl #(
      .DataWidth    (DataWidth),
      .PriorityWidth(PriorityWidth)
  ) u_push_ctl (
      .push_data,
      .push_pri,
      .push_valid,
      .push_ready,

      .queue_push_data,
      .queue_push_pri,
      .queue_push_valid,

      .full
  );


  chiplib_pri_queue_mgr #(
      .DataWidth    (DataWidth),
      .PriorityWidth(PriorityWidth),
      .QueueDepth   (QueueDepth)
  ) u_mgr (
      .clk,
      .rst,

      .push_data (queue_push_data),
      .push_pri  (queue_push_pri),
      .push_valid(queue_push_valid),

      .pop_data (queue_pop_data),
      .pop_pri  (queue_pop_pri),
      .pop_valid(queue_pop_valid),

      .full,
      .empty
  );

  chiplib_pri_queue_pop_ctl #(
      .DataWidth    (DataWidth),
      .PriorityWidth(PriorityWidth)
  ) u_pop_ctl (
      .clk,
      .rst,

      .pop_data,
      .pop_pri,
      .pop_valid,
      .pop_ready,

      .queue_pop_data,
      .queue_pop_pri,
      .queue_pop_valid,

      .empty
  );

endmodule
