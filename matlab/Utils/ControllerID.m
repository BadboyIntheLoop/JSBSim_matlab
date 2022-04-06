classdef ControllerID < int8
	enumeration 
		ALR_P 				  (0)  %< Aileron from P (angular velocity in X axis)
		ELV_Q 				  (1)  %< Elevator from Q (angular velocity in Y axis)
		RDR_R 			      (2)  %< Rudder from R (angular velocity in Z axis)
		RDR_YACC              (3)  %< Rudder from Yacc
		THR_SPEED 			  (4)  %< Throttle from Airspeed
		THR_ALT			 	  (5)  %< Throttle from Altitude
		THR_ALT_2STATE  	  (6)  %< Throttle from Altitude (2 state with histeresis)
		BTFLY_ALT_2STATE 	  (7)  %< Butterfly from Altitude (2 state with histeresis)
		FLP_SPEED			  (8)  %< Flaps From Airspeed
		ABR_GPERR			  (9)  %< Airbrakes from Glide Path Error
		FALR_ALR			  (10) %< Flaps As Aileron from Ailerons
		P_PHI				  (11) %< Angular velocity in X axis from Phi (roll)
		Q_THETA				  (12) %< Angular velocity in Y axis from Theta (pitch)
		R_PSI   			  (13) %< Angular velocity in Z axis from Psi (yaw)
		R_COORDEXP			  (14) %< Angular velocity in Z axis from  calculated value of turn coordination
		R_TRACK			      (15) %< Angular velocity in Z axis from track deviation.
		THETA_ALT			  (16) %< Theta from Altitude
		THETA_SPEED			  (17) %< Theta from Speed
		PHI_TRACK			  (18) %< Phi from Track - Angle roll from track deviation.
		PHI_CTRACK			  (19) %< Phi from CTrack - Angle roll from track deviation in circle.
		PHI_PSI				  (20) %< Phi from Psi - Angle roll from  from Psi error
		TRACK_TRACKCORR		  (21) %< Track from CrossTrack Error - track angle from track deviation
		TRACK_WPT			  (22) %< Track from Waypoint - track angle from angle to waypoint
		TRACKCORR_CTE		  (23) %< Track angle correction from desire track.
		BTFLY_GPATH_2STATE    (24) %< The flap setting in Butterfly from GlidePath
		THETA_GPATH_2STATE    (25) %< Theta in Butterfly from GlidePath
        THETA_VERTSPEED       (26)
		VERTSPEED_ALT         (27) 
		L1_PHI       		  (28) %< L1 Controller
		TECS       			  (29) %< TECS_THR_SPEED & TECS_THETA_ALT
	end
end
