# Glider Instrumentation Toolkit
#
# Copyright (C) 2013-2014 Anton Gomez Alvedro
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Features:
#   + Total energy compensated variometer
#   + Netto variometer
#   + Relative (Super Netto) variometer
#   + Configurable dampener for simulating needle response time
#   + Configurable averager
#   + Speed to fly computer
#
# TODO:
# - add wind correction to speed-to-fly
# - final glide computer

io.include("updateloop.nas");

var MPS2KPH = 3.6;
var sqr = func(x) {x * x}


var InstrumentComponent = {
	parents: [Updatable],
	output: 0,
	reset: func { me.output = 0 },
};

# This alias is for keeping backwards compatibility.
# TODO: Refactor aircrafts that use it and remove this.
var Instrument = UpdateLoop;

##
# Helper generator for updating a property on every element update
#
# Example:
#
# var needle = Dampener.new(
#	input: probe,
#	dampening: 2.8,
#	on_update: update_prop("/instrumentation/variometer/te-reading-mps"));
#
# See Aircraft/Instruments-3d/glider/vario/ilec-sc7.nas and
# Aircraft/Generic/soaring-instrumentation-sdk.nas for usage examples.
# You can also refer to the soaring sdk wiki page.

var update_prop = func(property) {
	func(value) { setprop(property, value) }
};

# InputSwitcher
# Selects output from one of multiple components given as inputs
#
# var lcd_controller = InputSwitcher.new(
#	inputs: Vector of objects connected to the input
#	active_input: (optional) Input number that is active at start
#	on_update: (optional) function to call whenever a new output is available

var InputSwitcher = {

	parents: [InstrumentComponent],

	new: func(inputs, active_input = 0, on_update = nil) {
		return {
			parents: [me],
			inputs: inputs,
			active_input: active_input,
			on_update: on_update
		};
	},

	select_input: func(input_number) {
		me.active_input = input_number;
		me.update();
	},

	update: func {
		me.output = me.inputs[me.active_input].output;
		if (me.on_update != nil) me.on_update(me.output);
	}
};

# PropertyReader
# Makes a property available at its output. Its purpose is to adapt properties
# to the component model used by the library.
#
# var temperature = PropertyReader.new(
#	property: Property to read from
#	scale: Scale factor applied to the property value (output = scale * prop)

var PropertyReader = {

	parents: [InstrumentComponent],

	new: func(property, scale = 1) {
		return {
			parents: [me],
			property: property,
			scale: scale
		};
	},

	update: func {
		me.output = me.scale * getprop(me.property);
	}
};

# YawString
# The most important instrument in a glider. Simple, cheap and effective!
#
# var string = YawString.new(
#	on_update: update_prop("/instrumentation/yaw-string/deflection-deg");

var YawString = {

	parents: [InstrumentComponent],

	new: func (on_update = nil) {
		return {
			parents: [me],
			on_update: on_update
		};
	},

	update: func {
		var airspeed = getprop("velocities/airspeed-kt");
		var noise = (airspeed < 54) ?
			math.sin(math.pi * airspeed / 54) * rand() : 0;

		me.output = noise + getprop("orientation/side-slip-deg");

		if (me.on_update != nil) me.on_update(me.output);
	}
};

# TotalEnergyProbe
# Computes total energy variation by reading current airspeed and altitude
#
# var probe = TotalEnergyProbe.new(
#	on_update: (optional) function to call whenever a new output is available

var TotalEnergyProbe = {

	parents: [InstrumentComponent],
	altitude: 0, # meters
	airspeed: 0, # m/s

	new: func(on_update = nil) {
		return {
			parents: [me],
			on_update: on_update
		};
	},

	reset: func {
		me.airspeed = getprop("/velocities/airspeed-kt") * KT2MPS;
		me.altitude = getprop("/position/altitude-ft") * FT2M;
		me.output = 0;
	},

	update: func(dt) {
		var altitude_now = getprop("/position/altitude-ft") * FT2M;
		var airspeed_now = getprop("/velocities/airspeed-kt") * KT2MPS;

		me.output = (altitude_now - me.altitude) / dt;
		me.output += (sqr(airspeed_now) - sqr(me.airspeed)) / (19.62 * dt);

		me.altitude = altitude_now;
		me.airspeed = airspeed_now;

		if (me.on_update != nil) me.on_update(me.output);
	}
};

