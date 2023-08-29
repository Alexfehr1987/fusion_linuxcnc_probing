(do this in metric)
G21

(Probing control variables)
#<_probeFastSpeed>= 762.
#<_probeSlowSpeed>= 50.8
#<_probeSlowDistance>= 1.016

(Probe Protection)
M66 P0
o<probe_protection> call

(select the correct wcs for rotary work)
G54.1 P100

(clearance set to 10 mm)
#<clearance> = 10.0
#<feed> = 1500.0

G90

(probe down to the first touch)
o<f360_probe_z> call [-1.] [2.0 * #<clearance>]

(and record the z coord)
#<zhit1> = #5063

(Retract above the hit)
G90 G1 Z[#<zhit1> + #<clearance>] F#<feed>
(DEBUG,Z touch found at #<zhit1>)

(move across)
o<f360_safe_move_y> call [-2.0 * #5421] [#<feed>]

(probe down to the second touch)
o<f360_probe_z> call [-1.] [2.0 * #<clearance>]

(and record the z coord)
#<zhit2> = #5063

(Retract above the hit)
G90 G1 Z[#<zhit2> + #<clearance>] F#<feed>
(DEBUG,Z touch found at #<zhit2>)
o100 if [#5421 LT 0.0]
    #<angleResult> = [atan [#<zhit1> - #<zhit2>] /  [-2.0 * #5421]]
o100 else
    #<angleResult> = [atan [#<zhit2> - #<zhit1>] /  [2.0 * #5421]]
o100 endif

(DEBUG,Angle was #<angleResult>, should have been #5423)

(now correct the wcs)
G10 L2 P0 A[#<_work_offset_a> - #<angleResult>+#5423]
G0 A0.0

(end of program)
G90
M30
