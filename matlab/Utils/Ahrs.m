classdef Ahrs < handle
	properties
		%% struct contains data caculated by AHRS module
		% use ahrs date in AP
		p double;
		q double;
		r double;
		phi  double;
		theta  double;
		psi  double;
		phiDot  double;
		thetaDot  double;
		psiDot double;
		ahrsUpdateFlag int8;
		incdError double;
		gaugeCyclesPerSecond
		% Dec & Inc in Magnetometer
		Declination double;
		Pi_2minusInclination double;
		accXlinUpdate;
	end

	properties(Access = private)
		BMAG_UPDATE = true;
		magValid int8;

		AXIS_X=0;
		AXIS_Y=1;
		AXIS_Z=2; 
		AXIS_NB=3;

	    AXIS_P=0; 
	    AXIS_Q=1;
	    AXIS_R=2;

	    UPDATE_PHI=0;
	    UPDATE_THETA=1;
	    UPDATE_PSI=2;
	    UPDATE_NB=3;

	    AHRS_R_PHI = 1.7*1.7;
	    AHRS_R_THETA = 1.3*1.3;
	    AHRS_R_PSI = 2.5*2.5;
	    AHRS_DT = 1/100;

		KF_CR_ALT = 0.0722; % 0.2267
		KF_CR_CR = 0.05627; % 0.04097
		KF_CR_BIAS = -0.0202; % -0.01728

		KF_GPS_X = -0.2438564;
		KF_GPS_VX = 0.323019;
		KF_GPS_BX = 0.28472529;

		% struct Kalman Filter
		f32Speed double;
		f32Distance double;
		f32Bias double;

		f32EstAlt double;
		f32EstDeltaAlt double;
		f32EstVertSpeed double;

		% AHRS other
		ahrs_Q_gyro;

		%% struct contains AHRS States ahrs_stateT
		% Quaternion state and gyro bias
		ahrs_q0;
		ahrs_q1;
		ahrs_q2;
		ahrs_q3;
		ahrs_bias_p;
		ahrs_bias_q;
		ahrs_bias_r;
		% unbiased rates
		ahrs_p;
		ahrs_q;
		ahrs_r;
		% euler angle
		ahrs_phi;
		ahrs_theta;
		ahrs_psi;
		ahrs_phiDot;
		ahrs_thetaDot;
		ahrs_psiDot;
		% derivative of quaternion 
		ahrs_q0_dot;
		ahrs_q1_dot;
		ahrs_q2_dot;
		ahrs_q3_dot;
		dt;
		% Direction cosine matrix
		ahrs_dcm (3,3) double;
		% Covariance matrix and covarianc matrix derivative
		ahrs_P (7,7) double;
		ahrs_Phik (7,7) double;
		ahrs_Qdk (7,7) double;
		% Kalman Filter
		ahrs_PHt (7,1) double;
		ahrs_K (7,1) double;
		ahrs_E;
		ahrs_H (4,1) double;
		% Airspeed and previous ones
		airspeed_1 double;
		airspeed_2 double;
		airspeedHistory (3,1);
		airspeedDivider double;
		updateSelector;
		lockUpdateCounter;
		% Vertical speed
		% vertSpeedKF = [VSf32Alt; VSf32BiasAccZ; VSf32VertSpeed]
		vertSpeedKF (3,1);
		velX double;
		velY double;
		accelX double;
		accelY double;
	end

	methods
		% Constructor
		function obj = Ahrs()
		end
		% Compute DCM from quaternion
		function obj = Ahrs_dcm_of_quat(obj)
			obj.ahrs_dcm = [1-2*(obj.ahrs_q2^2+obj.ahrs_q3^2) 2*(obj.ahrs_q1*obj.ahrs_q2-obj.ahrs_q0*obj.ahrs_q3) 2*(obj.ahrs_q0*obj.ahrs_q2+obj.ahrs_q1*obj.ahrs_q3);...
							2*(obj.ahrs_q0*obj.ahrs_q3+obj.ahrs_q1*obj.ahrs_q2) 1-2*(obj.ahrs_q1^2+obj.ahrs_q3^2) 2*(obj.ahrs_q2*obj.ahrs_q3-obj.ahrs_q0*obj.ahrs_q1);...
							2*(obj.ahrs_q1*obj.ahrs_q3-obj.ahrs_q0*obj.ahrs_q2) 2*(obj.ahrs_q0*obj.ahrs_q1+obj.ahrs_q2*obj.ahrs_q3) 1-2*(obj.ahrs_q1^2+obj.ahrs_q2^2)];
        end
        % Compute Euler angles from DCM
        function obj = Ahrs_euler_of_dcm(obj)
        	% ahrs_phi
        	obj.ahrs_phi = atan2(obj.ahrs_dcm(3,2), obj.ahrs_dcm(3,3));
        	% ahrs_theta
            if (abs(obj.ahrs_theta) < 1)
                obj.ahrs_theta = -asin(obj.ahrs_dcm(3,1));
            else
                if(obj.ahrs_dcm(3,1) > 0)
                	obj.ahrs_theta = -pi/2;
                else 
                	obj.ahrs_theta = pi/2;
                end
            end
        	% ahrs_psi
        	obj.ahrs_psi = atan2(obj.ahrs_dcm(2,1), obj.ahrs_dcm(1,1));
        end
        % Compute H _ phi,theta,psi
        function obj = Ahrs_compute_H_phi(obj)
			phi_err = obj.ahrs_dcm(3,3)^2 + obj.ahrs_dcm(3,2)^2;    
			if (phi_err ~= 0.0)
			    phi_err = 2.0 / phi_err; 
			    obj.ahrs_H = [(obj.ahrs_q1 * obj.ahrs_dcm(3,3)) * phi_err;...				        
			                    (obj.ahrs_q0 * obj.ahrs_dcm(3,3) + 2.0 * obj.ahrs_q1 * obj.ahrs_dcm(3,2)) * phi_err;...	        
			                    (obj.ahrs_q3 * obj.ahrs_dcm(3,3) + 2.0 * obj.ahrs_q2 * obj.ahrs_dcm(3,2)) * phi_err;...	        
			                    (obj.ahrs_q2 * obj.ahrs_dcm(3,3)) * phi_err];
			end
		end
		function obj = Ahrs_compute_H_theta(obj)
			theta_err  =  1.0 - obj.ahrs_dcm(3,1) * obj.ahrs_dcm(3,1);
			if (theta_err > 0.0)
			    theta_err = sqrt(theta_err);
			    theta_err = 2.0 / theta_err; 

			    obj.ahrs_H = [ obj.ahrs_q2 * theta_err;...						
			                  -obj.ahrs_q3 * theta_err;...						
			                   obj.ahrs_q0 * theta_err;...						
			                  -obj.ahrs_q1 * theta_err];
			end
		end
		function obj = Ahrs_compute_H_psi(obj)
			psi_err = (obj.ahrs_dcm(1,1)^2 + obj.ahrs_dcm(2,1)^2);
			if (psi_err ~= 0.0)
			    psi_err = 2.0 / psi_err;
			    obj.ahrs_H = [(obj.ahrs_q3 * obj.ahrs_dcm(1,1)) * psi_err;...
			                    (obj.ahrs_q2 * obj.ahrs_dcm(1,1)) * psi_err;...
			                    (obj.ahrs_q1 * obj.ahrs_dcm(1,1) + 2 * obj.ahrs_q2 * obj.ahrs_dcm(2,1)) * psi_err;...
			                    (obj.ahrs_q0 * obj.ahrs_dcm(1,1) + 2 * obj.ahrs_q3 * obj.ahrs_dcm(2,1)) * psi_err];
			end
		end
        % Compute quaternion from Euler angles
        function obj = Ahrs_quat_of_euler(obj)
        	sinphi_2 = sin(obj.ahrs_phi/2); cosphi_2 = cos(obj.ahrs_phi/2);
        	sintheta_2 = sin(obj.ahrs_theta/2); costheta_2 = cos(obj.ahrs_theta/2);
        	sinpsi_2 = sin(obj.ahrs_psi/2); cospsi_2 = cos(obj.ahrs_psi/2);
        	
        	obj.ahrs_q0 =  cosphi_2*costheta_2*cospsi_2 + sinphi_2*sintheta_2*sinpsi_2; 
        	obj.ahrs_q1 = -cosphi_2*sintheta_2*sinpsi_2 + sinphi_2*costheta_2*cospsi_2; 
        	obj.ahrs_q2 =  cosphi_2*sintheta_2*cospsi_2 + sinphi_2*costheta_2*sinpsi_2; 
        	obj.ahrs_q3 = -sinphi_2*sintheta_2*cospsi_2 + cosphi_2*costheta_2*sinpsi_2; 
        end
        % Normalize quaternion 
        function obj = Ahrs_norm_quat(obj)
        	mag = obj.ahrs_q0^2 + obj.ahrs_q1^2 + obj.ahrs_q2^2 + obj.ahrs_q3^2;
        	if (mag > 0)
        		obj.ahrs_q0 = obj.ahrs_q0/sqrt(mag);
        		obj.ahrs_q0 = obj.ahrs_q0/sqrt(mag);
		        obj.ahrs_q0 = obj.ahrs_q0/sqrt(mag);
		        obj.ahrs_q0 = obj.ahrs_q0/sqrt(mag);
            end
		end
		% Warp value
		function x = Ahrs_warp(obj, xx, b)
			while (xx < -b)
				xx = xx + (2*b);
			end
			while (xx > b)
				xx = xx - (2*b);
			end
			x = xx;
		end
		%% 
		%{
		 * Call ahrs_state_update every dt seconds with the raw body frame angular
		 * rates.  It updates the attitude state estimate via this function:
		 *
		 *      quat_dot = Wxq(pqr) * quat
		 *      bias_dot = 0
		 *
		 * Since F also contains Wxq, we fill it in here and then reuse the computed
		 * values.  This avoids the extra floating point math.
		 *
		 * Wxq is the quaternion omega matrix:
		 *
		 *              [ 0, -p, -q, -r ]
		 *      1/2 *   [ p,  0,  r, -q ]
		 *              [ q, -r,  0,  p ]
		 *              [ r,  q, -p,  0 ]
		 *
		 *                 [ 0  -p  -q  -r   q1  q2  q3]
		 *   F =   1/2 *   [ p   0   r  -q  -q0  q3 -q2]
		 *                 [ q  -r   0   p  -q3  q0  q1]
		 *                 [ r   q  -p   0   q2 -q1 -q0]
		 *                 [ 0   0   0   0    0   0   0]
		 *                 [ 0   0   0   0    0   0   0]
		 *                 [ 0   0   0   0    0   0   0]
		 *
		%}
		function obj = Ahrs_predict(obj, gyro)
			% Eleminate offset
			obj.ahrs_p = gyro(1) - obj.ahrs_bias_p;
			obj.ahrs_q = gyro(2) - obj.ahrs_bias_q;
			obj.ahrs_r = gyro(3) - obj.ahrs_bias_r;
			% Compute Jacobian matrix F 
			% F is only needed later on to update the state covariance P.
			ahrs_F = [0 -obj.ahrs_p -obj.ahrs_q -obj.ahrs_r obj.ahrs_q1 obj.ahrs_q2 obj.ahrs_q3;...
				 obj.ahrs_p 0 obj.ahrs_r -obj.ahrs_q -obj.ahrs_q0 obj.ahrs_q3 -obj.ahrs_q2;...
				 obj.ahrs_q -obj.ahrs_r 0 obj.ahrs_p -obj.ahrs_q3 obj.ahrs_q0 obj.ahrs_q1;...
				 obj.ahrs_r obj.ahrs_q -obj.ahrs_p 0 obj.ahrs_q2 -obj.ahrs_q1 -obj.ahrs_q0;...
				 0          0           0          0 -0.02            0            0;...
				 0          0           0          0 0            -0.02            0;...
				 0          0           0          0 0            0            -0.02]*0.5;
