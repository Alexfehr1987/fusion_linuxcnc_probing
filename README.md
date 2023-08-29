# fusion_linuxcnc_probing

modified Postprocessor to accept Fusion360 Probing cylcles.

Important:  
-Subroutines need to be added to linuxcnc  
-will not work out of the box, due to adaption to my machine/hal...  

additional features:  
-M300 for in G-Code tool-lenght probing  
-Probe active Pin checked to prevent crashing  
-Probe Tip Calibration Value used from Probebasic  
