// Copyright (c) 2026 subnyquist
//
// Use is permitted for non-commercial purposes only. See the accompanying
// LICENSE file for terms of use.

module chiplib_riscv_plic #(
    parameter int unsigned NumSources    = 100,
    parameter int unsigned NumTargets    = 10,
    parameter int unsigned PriorityWidth = 8,
    parameter int unsigned ArbiterRadix  = 8,

    parameter bit [NumSources-1:0][PriorityWidth-1:0] PriorityMask = '{default: '1},
    parameter bit [NumTargets-1:0][NumSources-1:0]    IrqMask = '{default: '1}
) (
    input logic clk,
    input logic rst,

    input  logic [NumSources-1:0] irq_in,
    output logic [NumTargets-1:0] irq_out,

    output logic        s_axil_awready,
    input  wire         s_axil_awvalid,
    input  wire  [25:0] s_axil_awaddr,
    output logic        s_axil_wready,
    input  wire         s_axil_wvalid,
    input  wire  [31:0] s_axil_wdata,
    input  wire  [ 3:0] s_axil_wstrb,
    input  wire         s_axil_bready,
    output logic        s_axil_bvalid,
    output logic [ 1:0] s_axil_bresp,
    output logic        s_axil_arready,
    input  wire         s_axil_arvalid,
    input  wire  [25:0] s_axil_araddr,
    input  wire         s_axil_rready,
    output logic        s_axil_rvalid,
    output logic [31:0] s_axil_rdata,
    output logic [ 1:0] s_axil_rresp

);

  logic [NumSources-1:0][     PriorityWidth-1:0] irq_pri;
  logic [NumSources-1:0]                         irq_pend;
  logic [NumTargets-1:0][        NumSources-1:0] irq_enable;
  logic [NumTargets-1:0][     PriorityWidth-1:0] irq_thresh;
  logic [NumTargets-1:0][$clog2(NumSources)-1:0] irq_claim_id;
  logic [NumSources-1:0]                         irq_claim;
  logic [NumSources-1:0]                         irq_complete;

  for (genvar i = 0; i < NumSources; i++) begin : g_gateway
    if (i == 0) begin : g_0
      assign irq_pend[i] = 0;
    end else begin : g_norm
      chiplib_riscv_plic_gateway #(
          .IsPulse(0),  // TODO: Add top params for pulse and async interrupts
          .IsAsync(0)
      ) u_gateway (
          .clk,
          .rst,
          .irq_in      (irq_in[i]),
          .irq_claim   (irq_claim[i]),
          .irq_complete(irq_complete[i]),
          .irq_pend    (irq_pend[i])
      );
    end
  end

  for (genvar i = 0; i < NumTargets; i++) begin : g_arb
    chiplib_riscv_plic_arb #(
        .NumSources   (NumSources),
        .PriorityWidth(PriorityWidth),
        .Radix        (ArbiterRadix),
        .IrqMask      (IrqMask[i])
    ) u_arb (
        .clk,
        .rst,
        .irq_pri,
        .irq_pend,
        .irq_enable  (irq_enable[i]),
        .irq_thresh  (irq_thresh[i]),
        .irq_out     (irq_out[i]),
        .irq_claim_id(irq_claim_id[i])
    );
  end

  chiplib_riscv_plic_reg_ctl #(
      .NumSources   (NumSources),
      .NumTargets   (NumTargets),
      .PriorityWidth(PriorityWidth),
      .PriorityMask (PriorityMask),
      .IrqMask      (IrqMask)
  ) u_reg_ctl (
      .clk,
      .rst,

      .irq_pri,
      .irq_pend,
      .irq_enable,
      .irq_thresh,
      .irq_claim_id,
      .irq_claim,
      .irq_complete,

      .s_axil_awready,
      .s_axil_awvalid,
      .s_axil_awaddr,
      .s_axil_wready,
      .s_axil_wvalid,
      .s_axil_wdata,
      .s_axil_wstrb,
      .s_axil_bready,
      .s_axil_bvalid,
      .s_axil_bresp,
      .s_axil_arready,
      .s_axil_arvalid,
      .s_axil_araddr,
      .s_axil_rready,
      .s_axil_rvalid,
      .s_axil_rdata,
      .s_axil_rresp
  );

endmodule
