// Copyright (c) 2026 subnyquist
//
// Use is permitted for non-commercial purposes only. See the accompanying
// LICENSE file for terms of use.

module chiplib_riscv_plic_arb #(
    parameter int unsigned NumSources    = 100,
    parameter int unsigned PriorityWidth = 8,
    parameter int unsigned Radix         = 8,

    parameter bit [NumSources-1:0] IrqMask = '1,

    localparam int unsigned IdWidth = $clog2(NumSources)
) (
    input logic clk,
    input logic rst,

    input logic [   NumSources-1:0][PriorityWidth-1:0] irq_pri,
    input logic [   NumSources-1:0]                    irq_pend,
    input logic [   NumSources-1:0]                    irq_enable,
    input logic [PriorityWidth-1:0]                    irq_thresh,

    output logic               irq_out,
    output logic [IdWidth-1:0] irq_claim_id
);

  // Count the number of interrupts actually mapped to the target
  localparam int unsigned NumActualSources = $countones(IrqMask);

  // Only those interrupts that are mapped to the target are sent to the
  // arbiter. Convert the IrqMask bitmask into a mapping table that gives the
  // interrupt ID for each arbiter request index.

  typedef bit [NumActualSources-1:0][IdWidth-1:0] id_map_t;

  function automatic id_map_t build_id_map(bit [NumSources-1:0] irq_mask);
    id_map_t id_map;
    int i;

    i = 0;
    for (int id = 0; id < NumSources; id++) begin
      if (irq_mask[id]) begin
        id_map[i] = IdWidth'(id);
        i++;
      end
    end
    return id_map;
  endfunction

  localparam id_map_t IdMap = build_id_map(IrqMask);

  // Construct requests to the priority arbiter. A pending interrupt is eligible
  // for arbitration if it's enabled and its priority exceeds the target's
  // priority threshold.
  //
  // The interrupt ID is passed as payload to the arbiter.

  logic [NumActualSources-1:0]                    req;
  logic [NumActualSources-1:0][PriorityWidth-1:0] req_pri;
  logic [NumActualSources-1:0][      IdWidth-1:0] req_payload;

  for (genvar i = 0; i < NumActualSources; i++) begin : g_req
    localparam bit [IdWidth-1:0] Id = IdMap[i];

    assign req[i]         = irq_pend[Id] & irq_enable[Id] & (irq_pri[Id] > irq_thresh);
    assign req_pri[i]     = irq_pri[Id];
    assign req_payload[i] = Id;
  end

  // Pipelined priority arbiter. Grant indicates a valid interrupt to the target
  // and the payload of the grantee is the ID of the highest-priority interrupt.

  chiplib_arb_pri_pipe #(
      .NumReq       (NumActualSources),
      .NumPriorities(2 ** PriorityWidth),
      .PayloadWidth (IdWidth),
      .Radix        (Radix)
  ) u_arb (
      .clk,
      .rst,
      .req,
      .req_pri,
      .req_payload,
      .gnt        (irq_out),
      .gnt_pri    (),
      .gnt_payload(irq_claim_id)
  );

endmodule
