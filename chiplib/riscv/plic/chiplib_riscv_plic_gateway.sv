// Copyright (c) 2026 subnyquist
//
// Use is permitted for non-commercial purposes only. See the accompanying
// LICENSE file for terms of use.

module chiplib_riscv_plic_gateway #(
    parameter bit IsPulse = 0,
    parameter bit IsAsync = 0
) (
    input logic clk,
    input logic rst,

    input logic irq_in,
    input logic irq_claim,
    input logic irq_complete,

    output logic irq_pend
);

  // TODO: Add support for pulse interrupts and async interrupts

  typedef enum logic [1:0] {
    Idle    = 2'b00,
    Pending = 2'b11,
    Claimed = 2'b01
  } state_t;

  state_t state;
  state_t state_next;

  assign irq_pend = (state == Pending);

  always_comb begin
    state_next = state;

    unique case (state)
      Idle: if (irq_in) state_next = Pending;

      Pending: if (irq_claim) state_next = Claimed;

      Claimed: if (irq_complete) state_next = (irq_in && !IsPulse) ? Pending : Idle;

      default: state_next = state_t'('x);
    endcase
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= Idle;
    end else begin
      state <= state_next;
    end
  end

endmodule