# Dampener
# Simple IIR exponential filter. Appropriate and efficient for simulating
# mechanical needle dampening.
#
# var needle = Dampener.new(
#	input: Object connected to the dampeners input.
#	dampening: (optional) Time constant for the filter in seconds
#	scale: (optional) Scale factor applied to the input signal before filtering
#	on_update: (optional) function to call whenever a new output is available

var Dampener = {

	parents: [InstrumentComponent],
	dampening: 0, # time constant of the exponential filter (sec)
	scale: 1,

	new: func(input, dampening = 3, scale = 1, on_update = nil) {
		return {
			parents: [me],
			input: input,
			dampening: dampening,
			scale: scale,
			on_update: on_update,
		};
	},

	update: func(dt) {
		var alfa = math.exp(-dt / me.dampening);
		me.output = me.output * alfa + me.input.output * me.scale * (1 - alfa);
		if (me.on_update != nil) me.on_update(me.output);
	}
};

# Averager
# Provides a windowed moving average of its input signal. Window size is
# set on construction, and is given in samples (i.e. not seconds).
#
# var averager = Averager.new(
#	input: Object connected to the averagers input.
#	size: (optional) window size in samples
#	on_update: (optional) function to call whenever a new output is available

var Averager = {

	parents: [InstrumentComponent],

	new: func(input, buffer_size = 25, on_update = nil) {
		var m = { parents: [me] };
		m.input = input;
		m.on_update = on_update;
		m.size = buffer_size;
		m.sum = m.wp = 0;

		m.buffer = setsize([], buffer_size);
		m.reset();
		return m;
	},

	reset: func {
		me.sum = me.wp = me.output = 0;
		forindex (var i; me.buffer)
			me.buffer[i] = 0;
	},

	update: func {
		var new_value = me.input.output;

		me.sum = me.sum + new_value - me.buffer[me.wp];
		me.output = me.sum / me.size;

		me.buffer[me.wp] = new_value;
		if ((me.wp += 1) == me.size)
			me.wp = 0;

		if (me.on_update != nil) me.on_update(me.output);
	}
};

# PolarSolver
# Helper object required for advanced soaring instrumentation.
# Provides McCready speed-to-fly computations assuming a parabolic glider polar
# (this approximation is frequently used in real instruments as well).
#
# Polar coeficients provided on construction correspond to the equation:
# sink = coefs[0] * airspeed^2 + coefs[1] * airspeed + coefs[2]
#
# Note that sink is considered positive. Negative sink means.. lift!
#
# var solver = PolarSolver.new(
#	polar_coefs: [0.000364277, -0.0479199, 2.31644]
#	mass: Reference mass in Kg used while obtaining the polar above

var PolarSolver = {

	min_sink: 0, # minimum sink m/s, according to glider polar

	new: func(polar_coefs, mass) {
		var m = { parents: [me] };
		m.reference_coefs = polar_coefs;
		m.coefs = polar_coefs;
		m.reference_mass = mass;
		m.total_mass = mass;
		m.min_sink = m.coefs[2] - (sqr(m.coefs[1]) / (4 * m.coefs[0]));
		return m;
	},

	set_total_mass: func(mass) {
		me.total_mass = mass;
		var load_factor = math.sqrt(mass / me.reference_mass);

		# Update active polar
		me.coefs[0] = me.reference_coefs[0] / load_factor;
		me.coefs[2] = me.reference_coefs[2] * load_factor;

		me.min_sink = me.coefs[2] - (sqr(me.coefs[1]) / (4 * me.coefs[0]));
	},

	speed_to_fly: func(mc, airmass_sink) {
		var speed = (mc + me.coefs[2] + airmass_sink) / me.coefs[0];
		return (speed > 0) ? math.sqrt(speed) : 0;
	},

	ld: func(airspeed) {
		return aispeed / me.sink(airspeed);
	},

	sink: func(airspeed) {
		return me.coefs[0] * sqr(airspeed)
		       + me.coefs[1] * airspeed + me.coefs[2];
	}
};

