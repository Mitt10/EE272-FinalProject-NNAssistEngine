# EE272-FinalProject-NNAssistEngine
High-speed neural network assist engine in SystemVerilog: 42-lane floating-point multiply-accumulate core with 1 GHz pipelined adder tree and token-based 1008-bit ring bus architecture.

This project implements a Neural Network Assist Engine — a high-throughput, fixed-function hardware accelerator designed to perform 42 parallel floating-point (E5M6) multiplications and an accumulated 48-bit fixed-point sum every clock cycle at a 1 GHz target frequency.

The engine interfaces with a 1008-bit token-ring bus that manages communication between multiple compute engines and shared memories using a distributed arbitration protocol. The full system includes a HUB connecting the testbench, four processing engines, and external memory FIFOs.

flowchart LR
  subgraph RING["1008-bit Token Ring (logical view)"]
    direction LR
    TB["TestBench / CPU<br/>(ID 0)"] --> MEM8["Memory A<br/>(ID 8)"]
    MEM8 --> ENG9["Engine 0<br/>(ID 9)"]
    ENG9 --> MEM10["Memory B<br/>(ID 10)"]
    MEM10 --> ENG11["Engine 1<br/>(ID 11)"]
    ENG11 --> MEM12["Memory C<br/>(ID 12)"]
    MEM12 --> ENG13["Engine 2<br/>(ID 13)"]
    ENG13 --> MEM14["Memory D<br/>(ID 14)"]
    MEM14 --> ENG15["Engine 3<br/>(ID 15)"]
    ENG15 --> TB
  end

  classDef node fill:#fff,stroke:#333,stroke-width:1px,rx:8px,ry:8px;
  class TB,MEM8,MEM10,MEM12,MEM14,ENG9,ENG11,ENG13,ENG15 node;

  %% Token circulation hint
  %% (Clockwise around the ring; any node that holds the token may inject frames)
