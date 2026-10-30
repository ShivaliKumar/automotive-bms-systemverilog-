
module bms_monitor #(
    parameter logic [11:0] OV_LIMIT       = 12'd3800,
    parameter logic [11:0] UV_LIMIT       = 12'd2500,
    parameter logic [11:0] UV_RECOVERY    = 12'd2600,

    parameter logic [11:0] OC_LIMIT       = 12'd3500,

    parameter logic [11:0] OT_LIMIT       = 12'd3000,

    parameter logic [7:0]  SOC_LOW_LIMIT  = 8'd10,
    parameter logic [7:0]  SOC_LOW_REC    = 8'd15,
    parameter logic [7:0]  SOC_HIGH_LIMIT = 8'd95
)(
    input  logic [11:0] cell1_adc,
    input  logic [11:0] cell2_adc,
    input  logic [11:0] cell3_adc,

    input  logic [11:0] current_adc,
    input  logic [11:0] temp_adc,

    input  logic [7:0] soc_percent,

    input  logic adc_valid,

    output logic ov_flag,
    output logic uv_flag,
    output logic oc_flag,
    output logic ot_flag,

    output logic soc_low_flag,
    output logic soc_high_flag,

    output logic sensor_fault
);

    // VOLTAGE MONITORING

    always_comb begin

        ov_flag = 1'b0;
        uv_flag = 1'b0;

        if (adc_valid) begin

            ov_flag =
                (cell1_adc >= OV_LIMIT) ||
                (cell2_adc >= OV_LIMIT) ||
                (cell3_adc >= OV_LIMIT);

            uv_flag =
                (cell1_adc <= UV_LIMIT) ||
                (cell2_adc <= UV_LIMIT) ||
                (cell3_adc <= UV_LIMIT);

        end

    end

    // CURRENT MONITORING

    always_comb begin

        oc_flag = 1'b0;

        if (adc_valid)
            oc_flag = (current_adc >= OC_LIMIT);

    end

    // TEMPERATURE MONITORING
  
    always_comb begin

        ot_flag = 1'b0;

        if (adc_valid)
            ot_flag = (temp_adc >= OT_LIMIT);

    end


    // STATE OF CHARGE MONITORING
  
    always_comb begin

        soc_low_flag = 1'b0;
        soc_high_flag = 1'b0;

        if (adc_valid) begin

            soc_low_flag =
                (soc_percent <= SOC_LOW_LIMIT);

            soc_high_flag =
                (soc_percent >= SOC_HIGH_LIMIT);

        end

    end


    // SENSOR VALIDITY

    always_comb begin

        sensor_fault = !adc_valid;

    end

endmodule



