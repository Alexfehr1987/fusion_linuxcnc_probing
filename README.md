# fusion_linuxcnc_probing

modified Postprocessor to accept Fusion360 Probing cylcles. 

Key features:   
-Fusion Probing Cycles
-Fusion Edge angle probing for G54 
-Machine Simulation with rotary axis possible
-latest Linuxcnc post from Fusion as base 44083

Important:  
-Subroutines need to be added to linuxcnc subroutines folder 
-will not work out of the box, due to adaption to my machine/hal...  

additional features:  
-Probe active Pin checked to prevent crashing  (Probe protection subroutine checks motion.digital-in-00 pin with M66)
-Probe Tip Calibration Value used from Probebasic  (Parameter #1000)


not tested:  
-inch mode

known issues:  
-angle probing only working with G54 and without override wcs from fusion(drive g54 from g55 e.g.)  
-tool table needs to be in metric
-machine simulation only working with machine configuration   
-Probing Cycles not possible with machine simulation(but with vise, chuck e.g.)-->sepatate setup for probe cycles or deactivate probe cycles temporary for complete machine simulation


# DISCLAIMER  
THE AUTHORS OF THIS SOFTWARE ACCEPT ABSOLUTELY NO LIABILITY FOR ANY HARM OR LOSS RESULTING FROM ITS USE. IT IS EXTREMELY UNWISE TO RELY ON SOFTWARE ALONE FOR SAFETY. Any machinery capable of harming persons must have provisions for completely removing power from all motors, etc, before persons enter any danger area. All machinery must be designed to comply with local and national safety codes, and the authors of this software can not, and do not, take any responsibility for such compliance.

This software is released under the GPLv2.

Credits go to  David Loomes for initial creation of Tormach PP with probing and Marty Jacobson for conversion to Linuxcnc!!!
