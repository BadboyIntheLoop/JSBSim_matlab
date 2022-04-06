classdef Pid < handle
%{
*                                                                   
* @class Pid                                                                 
*                                                                   
* @brief Class describing PID controller.
*
* Each of the controller could work in two modes:
* 
* --- NORMAL_PID_MODE---
*
* Normal mode of the controller:
* of transmittance: 
*
*            G(s)=K[1 + 1/(Ti*s) + Td*s])
*
* with extensions:
*   
*    1. "Clean" transmittance part D (K*Td*s) was replaced with:
*        D(s) = K*Td*s/(1 + s*Td/N)]  (usually N=8-20, default N=10)
*       
*    2. "Back Calculation" - protection against saturation integrator
*      (anti windup).  Constant Tt determines the integrator reset time;
*       when Tt=0 =>antiwindup turned off. 
*      Should be fulfilled relation:
*         Td < Tt < Ti, typowo: Tt=sqrt(Td*Ti)
*       Modification: exclusion of part D of the updates of the integral
*
*   3. "Setpoint Weighting" - to decide whether we are operating on errors or on the same values​​. 
*       This applies regardless of the proportional component and the differential (Integral part always an error):
*
*          eP = wP*Vref - wX*V,  eD = wD*Vref - V
*
*       Typically assumed that wP=1 (although sometimes wP<1) and wD=0.
*       Often wD = 1 for regulators control servos. Setpoint Weighing is off when wP = wD = 1; 
*       wX setting to 0 allows you to override the controller (default wX = 1)
*
*   4 For controllers servo control is modified gain 
*        Proportional to the square of the velocity (the ratio is given as a parameter):
*           K = Kp * Kas, (Kas is from upper limited)
*   5. "Slew rate" to reference value (maximum change of reference value / 1 sek.)
*   6. Limitation the value of the integral Imin, Imax (note: the value of 0.0f means no limit)   
* Final formula:
*
*    P(k)   = K * eP(k)                 
*    I(k+1) = I(k) + K*Ts/Ti*e(k) + Ts/Tt*(u(k)-(v(k)-D(k)))      // e = Vref - V
*    D(k)   = Td * [D(k-1) + N*K*(eD(k)-eD(k-1))] / (Ts*N + Td);
*
*    v = P + I + D
*    u = sat(v)   // cutoff (saturation)
*
* The values ​​saved in the following steps are: D(k-1), eD(k-1), I(k), Vref(k-1)
*
* --- TWO_STATE_PID_MODE ---
*
* bistable mode with hysteresis, with a possible inverse min-max 
*
%}
    properties (Access = private)
        MIN_TS = 0.001;
        MAX_TS = 2.0;
        DEFAULT_MAX_KAS = 4.0;
    end 
    properties
        pid_CtrlID = ControllerID.ALR_P;
        pid_state PidState;
        pid_mode = PidMode.NORMAL_PID;
        pid_param PidParams;
        pid_modifier PidModifierBase;
        pid_cp ControllerProperties;
    end
    methods 
        %% Constructor
        function obj = Pid(CtrlID, cp, state, param, modePID, modifier)
            obj.pid_CtrlID = CtrlID;
            obj.pid_state = state;
            obj.pid_mode = modePID;
            obj.pid_param = param;
            obj.pid_modifier = modifier;
            obj.pid_cp = cp;
        end
        %% Clear States
        function obj = clearState(obj)
            obj.pid_state.eD_1 = 0;
            obj.pid_state.D_1 = 0;
            obj.pid_state.I = 0;
            obj.pid_state.ref_1 = 0;
            obj.pid_state.output_1 = obj.pid_cp.minValue;
            obj.pid_state.output_1m = obj.pid_cp.minValue;
            obj.pid_state.timeout = false;
            obj.pid_state.computed = false;
        end
        %% Computed PID
        function y = compute(obj, time100, in, ref, out, Kas)
            % output must be passed by reference 
            % To do that we set out as an output of function compute
            % After that, we pass it to variable of handle object
            obj.pid_state.computed = false;
            if (~obj.pid_cp.enable)
                return 
            end
            if (~obj.pid_state.enable)
                obj.pid_state.enable = true;
                obj.pid_state.time100_1 = time100;
                obj.clearState();
                obj.pid_state.output_1 = out;
                obj.pid_state.output_1m = out;
                obj.pid_state.I = out;
                obj.pid_state.ref_1 = in;
                y = [false; out];
                return;
            end
            % time100 is (centi-seconds) current time; 
            % Check timeout 
            Ts = (time100 - time100_1)*1e-4;
            if (Ts > obj.MAX_TS)
                fprintf('Invoking time out!!! \n');
                obj.pid_state.timeout = true;
                y = [false; out];
                return
            end
            bank = obj.pid_param.bank(obj.pid_cp.num_bank);
            
            switch obj.pid_mode 
                case PidMode.NORMAL_PID
                    if (Kas > obj.pid_param.maxKas)
                        Kas = obj.pid_param.maxKas;
                    end
                    sRefTs = bank.sRef * Ts;
                    % part P
                    eP = bank.wP*ref - bank.wX*in;
                    P = bank.Kp * Kas * eP;
                    % part I
                    if (bank.Ti ~= 0)
                        I = obj.pid_state.I;
                        if (I > bank.Imax)
                            I = Imax;
                        elseif (I < bank.Imin)
                            I = Imin;
                        end
                    else
                        I = 0;
                    end
                    % part D
                    eD = bank.wD * ref - in;
                    if (bank.Td == 0)
                        D = bank.Td*(obj.pid_state.D_1 +...
                         bank.N*bank.Kp*Kas*(eD-obj.pid_state.eD_1))/(Ts*bank.N+bank.Td);
                    end
                    D = (D + obj.pid_state.D_1)/2;
                    v = P+I+D;

                    % Saturation 
                    if(v > obj.pid_cp.maxValue)
                        out = obj.pid_cp.maxValue;
                    elseif (v < obj.pid_cp.minValue)
                        out = obj.pid_cp.minValue;
                    else
                        out = v;
                    end

                    % part I for next step 
                    if (bank.Ti ~= 0)
                        I = I + bank.Kp*Kas*Ts/bank.Ti*(ref-in);
                        if (I > bank.Imax)
                            I = Imax;
                        elseif (I < bank.Imin)
                            I = Imin;
                        end
                        % anti-windup
                        if ((bank.Tt~=0) && (v~=out))
                            I = I + Kas*Ts/bank.Tt*(out-(v-Ds));
                        end
                    end
                    % slew rate on output value
                    sOutTs = bank.sOut*Ts;
                    if(bank.sOut~=0)
                        if((out-bank.output_1) > sOutTs)
                            out = obj.pid_state.output_1 + sOutTs;
                        elseif ((out-bank.output_1) < -sOutTs)
                            out = obj.pid_state.output_1 - sOutTs; 
                        end
                    end

                    % Save previous data for nextstep
                    obj.pid_state.eD_1 = eD;
                    obj.pid_state.D_1 = D;
                    obj.pid_state.I = I;
                    obj.pid_state.ref_1 = ref;
                    obj.pid_state.output_1 = out;
                    obj.pid_state.time100_1 = time100;
                    % Output function
                    obj.pid_state.computed = true;
                    y = [obj.pid_state.computed; out];
                % Two states controller
                case PidMode.STATE_2H
                    out = obj.pid_state.output_1m;
                    if(~obj.pid_cp.invMargins)
                        if(in > (ref+obj.pid_cp.marginHigh))
                            out = obj.pid_cp.minValue;
                        end
                        if(in < (ref+obj.pid_cp.marginHigh))
                            out = obj.pid_cp.maxValue;
                        end
                    else
                        if(in > (ref+obj.pid_cp.marginHigh))
                            out = obj.pid_cp.maxValue;
                        end
                        if(in < (ref+obj.pid_cp.marginHigh))
                            out = obj.pid_cp.minValue;
                        end
                    end
                    % Save previous data for nextstep
                    obj.pid_state.output_1 = out;
                    obj.pid_state.time100_1 = time100;
                    % Output function
                    obj.pid_state.computed = true;
                    y = [obj.pid_state.computed; out];
                case PidMode.MULTI_STEP
                    y = [false, out];
                otherwise 
                    fprintf('Controller Mode Error! \n');
            end

        end
    end
end