module bms_dut #(

    parameter logic [11:0] OV_LIMIT       = 12'd3800,
    parameter logic [11:0] UV_LIMIT       = 12'd2500,
    parameter logic [11:0] UV_RECOVERY    = 12'd2600,

    parameter logic [11:0] OC_LIMIT       = 12'd3500,

    parameter logic [11:0] OT_LIMIT       = 12'd3000,

    parameter logic [7:0] SOC_LOW_LIMIT  = 8'd10,
    parameter logic [7:0] SOC_LOW_REC    = 8'd15,
    parameter logic [7:0] SOC_HIGH_LIMIT = 8'd95,

    parameter logic [11:0] BALANCE_START = 12'd3200,
    parameter logic [11:0] BALANCE_DELTA = 12'd50

)(
    input logic clk,
    input logic rst_n,

    // 12-bit ADC inputs
    input logic [11:0] cell1_adc,
    input logic [11:0] cell2_adc,
    input logic [11:0] cell3_adc,

    input logic [11:0] current_adc,
    input logic [11:0] temp_adc,

    // SOC estimator output
    input logic [7:0] soc_percent,

    // ADC validity signal
    input logic adc_valid,

    // Control outputs
    output logic charge_enable,
    output logic discharge_enable,

    output logic system_fault,

    output logic [2:0] balance_enable,

    // Fault flags
    output logic ov_flag,
    output logic uv_flag,
    output logic oc_flag,
    output logic ot_flag,

    output logic soc_low_flag,
    output logic soc_high_flag,

    output logic sensor_fault,

    // FSM state visibility for verification
    output logic [1:0] current_state

);

    // FSM ENCODING-

    localparam logic [1:0] INIT        = 2'b00;
    localparam logic [1:0] NORMAL      = 2'b01;
    localparam logic [1:0] CHARGE_ONLY = 2'b10;
    localparam logic [1:0] FAULT       = 2'b11;

    logic [1:0] next_state;


    // FAULT MONITOR INSTANTIATION

    bms_monitor #(

        .OV_LIMIT(OV_LIMIT),
        .UV_LIMIT(UV_LIMIT),
        .UV_RECOVERY(UV_RECOVERY),
        .OC_LIMIT(OC_LIMIT),
        .OT_LIMIT(OT_LIMIT),

        .SOC_LOW_LIMIT(SOC_LOW_LIMIT),
        .SOC_LOW_REC(SOC_LOW_REC),
        .SOC_HIGH_LIMIT(SOC_HIGH_LIMIT)

    ) monitor_inst (

        .cell1_adc(cell1_adc),
        .cell2_adc(cell2_adc),
        .cell3_adc(cell3_adc),

        .current_adc(current_adc),
        .temp_adc(temp_adc),

        .soc_percent(soc_percent),
        .adc_valid(adc_valid),

        .ov_flag(ov_flag),
        .uv_flag(uv_flag),
        .oc_flag(oc_flag),
        .ot_flag(ot_flag),

        .soc_low_flag(soc_low_flag),
        .soc_high_flag(soc_high_flag),

        .sensor_fault(sensor_fault)

    );


    // HYSTERESIS RECOVERY CONDITIONS

    logic uv_active;
    logic soc_low_active;

    logic uv_recovered;
    logic soc_recovered;

    assign uv_recovered =
        (cell1_adc > UV_RECOVERY) &&
        (cell2_adc > UV_RECOVERY) &&
        (cell3_adc > UV_RECOVERY);

    assign soc_recovered =
        (soc_percent > SOC_LOW_REC);


    // Track undervoltage until recovery threshold
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n)
            uv_active <= 1'b0;

        else if (!adc_valid)
            uv_active <= uv_active;

        else if (uv_flag)
            uv_active <= 1'b1;

        else if (uv_recovered)
            uv_active <= 1'b0;

    end


    // Track low SOC until recovery threshold
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n)
            soc_low_active <= 1'b0;

        else if (!adc_valid)
            soc_low_active <= soc_low_active;

        else if (soc_low_flag)
            soc_low_active <= 1'b1;

        else if (soc_recovered)
            soc_low_active <= 1'b0;

    end


    // FAULT DETECTION
  
    logic critical_fault;

    assign critical_fault =
        ov_flag       ||
        oc_flag       ||
        ot_flag       ||
        soc_high_flag ||
        sensor_fault;


    // NEXT STATE LOGIC

    always_comb begin

        next_state = current_state;

        case (current_state)

            INIT: begin

                if (critical_fault)
                    next_state = FAULT;

                else if (uv_active || soc_low_active)
                    next_state = CHARGE_ONLY;

                else if (adc_valid)
                    next_state = NORMAL;

                else
                    next_state = INIT;

            end


            NORMAL: begin

                if (critical_fault)
                    next_state = FAULT;

                else if (uv_active || soc_low_active)
                    next_state = CHARGE_ONLY;

                else
                    next_state = NORMAL;

            end


            CHARGE_ONLY: begin

                if (critical_fault)
                    next_state = FAULT;

                else if (!(uv_active || soc_low_active))
                    next_state = NORMAL;

                else
                    next_state = CHARGE_ONLY;

            end


            FAULT: begin

                // Fault remains latched until reset
                next_state = FAULT;

            end


            default: begin

                next_state = INIT;

            end

        endcase

    end


    // SEQUENTIAL FSM

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n)
            current_state <= INIT;

        else
            current_state <= next_state;

    end


    // OUTPUT DECODING

    always_comb begin

        charge_enable    = 1'b0;
        discharge_enable = 1'b0;
        system_fault     = 1'b0;

        case (current_state)

            INIT: begin

                charge_enable    = 1'b0;
                discharge_enable = 1'b0;
                system_fault     = 1'b0;

            end


            NORMAL: begin

                charge_enable    = 1'b1;
                discharge_enable = 1'b1;
                system_fault     = 1'b0;

            end


            CHARGE_ONLY: begin

                charge_enable    = 1'b1;
                discharge_enable = 1'b0;
                system_fault     = 1'b0;

            end


            FAULT: begin

                charge_enable    = 1'b0;
                discharge_enable = 1'b0;
                system_fault     = 1'b1;

            end


            default: begin

                charge_enable    = 1'b0;
                discharge_enable = 1'b0;
                system_fault     = 1'b1;

            end

        endcase

    end


    // CELL BALANCING

    logic [11:0] max_cell;
    logic [11:0] min_cell;

    always_comb begin

        max_cell = cell1_adc;
        min_cell = cell1_adc;

        if (cell2_adc > max_cell)
            max_cell = cell2_adc;

        if (cell3_adc > max_cell)
            max_cell = cell3_adc;

        if (cell2_adc < min_cell)
            min_cell = cell2_adc;

        if (cell3_adc < min_cell)
            min_cell = cell3_adc;

    end


    always_comb begin

        balance_enable = 3'b000;

        if ((current_state == NORMAL) &&
            adc_valid &&
            !critical_fault &&
            !uv_active &&
            !soc_low_active &&
            ((max_cell - min_cell) >= BALANCE_DELTA)) begin

            balance_enable[0] =
                (cell1_adc >= BALANCE_START) &&
                ((max_cell - cell1_adc) <=
                 (max_cell - min_cell - BALANCE_DELTA));

            balance_enable[1] =
                (cell2_adc >= BALANCE_START) &&
                ((max_cell - cell2_adc) <=
                 (max_cell - min_cell - BALANCE_DELTA));

            balance_enable[2] =
                (cell3_adc >= BALANCE_START) &&
                ((max_cell - cell3_adc) <=
                 (max_cell - min_cell - BALANCE_DELTA));

        end

    end

endmodule
