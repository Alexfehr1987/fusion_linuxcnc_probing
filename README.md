# fusion_linuxcnc_probing

modified Postprocessor to accept Fusion360 Probing cylcles.

Important:  
-Subroutines need to be added to linuxcnc  
-will not work out of the box, due to adaption to my machine/hal...  

additional features:  
-M300 for in G-Code tool-lenght probing  
-Probe active Pin checked to prevent crashing  
-Probe Tip Calibration Value used from Probebasic  


not tested:  
-probing -y angle  
-probing -x angle  
-inch mode

known issues:  
-angle probing only working with G54 and without override wcs from fusion(drive g54 from g55 e.g.)  
-tool table needs to be in metric


# DISCLAIMER  
THE AUTHORS OF THIS SOFTWARE ACCEPT ABSOLUTELY NO LIABILITY FOR ANY HARM OR LOSS RESULTING FROM ITS USE. IT IS EXTREMELY UNWISE TO RELY ON SOFTWARE ALONE FOR SAFETY. Any machinery capable of harming persons must have provisions for completely removing power from all motors, etc, before persons enter any danger area. All machinery must be designed to comply with local and national safety codes, and the authors of this software can not, and do not, take any responsibility for such compliance.

This software is released under the GPLv2.

Credits go to  David Loomes for initial creation of Tormach PP with probing and Marty Jacobson for conversion to Linuxcnc!!!
