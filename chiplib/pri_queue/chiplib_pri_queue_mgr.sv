// Copyright (c) 2025 subnyquist
//
// Use is permitted for non-commercial purposes only. See the accompanying
// LICENSE file for terms of use.

module chiplib_pri_queue_mgr #(
    parameter int unsigned DataWidth     = 64,
    parameter int unsigned PriorityWidth = 16,
    parameter int unsigned QueueDepth    = 1024
) (
    input logic clk,
    input logic rst,

    input logic                     push_valid,
    input logic [    DataWidth-1:0] push_data,
    input logic [PriorityWidth-1:0] push_pri,

    input  logic                     pop_valid,
    output logic [    DataWidth-1:0] pop_data,
    output logic [PriorityWidth-1:0] pop_pri,

    output logic empty,
    output logic full
);

  typedef struct packed {
    logic [PriorityWidth-1:0] pri;
    logic [DataWidth-1:0]     data;
  } entry_t;

  logic   [QueueDepth+1:0] entry_valid  /* verilator split_var */;
  entry_t [QueueDepth+1:0] entry  /* verilator split_var */;
  entry_t                  push_entry;
  logic   [QueueDepth+1:0] cmp;
  logic   [  QueueDepth:1] load_push;
  logic   [  QueueDepth:1] load_lower;
  logic   [  QueueDepth:1] load_higher;

  assign push_entry = '{pri: push_pri, data: push_data};

  // cmp[i] indicates whether the i-th entry has higher or equal priority than
  // the entry that is being pushed.
  //
  // Padding is added at the start and end for simpler calculation.
  //
  //   [0]            : fake entry with highest priority
  //   [QueueDepth:1] : the actual queue
  //   [QueueDepth+1] : fake entry with lowest priority
  //
  for (genvar i = 0; i < QueueDepth + 2; i++) begin : g_cmp
    if (i == 0) begin : g_lo_pad
      assign cmp[i] = 1;
    end else if (i == QueueDepth + 1) begin : g_hi_pad
      assign cmp[i] = 0;
    end else begin : g_norm
      assign cmp[i] = entry_valid[i] & (entry[i].pri >= push_entry.pri);
    end
  end

  // Index 1 is the actual head of the queue and index QueueDepth is the actual
  // tail
  assign empty    = ~entry_valid[1];
  assign full     = entry_valid[QueueDepth];

  // Head is always the highest priority entry
  assign pop_data = entry[1].data;
  assign pop_pri  = entry[1].pri;

  // Calculate push index and shifts
  for (genvar i = 1; i < QueueDepth + 1; i++) begin : g_load
    always_comb begin
      unique case ({
        push_valid, pop_valid
      })
        // push
        2'b10: begin
          load_push[i]   = ~cmp[i] & cmp[i-1];
          load_lower[i]  = ~cmp[i] & ~cmp[i-1];
          load_higher[i] = 0;
        end

        // pop
        2'b01: begin
          load_push[i]   = 0;
          load_lower[i]  = 0;
          load_higher[i] = 1;
        end

        // push + pop
        2'b11: begin
          load_push[i]   = ~cmp[i+1] & cmp[i];
          load_lower[i]  = 0;
          load_higher[i] = cmp[i+1];
        end

        // no-op
        default: begin
          load_push[i]   = 0;
          load_lower[i]  = 0;
          load_higher[i] = 0;
        end
      endcase
    end
  end

  for (genvar i = 0; i < QueueDepth + 2; i++) begin : g_entry
    if ((i == 0) || (i == QueueDepth + 1)) begin : g_pad
      assign entry_valid[i] = 0;
      assign entry[i]       = entry_t'('x);
    end else begin : g_norm
      logic   entry_valid_next;
      logic   entry_valid_le;
      entry_t entry_next;
      logic   entry_le;

      assign entry_valid_le = load_push[i] | load_lower[i] | load_higher[i];

      assign entry_le = load_push[i]
                          | (load_lower[i] & entry_valid[i-1])
                          | (load_higher[i] & entry_valid[i]);

      // One-hot mux
      always_comb begin
        unique case ({
          load_push[i], load_lower[i], load_higher[i]
        })
          3'b100: begin
            entry_valid_next = 1;
            entry_next       = push_entry;
          end

          3'b010: begin
            entry_valid_next = entry_valid[i-1];
            entry_next       = entry[i-1];
          end

          3'b001: begin
            entry_valid_next = entry_valid[i+1];
            entry_next       = entry[i+1];
          end

          default: begin
            entry_valid_next = 'x;
            entry_next       = entry_t'('x);
          end
        endcase
      end

      always_ff @(posedge clk) begin
        if (rst) begin
          entry_valid[i] <= 0;
        end else if (entry_valid_le) begin
          entry_valid[i] <= entry_valid_next;
        end
      end

      always_ff @(posedge clk) begin
        if (entry_le) begin
          entry[i] <= entry_next;
        end
      end
    end
  end

endmodule
