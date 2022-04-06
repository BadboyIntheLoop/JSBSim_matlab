classdef PidParamsSet < handle
    properties
        Alr_P PidParams; Elv_Q PidParams; Rdr_R PidParams; Rdr_Yacc PidParams;
        Thr_Speed PidParams; Thr_Alt PidParams; Thr_Alt_2State PidParams;
        Btfly_Alt_2State PidParams; Flp_Speed PidParams; Abr_GPErr PidParams;
        FAlr_Alr PidParams; P_Phi PidParams; Q_Theta PidParams; R_Psi PidParams;
        R_CoordExp PidParams; R_Track PidParams; Theta_Alt PidParams; Theta_Speed PidParams;
        Phi_Track PidParams; Phi_CTrack PidParams; Phi_Psi PidParams; Track_TrackCorr PidParams;
        Track_Wpt PidParams; TrackCorr_Cte PidParams; ThrTheta_TECS PidParams;
        Btfly_GPath_2State PidParams; Theta_GPath_2State PidParams; 
        Theta_VertSpeed PidParams; VertSpeed_Alt PidParams;
    end
    methods
        function obj = PidParamsSet()
            obj.setDefault()
        end 
        function setDefault(obj)
            obj.Alr_P = PidParams();
            obj.Elv_Q = PidParams();
            obj.Rdr_R = PidParams();
            obj.Rdr_R = PidParams();
            obj.Rdr_Yacc = PidParams();
            obj.Thr_Speed = PidParams();
            obj.Thr_Alt = PidParams();
            obj.Thr_Alt_2State = PidParams();
            obj.Btfly_Alt_2State = PidParams();
            obj.Flp_Speed = PidParams();
            obj.Abr_GPErr = PidParams();
            obj.FAlr_Alr = PidParams();
            obj.P_Phi = PidParams();
            obj.Q_Theta = PidParams();
            obj.R_Psi = PidParams();
            obj.R_CoordExp = PidParams();
            obj.R_Track = PidParams();
            obj.Theta_Alt = PidParams();
            obj.Theta_Speed = PidParams();
            obj.Phi_Track = PidParams();
            obj.Phi_CTrack = PidParams();
            obj.Phi_Psi = PidParams();
            obj.Track_TrackCorr = PidParams();
            obj.Track_Wpt = PidParams();
            obj.TrackCorr_Cte = PidParams();
            obj.ThrTheta_TECS = PidParams();
            obj.Btfly_GPath_2State = PidParams();
            obj.Theta_VertSpeed = PidParams();
            obj.VertSpeed_Alt = PidParams();
        end
    end
end