# NettoVario
# The Netto variometer substract glider's sink rate for current airpseed from a
# total energy reading. The resulting value is airmass' lift/sink in m/s.
#
# var netto = NettoVario.new(
#	te_probe: Object providing a total energy reading
#	polar_solver: Object providing a McCready implementation
#	on_update: (optional) function to call whenever a new output is available

var NettoVario = {

	parents: [InstrumentComponent],

	new: func(te_probe, polar_solver, on_update=nil) {
		return {
			parents: [me],
			probe: te_probe,
			polar: polar_solver,
			on_update: on_update
		};
	},

	update: func {
		me.output = probe.output
		            + me.polar.sink(probe.airspeed);

		if (me.on_update != nil) me.on_update(me.output);
	}
};

# RelativeVario
# The Relative (aka Super Netto) variometer tell you what climb rate would you
# get if you slowed down to optimal thermaling speed.
#
# var snetto = RelativeVario.new(
#	te_probe: Object providing a total energy reading
#	polar_solver: Object providing a McCready implementation
#	on_update: (optional) function to call whenever a new output is available

var RelativeVario = {

	new: func(te_probe, polar_solver, on_update=nil) {
		return {
			parents: [me, NettoVario.new(te_probe, polar_solver, on_update)]
		};
	},

	update: func {
		me.output = probe.output
		            + me.polar.sink(probe.airspeed)
		            - me.polar.min_sink;

		if (me.on_update != nil) me.on_update(me.output);
	}
};

# SpeedCmdVario
# The speed command variometer tells you how fast or slow your airspeed is with
# respect to the optimal speed-to-fly (computed according to McCready theory).
#
# var speedcmd = SpeedCmdVario.new(
#	te_probe: Object providing a total energy reading
#	polar_solver: Object providing a McCready implementation
#	netto: (optional) Object providing a Netto reading
#	on_update: (optional) function to call whenever a new output is available

var SpeedCmdVario = {

	parents: [InstrumentComponent],
	mc: 0, # mccready setting

	new: func(te_probe, polar_solver, netto = nil, on_update = nil) {
		return {
			parents: [me],
			polar: polar_solver,
			probe: te_probe,
			netto: netto or NettoVario.new(te_probe, polar_solver),
			update_netto: (netto == nil),
			on_update: on_update
		};
	},

	update: func {
		if (me.update_netto) me.netto.update();

		var target_speed = me.polar.speed_to_fly(me.mc, -me.netto.output);
		me.output = me.probe.airspeed * MPS2KPH - target_speed;

		if (me.on_update != nil) me.on_update(me.output);
	}
};

# Vario sound pitch controller
# Computes the frequency factor for a variometer sound.
#
# var vario_sound = SoundPitchController.new(
#   input: Object connected to the pitch controller input, e.g. a variometer reading.
#   max_pitch: (optional) Maximum sound frequency factor, the output will be
#              in the range [1/max_pitch, max_pitch], default 2.
#   max_input: Value of input for which max_pitch is reached.
#	on_update: (optional) function to call whenever a new output is available

var SoundPitchController = {
    parents: [InstrumentComponent],

    new: func(input, max_input, max_pitch = 2, on_update = nil) {
        return {
            parents: [me],
            input: input,
            max_pitch: max_pitch,
            max_input: max_input,
            on_update: on_update,
        };
    },

    update: func {
        var input = math.clamp(me.input.output, -me.max_input, me.max_input);
        me.output = math.pow(me.max_pitch, input / me.max_input);

        if (me.on_update != nil) me.on_update(me.output);
    },
};
