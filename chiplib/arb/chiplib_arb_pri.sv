// Copyright (c) 2026 subnyquist
//
// Use is permitted for non-commercial purposes only. See the accompanying
// LICENSE file for terms of use.

// Priority arbiter
//
// The request with the numerically highest priority is granted. In case of tie,
// the request with the lowest index is granted.

module chiplib_arb_pri #(
    parameter int unsigned NumReq        = 10,
    parameter int unsigned NumPriorities = 5,

    localparam int unsigned PriorityWidth = $clog2(NumPriorities)
) (
    input  logic [NumReq-1:0]                    req,
    input  logic [NumReq-1:0][PriorityWidth-1:0] req_pri,
    output logic [NumReq-1:0]                    gnt
);

  // Unroll the requests into NumPriorities levels. The lowest level corresponds
  // to requests with the highest priority and vice versa.

  logic [NumPriorities-1:0][NumReq-1:0] req_unrolled;

  for (genvar i = 0; i < NumPriorities; i++) begin : g_req_unrolled
    for (genvar j = 0; j < NumReq; j++) begin : g_req_unrolled
      assign req_unrolled[i][j] = req[j] & (req_pri[j] == PriorityWidth'(NumPriorities - i - 1));
    end
  end

  // Flatten the unrolled requests into a linear array.

  logic [NumPriorities*NumReq-1:0] req_unrolled_flat;
  assign req_unrolled_flat = req_unrolled;

  // Do fixed priority arbitration on the flattened requests. At each position,
  // the mask bit indicates whether any request with higher priority is active.

  logic [NumPriorities*NumReq-1:0] mask;

  assign mask[0] = 0;

  for (genvar i = 1; i < NumPriorities * NumReq; i++) begin : g_mask
    assign mask[i] = req_unrolled_flat[i-1] | mask[i-1];
  end

  logic [NumPriorities*NumReq-1:0] gnt_unrolled_flat;

  assign gnt_unrolled_flat = req_unrolled_flat & ~mask;

  // OR the grants from each level to get the final arbiter grant.

  logic [NumPriorities-1:0][NumReq-1:0] gnt_unrolled;

  assign gnt_unrolled = gnt_unrolled_flat;

  always_comb begin
    gnt = '0;
    for (int i = 0; i < NumPriorities; i++) begin
      gnt |= gnt_unrolled[i];
    end
  end

endmodule
