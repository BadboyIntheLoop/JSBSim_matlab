
/** Models atmospheric disturbances: winds, gusts, turbulence, downbursts, etc.
<h2>Turbulence</h2>
Various turbulence models are available. They are specified
via the property <tt>atmosphere/turb-type</tt>. The following models are
available:

* 0: ttNone (turbulence disabled)
* 1: ttStandard
* 2: ttCulp
* 3: ttMilspec (Dryden spectrum)
* 4: ttTustin (Dryden spectrum)
    
The Milspec and Tustin models are described in the Yeager report cited
below.  They both use a Dryden spectrum model whose parameters (scale
lengths and intensities) are modelled according to MIL-F-8785C. Parameters
are modelled differently for altitudes below 1000ft and above 2000ft, for
altitudes in between they are interpolated linearly. The two models differ in the implementation of the transfer functions described in the milspec.

To use one of these two models, set <tt>atmosphere/turb-type</tt> to 4
resp. 5, and specify values for
<tt>atmosphere/turbulence/milspec/windspeed_at_20ft_AGL-fps</tt> and
<tt>atmosphere/turbulence/milspec/severity</tt> (the latter corresponds to
the probability of exceedence curves from Fig.&nbsp;7 of the milspec,
allowable range is 0 (disabled) to 7). <tt>atmosphere/psiw-rad</tt> is
respected as well; note that you have to specify a positive wind magnitude
to prevent psiw from being reset to zero.
Reference values (cf. figures 7 and 9 from the milspec):
<table>
    <tr><td><b>Intensity</b></td>
        <td><b><tt>windspeed_at_20ft_AGL-fps</tt></b></td>
        <td><b><tt>severity</tt></b></td></tr>
    <tr><td>light</td>
        <td>25 (15 knots)</td>
        <td>3</td></tr>
    <tr><td>moderate</td>
        <td>50 (30 knots)</td>
        <td>4</td></tr>
    <tr><td>severe</td>
        <td>75 (45 knots)</td>
        <td>6</td></tr>
</table>
<h2>Cosine Gust</h2>
A one minus <em>cosine</em> gust model is available. This permits a configurable, predictable gust to be input to JSBSim for testing handling and
dynamics. Here is how a gust can be entered in a script: {.xml}
<event name="Introduce gust">
    <condition> simulation/sim-time-sec ge 10 </condition>
    <set name="atmosphere/cosine-gust/startup-duration-sec" value="5"/>
    <set name="atmosphere/cosine-gust/steady-duration-sec" value="1"/>
    <set name="atmosphere/cosine-gust/end-duration-sec" value="5"/>
    <set name="atmosphere/cosine-gust/magnitude-ft_sec" value="30"/>
    <set name="atmosphere/cosine-gust/frame" value="2"/>
    <set name="atmosphere/cosine-gust/X-velocity-ft_sec" value="-1"/>
    <set name="atmosphere/cosine-gust/Y-velocity-ft_sec" value="0"/>
    <set name="atmosphere/cosine-gust/Z-velocity-ft_sec" value="0"/>
    <set name="atmosphere/cosine-gust/start" value="1"/>
    <notify/>
</event>
~~~
The x, y, z velocity components are meant to define the direction vector.
The vector will be normalized by the routine, so it does not need to be a
unit vector.
The startup duration is the time it takes to build up to full strength
(magnitude-ft_sec) from zero. Steady duration is the time the gust stays at
the specified magnitude. End duration is the time it takes to dwindle to
zero from the specified magnitude. The start and end transients are in a
smooth cosine shape.
The frame is specified from the following enum:
enum eGustFrame {gfNone=0, gfBody, gfWind, gfLocal};
That is, if you specify the X, Y, Z gust direction vector in the body frame,
frame will be "1". If the X, Y, and Z gust direction vector is in the Wind
frame, use frame = 2. If you specify the gust direction vector in the local
frame (N-E-D) use frame = 3. Note that an internal local frame direction
vector is created based on the X, Y, Z direction vector you specify and the
frame *at the time the gust is begun*. The direction vector is not updated
after the initial creation. This is to keep the gust at the same direction
independent of aircraft dynamics.
The gust is triggered when the property atmosphere/cosine-gust/start is set
to 1. It can be used repeatedly - the gust resets itself after it has
completed.
The cosine gust is global: it affects the whole world not just the vicinity
of the aircraft.
@see Yeager, Jessie C.: "Implementation and Testing of Turbulence Models for
        the F18-HARV" (<a
        href="http://ntrs.nasa.gov/archive/nasa/casi.ntrs.nasa.gov/19980028448_1998081596.pdf">
        pdf</a>), NASA CR-1998-206937, 1998
@see MIL-F-8785C: Military Specification: Flying Qualities of Piloted Aircraft

## **Inputs and Outputs for Matlab**
### **Inputs**
1. Init Winds (FGInitialCondition)
    void SetWindNEDFpsIC(double wN, double wE, double wD);

    void SetWindMagKtsIC(double mag);

    void SetWindDirDegIC(double dir);

    void SetHeadWindKtsIC(double head);

    void SetCrossWindKtsIC(double cross);

    void SetWindDownKtsIC(double wD);

2. Init States (FGInitialCondition)
### **Outputs**