% 			persistent ahrs_Pk;
% 			ahrs_Pk = [1 0 0 0 0 0 0;...
% 					   0 1 0 0 0 0 0;...
% 					   0 0 1 0 0 0 0;...
% 					   0 0 0 1 0 0 0;...
% 					   0 0 0 0 .5 0 0;...
% 					   0 0 0 0 0 .5 0;...
% 					   0 0 0 0 0 0 .5];
			% Phik = F*dt + I(7)
			obj.ahrs_Phik = eye(7) + ahrs_F*obj.dt;
			quat = [obj.ahrs_q0; obj.ahrs_q1; obj.ahrs_q2; obj.ahrs_q3];
			gyro_bias = [obj.ahrs_bias_p obj.ahrs_bias_q; obj.ahrs_bias_r];
			quat = quat + (ahrs_F(1:4,1:4)*quat + ahrs_F(1:4,5:7)*gyro_bias)*obj.dt;
			obj.ahrs_q0 = quat(1); obj.ahrs_q1 = quat(2);
			obj.ahrs_q2 = quat(3); obj.ahrs_q3 = quat(4);
			obj.ahrs_bias_p = obj.ahrs_bias_p*0.99;
			obj.ahrs_bias_q = obj.ahrs_bias_q*0.99;
			obj.ahrs_bias_r = obj.ahrs_bias_r*0.99;

			% Normalize and update 
			obj.Ahrs_norm_quat();
			obj.Ahrs_dcm_of_quat();
			obj.Ahrs_euler_of_dcm();
			% update covariance
			% Pdot = F*P*F' + Q
			% P += Pdot * dt
			obj.ahrs_Qk = [zeros(4,4), zeros(4,3);...
			      zeros(4,3), diag([obj.ahrs_Q_gyro*obj.ahrs_Phik(5,5)*obj.dt ...
			      	obj.ahrs_Q_gyro*obj.ahrs_Phik(6,6)*obj.dt ...
			      	obj.ahrs_Q_gyro*obj.ahrs_Phik(7,7)*obj.dt])];
			% Update ahrs_P
			obj.ahrs_P = obj.ahrs_P + obj.ahrs_F*obj.ahrs_P*obj.ahrs_F'*obj.dt + Qk;
		end
		%{
		 * Do the Kalman filter on the acceleration and compass readings.
		 * This is normally a very simple:
		 *
		 *      E = H * P * H' + R
		 *      K = P * H' * inv(E)
		 *      P = P - K * H * P
		 *      X = X + K * error
		 *
		 * We notice that P * H' is used twice, so we can cache the
		 * results of it.
		 *
		 * H represents the Jacobian of measurements to states, which we know
		 * to only have the top four rows filled in since the attitude
		 * measurement does not relate to the gyro bias.  This allows us to
		 * ignore parts of PHt
		 *
		 * We also only process one axis at a time to avoid having to perform
		 * the 3x3 matrix inversion.
		%} 
		function obj = run_Kalman(obj, R_axis, err, active)
			ahrs_Hdif = [obj.ahrs_H; 0; 0; 0];
			obj.ahrs_E = ahrs_Hdif' * obj.ahrs_P * ahrs_Hdif + R_axis/1;
			if (obj.ahrs_E == 0)
				obj.ahrs_E = 10000;
			else
				obj.ahrs_E = 1/obj.ahrs_E;
			end
			obj.ahrs_K = obj.ahrs_P * ahrs_Hdif * obj.ahrs_E;

			obj.ahrs_P = obj.ahrs_P - obj.ahrs_K * ahrs_Hdif' * obj.ahrs_P;
			obj.ahrs_q0     = obj.ahrs_q0 + obj.ahrs_K(1) * err;
			obj.ahrs_q1     = obj.ahrs_q1 + obj.ahrs_K(2) * err;
			obj.ahrs_q2     = obj.ahrs_q2 + obj.ahrs_K(3) * err;
			obj.ahrs_q3     = obj.ahrs_q3 + obj.ahrs_K(4) * err;
			obj.ahrs_bias_p = obj.ahrs_bias_p + obj.ahrs_K(5) * err;
			obj.ahrs_bias_q = obj.ahrs_bias_q + obj.ahrs_K(6) * err;
			obj.ahrs_bias_r = obj.ahrs_bias_r + obj.ahrs_K(7) * err;
			% [obj.ahrs_bias_p, obj.ahrs_bias_q, obj.ahrs_bias_r]
			obj.Ahrs_norm_quat();
		end
		% phi/theta/psi from accel/accel/mag
		function phi_acccel = ahrs_phi_of_accel(obj, accel)
			accZ = accel(3);
		    accY = accel(2);		
		    if (accZ ~= 0.0)
		        phi_acccel = atan2(accY , -accZ);
		    else
		        if (accel(2) ~= 0.0)
		            phi_acccel = pi/2;
		        else
		            phi_acccel = 0.0;
		        end
		    end
		end
		function theta_accel = ahrs_theta_of_accel(obj, accel)
		    G = 9.80665;
		    x = accel(1) / G;
		    if (x > 1.0) 
		        x = 1.0;
		    end
		    if(x < -1.0) 
		        x = -1.0;
		    end
			theta_accel = -asin(x);	
		end
		function psi_accel = ahrs_psi_of_mag(obj, mag)
			% mag (3,1)
			ctheta  = cos( obj.ahrs_theta );
			stheta  = sin( obj.ahrs_theta );
			cphi  = cos( obj.ahrs_phi );
			sphi  = sin( obj.ahrs_phi );
			psi_accel = 0.0;

			x = ctheta * mag(1) + sphi * stheta * mag(2) + cphi * stheta * mag(3);

			y = 0 * mag(1) + cphi * mag(2) - sphi * mag (3);

			if ((x==0)&&(y<0))
			    psi_accel = pi/2;
			elseif (x==0)&&(y>0)
			    psi_accel = 1.5 * pi;
			elseif (x<0)
			    psi_accel = pi - atan(y/x);
			elseif (x>0)&&(y<0)
			    psi_accel = -atan(y/x);
			elseif (x>0)&&(y>0)
			    psi_accel = 2*pi - atan( y/x );
			end
			psi_accel = psi_accel + 3.6/180*pi;
			
            if(psi_accel > pi)
			   psi_accel = psi_accel - 2.0*pi;
            end
		end
		% PHI Update
		function obj = ahrs_update_phi(obj, accel, active, mag, magEnable)
			err_phi = 0;
			obj.Ahrs_compute_H_phi();
			accel_phi = obj.ahrs_phi_of_accel(accel);
			if (active ~= 0)
			    err_phi = accel_phi - obj.ahrs_phi;
			end
			err_phi = obj.Ahrs_warp(err_phi, pi);
			obj.run_kalman(obj.AHRS_R_PHI, err_phi, active);
			obj.Ahrs_dcm_of_quat();
			obj.Ahrs_euler_of_dcm();
		end
		% THETA update from magnetometer
		function obj = ahrs_update_theta_from_mag(obj, accel, active, mag, magEnable)
			err_theta = 0.0;

			% I = Pi_2minusInclination;
			I = obj.Pi_2minusInclination;
			w = 0.0;
			if (obj.BMAG_UPDATE)
				if((active ~= 0) && (obj.magValid ~= 0) && (magEnable==1))
				    incd = obj.incd_of_mag(obj, mag, I);
				    obj.Ahrs_compute_H_theta();
				    theta_mag = obj.theta_of_mag(obj, mag, I, w);

				    if(w==0.0)
				        err_theta = theta_mag - obj.ahrs_theta;
				        err_theta = obj.Ahrs_warp(err_theta, pi/2);
				        if(abs(incd) > 0.04)
				            obj.run_kalman(obj, 2.5*2.5 , err_theta, active);
				        else
				            obj.run_kalman(obj, 5.5*5.5 , err_theta, active);
				        end
				        obj.Ahrs_dcm_of_quat();
				        obj.Ahrs_euler_of_dcm();
				    end
				end
			end
		end
		% THETA update
		function obj = ahrs_update_theta(obj, accel, active, mag, magEnable)
			err_theta = 0;
			obj.Ahrs_compute_H_theta();
			accel_theta = obj.ahrs_theta_of_accel(accel);
			if(active ~= 0)
			    err_theta = accel_theta - obj.ahrs_theta;
			end
			err_theta = obj.Ahrs_warp(err_theta, pi/2);
			obj.run_kalman(obj, obj.AHRS_R_THETA, err_theta, active);
			obj.Ahrs_dcm_of_quat();
			obj.Ahrs_euler_of_dcm();
		end
		% PHI update from magnetometer
		function obj = ahrs_update_phi_from_mag(obj, accel, active, mag, magEnable)
			err_phi = 0;
			I = obj.Pi_2minusInclination;
			w = 0.0;
			if (obj.BMAG_UPDATE)
				if( (active ~= 0)&&(obj.magValid ~= 0)&&((magEnable == 1)||(magEnable == 2)) )
				    incd = obj.incd_of_mag(obj.ahrs_phi, obj.ahrs_theta, mag, I);
				    obj.Ahrs_compute_H_phi();
				    phi_mag = obj.phi_of_mag(obj.ahrs_phi, obj.ahrs_theta, mag, I, w);
			    	if(w==0.0)
				        err_phi = phi_mag - obj.ahrs_phi;
				        err_phi = obj.Ahrs_warp(err_phi, pi);
				        if( abs(incd)>0.04 )
				            obj.run_kalman(obj, 2.5*2.5, err_phi, active);
				        else
				            obj.run_kalman(obj, 5.5*5.5, err_phi, active);
				        end
			        end
			        obj.Ahrs_dcm_of_quat();
			        obj.Ahrs_euler_of_dcm();
			    end
			end
        end
		% PSI Update
		function obj = ahrs_update_psi(obj, psiFromHeading, active, mag, magEnable) 
			mag_psi = 0.0;
			err_psi = 0.0 ;
			incd = 0.0;

			I = obj.Pi_2minusInclination;
			D = obj.Declination;

			obj.Ahrs_compute_H_psi;
			if (~obj.BMAG_UPDATE)
				mag_psi = obj.ahrs_psi_of_mag(mag, D);
				if( active ~= 0 )
				    err_psi = mag_psi - obj.ahrs_psi;
				end
			else
				if((active ~= 0)&&(magEnable~=0))
					incd = incd_of_mag(mag, I);
					mag_psi = obj.ahrs_psi_of_mag(mag, D);
					err_psi = mag_psi - obj.ahrs_psi;
				end
					err_psi = obj.Ahrs_warp(err_psi, pi);
					obj.run_kalman(obj.AHRS_R_PSI, err_psi, active );
					obj.Ahrs_dcm_of_quat();
					obj.Ahrs_euler_of_dcm();
			end
        end
        % Get Euler form quaternion
        function euler = eulers_of_quat(obj, quat)
        	dcm11 = 1.0-2.0*(quat(3)^2 + quat(4)^2);
			dcm12 =     2.0*(quat(2)*quat(3) + quat(1)*quat(4));
			dcm13 =     2.0*(quat(2)*quat(4) - quat(1)*quat(3));
			dcm23 =     2.0*(quat(3)*quat(4) + quat(1)*quat(2));
			dcm33 = 1.0-2.0*(quat(2)^2 + quat(3)^2);
        	euler(1) = atan2(dcm23, dcm33);
			if( abs(dcm13) < 1.0)
				euler(2) = -asin( dcm02 );
			else
			    if (dcm02 > 0.0) 
			        euler(2) =  -pi/2;
			    else
			        euler(2) =  -pi/2; 
			    end
			end
			euler(3) = atan2(dcm12, dcm11);

        	euler = [euler(1); euler(2); euler(3)];
        end
        % Normalize quat 
        function quatN = norm_quat(obj, quat)
        	mag = quat(1)^2+quat(2)^2+quat(3)^2+quat(4)^2;
        	if (mag < 0)
        		mag = 100000;
        	else
        		mag = 1/sqrt(mag);
        	end
        	quatN = [quat(1); quat(2); quat(3); quat(4)]*mag;
        end
        %{
		/** 
		* Initialize the AHRS state data and covariance matrix.
		* /param gyro
		* /param accel
		* /param psiFromHeading (or mag)
		* /param airspeed
		* output: ahrsState
		*/
        %}
        function obj = ahrsInit(obj, psiFromHeading, accel, gyro, airspeed, mag)
        	obj.ahrs_P = diag([1 1 1 1 0.5 0.5 0.5]);
			obj.ahrs_bias_p = 0.0;
			obj.ahrs_bias_q = 0.0;
			obj.ahrs_bias_r = 0.0;

			obj.psiDot = 0.0;
			obj.thetaDot = 0.0;
			obj.phiDot = 0.0;
			obj.ahrsUpdateFlag = 0;

			obj.dt = obj.AHRS_DT;
			obj.dt_1 = obj.AHRS_DT;

			obj.airspeed_1 = airspeed;	
			obj.airspeed_2 = airspeed;

			obj.accXlin = 0.0;
			obj.lastAccXlin = 0.0;


			obj.ahrs_phi = obj.ahrs_phi_of_accel(accel);
			FLTMAX = 1e18+7;
			if (accel(1) < FLTMAX)
			    obj.ahrs_theta = obj.ahrs_theta_of_accel(accel);
			else
			    obj.ahrs_theta = 0.0;
			end

			if(mag(4) == 1.0)         
			       obj.ahrs_psi = obj.ahrs_psi_of_mag(mag);
			else
			       obj.ahrs_psi = 0.0;
			end

			obj.updateSelector = 0;
			obj.Ahrs_quat_of_euler();
			obj.Ahrs_dcm_of_quat();
			
			obj.p = 0.0;
			obj.q = 0.0;
			obj.r = 0.0;
			obj.phi = 0.0;
			obj.theta = 0.0;
			obj.psi = 0.0;
			obj.phiDot = 0.0;
			obj.thetaDot = 0.0;
			obj.psiDot = 0.0;
			obj.ahrsUpdateFlag = 0;
			obj.incdError = 0;
			obj.f32EstAlt = 0.0;
			obj.f32EstDeltaAlt = 0.0;
			obj.f32EstVertSpeed = 0.0;

			obj.airspeedDivider = 0;
			obj.airspeedHistory(1) = airspeed;
			obj.airspeedHistory(2) = airspeed;
			obj.airspeedHistory(3) = airspeed;	

			obj.vertSpeedKF(1) = 0.0;
			obj.vertSpeedKF(2) = 0.0;
			obj.vertSpeedKF(3) = 0.0;
		end
		% Extracts gravity part from acceleration in Quad mode
		function accel_out = ahrsAccelerometerModify(obj, gyro, accel, airSpeed)
			KPH_2_MS = 1/3.6;
			accel_out(1) = accel(1) + obj.accXlin;
			accel_out(2) = accel(2) + gyro(3) * airSpeed * KPH_2_MS;
			accel_out(3) = accel(3) + gyro(2) * airSpeed * KPH_2_MS;
			obj.airspeed_2 = obj.airspeed_1 = airSpeed;
			accel_out = [accel_out(1); accel_out(2); accel_out(3)];
		end
		% Caculate euler angle dot
		function obj = ahrsCalculateDots(obj)
			sinPhi = sin(obj.ahrs_phi);
			cosPhi = cos(obj.ahrs_phi);
			sinTheta = sin(obj.ahrs_theta);
			cosTheta = cos(obj.ahrs_theta);

			obj.thetaDot = obj.ahrs_q*cosPhi - obj.ahrs_r*sinPhi;
			if (cosTheta == 0.0)
			    obj.psiDot = 0.0;
			else
			    obj.psiDot = (obj.ahrs_q*sinPhi + obj.ahrs_r*cosPhi)/cosTheta;
			end
			obj.phiDot = obj.ahrs_p + obj.psiDot*sinTheta;
		end
		% Extracts gravity from accelerations in quad mode
		function accel_out = ahrsQuadAccelModify(obj, gyro, accel, velX, velY);
			KPH_2_MS = 1/3.6;
			accel_out(1) = accel(1) + obj.accelX + gyro(3)*obj.velY*KPH_2_MS;
			accel_out(2) = accel(2) + obj.accelY + gyro(3)*obj.velX*KPH_2_MS;
			accel_out(3) = accel(3) + gyro(2)*obj.velX*KPH_2_MS - gyro(1)*obj.velY*KPH_2_MS;
			accel_out = [accel_out(1); accel_out(2); accel_out(3)];
		end

		%% Main AHRS
		%{
		* The main AHRS function
		* /param ahrsState
		* /param gyro
		* /param accel
		* /param psiFromHeading (or mag)
		* /param airspeed
		* output: ahrsState
		%}
		function obj = ahrsCompute(obj, gyro, accel, psiFromHeading, airSpeed, mag,...
								   magEnable, flightMode, version, groundSpeed)
   			magValid = 0;
   			if (mag(4) ~= 0.0)
		    	normMag = sqrt(mag(1)^2 + mag(2)^2 + mag(3)^2);
			    if (abs(normMag-1)<1)
			        magValid = 1;
			    end
			    
			    if ( normMag > 0.0 )
			        mag(1) = mag(1)/normMag;
			        mag(2) = mag(2)/normMag;
			        mag(3) = mag(3)/normMag;
			    end
			end

			if (obj.dt == 0.0)
			    obj.dt_1 = obj.dt;
			end

			obj.Ahrs_predict(gyro);

			accX = accel(1);
			psd_theta = obj.ahrs_theta;
			psd_phi = obj.ahrs_phi;
			%------------------------------------------
			accXlinUpdate = 0;
			% if (gpsGood==0)
		    if (airSpeed > 20.0)
				accel = obj.ahrsAccelerometerModify(gyro, accel, airSpeed);
		    end
			% else
			%     if (airSpeed > 60.0) 
			%      accel = 	obj.ahrsAccelerometerModify(gyro, accel, airSpeed);
			%      accXlinUpdate = 1;
			%     else
			%      accel = obj.ahrsQuadAccelModify(gyro, accel, obj.velocityXHistory(1), obj.velocityYHistory(1));
			%     end
			% end
			%---------------------------------------
			ahrsState.ahrsUpdateFlag = 0;
			% Update phi and theta from Accelerations
			updated_phi = obj.ahrs_phi_of_accel(accel);
			updated_theta = obj.ahrs_theta_of_accel(accel);

			phiCondition = obj.checkResetUpdateCondition(psd_phi, updated_phi, obj.resetUpdatedPhiCounter, 2, 100);
			obj.resetUpdatedPhiFlag = phiCondition(1);
			obj.resetUpdatedPhiCounter = phiCondition(2);
			thetaCondition = checkResetUpdateCondition(psd_theta, updated_theta, obj.resetUpdatedPhiCounter, 2, 100);
			ahrsState.resetUpdateThetaFlag = thetaCondition(1);
			ahrsState.resetUpdatedPhiCounter = thetaCondition(2);
			%-------------------------------------------
			if (PILOT_TYPE==VUA_SC_6G)
			    condition1=(abs(ahrsState.ahrs_q)<0.1)&&(abs(ahrsState.ahrs_r)<0.1)&& (abs(accX)<2.0);
			    condition2=((airspeed<20.0)&&(lockUpdateCounter<=0));
			else
			    condition1=(abs(ahrsState.ahrs_q)<0.1)&&(abs(ahrsState.ahrs_r)<0.1)&& (abs(accX)<2.0)&&(lockUpdateCounter<=0);
			    condition2=((airspeed<20.0)&&(lockUpdateCounter<=0));
			end
			%--------------------------------------------
			if((abs(ahrsState.ahrs_p)<0.01&&((abs(accel(3))<2.0*9.81))&&((abs(accel(2))<8.0))&&((abs(accel(3))>3.0))&&condition1)...
			        && ((abs(updated_phi - psd_phi) < 0.05) || ahrsState.resetUpdatedPhiFlag)...
			        ||...
			        condition2)
			    ahrsState = ahrs_update_phi(ahrsState,accel,1,mag,magEnable);
			    if (version == 0)
			        ahrsState = ahrs_update_phi_from_mag(ahrsState,accel,1,mag,magEnable);
			    end
			        ahrsState.ahrsUpdateFlag =(ahrsState.ahrsUpdateFlag | 1);
			else
			    ahrsState = ahrs_update_phi(ahrsState,accel,0,mag,magEnable);
			end
			ahrsState.accelGx = accel(1);

			%---------------------------------------------------
			% check update condition for phi
			%---------------------------------------------------
			if((ahrsState.ahrs_q) > 0.1)
			    ahrsState.updatedPhiCondition = 1;
			else if(abs(ahrsState.ahrs_r)> 0.1)
			        ahrsState.updatedPhiCondition = 2;
			    else if (abs(accX)> 2.0)
			            ahrsState.updatedPhiCondition = 3;
			        else if (abs(ahrsState.ahrs_p)> 0.01 )
			                ahrsState.updatedPhiCondition = 4;
			            else if(abs(accel(3))> 2.0*9.81)
			                    ahrsState.updatedPhiCondition = 5;
			                else if (abs(accel(2))> 8.0)
			                        ahrsState.updatedPhiCondition = 6;
			                    else if (abs(accel(3)) < 3.0)
			                            ahrsState.updatedPhiCondition = 7;
			                        else if (abs(updated_phi - psd_phi) > 0.05)
			                                ahrsState.updatedPhiCondition = 8;
			                            else
			                                ahrsState.updatedPhiCondition = 0;
			                            end                            
			                        end
			                    end
			                end
			            end
			        end
			    end
			end

			if (lockUpdateCounter <= 0)
			    ahrsState.updatedPhiCondition = 10;
			end

			if(ahrsState.resetUpdatedPhiFlag)
			    ahrsState.updatedPhiCondition = 9;
			end
			%----------------------------------------------------
			if (PILOT_TYPE==VUA_SC_6G)
			    condition3=(abs(gyro(2))<0.02);
			else
			    condition3=	(abs(gyro(2))<0.05)&&(lockUpdateCounter<=0);
			end
			%----------------------------------------------------
			ahrsState.accXcen = ahrsState.velocityYHistory(1) * gyro(3);
			if(flightMode == 1)
			    if ( ( ((abs(ahrsState.accelX)<0.2) && (accXlinUpdate == 0) || ((abs(ahrsState.accXlin) < 0.1) && (accXlinUpdate == 1)))&& ...
			           (abs(accX)<2.0) && ...
			           ((abs(accel(1)) < abs(G * sin(psd_theta + 0.5 * pi/180))) && ... %%sua 2 thanh 0.5
			           (abs(updated_theta - psd_theta) < 0.05) || ahrsState.resetUpdateThetaFlag)&&...
			           condition3...
			          )...
			        || ... 
			        ((airspeed<20.0) && ... 
			        (lockUpdateCounter<=0)))
			        ahrsState = ahrs_update_theta(ahrsState,accel,1,mag,magEnable);

			        if(version == 0)
			            ahrsState = ahrs_update_phi_from_mag(ahrsState,accel,1,mag,magEnable);
			        end
			            ahrsState.ahrsUpdateFlag = ahrsState.ahrsUpdateFlag | 2;
			    else
			        ahrsState = ahrs_update_theta(ahrsState,accel,0,mag,magEnable);
			    end
			else
			    if ( ( (abs(ahrsState.accXlin)<0.5) && ...
			           (abs(accX)<2.0) && ...
			           (abs(gyro(2))<0.05) &&...
			           (lockUpdateCounter<=0)...
			             )...
			            ||... 
			            ((airspeed<20.0) &&...
			              (lockUpdateCounter<=0)))
			        ahrsState = ahrs_update_theta(ahrsState,accel,1,mag,magEnable);
			        ahrsState.ahrsUpdateFlag = ahrsState.ahrsUpdateFlag | 2;
			    else
			        ahrsState = ahrs_update_theta(ahrsState,accel,0,mag,magEnable);
			    end
			end
			%---------------------------------------------------------------------
			% check update condition for theta
			%---------------------------------------------------------------------
			if (abs(ahrsState.accelX)>0.2)
			    ahrsState.updatedThetaCondition = 1;
			else if (abs(accX)>2.0)
			        ahrsState.updatedThetaCondition = 2;
			    else if (abs(accel(1)) > abs(G * sin(psd_theta + 0.5 * pi/180)))
			            ahrsState.updatedThetaCondition = 3;
			        else if (abs(updated_theta - psd_theta) > 0.05)
			                ahrsState.updatedThetaCondition = 4;
			            else if (abs(gyro(2))<0.02)
			                    ahrsState.updatedThetaCondition = 5;
			                else
			                    ahrsState.updatedThetaCondition = 0;
			                end
			            end
			        end
			    end
			end

			if (lockUpdateCounter <= 0)
			    ahrsState.updatedThetaCondition = 10;
			end

			if(ahrsState.resetUpdateThetaFlag)
			    ahrsState.updatedThetaCondition = 9;
			end
			%---------------------------------------------------------------------
			if(version >0)
			    if(ahrsState.ahrsUpdateFlag==1)		
			        ahrsState = ahrs_update_theta_from_mag(ahrsState,accel,1,mag,magEnable);
			    end			
			    if(ahrsState.ahrsUpdateFlag==2)
			        ahrsState = ahrs_update_phi_from_mag(ahrsState,accel,1,mag,magEnable);
			    end
			end
			%--------------------------------------------------------------------
			    gAhrsData.incdError = checkMagnetometer(ahrsState,mag,magEnable);
			%--------------------------------------------------------------------    
			    ahrsState.lastUpdatePhi = updated_phi;
			    ahrsState.lastUpdateTheta = updated_theta;
			    
			if (((magValid == 1) &&... 
			    (abs(ahrsState.ahrs_phi)<0.26) &&...
			    (abs(ahrsState.ahrs_theta)<0.26) && ...
			    (lockUpdateCounter<=0)) ...
			         ||...
			         ((magValid == 1)&&	...
			        (airspeed<20.0)&&...
			        (lockUpdateCounter<=0)))
			    ahrsState = ahrs_update_psi(ahrsState,psiFromHeading,1,mag,magEnable);
			    ahrsState.ahrsUpdateFlag = (ahrsState.ahrsUpdateFlag | 4); 
			else
			    ahrsState = ahrs_update_psi(ahrsState,psiFromHeading,0,mag,magEnable);
			end

		    ahrsState.updateSelector = ahrsState.updateSelector + 1;
		    if ( ahrsState.updateSelector >= 3 )
		        ahrsState.updateSelector=0;
		    end

		    ahrsState = ahrsCalculateDots(ahrsState);
		    y = ahrsState;
        end
        
        % Lock & Lock :D
        function obj = unlockUpdate(obj, sec)
        	obj.lockUpdateCounter = sec * obj.gaugeCyclesPerSecond;
        end
        function out = isUpdateLocked(obj)
        	out = (obj.lockUpdateCounter ~= 0);
        end
        % Correction from magnetometer
        function incd = checkMagnetometer(obj, mag, magEnable)
        	I = obj.Pi_2minusInclination;
        	incd = 0;
        	if(magEnable ~= 0)
        		incd = obj.incd_of_mag(mag, I);
        	end
        end
        function incd = incd_of_mag(obj, phi, theta, mag, I)
        	sphi = sin(phi);
        	cphi = cos(phi);
        	stheta = sin(theta);
        	ctheta = cos(theta);

        	z = -stheta*mag(1) + spphi*ctheta*mag(2) + cphi*ctheta*mag(3);
        	incd = asin(z) - (pi/2-I);
        end
        % 
        function [y, A, epsilon, x, w] = sasbc(obj, A, epsilon, x, w);
        	w = 0;
			tmp = sqrt( A(1)^2 + A(2)^2);
			if(abs(A(3)) >= ((1-epsilon)*tmp))
			    w = 1;
			    x(1) = pi/2;
			    if (A(3) < 0.0)
			        x(1) = -pi/2;
			    end
			else
			    if (tmp > 0.0)
			        tmp = A(3)/tmp;
			        x(1) = asin(tmp);
			    end
			end

			x(2) = (pi - abs(x(1)));
			if(x(1) < 0)
			    x(2) = -x(2);
			end

			tmp = atan2(A(2),A(1));
			x(1) = x(1) - tmp;
			x(2) = x(2) - tmp;


			if(x(1) > pi)

			    x(1) = x(1) - 2*pi;
			end
			if(x(1) <= -pi)

			    x(1) = x(1) + 2*pi;
			end
			if(x(2) > pi)

			    x(2) = x(2) - 2*pi;
			end
			if(x(2) <= -pi)

			    x(2) = x(2) + 2*pi;
			end
			y = 0;
		end
		% PHI of mag
		function y = phi_of_mag(obj, phi, theta, mag, I, w)
			A = zeros(3,1);
			phic = zeros(2,1);
			stheta = sin(theta);
			ctheta = cos(theta);
			cI = cos(I);

			A(1) = ctheta*mag(2);
			A(2) = ctheta*mag(3);
			A(3) = cI + stheta*mag(1);

			[~, A, epsilon, phic, w] = sasbc(A, 0.03, phic, w);
			if(abs(phic(1) - phi) > abs(phic(2) - phi))
			    phic(1) = phic(2);
			end
			y = phic(1);
		end
		% THETA of mag
		function y = theta_of_mag(obj, phi, theta, mag, I, w)
			A = zeros(3,1);
			thetac = [0.0, 0.0];


			sphi = sin(phi);
			cphi = cos(phi);
			cI = cos(I);

			A(1) = -mag(1);
			A(2)= sphi*mag(2) + cphi*mag(3);
			A(3) = cI;

			[~, A, epsilon, thetac, w] = sasbc(A, 0.03, thetac, w);

			%if(abs(thetac(1) - theta) > fabsf(thetac(2) - theta)) 
			% fabsf is not defined in matlab
			if(abs(thetac(1) - theta) > abs(thetac(2) - theta))

			    thetac(1) = thetac(2);
			end

			y = thetac(1);		
		end	
		% PSI of mag 
		function psi = psi_of_mag(obj, phi, theta, mag, I, w)
			sphi = sin(phi);
			cphi = cos(phi);
			stheta = sin(theta);
			ctheta = cos(theta);

			x = ctheta*mag(1) + sphi*stheta*mag(2) + cphi*stheta*mag(3);
			y = cphi*mag(2) - sphi*mag(3);

			psi = -atan2(y,x);

			psi = psi + D;
			if (psi > pi)
			    psi = psi - 2*pi;
			end
			if (psi <= -pi)
			    psi = psi + 2*pi;
			end
		end
		% Estimate vertical speed
		function obj = estVertSpeed(obj, )

    end
end





