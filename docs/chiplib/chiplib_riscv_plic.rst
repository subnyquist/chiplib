RISC-V PLIC
***********

Introduction
============

:doc:`Chiplib RISC-V PLIC </generated/chiplib_riscv_plic>` is a platform-level
interrupt controller (PLIC) intended for use in RISC-V systems.

The PLIC aggregates and routes interrupts from multiple source devices to one or
more targets, which can be processors, DMA controllers, or accelerators. It
supports interrupt masking, configurable priority levels, and atomic interrupt
claims in multi-target systems, accessible through an AXI-Lite programming
interface.

The PLIC implements the `RISC-V PLIC Specification <plic_spec_>`_. It is
designed as a synthesizable SystemVerilog module and is verified through
simulation and FPGA implementation.

Key Features
------------

* Fully implements the `RISC-V Platform-Level Interrupt Controller
  Specification, Version 1.0.0 <plic_spec_>`_.

* Supports up to 1023 interrupt sources and 128 targets, with arbitrary
  source-to-target interrupt mapping for sparse routing topologies.

* Multi-stage, configurable router pipeline for timing closure with large
  numbers of interrupt sources and priority levels.

* Supports atomic claims, where one interrupt can be simultaneously routed to
  multiple targets with any of the targets being able to claim the interrupt
  atomically.

* AXI-Lite programming interface for integration with standard AMBA
  interconnects.

Functional Description
----------------------

The architectural operation of the PLIC is described in the `RISC-V PLIC
Specification <plic_spec_>`_.

.. figure:: /diagrams/chiplib_riscv_plic_block_diagram.svg

   Functional units of the PLIC.

The PLIC consists of the following functional units.

Interrupt Gateway
  A gateway instance is present for each interrupt source. It samples the
  incoming interrupt signal (synchronizing it if configured as asynchronous),
  registers the interrupt request, and forwards the pending interrupt to the
  routers.

Interrupt Router
  A router instance is present for each interrupt target. It accepts the
  interrupts forwarded by the gateways, compares them against the enabled
  interrupts and the priority threshold, and routes the highest-priority
  interrupt to the target.

  It is implemented as a pipelined priority arbiter with a configurable arbiter
  radix per pipeline stage for timing closure with large numbers of interrupt
  sources and priority levels.

Memory-Mapped Registers
  Implements memory-mapped control and status registers, accessible through the
  AXI-Lite programming interface. See the `Programming Model`_ for a description
  of the registers.

Hardware Integration
====================

Parameters
----------

The design parameters are configurable at synthesis time. The parameter values
should be set based on functional requirements, frequency, and area targets.

.. list-table:: Module Parameters
   :widths: 15 20 65
   :header-rows: 1

   * - Parameter
     - Type
     - Description

   * - *NumSources*
     - Integer (2--1024)
     - **Number of interrupt sources.**

       .. note::

          Interrupt 0 is reserved to mean "no interrupt" and is internally
          ignored.  Hence, only (*NumSources* − 1) interrupts are actually
          available for use.

   * - *NumTargets*
     - Integer (1--128)
     - **Number of interrupt targets.**

       Interrupt targets are usually RISC-V hart contexts, but other targets
       such as DMA controllers and accelerators are possible.

   * - *PriorityWidth*
     - Integer (1--32)
     - **Bit-width of the interrupt priority registers.**

       The priority value of 0 is reserved to mean "never interrupt". Thus, a
       value of 8 provides 255 nonzero priority levels. A higher number of
       priority levels uses more hardware resources.

   * - *ArbiterRadix*
     - Integer (2--1024)
     - **Number of inputs per arbitration stage in the router pipeline.**

       A smaller number facilitates timing closure at the cost of higher
       pipeline latency. If set to *NumSources*, all interrupt sources are
       arbitrated and routed to the target in a single clock cycle.

   * - *PriorityMask*
     - Bit array (*NumSources* × *PriorityWidth*)
     - **Per-source bitmask for the interrupt priority registers.**

       If *PriorityMask*\ [\ *i*\ ][\ *j*\ ] is set to 0, then the *j*-th bit
       in the interrupt priority register for the *i*-th interrupt source is
       masked to 0.

       Use this parameter to minimize router complexity if particular interrupt
       sources can only be configured with a known range of priority levels.

   * - *IrqMask*
     - Bit array (*NumTargets* × *NumSources*)
     - **Reachability matrix mapping interrupt sources to targets.**

       Target *i* can receive interrupts from source *j* only if
       *IrqMask*\ [\ *i*\ ][\ *j*\ ] is set to 1.

       Use this parameter to minimize router complexity if particular interrupt
       sources can only be routed to known subsets of targets.

Port Descriptions
-----------------

``clk``
  Input clock. All internal logic, including the AXI-Lite interface and
  interrupt gateways, is synchronous to the rising edge of this clock.

``rst``
  Synchronous, active high reset. When asserted, all internal state (including
  pending interrupts) is cleared.

``irq_in[NumSources-1:0]``
  Interrupt signals from individual interrupt sources.

  .. note::

     ``irq_in[0]`` is reserved to mean "no interrupt" and is internally ignored.
     Hence it is recommended to tie off this signal to 0 during integration.

``irq_out[NumTargets-1:0]``
  Interrupt signals to individual targets. The signal is asserted when a target
  has a pending interrupt.

``s_axil_*``
  AXI4-Lite subordinate interface providing read/write access to memory mapped
  registers described in the `Programming Model`_. The address width is 26 bits
  and the data width is 32 bits.

Programming Model
=================

The PLIC implements the programming model defined in the `RISC-V PLIC
Specification <plic_spec_>`_. Read and write access to all memory-mapped
registers is performed through the AXI-Lite programming interface.

.. rdl:doctree:: chiplib_riscv_plic
   :link-to: doc

.. _plic_spec: https://docs.riscv.org/reference/hardware/plic/_attachments/riscv-plic.pdf
