# Automotive Battery Management System (BMS)

## Overview
Designed and verified a parameterized Automotive Battery Management System using SystemVerilog RTL. The system monitors three battery cells through 12-bit ADC inputs and implements battery protection using a four-state Finite State Machine (FSM).

## Key Features
- 12-bit ADC-based monitoring of three battery cells.
- Overvoltage (OV) and undervoltage (UV) detection.
- Overcurrent (OC) and overtemperature (OT) protection.
- State of Charge (SOC) monitoring.
- Four-state FSM: INIT, NORMAL, CHARGE_ONLY and FAULT.
- Fault latching and hysteresis-based recovery.
- ADC validity monitoring.
- Cell voltage balancing logic.
- Asynchronous active-low reset.

## Architecture

The design consists of two main modules:

1. **BMS Monitor:** Monitors cell voltages, pack current, temperature and SOC.
2. **BMS Controller:** Implements FSM-based protection, fault management, charge/discharge control and cell balancing.

## Verification Methodology

A self-checking SystemVerilog testbench was developed with:

- Directed test scenarios.
- Randomized ADC stimulus.
- SystemVerilog Assertions (SVA).
- Functional and cross coverage.
- FSM state and transition coverage.
- Threshold boundary testing.
- Fault latching and recovery verification.

## Simulation Results

| Verification Metric | Result |
|---|---:|
| Directed test cases | 25 |
| Tests passed | 25 |
| Tests failed | 0 |
| Directed test pass rate | 100% |
| Randomized iterations | 100 |
| Functional coverage | 90.61% |

*Simulation performed using EDA Playground.*

## Tools & Technologies
- SystemVerilog
- RTL Design
- FSM Design
- SystemVerilog Assertions
- Functional Verification
- EDA Playground

## Future Enhancements
- ADC sampling and digital filtering.
- Bidirectional current sensing.
- Short-circuit protection.
- Precharge and contactor control.
- CAN communication interface.

## Disclaimer
ADC threshold values are illustrative simulation parameters and require calibration against actual battery specifications and hardware before physical implementation.
