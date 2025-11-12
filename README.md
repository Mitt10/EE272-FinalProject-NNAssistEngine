# EE272-FinalProject-NNAssistEngine
High-speed neural network assist engine in SystemVerilog: 42-lane floating-point multiply-accumulate core with 1 GHz pipelined adder tree and token-based 1008-bit ring bus architecture.

This project implements a Neural Network Assist Engine — a high-throughput, fixed-function hardware accelerator designed to perform 42 parallel floating-point (E5M6) multiplications and an accumulated 48-bit fixed-point sum every clock cycle at a 1 GHz target frequency.

The engine interfaces with a 1008-bit token-ring bus that manages communication between multiple compute engines and shared memories using a distributed arbitration protocol. The full system includes a HUB connecting the testbench, four processing engines, and external memory FIFOs.
