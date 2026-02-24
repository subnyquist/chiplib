// Copyright (c) 2026 Chiplib Authors
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

  chiplib_riscv_plic__in_t  hi;
  chiplib_riscv_plic__out_t ho;

  // Interrupt priority

  for (genvar i = 0; i < 1024; i++) begin : g_pri
    assign hi.pri[i].rd_ack = ho.pri[i].req & ~ho.pri[i].req_is_wr;
    assign hi.pri[i].wr_ack = ho.pri[i].req & ho.pri[i].req_is_wr;

    if (i > 0 && i < NumSources) begin : g_norm
      assign hi.pri[i].rd_data.data = 32'(irq_pri[i]);

      always_ff @(posedge clk) begin
        if (rst) begin
          irq_pri[i] <= '0;
        end else if (hi.pri[i].wr_ack) begin
          irq_pri[i] <= PriorityMask[i] & (
            (ho.pri[i].wr_data.data[PriorityWidth-1:0] & ho.pri[i].wr_biten.data[PriorityWidth-1:0]) |
            (irq_pri[i] & ~ho.pri[i].wr_biten.data[PriorityWidth-1:0])
          );
        end
      end
    end else begin : g_tieoff
      assign hi.pri[i].rd_data.data = '0;

      if (i == 0) begin : g_0
        assign irq_pri[i] = '0;
      end
    end
  end

  // Interrupt pending

  for (genvar i = 0; i < 32; i++) begin : g_pend
    assign hi.pend[i].rd_ack = ho.pend[i].req & ~ho.pend[i].req_is_wr;

    if (i < NumSources / 32) begin : g_full
      assign hi.pend[i].rd_data.data = irq_pend[i*32+:32];
    end else if (i < (NumSources + 31) / 32) begin : g_partial
      assign hi.pend[i].rd_data.data = 32'(irq_pend[NumSources-1:i*32]);
    end else begin : g_tieoff
      assign hi.pend[i].rd_data.data = '0;
    end
  end

  // Interrupt enable

  for (genvar i = 0; i < 128; i++) begin : g_enable
    if (i < NumTargets) begin : g_norm
      // Interrupt 0 cannot be enabled
      localparam bit [NumSources-1:0] ActualIrqMask = IrqMask[i] & ~(NumSources'(1));

      for (genvar j = 0; j < 32; j++) begin : g_enable
        assign hi.enable[i].enable[j].rd_ack = ho.enable[i].enable[j].req & ~ho.enable[i].enable[j].req_is_wr;
        assign hi.enable[i].enable[j].wr_ack = ho.enable[i].enable[j].req & ho.enable[i].enable[j].req_is_wr;

        if (j < (NumSources + 31) / 32) begin : g_norm
          localparam int unsigned Lo = j * 32;
          localparam int unsigned Hi = ((j * 32 + 32) > NumSources) ? (NumSources - 1) : (j * 32 + 31);
          localparam int unsigned Sz = Hi - Lo + 1;

          assign hi.enable[i].enable[j].rd_data.data = 32'(irq_enable[i][Hi:Lo]);

          always_ff @(posedge clk) begin
            if (rst) begin
              irq_enable[i][Hi:Lo] <= '0;
            end else if (hi.enable[i].enable[j].wr_ack) begin
              irq_enable[i][Hi:Lo] <= ActualIrqMask[Hi:Lo] & (
                (ho.enable[i].enable[j].wr_data.data[Sz-1:0] & ho.enable[i].enable[j].wr_biten.data[Sz-1:0]) |
                (irq_enable[i][Hi:Lo] & ~ho.enable[i].enable[j].wr_biten.data[Sz-1:0])
              );
            end
          end
        end else begin : g_tieoff
          assign hi.enable[i].enable[j].rd_data.data = '0;
        end
      end
    end else begin : g_tieoff
      for (genvar j = 0; j < 32; j++) begin : g_enable
        assign hi.enable[i].enable[j].rd_ack = ho.enable[i].enable[j].req & ~ho.enable[i].enable[j].req_is_wr;
        assign hi.enable[i].enable[j].wr_ack = ho.enable[i].enable[j].req & ho.enable[i].enable[j].req_is_wr;
        assign hi.enable[i].enable[j].rd_data.data = '0;
      end
    end
  end

  // Interrupt threshold

  for (genvar i = 0; i < 128; i++) begin : g_thresh
    assign hi.ctl[i].thresh.rd_ack = ho.ctl[i].thresh.req & ~ho.ctl[i].thresh.req_is_wr;
    assign hi.ctl[i].thresh.wr_ack = ho.ctl[i].thresh.req & ho.ctl[i].thresh.req_is_wr;

    if (i < NumTargets) begin : g_norm
      assign hi.ctl[i].thresh.rd_data.data = 32'(irq_thresh[i]);

      always_ff @(posedge clk) begin
        if (rst) begin
          irq_thresh[i] <= '0;
        end else if (hi.ctl[i].thresh.wr_ack) begin
          irq_thresh[i] <= (
            (ho.ctl[i].thresh.wr_data.data[PriorityWidth-1:0] & ho.ctl[i].thresh.wr_biten.data[PriorityWidth-1:0]) |
            (irq_thresh[i] & ~ho.ctl[i].thresh.wr_biten.data[PriorityWidth-1:0])
          );
        end
      end
    end else begin : g_tieoff
      assign hi.ctl[i].thresh.rd_data.data = '0;
    end
  end

  // Interrupt claim/complete

  logic [NumTargets-1:0]              irq_claim_by_tgt;
  logic [NumTargets-1:0]              irq_complete_by_tgt;
  logic [NumTargets-1:0][IdWidth-1:0] irq_complete_id;

  for (genvar i = 0; i < 128; i++) begin : g_claim_complete
    assign hi.ctl[i].claim_complete.rd_ack = ho.ctl[i].claim_complete.req & ~ho.ctl[i].claim_complete.req_is_wr;
    assign hi.ctl[i].claim_complete.wr_ack = ho.ctl[i].claim_complete.req & ho.ctl[i].claim_complete.req_is_wr;

    if (i < NumTargets) begin : g_norm
      assign hi.ctl[i].claim_complete.rd_data.data = 32'(irq_claim_id[i]);

      // Read = claim, write = complete. Write data is the interrupt ID.
      assign irq_claim_by_tgt[i] = hi.ctl[i].claim_complete.rd_ack;
      assign irq_complete_by_tgt[i] = hi.ctl[i].claim_complete.wr_ack;
      assign irq_complete_id[i] = hi.ctl[i].claim_complete.wr_data.data[IdWidth-1:0];
    end else begin : g_tieoff
      assign hi.ctl[i].claim_complete.rd_data.data = '0;
    end
  end

  logic [   IdWidth-1:0] irq_claim_bin_next;
  logic [   IdWidth-1:0] irq_complete_bin_next;
  logic [NumSources-1:0] irq_claim_next;
  logic [NumSources-1:0] irq_complete_next;

  br_mux_onehot #(
      .NumSymbolsIn            (NumTargets),
      .SymbolWidth             (IdWidth),
      .EnableAssertSelectOnehot(1)
  ) u_mux_claim (
      .select(irq_claim_by_tgt),
      .in    (irq_claim_id),
      .out   (irq_claim_bin_next)
  );

  br_mux_onehot #(
      .NumSymbolsIn            (NumTargets),
      .SymbolWidth             (IdWidth),
      .EnableAssertSelectOnehot(1)
  ) u_mux_complete (
      .select(irq_complete_by_tgt),
      .in    (irq_complete_id),
      .out   (irq_complete_bin_next)
  );


  always_ff @(posedge clk) begin
    if (rst) begin
      irq_claim <= '0;
    end else if (irq_claim_le) begin
      irq_claim <= irq_claim_next;
    end
  end

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
      .hwif_in      (hi),
      .hwif_out     (ho)
  );

endmodule
