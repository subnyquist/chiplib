// Copyright (c) 2025 subnyquist
//
// Use is permitted for non-commercial purposes only. See the accompanying
// LICENSE file for terms of use.

module chiplib_pri_queue_push_ctl #(
    parameter int unsigned DataWidth     = 64,
    parameter int unsigned PriorityWidth = 16
) (
    input  logic [    DataWidth-1:0] push_data,
    input  logic [PriorityWidth-1:0] push_pri,
    input  logic                     push_valid,
    output logic                     push_ready,

    output logic                     queue_push_valid,
    output logic [    DataWidth-1:0] queue_push_data,
    output logic [PriorityWidth-1:0] queue_push_pri,

    input logic full
);

  assign push_ready       = ~full;

  assign queue_push_valid = push_valid & push_ready;
  assign queue_push_data  = push_data;
  assign queue_push_pri   = push_pri;

endmodule
