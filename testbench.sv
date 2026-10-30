
`timescale 1ns/1ps

module bms_tb;

    // PARAMETERS

    localparam logic [11:0] OV_LIMIT       = 3800;
    localparam logic [11:0] UV_LIMIT       = 2500;
    localparam logic [11:0] UV_RECOVERY    = 2600;

    localparam logic [11:0] OC_LIMIT       = 3500;
    localparam logic [11:0] OT_LIMIT       = 3000;

    localparam logic [7:0] SOC_LOW_LIMIT   = 10;
    localparam logic [7:0] SOC_LOW_REC     = 15;
    localparam logic [7:0] SOC_HIGH_LIMIT  = 95;

    localparam logic [11:0] BALANCE_START  = 3200;
    localparam logic [11:0] BALANCE_DELTA  = 50;

    localparam logic [1:0] INIT        = 2'b00;
    localparam logic [1:0] NORMAL      = 2'b01;
    localparam logic [1:0] CHARGE_ONLY = 2'b10;
    localparam logic [1:0] FAULT       = 2'b11;


    // SIGNAL DECLARATIONS

    logic clk;
    logic rst_n;

    logic [11:0] cell1_adc;
    logic [11:0] cell2_adc;
    logic [11:0] cell3_adc;

    logic [11:0] current_adc;
    logic [11:0] temp_adc;

    logic [7:0] soc_percent;

    logic adc_valid;

    wire charge_enable;
    wire discharge_enable;

    wire system_fault;

    wire [2:0] balance_enable;

    wire ov_flag;
    wire uv_flag;
    wire oc_flag;
    wire ot_flag;

    wire soc_low_flag;
    wire soc_high_flag;

    wire sensor_fault;

    wire [1:0] current_state;


    // TEST COUNTERS

    integer total_tests = 0;
    integer passed_tests = 0;
    integer failed_tests = 0;

    integer random_iterations = 100;


    // DUT INSTANTIATION

    bms_dut #(

        .OV_LIMIT(OV_LIMIT),
        .UV_LIMIT(UV_LIMIT),
        .UV_RECOVERY(UV_RECOVERY),

        .OC_LIMIT(OC_LIMIT),
        .OT_LIMIT(OT_LIMIT),

        .SOC_LOW_LIMIT(SOC_LOW_LIMIT),
        .SOC_LOW_REC(SOC_LOW_REC),
        .SOC_HIGH_LIMIT(SOC_HIGH_LIMIT),

        .BALANCE_START(BALANCE_START),
        .BALANCE_DELTA(BALANCE_DELTA)

    ) dut (

        .clk(clk),
        .rst_n(rst_n),

        .cell1_adc(cell1_adc),
        .cell2_adc(cell2_adc),
        .cell3_adc(cell3_adc),

        .current_adc(current_adc),
        .temp_adc(temp_adc),

        .soc_percent(soc_percent),

        .adc_valid(adc_valid),

        .charge_enable(charge_enable),
        .discharge_enable(discharge_enable),

        .system_fault(system_fault),

        .balance_enable(balance_enable),

        .ov_flag(ov_flag),
        .uv_flag(uv_flag),
        .oc_flag(oc_flag),
        .ot_flag(ot_flag),

        .soc_low_flag(soc_low_flag),
        .soc_high_flag(soc_high_flag),

        .sensor_fault(sensor_fault),

        .current_state(current_state)

    );


    // CLOCK GENERATION
    // 100 MHz = 10 ns period

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    // WAVEFORM GENERATION

    initial begin

        $dumpfile("bms_waveform.vcd");

        $dumpvars(0, bms_tb);

    end


    // INITIALIZE INPUTS

    task initialize_inputs;

    begin

        cell1_adc = 12'd3000;
        cell2_adc = 12'd3000;
        cell3_adc = 12'd3000;

        current_adc = 12'd1000;
        temp_adc = 12'd1000;

        soc_percent = 8'd50;

        adc_valid = 1'b1;

    end

    endtask


    // RESET TASK

    task reset_dut;

    begin

        @(negedge clk);

        rst_n = 1'b0;

        initialize_inputs();

        #1;

        if ({charge_enable,
             discharge_enable,
             system_fault} !== 3'b000)

            $error("Asynchronous reset output failure");


        repeat (2) @(posedge clk);

        @(negedge clk);

        rst_n = 1'b1;

        repeat (2) @(posedge clk);

        #1;

        if (current_state !== NORMAL)

            $error("DUT failed to enter NORMAL after reset");

    end

    endtask


    // APPLY ADC INPUTS

    task apply_adc;

        input [11:0] v1;
        input [11:0] v2;
        input [11:0] v3;

        input [11:0] current;
        input [11:0] temperature;

        input [7:0] soc;

        input valid;

    begin

        @(negedge clk);

        cell1_adc = v1;
        cell2_adc = v2;
        cell3_adc = v3;

        current_adc = current;
        temp_adc = temperature;

        soc_percent = soc;

        adc_valid = valid;

        // Allow registered logic to respond
        repeat (3) @(posedge clk);

        #1;

    end

    endtask


    // SELF-CHECKING OUTPUT TASK

    task check_outputs;

        input expected_charge;
        input expected_discharge;
        input expected_fault;

        input [1:0] expected_state;

        input [8*60-1:0] test_name;

    begin

        total_tests = total_tests + 1;

        if (

            charge_enable === expected_charge &&

            discharge_enable === expected_discharge &&

            system_fault === expected_fault &&

            current_state === expected_state

        ) begin

            passed_tests = passed_tests + 1;

            $display("[PASS] %0s", test_name);

        end

        else begin

            failed_tests = failed_tests + 1;

            $display("[FAIL] %0s", test_name);

            $display("Expected state: %b", expected_state);

            $display("Actual state:   %b", current_state);

            $display("Expected outputs: %b%b%b",

                expected_charge,
                expected_discharge,
                expected_fault
            );

            $display("Actual outputs:   %b%b%b",

                charge_enable,
                discharge_enable,
                system_fault
            );

        end

    end

    endtask


    // BALANCING CHECK

    task check_balance;

        input [2:0] expected_balance;

        input [8*60-1:0] test_name;

    begin

        total_tests = total_tests + 1;

        if (balance_enable === expected_balance) begin

            passed_tests = passed_tests + 1;

            $display("[PASS] %0s", test_name);

        end

        else begin

            failed_tests = failed_tests + 1;

            $display("[FAIL] %0s", test_name);

            $display("Expected balance: %b",
                     expected_balance);

            $display("Actual balance:   %b",
                     balance_enable);

        end

    end

    endtask


    // TEST CASES

    initial begin

        rst_n = 1'b0;

        initialize_inputs();

        // TEST 1: NORMAL OPERATION

        reset_dut();

        check_outputs(
            1, 1, 0, NORMAL,
            "Normal operation"
        );


        // TEST 2: OVERVOLTAGE CELL 1
        apply_adc(
            3800, 3000, 3000,
            1000, 1000, 50, 1
        );

        check_outputs(
            0, 0, 1, FAULT,
            "Cell 1 overvoltage"
        );

      
        // TEST 3: OVERVOLTAGE CELL 2

        reset_dut();

        apply_adc(
            3000, 3800, 3000,
            1000, 1000, 50, 1
        );

        check_outputs(
            0, 0, 1, FAULT,
            "Cell 2 overvoltage"
        );


        // TEST 4: OVERVOLTAGE CELL 3

        reset_dut();

        apply_adc(
            3000, 3000, 3800,
            1000, 1000, 50, 1
        );

        check_outputs(
            0, 0, 1, FAULT,
            "Cell 3 overvoltage"
        );


        // TEST 5: UNDERVOLTAGE CELL 1

        reset_dut();

        apply_adc(
            2500, 3000, 3000,
            1000, 1000, 50, 1
        );

        check_outputs(
            1, 0, 0, CHARGE_ONLY,
            "Cell 1 undervoltage"
        );


        // TEST 6: UNDERVOLTAGE CELL 2

        reset_dut();

        apply_adc(
            3000, 2500, 3000,
            1000, 1000, 50, 1
        );

        check_outputs(
            1, 0, 0, CHARGE_ONLY,
            "Cell 2 undervoltage"
        );


        // TEST 7: UNDERVOLTAGE CELL 3

        reset_dut();

        apply_adc(
            3000, 3000, 2500,
            1000, 1000, 50, 1
        );

        check_outputs(
            1, 0, 0, CHARGE_ONLY,
            "Cell 3 undervoltage"
        );


        // TEST 8: UV HYSTERESIS

        apply_adc(
            2550, 3000, 3000,
            1000, 1000, 50, 1
        );

        check_outputs(
            1, 0, 0, CHARGE_ONLY,
            "UV remains active inside hysteresis"
        );


        // TEST 9: UV RECOVERY

        apply_adc(
            2700, 3000, 3000,
            1000, 1000, 50, 1
        );

        check_outputs(
            1, 1, 0, NORMAL,
            "UV recovery"
        );


        // TEST 10: OVERCURRENT

        reset_dut();

        apply_adc(
            3000, 3000, 3000,
            3500, 1000, 50, 1
        );

        check_outputs(
            0, 0, 1, FAULT,
            "Overcurrent"
        );


        // TEST 11: OVERTEMPERATURE

        reset_dut();

        apply_adc(
            3000, 3000, 3000,
            1000, 3000, 50, 1
        );

        check_outputs(
            0, 0, 1, FAULT,
            "Overtemperature"
        );


        // TEST 12: LOW SOC

        reset_dut();

        apply_adc(
            3000, 3000, 3000,
            1000, 1000, 10, 1
        );

        check_outputs(
            1, 0, 0, CHARGE_ONLY,
            "Low SOC"
        );


        // TEST 13: SOC HYSTERESIS

        apply_adc(
            3000, 3000, 3000,
            1000, 1000, 12, 1
        );

        check_outputs(
            1, 0, 0, CHARGE_ONLY,
            "SOC remains low within hysteresis"
        );


        // TEST 14: SOC RECOVERY

        apply_adc(
            3000, 3000, 3000,
            1000, 1000, 20, 1
        );

        check_outputs(
            1, 1, 0, NORMAL,
            "SOC recovery"
        );


        // TEST 15: HIGH SOC

        reset_dut();

        apply_adc(
            3000, 3000, 3000,
            1000, 1000, 95, 1
        );

        check_outputs(
            0, 0, 1, FAULT,
            "High SOC"
        );


        // TEST 16: SENSOR FAILURE

        reset_dut();

        apply_adc(
            3000, 3000, 3000,
            1000, 1000, 50, 0
        );

        check_outputs(
            0, 0, 1, FAULT,
            "ADC invalid signal"
        );


        // TEST 17: FAULT LATCHING
        apply_adc(
            3000, 3000, 3000,
            1000, 1000, 50, 1
        );

        check_outputs(
            0, 0, 1, FAULT,
            "Fault remains latched"
        );


        // TEST 18: RESET RECOVERY

        reset_dut();

        check_outputs(
            1, 1, 0, NORMAL,
            "Reset clears fault"
        );


        // TEST 19: MULTIPLE SIMULTANEOUS FAULTS
        apply_adc(
            3800, 2500, 3000,
            3500, 3000, 95, 1
        );

        check_outputs(
            0, 0, 1, FAULT,
            "Multiple simultaneous faults"
        );


        // TEST 20: THRESHOLD BELOW OV

        reset_dut();

        apply_adc(
            3799, 3000, 3000,
            1000, 1000, 50, 1
        );

        check_outputs(
            1, 1, 0, NORMAL,
            "OV threshold minus one"
        );


        // TEST 21: OV EXACT THRESHOLD
      

        apply_adc(
            3800, 3000, 3000,
            1000, 1000, 50, 1
        );

        check_outputs(
            0, 0, 1, FAULT,
            "OV exact threshold"
        );

      
        // TEST 22: BALANCING
      

        reset_dut();

        apply_adc(
            3300, 3400, 3500,
            1000, 1000, 50, 1
        );

        check_outputs(
            1, 1, 0, NORMAL,
            "Normal state for balancing"
        );

        check_balance(
            3'b110,
            "Balancing higher voltage cells"
        );


        // TEST 23: NO BALANCING

        apply_adc(
            3300, 3320, 3340,
            1000, 1000, 50, 1
        );

        check_balance(
            3'b000,
            "No balancing for small voltage difference"
        );


        // TEST 24: BALANCING DISABLED DURING UV

        apply_adc(
            2500, 3300, 3500,
            1000, 1000, 50, 1
        );

        check_balance(
            3'b000,
            "Balancing disabled during UV"
        );


        // TEST 25: RANDOMIZED ADC TESTING
        reset_dut();

        repeat (random_iterations) begin

            apply_adc(

                $urandom_range(2700, 3700),
                $urandom_range(2700, 3700),
                $urandom_range(2700, 3700),

                $urandom_range(0, 3400),
                $urandom_range(0, 2900),

                $urandom_range(16, 94),

                1'b1

            );

        end

        // FINAL SUMMARY

        $display("\n");
        $display("BMS VERIFICATION REPORT");

        $display("Total tests : %0d", total_tests);
        $display("Passed      : %0d", passed_tests);
        $display("Failed      : %0d", failed_tests);

        if (failed_tests == 0)
            $display("ALL DIRECTED TESTS PASSED");

        else
            $display("VERIFICATION FAILURES DETECTED");

        $finish;

    end


    // SYSTEMVERILOG ASSERTIONS

    // 1. NORMAL state output verification

    property p_normal_outputs;

        @(posedge clk)

        disable iff (!rst_n)

        current_state == NORMAL

        |->
        (charge_enable &&
         discharge_enable &&
         !system_fault);

    endproperty

    a_normal_outputs:
        assert property(p_normal_outputs);


    // 2. CHARGE_ONLY output verification

    property p_charge_only_outputs;

        @(posedge clk)

        disable iff (!rst_n)

        current_state == CHARGE_ONLY

        |->
        (charge_enable &&
         !discharge_enable &&
         !system_fault);

    endproperty

    a_charge_only_outputs:
        assert property(p_charge_only_outputs);


    // 3. FAULT output verification

    property p_fault_outputs;

        @(posedge clk)

        disable iff (!rst_n)

        current_state == FAULT

        |->
        (!charge_enable &&
         !discharge_enable &&
         system_fault &&
         (balance_enable == 3'b000));

    endproperty

    a_fault_outputs:
        assert property(p_fault_outputs);


    // 4. Fault latching

    property p_fault_latched;

        @(posedge clk)

        disable iff (!rst_n)

        current_state == FAULT

        |=> current_state == FAULT;

    endproperty

    a_fault_latched:
        assert property(p_fault_latched);


    // 5. Overvoltage leads to FAULT

    property p_ov_fault;

        @(posedge clk)

        disable iff (!rst_n)

        (current_state != FAULT && ov_flag)

        |=> current_state == FAULT;

    endproperty

    a_ov_fault:
        assert property(p_ov_fault);


    // 6. Overcurrent leads to FAULT

    property p_oc_fault;

        @(posedge clk)

        disable iff (!rst_n)

        (current_state != FAULT && oc_flag)

        |=> current_state == FAULT;

    endproperty

    a_oc_fault:
        assert property(p_oc_fault);


    // 7. Overtemperature leads to FAULT

    property p_ot_fault;

        @(posedge clk)

        disable iff (!rst_n)

        (current_state != FAULT && ot_flag)

        |=> current_state == FAULT;

    endproperty

    a_ot_fault:
        assert property(p_ot_fault);


    // 8. Invalid ADC leads to FAULT

    property p_sensor_fault;

        @(posedge clk)

        disable iff (!rst_n)

        (current_state != FAULT && !adc_valid)

        |=> current_state == FAULT;

    endproperty

    a_sensor_fault:
        assert property(p_sensor_fault);


    // 9. UV leads to CHARGE_ONLY
    // UV active flag has one-cycle registration.

    property p_uv_charge_only;

        @(posedge clk)

        disable iff (!rst_n)

        (current_state == NORMAL &&
         uv_flag &&
         !ov_flag &&
         !oc_flag &&
         !ot_flag &&
         !soc_high_flag &&
         adc_valid)

        |-> ##2 (current_state == CHARGE_ONLY);

    endproperty

    a_uv_charge_only:
        assert property(p_uv_charge_only);


    // 10. Low SOC leads to CHARGE_ONLY

    property p_soc_charge_only;

        @(posedge clk)

        disable iff (!rst_n)

        (current_state == NORMAL &&
         soc_low_flag &&
         !ov_flag &&
         !oc_flag &&
         !ot_flag &&
         !soc_high_flag &&
         adc_valid)

        |-> ##2 (current_state == CHARGE_ONLY);

    endproperty

    a_soc_charge_only:
        assert property(p_soc_charge_only);


    // 11. Charge and discharge never enabled in FAULT

    property p_safe_fault_outputs;

        @(posedge clk)

        disable iff (!rst_n)

        system_fault

        |->
        (!charge_enable && !discharge_enable);

    endproperty

    a_safe_fault_outputs:
        assert property(p_safe_fault_outputs);


    // 12. Cell balancing only in NORMAL state

    property p_balance_only_normal;

        @(posedge clk)

        disable iff (!rst_n)

        (balance_enable != 3'b000)

        |->
        (current_state == NORMAL &&
         !system_fault);

    endproperty

    a_balance_only_normal:
        assert property(p_balance_only_normal);


    // 13. No simultaneous charge and discharge
    // when a fault is active.

    property p_no_charge_discharge_fault;

        @(posedge clk)

        disable iff (!rst_n)

        system_fault

        |->
        !(charge_enable || discharge_enable);

    endproperty

    a_no_charge_discharge_fault:
        assert property(p_no_charge_discharge_fault);


    // FUNCTIONAL COVERAGE

    covergroup bms_coverage @(posedge clk);

        // FSM state coverage

        cp_state: coverpoint current_state {

            bins init_state = {INIT};

            bins normal_state = {NORMAL};

            bins charge_only_state = {CHARGE_ONLY};

            bins fault_state = {FAULT};

            bins init_to_normal =
                (INIT => NORMAL);

            bins normal_to_charge =
                (NORMAL => CHARGE_ONLY);

            bins normal_to_fault =
                (NORMAL => FAULT);

            bins charge_to_normal =
                (CHARGE_ONLY => NORMAL);

            bins charge_to_fault =
                (CHARGE_ONLY => FAULT);

        }


        // Individual fault coverage

        cp_ov: coverpoint ov_flag {

            bins no_ov = {0};

            bins ov_detected = {1};

        }


        cp_uv: coverpoint uv_flag {

            bins no_uv = {0};

            bins uv_detected = {1};

        }


        cp_oc: coverpoint oc_flag {

            bins no_oc = {0};

            bins oc_detected = {1};

        }


        cp_ot: coverpoint ot_flag {

            bins no_ot = {0};

            bins ot_detected = {1};

        }


        cp_low_soc: coverpoint soc_low_flag {

            bins normal_soc = {0};

            bins low_soc = {1};

        }


        cp_high_soc: coverpoint soc_high_flag {

            bins normal_high_soc = {0};

            bins high_soc = {1};

        }


        cp_sensor: coverpoint sensor_fault {

            bins valid_sensor = {0};

            bins invalid_sensor = {1};

        }


        // Cell voltage coverage

        cp_cell1: coverpoint cell1_adc {

            bins undervoltage =
                {[0:UV_LIMIT]};

            bins normal_voltage =
                {[UV_LIMIT+1:OV_LIMIT-1]};

            bins overvoltage =
                {[OV_LIMIT:4095]};

        }


        cp_cell2: coverpoint cell2_adc {

            bins undervoltage =
                {[0:UV_LIMIT]};

            bins normal_voltage =
                {[UV_LIMIT+1:OV_LIMIT-1]};

            bins overvoltage =
                {[OV_LIMIT:4095]};

        }


        cp_cell3: coverpoint cell3_adc {

            bins undervoltage =
                {[0:UV_LIMIT]};

            bins normal_voltage =
                {[UV_LIMIT+1:OV_LIMIT-1]};

            bins overvoltage =
                {[OV_LIMIT:4095]};

        }


        // Current coverage

        cp_current: coverpoint current_adc {

            bins normal_current =
                {[0:OC_LIMIT-1]};

            bins overcurrent =
                {[OC_LIMIT:4095]};

        }


        // Temperature coverage

        cp_temperature: coverpoint temp_adc {

            bins normal_temperature =
                {[0:OT_LIMIT-1]};

            bins overtemperature =
                {[OT_LIMIT:4095]};

        }


        // SOC coverage

        cp_soc: coverpoint soc_percent {

            bins low =
                {[0:SOC_LOW_LIMIT]};

            bins normal =
                {[SOC_LOW_LIMIT+1:SOC_HIGH_LIMIT-1]};

            bins high =
                {[SOC_HIGH_LIMIT:255]};

        }


        // ADC validity coverage

        cp_adc_valid: coverpoint adc_valid {

            bins valid = {1};

            bins invalid = {0};

        }


        // Output coverage

        cp_outputs: coverpoint {
            charge_enable,
            discharge_enable,
            system_fault
        } {

            bins normal = {3'b110};

            bins charge_only = {3'b100};

            bins fault = {3'b001};

            bins init = {3'b000};

        }


        // Fault combination cross coverage

        fault_cross: cross cp_ov, cp_uv, cp_oc,
                          cp_ot, cp_low_soc,
                          cp_high_soc;

        // Cell voltage cross coverage

        cell_cross: cross cp_cell1, cp_cell2, cp_cell3;

    endgroup


    bms_coverage coverage = new();


    // FINAL COVERAGE REPORT

    final begin

        $display("\n");
        $display("FUNCTIONAL COVERAGE REPORT");

        $display("Overall coverage = %0.2f%%",
                 coverage.get_coverage());


    end

endmodule
