// Copyright (c) 2026 subnyquist
//
// Use is permitted for non-commercial purposes only. See the accompanying
// LICENSE file for terms of use.

module chiplib_arb_pri_pipe #(
    parameter int unsigned NumReq        = 20,
    parameter int unsigned NumPriorities = 5,
    parameter int unsigned PayloadWidth  = 30,
    parameter int unsigned Radix         = 6,

    localparam int unsigned PriorityWidth = $clog2(NumPriorities)
) (
    input logic clk,
    input logic rst,

    input logic [NumReq-1:0]                    req,
    input logic [NumReq-1:0][PriorityWidth-1:0] req_pri,
    input logic [NumReq-1:0][ PayloadWidth-1:0] req_payload,

    output logic                     gnt,
    output logic [PriorityWidth-1:0] gnt_pri,
    output logic [ PayloadWidth-1:0] gnt_payload
);

  if (NumReq <= Radix) begin : g_leaf
    logic [       NumReq-1:0] arb_gnt;
    logic [PriorityWidth-1:0] arb_gnt_pri;
    logic [ PayloadWidth-1:0] arb_gnt_payload;

    chiplib_arb_pri #(
        .NumReq       (NumReq),
        .NumPriorities(NumPriorities)
    ) u_arb (
        .req,
        .req_pri,
        .gnt(arb_gnt)
    );

    br_mux_onehot #(
        .NumSymbolsIn(NumReq),
        .SymbolWidth(PriorityWidth),
        .EnableAssertSelectOnehot(1)
    ) u_mux_pri (
        .select(arb_gnt),
        .in    (req_pri),
        .out   (arb_gnt_pri)
    );

    br_mux_onehot #(
        .NumSymbolsIn(NumReq),
        .SymbolWidth(PayloadWidth),
        .EnableAssertSelectOnehot(1)
    ) u_mux_payload (
        .select(arb_gnt),
        .in    (req_payload),
        .out   (arb_gnt_payload)
    );

    br_delay_valid #(
        .Width(PriorityWidth + PayloadWidth),
        .NumStages(1),
        .FirstStageUngated(0),
        .EnableAssertFinalNotValid(0)
    ) u_reg (
        .clk,
        .rst,
        .in_valid        (|req),
        .in              ({arb_gnt_pri, arb_gnt_payload}),
        .out_valid       (gnt),
        .out             ({gnt_pri, gnt_payload}),
        .out_valid_stages(),
        .out_stages      ()
    );

  end else begin : g_recursive
    localparam int unsigned NumGroups = (NumReq + Radix - 1) / Radix;

    logic [NumGroups-1:0]                    parent_gnt;
    logic [NumGroups-1:0][PriorityWidth-1:0] parent_gnt_pri;
    logic [NumGroups-1:0][ PayloadWidth-1:0] parent_gnt_payload;

    for (genvar i = 0; i < NumGroups; i++) begin : g_parent
      localparam int unsigned GroupSize = (i == NumGroups - 1) ? (NumReq - i * Radix) : Radix;

      chiplib_arb_pri_pipe #(
          .NumReq       (GroupSize),
          .NumPriorities(NumPriorities),
          .PayloadWidth (PayloadWidth),
          .Radix        (Radix)
      ) u_arb (
          .clk,
          .rst,
          .req        (req[i*Radix+:GroupSize]),
          .req_pri    (req_pri[i*Radix+:GroupSize]),
          .req_payload(req_payload[i*Radix+:GroupSize]),
          .gnt        (parent_gnt[i]),
          .gnt_pri    (parent_gnt_pri[i]),
          .gnt_payload(parent_gnt_payload[i])
      );
    end

    chiplib_arb_pri_pipe #(
        .NumReq       (NumGroups),
        .NumPriorities(NumPriorities),
        .PayloadWidth (PayloadWidth),
        .Radix        (Radix)
    ) u_arb (
        .clk,
        .rst,
        .req        (parent_gnt),
        .req_pri    (parent_gnt_pri),
        .req_payload(parent_gnt_payload),
        .gnt,
        .gnt_pri,
        .gnt_payload
    );
  end

endmodule
