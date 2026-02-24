// Copyright (c) 2026 subnyquist
//
// Use is permitted for non-commercial purposes only. See the accompanying
// LICENSE file for terms of use.

module chiplib_riscv_plic_reg_ctl
  import chiplib_riscv_plic_reg_pkg::*;
#(
    parameter int unsigned NumSources    = 100,
    parameter int unsigned NumTargets    = 10,
    parameter int unsigned PriorityWidth = 8,

    parameter bit [NumSources-1:0][PriorityWidth-1:0] PriorityMask = '{default: '1},
    parameter bit [NumTargets-1:0][   NumSources-1:0] IrqMask      = '{default: '1},

    localparam int unsigned IdWidth = $clog2(NumSources)
) (
    input logic clk,
    input logic rst,

    output logic [NumSources-1:0][PriorityWidth-1:0] irq_pri,
    input  logic [NumSources-1:0]                    irq_pend,
    output logic [NumTargets-1:0][   NumSources-1:0] irq_enable,
    output logic [NumTargets-1:0][PriorityWidth-1:0] irq_thresh,
    input  logic [NumTargets-1:0][      IdWidth-1:0] irq_claim_id,
    output logic [NumSources-1:0]                    irq_claim,
    output logic [NumSources-1:0]                    irq_complete,

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


  chiplib_riscv_plic__in_t  hwif_in;
  chiplib_riscv_plic__out_t hwif_out;

  chiplib_riscv_plic_reg u_reg (
      .clk,
      .rst,
      .s_axil_awready,
      .s_axil_awvalid,
      .s_axil_awaddr,
      .s_axil_awprot('0),
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
      .s_axil_arprot('0),
      .s_axil_rready,
      .s_axil_rvalid,
      .s_axil_rdata,
      .s_axil_rresp,
      .hwif_in,
      .hwif_out
  );

endmodule
