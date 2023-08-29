/*
  Copyright (C) 2012-2020 by Autodesk, Inc.
  All rights reserved.

  Tormach PathPilot post processor configuration.

  $Revision: 2651 $
  $Date: 2021-09-22 17:17:07 +0100 (Wed, 22 Sep 2021) $
  $Author: david $
  
  Modified by Marty Jacobson to work with LinuxCNC:
  03/09/23		Removed G50 preamble which causes fault in vanilla LinuxCNC
  03/09/23		Added awareness of G64 value based on each operation's tolerance value to prevent excessive smoothing in vanilla LinuxCNC on high-acceleration machines
  03/09/23		Added output of Fusion360/HSM Notes (custom G-code blocks in CAM) to comments which will pop up messages in LinuxCNC if configured correctly
  Modified by Alex to work with metric machine and implementing updates from David Loomes
  12/04/23		fixed metric Inch issue G30
  12/04/23		Outputs block delete character "/" before optional sections.
  12/04/23		[x], [y], [z] substituted in comment field for inspection reports.
  01/05/23		corrected ETS cycle, added M300
  
  Modified by David Loomes to support integrated Fusion 360 probing in PathPilot
  24/02/19		Initial probing release
  13/06/19		Added post support for plane angle probing
  27/10/19		Added support for Tormach extended WCS - 500 WCS max, using G54.1 Pxxx syntax
  11/12/19		Added support for electronic tool setter (G37)
  21/01/20		Incorporated corrections from Autodesk for smartcool processing.
  29/06/20		Added support for I/O boards
  25/07/20		Added partial circle probing operations
  06/08/20		Added support for inspection reports
  28/09/20		Added option to turn on output during probing ops
  29/09/20		Added multiple options to control retract operations
  09/10/20		Added comments to delimit pre-amble, post-amble and tool table
  02/01/21		Added Manual NC 'Action' options to control inspection probing
  22/09/21		Don't turn spindle and cooling off when retracting for WCS or 4th axis orientation change
  22/09/21		Correct error that caused 'redeclaration of function onParameter' warning from Fusion
*/

description = "LinuxCNC with probing, ETS, and G64 by operation";
vendor = "LinuxCNC";
vendorUrl = "http://www.linuxcnc.org";
legal = "Copyright (C) 2012-2018 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 40783;


longDescription = "LinuxCNC adaptation of Tormach PathPilot post SmartCool support and integrated probing functions. 500 WCS support, ETS support, G64 per-operation";

extension = "nc";
setCodePage("ascii");

capabilities = CAPABILITY_MILLING | CAPABILITY_MACHINE_SIMULATION;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion



// group names
var ncHeaderGroup = "1 - NC Header",
machineConfigGroup = "2 - Machine config",
retractiionGroup = "3 - Retraction",
afterFinishedGroup = "4 - At end of program",
probingGroup = "5 - Integrated probing",
etsGroup = "6 - Toolsetter",
tappingGroup = "7 - Tapping",
usbIoGroup = "8 - USB I/O",
coolantGroup = "9 - Coolant";

// user-defined properties
properties = {
	useOpToleranceAsG64: {title:"Op Tolerance as G64 P", description:"Uses Operation Tolerance Value as G64 P value ", type:"boolean", group:machineConfigGroup, value:true}, // MCJ
	
	writeMachine: {title:"Write machine", description:"Output the machine settings in the header of the code.", group:ncHeaderGroup, type:"boolean", value:true},

	writeTools: {title:"Write tool list", description:"Output a tool list in the header of the code.", group:ncHeaderGroup, type:"boolean", value: true},

	writeVersion: {title:"Write version", description:"Write the version number in the header of the code.", group:ncHeaderGroup, type:"boolean", value: false},

	toolChangeAtEnd: 
	{
		title: "Tool change at end",
		description: "add a final tool change after the program finishes",
		type: "enum",
		value: "None",
		group: afterFinishedGroup,
		values:
		[
			{title:"None", id:"none"}, 
			{title:"First in program", id:"first"}, 
			{title:"Specific - see tool to load", id:"specific"},
		]
		},

	toolNumberAtEnd:
	{
		title: "Tool to load",
		description: "If 'Specific tool is selected above, enter the tool number to load'",
		type:"integer", value: 1,
		group: afterFinishedGroup
	},

	retractOnProgramBegin: {title:"Retract before Program  start", description:"Retract opertion before start of program", type: "enum", group:retractiionGroup,
	values:[
		{title:"None", id:"none"}, 
		{title:"G30 - z only", id:"g30z"}, 
		{title:"G30 - z, then xy", id:"g30zxy"},
		{title:"G28 - z only", id:"g28z"}, 
		{title:"G28 - z, then xy", id:"g28zxy"},
	], value: "None"},
	
	retractOnProgramEnd: {title:"Retract after program end", description:"Retract operation after end of program", type: "enum", group:retractiionGroup,
	values:[
		{title:"None", id:"none"}, 
		{title:"G30 - z only", id:"g30z"}, 
		{title:"G30 - z, then xy", id:"g30zxy"},
		{title:"G28 - z only", id:"g28z"}, 
		{title:"G28 - z, then xy", id:"g28zxy"},
	], value: "g28z"},

	retractOnTCBegin: {title:"Retract before tool change", description:"Retract operation before each tool change", type: "enum", group:retractiionGroup,
	values:[
		{title:"None", id:"none"}, 
		{title:"G30 - z only", id:"g30z"}, 
		{title:"G30 - z, then xy", id:"g30zxy"},
		{title:"G28 - z only", id:"g28z"}, 
		{title:"G28 - z, then xy", id:"g28zxy"},
	], value: "g28z"},

	retractOnTCEnd: {title:"Retract after tool change", description:"Retract operation after each tool change", type: "enum", group:retractiionGroup,
	values:[
		{title:"None", id:"none"}, 
		{title:"G30 - z only", id:"g30z"}, 
		{title:"G30 - z, then xy", id:"g30zxy"},
		{title:"G28 - z only", id:"g28z"}, 
		{title:"G28 - z, then xy", id:"g28zxy"},
	], value: "none"},

	retractOnWCSChange: {title:"Retract on WCS change", description:"Retract operation when moving from one WCS to another", type: "enum", group:retractiionGroup,
	values:[
		{title:"None", id:"none"}, 
		{title:"G30 - z only", id:"g30z"}, 
		{title:"G30 - z, then xy", id:"g30zxy"},
		{title:"G28 - z only", id:"g28z"}, 
		{title:"G28 - z, then xy", id:"g28zxy"},
	], value: "g30z"},

	retractOnWorkPlaneChange: {title:"Retract on work plane change", description:"Retract operation when changing work plane (A axis move)", type: "enum", group:retractiionGroup,
	values:[
		{title:"None", id:"none"}, 
		{title:"G30 - z only", id:"g30z"}, 
		{title:"G30 - z, then xy", id:"g30zxy"},
		{title:"G28 - z only", id:"g28z"}, 
		{title:"G28 - z, then xy", id:"g28zxy"},
	], value: "g30z"},

	retractOnManualNCStop: {title:"Retract on ManualNC Stop", description:"Retract operation before M0", type: "enum", group:retractiionGroup,
	values:[
		{title:"None", id:"none"}, 
		{title:"G30 - z only", id:"g30z"}, 
		{title:"G30 - z, then xy", id:"g30zxy"},
		{title:"G28 - z only", id:"g28z"}, 
		{title:"G28 - z, then xy", id:"g28zxy"},
	], value: "none"},

	retractOnManualNCOptionalStop: {title:"Retract on ManualNC Optional Stop", description:"Retract operation before M1", type: "enum", group:retractiionGroup,
	values:[
		{title:"None", id:"none"}, 
		{title:"G30 - z only", id:"g30z"}, 
		{title:"G30 - z, then xy", id:"g30zxy"},
		{title:"G28 - z only", id:"g28z"}, 
		{title:"G28 - z, then xy", id:"g28zxy"},
	], value: "none"},

	//	substituteRapidAfterRetract: false,
	
	useM19: {title:"Use M19", description:"Disable to avoid spindle orient on toolchange.", group:machineConfigGroup, type:"boolean", value: true},

	showSequenceNumbers: {title:"Use sequence numbers", description:"Use sequence numbers for each block of outputted code.", group:machineConfigGroup, type:"boolean", value: false},

	sequenceNumberStart: {title:"Start sequence number", description:"The number at which to start the sequence numbers.", group:machineConfigGroup, type:"integer", value: 10},

	sequenceNumberIncrement: {title:"Sequence number increment", description:"The amount by which the sequence number is incremented by in each block.", group:machineConfigGroup, type:"integer", value: 10},

	sequenceNumberOperation: {title:"Sequence number at operation only", description:"Use sequence numbers at start of operation only.", group:machineConfigGroup, type:"boolean", value: true},

	optionalStopTool: {title:"Optional stop between tools", description:"Outputs optional stop code prior to a tool change.", group:machineConfigGroup, type:"boolean", value: false},

	optionalStopOperation: {title:"Optional stop between operations", description:"Outputs optional stop code prior between all operations.", group:machineConfigGroup, type:"boolean", value: false},

	separateWordsWithSpace: {title:"Separate words with space", description:"Adds spaces between words if 'yes' is selected.", group:machineConfigGroup, type:"boolean", value: true},

	useRadius: {title:"Radius arcs", description:"If yes is selected, arcs are outputted using radius values rather than IJK.", group:machineConfigGroup, type:"boolean", value: false},

	dwellInSeconds: {title:"Dwell in seconds", description:"Specifies the unit for dwelling, set to 'Yes' for seconds and 'No' for milliseconds.", group:machineConfigGroup, type:"boolean", value: true},

	forceWorkOffset: {title:"Force work offset", description:"Forces the work offset code at tool changes.", group:machineConfigGroup, type:"boolean", value: false},

	rotaryTableAxis: {
		title: "Rotary table axis",
		description: "Select rotary table axis. Check the table direction on the machine and use the (Reversed) selection if the table is moving in the opposite direction.",
		type: "enum",
		group:machineConfigGroup,
		values:[
		{title:"No rotary", id:"none"},
		{title:"X", id:"x"},
		{title:"Y", id:"y"},
		{title:"Z", id:"z"},
		{title:"X (Reversed)", id:"-x"},
		{title:"Y (Reversed)", id:"-y"},
		{title:"Z (Reversed)", id:"-z"}
		],
		value:"none"
	},


	smartCoolEquipped: {title:"SmartCool equipped", description:"Specifies if the machine has the SmartCool attachment.", group:coolantGroup, type:"boolean", value: false},
	
	multiCoolEquipped: {title:"Multi-Coolant equipped", description:"Specifies if the machine has the Multi-Coolant module.", group:coolantGroup, type:"boolean", value: false},

	smartCoolToolSweepPercentage: {title:"SmartCool sweep percentage", description:"Sets the tool length percentage to sweep coolant.", group:coolantGroup,type:"integer", value: 100},

	multiCoolAirBlastSeconds: {title:"Multi-Coolant air blast in seconds", description:"Sets the Multi-Coolant air blast time in seconds.", group:coolantGroup,type:"integer", value: 4},

	disableCoolant: {title:"Disable coolant", description:"Disable all coolant codes.", group:coolantGroup,type:"boolean", value: false},

	reversingHead: {title:"Use self-reversing tapping head", description:"Expanded cycles are output with a self-reversing tapping head.", group:tappingGroup, type:"boolean", value: false},

	reversingHeadFeed: {title:"Self-reversing head feed ratio", description:"The percentage of the tapping feedrate for retracting the tool.", group:tappingGroup, type:"number", value:2.0},

	maxTool: {title:"Maximum tool number", description:"Enter the maximum tool number allowed by the control.", group:machineConfigGroup, type:"number", value: 9999},
	
	// properties controlling integrated probing
	probeFastSpeed: {title: "Fast probing speed (inch/min)", description: "Fast probing speed (inch/min)", type:"number", group:probingGroup, value: 20.0},

	probeSlowSpeed: {title: "Slow probing speed (inch/min)", description: "Slow probing speed (inch/min)", type:"number", group:probingGroup, value: 1.0},

	probeSlowDistance: {title: "Slow probe distance (inch)", description: "Slow probe distance (inch)", type:"number", group:probingGroup, value: 0.04},

	// properties to control tool setter functions
	etsTolerance: {title: "Tolerance for ETS checks (inch)", description: "Tolerance allowed for tool lengths for ETS checks", type:"number", group:etsGroup, value: 0.005},

	etsDiameterLimit: {title: "ETS diameter limit (inch)", descriptopn: "Tools larger than this will not be checked by the tool setter", type: "number", group:etsGroup, value: 3},

	etsBeforeStart: 
	{
		title: "ETS op before start",
		description: "What toolsetter function should be performed before the start of the program",
		type: "enum",
		values:
			[
			{title: "None", id:"none"},
			{title: "Check", id:"check"},
			{title: "Set", id:"set"},
			],
			group:etsGroup,
			value: "none"
	},
	
	etsBeforeUse:
	{
		title: "ETS op before a tool is used",
		description: "What toolsetter function should be performed after a tool is loaded",
		type: "enum",
		values:
			[
			{title: "None", id:"none"},
			{title: "Check", id:"check"},
			{title: "Set", id:"set"},
			],
			group:etsGroup,
			value: "set"
	},
	
	etsAfterUse:
	{
		title: "ETS op after a tool is used",
		description: "What toolsetter function should be performed when a tool is returned to the ATC",
		type: "enum",
		values:
			[
			{title: "None", id:"none"},
			{title: "Check", id:"check"},
			{title: "Set", id:"set"},
			],
			group:etsGroup,
			value: "none"
	},
	
	etsAfterOperation:
	{
		title: "ETS op after each machining operation",
		description: "What toolsetter function should be performed after erach machining operation",
		type: "enum",
		values:
			[
			{title: "None", id:"none"},
			{title: "Check", id:"check"},
			{title: "Set", id:"set"},
			],
			group:etsGroup,
			value: "none"
	
	
	},
	
		
	//properties to allow tapping on a PCNC440
	expandTapping: {title:"Expand tapping", description:"Expand tapping code for machines without canned cycle tapping", group:tappingGroup, type:"boolean", value: false},

	tapSpeedFactor: {title:"Tap speed factor", description:"For expanded tapping code only. Spindle speed correction factor for tapping tools.  Leave at 1.0 otherwise", group:tappingGroup, type:"number", value: 1.0},

	spindleReverseChannel: 
	{
		title: "Spindle reversing",
		description: "For expanded tapping code only. Choose M4 for standard spindle reversing, one of the others for reverse controlled by USB I/O module",
		type: "enum",
		values:
			[
			{title: "M4", id:"0"},
			{title: "M3 M64 P0", id:"1"},
			{title: "M3 M64 P1", id:"2"},
			{title: "M3 M64 P2", id:"3"},
			{title: "M3 M64 P3", id:"4"},
			{title: "M3 M64 P4", id:"5"},
			{title: "M3 M64 P5", id:"6"},
			{title: "M3 M64 P6", id:"7"},
			{title: "M3 M64 P7", id:"8"},
			{title: "M3 M64 P8", id:"9"},
			{title: "M3 M64 P9", id:"10"},
			{title: "M3 M64 P10", id:"11"},
			{title: "M3 M64 P11", id:"12"},
			{title: "M3 M64 P12", id:"13"},
			{title: "M3 M64 P13", id:"14"},
			{title: "M3 M64 P14", id:"15"},
			{title: "M3 M64 P15", id:"16"},
			],
			group:tappingGroup,
			value: "0"
	},
	
	// properties to use usb i/o module
	spindleRunningChannel:
	{
		title: "I/O Spindle running",
		description: "Choose USB output channel to indicate spindle running",
		type: "enum",
		values:
			[
			{title: "none", id:"0"},

			{title: "Board 1, output 1", id:"1"},
			{title: "Board 1, output 2", id:"2"},
			{title: "Board 1, output 3", id:"3"},
			{title: "Board 1, output 4", id:"4"},

			{title: "Board 2, output 1", id:"5"},
			{title: "Board 2, output 2", id:"6"},
			{title: "Board 2, output 3", id:"7"},
			{title: "Board 2, output 4", id:"8"},

			{title: "Board 3, output 1", id:"9"},
			{title: "Board 3, output 2", id:"10"},
			{title: "Board 3, output 3", id:"11"},
			{title: "Board 3, output 4", id:"12"},

			{title: "Board 4, output 1", id:"13"},
			{title: "Board 4, output 2", id:"14"},
			{title: "Board 4, output 3", id:"15"},
			{title: "Board 4, output 4", id:"16"},
			],
			group:usbIoGroup,
			value: "0"
	},

	toolChangeInProgressChannel:
	{
		title: "I/O Tool change in progress",
		description: "Choose USB output channel to indicate tool change in progress",
		type: "enum",
		values:
			[
			{title: "none", id:"0"},

			{title: "Board 1, output 1", id:"1"},
			{title: "Board 1, output 2", id:"2"},
			{title: "Board 1, output 3", id:"3"},
			{title: "Board 1, output 4", id:"4"},

			{title: "Board 2, output 1", id:"5"},
			{title: "Board 2, output 2", id:"6"},
			{title: "Board 2, output 3", id:"7"},
			{title: "Board 2, output 4", id:"8"},

			{title: "Board 3, output 1", id:"9"},
			{title: "Board 3, output 2", id:"10"},
			{title: "Board 3, output 3", id:"11"},
			{title: "Board 3, output 4", id:"12"},

			{title: "Board 4, output 1", id:"13"},
			{title: "Board 4, output 2", id:"14"},
			{title: "Board 4, output 3", id:"15"},
			{title: "Board 4, output 4", id:"16"},
			],
			group:usbIoGroup,
			value: "0"
	},

	floodCoolingOnChannel:
	{
		title: "I/O Flood cooling",
		description: "Choose USB output channel to indicate flood cooling is on",
		type: "enum",
		values:
			[
			{title: "none", id:"0"},

			{title: "Board 1, output 1", id:"1"},
			{title: "Board 1, output 2", id:"2"},
			{title: "Board 1, output 3", id:"3"},
			{title: "Board 1, output 4", id:"4"},

			{title: "Board 2, output 1", id:"5"},
			{title: "Board 2, output 2", id:"6"},
			{title: "Board 2, output 3", id:"7"},
			{title: "Board 2, output 4", id:"8"},

			{title: "Board 3, output 1", id:"9"},
			{title: "Board 3, output 2", id:"10"},
			{title: "Board 3, output 3", id:"11"},
			{title: "Board 3, output 4", id:"12"},

			{title: "Board 4, output 1", id:"13"},
			{title: "Board 4, output 2", id:"14"},
			{title: "Board 4, output 3", id:"15"},
			{title: "Board 4, output 4", id:"16"},
			],
			group:usbIoGroup,
			value: "0"
	},

	mistCoolingOnChannel:
	{
		title: "I/O Mist cooling",
		description: "Choose USB output channel to indicate mist cooling is on",
		type: "enum",
		values:
			[
			{title: "none", id:"0"},

			{title: "Board 1, output 1", id:"1"},
			{title: "Board 1, output 2", id:"2"},
			{title: "Board 1, output 3", id:"3"},
			{title: "Board 1, output 4", id:"4"},

			{title: "Board 2, output 1", id:"5"},
			{title: "Board 2, output 2", id:"6"},
			{title: "Board 2, output 3", id:"7"},
			{title: "Board 2, output 4", id:"8"},

			{title: "Board 3, output 1", id:"9"},
			{title: "Board 3, output 2", id:"10"},
			{title: "Board 3, output 3", id:"11"},
			{title: "Board 3, output 4", id:"12"},

			{title: "Board 4, output 1", id:"13"},
			{title: "Board 4, output 2", id:"14"},
			{title: "Board 4, output 3", id:"15"},
			{title: "Board 4, output 4", id:"16"},
			],
			group:usbIoGroup,
			value: "0"
	},

	etsInUseChannel:
	{
		title: "I/O ETS in use",
		description: "Choose USB output channel to indicate ETS is in use",
		type: "enum",
		values:
			[
			{title: "none", id:"0"},

			{title: "Board 1, output 1", id:"1"},
			{title: "Board 1, output 2", id:"2"},
			{title: "Board 1, output 3", id:"3"},
			{title: "Board 1, output 4", id:"4"},

			{title: "Board 2, output 1", id:"5"},
			{title: "Board 2, output 2", id:"6"},
			{title: "Board 2, output 3", id:"7"},
			{title: "Board 2, output 4", id:"8"},

			{title: "Board 3, output 1", id:"9"},
			{title: "Board 3, output 2", id:"10"},
			{title: "Board 3, output 3", id:"11"},
			{title: "Board 3, output 4", id:"12"},

			{title: "Board 4, output 1", id:"13"},
			{title: "Board 4, output 2", id:"14"},
			{title: "Board 4, output 3", id:"15"},
			{title: "Board 4, output 4", id:"16"},
			],
			group:usbIoGroup,
			value: "0"
	},

	etsReadyInput:
	{
		title: "I/O ETS ready for use",
		description: "Choose USB input channel to indicate ETS is ready for use",
		type: "enum",
		values:
			[
			{title: "none", id:"0"},

			{title: "Board 1, input 1", id:"1"},
			{title: "Board 1, input 2", id:"2"},
			{title: "Board 1, input 3", id:"3"},
			{title: "Board 1, input 4", id:"4"},

			{title: "Board 2, input 1", id:"5"},
			{title: "Board 2, input 2", id:"6"},
			{title: "Board 2, input 3", id:"7"},
			{title: "Board 2, input 4", id:"8"},

			{title: "Board 3, input 1", id:"9"},
			{title: "Board 3, input 2", id:"10"},
			{title: "Board 3, input 3", id:"11"},
			{title: "Board 3, input 4", id:"12"},

			{title: "Board 4, input 1", id:"13"},
			{title: "Board 4, input 2", id:"14"},
			{title: "Board 4, input 3", id:"15"},
			{title: "Board 4, input 4", id:"16"},
			],
			group:usbIoGroup,
			value: "0"
	},

	progRunningChannel:
	{
		title: "I/O Program running",
		description: "Choose USB output channel to indicate a g-code program is running",
		type: "enum",
		values:
			[
			{title: "none", id:"0"},

			{title: "Board 1, output 1", id:"1"},
			{title: "Board 1, output 2", id:"2"},
			{title: "Board 1, output 3", id:"3"},
			{title: "Board 1, output 4", id:"4"},

			{title: "Board 2, output 1", id:"5"},
			{title: "Board 2, output 2", id:"6"},
			{title: "Board 2, output 3", id:"7"},
			{title: "Board 2, output 4", id:"8"},

			{title: "Board 3, output 1", id:"9"},
			{title: "Board 3, output 2", id:"10"},
			{title: "Board 3, output 3", id:"11"},
			{title: "Board 3, output 4", id:"12"},

			{title: "Board 4, output 1", id:"13"},
			{title: "Board 4, output 2", id:"14"},
			{title: "Board 4, output 3", id:"15"},
			{title: "Board 4, output 4", id:"16"},
			],
			group:usbIoGroup,
			value: "0"
	},

	probeInUseChannel:
	{
		title: "I/O Probe in use",
		description: "Choose USB output channel to indicate Probe is in use",
		type: "enum",
		values:
			[
			{title: "none", id:"0"},

			{title: "Board 1, output 1", id:"1"},
			{title: "Board 1, output 2", id:"2"},
			{title: "Board 1, output 3", id:"3"},
			{title: "Board 1, output 4", id:"4"},

			{title: "Board 2, output 1", id:"5"},
			{title: "Board 2, output 2", id:"6"},
			{title: "Board 2, output 3", id:"7"},
			{title: "Board 2, output 4", id:"8"},

			{title: "Board 3, output 1", id:"9"},
			{title: "Board 3, output 2", id:"10"},
			{title: "Board 3, output 3", id:"11"},
			{title: "Board 3, output 4", id:"12"},

			{title: "Board 4, output 1", id:"13"},
			{title: "Board 4, output 2", id:"14"},
			{title: "Board 4, output 3", id:"15"},
			{title: "Board 4, output 4", id:"16"},
			],
			group:usbIoGroup,
			value: "0"
	},
	
};

var permittedCommentChars = " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,=_-*#<>";

var nFormat = createFormat({prefix:"N", decimals:0});
var gFormat = createFormat({prefix:"G", decimals:1});
var mFormat = createFormat({prefix:"M", decimals:0});
var hFormat = createFormat({prefix:"H", decimals:0});
var dFormat = createFormat({prefix:"D", decimals:0});
var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var inchFormat = createFormat({decimals:4, forceDecimal:true});
var mmFormat = createFormat({decimals:3, forceDecimal:true});
var rFormat = xyzFormat; // radius
var abcFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
var feedFormat = createFormat({decimals:(unit == MM ? 0 : 1), forceDecimal:true});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var coolantOptionFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3, forceDecimal:true}); // seconds - range 0.001-99999.999
var milliFormat = createFormat({decimals:0}); // milliseconds // range 1-9999
var taperFormat = createFormat({decimals:1, scale:DEG});
var qFormat = createFormat({prefix:"Q", decimals:0});
var pFormat = createFormat({prefix:"P", decimals:0});
var probeAngleFormat = createFormat({decimals:3, forceDecimal:true});

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({onchange:function () {retracted = false;}, prefix:"Z"}, xyzFormat);
var aOutput = createVariable({prefix:"A"}, abcFormat);
var bOutput = createVariable({prefix:"B"}, abcFormat);
var cOutput = createVariable({prefix:"C"}, abcFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var sOutput = createVariable({prefix:"S", force:true}, rpmFormat);
var dOutput = createVariable({}, dFormat);
var coolantOutput = createVariable({}, mFormat);
var spindleOutput = createVariable({}, mFormat);

// circular output
var iOutput = createReferenceVariable({prefix:"I", force:true}, xyzFormat);
var jOutput = createReferenceVariable({prefix:"J", force:true}, xyzFormat);
var kOutput = createReferenceVariable({prefix:"K", force:true}, xyzFormat);

var gMotionModal = createModal({force:true}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange:function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gFeedModeModal = createModal({}, gFormat); // modal group 5 // G93-94
var gUnitModal = createModal({}, gFormat); // modal group 6 // G20-21
var gCycleModal = createModal({force:false}, gFormat); // modal group 9 // G81, ...
var gRetractModal = createModal({force:true}, gFormat); // modal group 10 // G98-99

// formatting and output objects to support probing
var probeMCode = 200;
var gVarBase = 2000;
var pProbeFormat = createFormat({decimals:0});
var pProbeOutput = createVariable({prefix:"P", force:true}, pProbeFormat);
var probe100Format = createFormat({decimals:3, zeropad:true, width:3, forceDecimal:true});
var gvarFormat = createFormat({decimals:0});
var gvarOutput = createVariable({prefix:"#", force:true}, gvarFormat);

var WARNING_WORK_OFFSET = 0;
var MAX_WORK_OFFSET = 500;

// collected state
var sequenceNumber;
var currentWorkOffset;
var currentCoolantMode = COOLANT_OFF;
var coolantZHeight = 9999.0;
var masterAxis;
var movementType;
var retracted = false; // specifies that the tool has been retracted to the safe plane

// variables to control the component and feature nos. for inspection routines.
var probeOutputWorkOffset = 1;
var inspectionHeaderWritten = false;
var inspectionRunning=false;
var inspectPartno=1;
var inspectFeatureno=1;

var optionalSection = false;

var g64Active = false; // MCJ

function formatSequenceNumber() {
  if (sequenceNumber > 99999) {
    sequenceNumber = getProperty("sequenceNumberStart");
  }
  var seqno = nFormat.format(sequenceNumber);
  sequenceNumber += getProperty("sequenceNumberIncrement");
  return seqno;
}

/**
  Writes the specified block.
*/
function writeBlock() 
{
	var text = formatWords(arguments);

  	if (!text) 
    	return;
  
  	if (getProperty("showSequenceNumbers")) 
  	{
		if (optionalSection)
			writeWords("/", formatSequenceNumber(), text);
		else
		{
			writeWords2(formatSequenceNumber(), arguments);
			sequenceNumber += getProperty("sequenceNumberIncrement");
		}
  	} 
  	else 
  	{
		if (optionalSection)
			writeWords("/", text);
    	else
			writeWords(text);
  	}
}

function formatSubroutineCall(funcName)
{
	return "o<" + "f360_" + funcName + "> call";
}

function formatParameter(parmVal)
{
	return "[" + parmVal + "]";
}

function formatComment(text) {
  return("(" + filterText(String(text), permittedCommentChars) + ")");
}

/**
  Output a comment.
*/
function writeComment(text) {
  writeln(formatComment(text));
}

function writeCommentSeqno(text) {
  writeln(formatSequenceNumber() + formatComment(text));
}

/**
  Compare a text string to acceptable choices.

  Returns -1 if there is no match.
*/
function parseChoice() {
  for (var i = 1; i < arguments.length; ++i) {
    if (String(arguments[0]).toUpperCase() == String(arguments[i]).toUpperCase()) {
      return i - 1;
    }
  }
  return -1;
}

function UseToolWithETS(tool)
{
	var toolTypeName = getToolTypeName(tool.type);
	// don't attempt to measure probes
	if (toolTypeName == "antasten")
	{
		writeComment("Skipping ETS functions for tool " + tool.number + ", antasten");
		return false;
	}
	
	if (toolTypeName == "spot drill" || toolTypeName == "drill")
		return true;

	// don't attempt to check tools that are too big for the ets
	if (tool.diameter > (unit == MM ? 25.4 : 1) * getProperty("etsDiameterLimit"))
	{
		writeComment("Skipping ETS functions for tool " + tool.number + ", " + toolTypeName + ", too big for the tool setter");
		return false;
	}
	
	return true;
}

function TurnOutputOn(channel)
{
	if (channel != "0")
		writeBlock(mFormat.format(64), pFormat.format(channel - 1));
}

function TurnOutputOff(channel)
{
	if (channel != "0")
		writeBlock(mFormat.format(65), pFormat.format(channel - 1));
}

function WaitForInputON(channel)
{
	if (channel != "0")
		writeBlock(mFormat.format(66), pFormat.format(channel - 1), "L3", "Q10000");
}

function CheckCurrentTool(tool)
{
	if (UseToolWithETS(tool))
	{
		writeComment("Use ETS to check length of tool " + tool.number)
		onCommand(COMMAND_COOLANT_OFF);
		onCommand(COMMAND_STOP_SPINDLE);
	
		TurnOutputOn(getProperty("etsInUseChannel"));
		WaitForInputON(getProperty("etsReadyInput"));
		writeBlock(gFormat.format(37), "P" + xyzFormat.format((unit == MM ? 25.4 : 1) * getProperty("etsTolerance")));
		TurnOutputOff(getProperty("etsInUseChannel"));
	}
}

function SetCurrentTool(tool)
{
	if (UseToolWithETS(tool))
	{
		writeComment("Use ETS to set length of tool " + tool.number)
		onCommand(COMMAND_COOLANT_OFF);
		onCommand(COMMAND_STOP_SPINDLE);
	
		TurnOutputOn(getProperty("etsInUseChannel"));
		WaitForInputON(getProperty("etsReadyInput"));
		writeBlock(mFormat.format(300));
		writeBlock(gFormat.format(43), hFormat.format(tool.number));
		TurnOutputOff(getProperty("etsInUseChannel"));
		}
}

function IsLiveTool(tool)
{
	// would love to implement it like this if Autodesk would sort out the logic in the library manager!
	//return tool.liveTool;
	return getToolTypeName(tool.type) != "antasten";
}

function onOpen() 
{
	// install my expand tapping handler
	expandTapping = myExpandTapping;

	if (getProperty("useRadius")) 
	{
		maximumCircularSweep = toRad(90); // avoid potential center calculation errors for CNC
	}

	if (getProperty("sequenceNumberOperation")) 
	{
		setProperty("showSequenceNumbers", false);
	}

	// Define rotary attributes from properties
	var rotary = parseChoice(getProperty("rotaryTableAxis"), "-Z", "-Y", "-X", "NONE", "X", "Y", "Z");
	if (rotary < 0) 
	{
		error(localize("Valid rotaryTableAxis values are: None, X, Y, Z, -X, -Y, -Z"));
		return;
	}
	rotary -= 3;

	// Define Master (carrier) axis
	masterAxis = Math.abs(rotary) - 1;
	if (masterAxis >= 0) 
	{
		var rotaryVector = [0, 0, 0];
		rotaryVector[masterAxis] = rotary/Math.abs(rotary);
		var aAxis = createAxis({coordinate:0, table:true, axis:rotaryVector, cyclic:true, preference:0});
		machineConfiguration = new MachineConfiguration(aAxis);

		setMachineConfiguration(machineConfiguration);
		// Single rotary does not use TCP mode
		optimizeMachineAngles2(1); // 0 = TCP Mode ON, 1 = TCP Mode OFF
	}

	if (!machineConfiguration.isMachineCoordinate(0)) 
	{
		aOutput.disable();
	}

	if (!machineConfiguration.isMachineCoordinate(1)) 
	{
		bOutput.disable();
	}

	if (!machineConfiguration.isMachineCoordinate(2)) 
	{
		cOutput.disable();
	}
  
	if (!getProperty("separateWordsWithSpace")) 
	{
		setWordSeparator("");
	}

	sequenceNumber = getProperty("sequenceNumberStart");

	writeln("%");
	if (programName) 
	{
		writeComment(programName);
	}

	if (programComment) 
	{
		writeComment(programComment);
	}

	if (getProperty("writeVersion")) 
	{
		if (typeof getHeaderVersion == "function" && getHeaderVersion()) 
		{
			writeComment(localize("post version") + ": " + getHeaderVersion());
		}
		if (typeof getHeaderDate == "function" && getHeaderDate()) 
		{
			writeComment(localize("post modified") + ": " + getHeaderDate());
		}
	}

	// dump machine configuration
	var vendor = machineConfiguration.getVendor();
	var model = machineConfiguration.getModel();
	var description = machineConfiguration.getDescription();

	if (getProperty("writeMachine") && (vendor || model || description)) 
	{
		writeComment(localize("Machine"));
		if (vendor) 
		{
			writeComment("  " + localize("vendor") + ": " + vendor);
		}
		if (model) 
		{
			writeComment("  " + localize("model") + ": " + model);
		}
		if (description) 
		{
			writeComment("  " + localize("description") + ": "  + description);
		}
	}

	// dump tool information
	if (getProperty("writeTools"))
	{
		var zRanges = {};
		if (is3D()) 
		{
			var numberOfSections = getNumberOfSections();
			for (var i = 0; i < numberOfSections; ++i) 
			{
				var section = getSection(i);
				var zRange = section.getGlobalZRange();
				var tool = section.getTool();

				if (zRanges[tool.number]) 
					zRanges[tool.number].expandToRange(zRange);
				else 
					zRanges[tool.number] = zRange;
			}
		}

		var tools = getToolTable();
		if (tools.getNumberOfTools() > 0) 
		{
			writeComment("Tool table");
			for (var i = 0; i < tools.getNumberOfTools(); ++i) 
			{
				var tool = tools.getTool(i);
				var comment = "T" + toolFormat.format(tool.number) + "  " +
					"D=" + xyzFormat.format(tool.diameter) + " " +
				localize("CR") + "=" + xyzFormat.format(tool.cornerRadius);
				if ((tool.taperAngle > 0) && (tool.taperAngle < Math.PI)) 
				{
					comment += " " + localize("TAPER") + "=" + taperFormat.format(tool.taperAngle) + localize("deg");
				}
				if (zRanges[tool.number]) 
				{
					comment += " - " + localize("ZMIN") + "=" + xyzFormat.format(zRanges[tool.number].getMinimum());
				}
				comment += " - " + getToolTypeName(tool.type);
				writeComment(comment);
			}
			writeComment("Tool table end");
		}
	}

	
	if (false) 
	{
		// check for duplicate tool number
		for (var i = 0; i < getNumberOfSections(); ++i) 
		{
			var sectioni = getSection(i);
			var tooli = sectioni.getTool();
			for (var j = i + 1; j < getNumberOfSections(); ++j) 
			{
				var sectionj = getSection(j);
				var toolj = sectionj.getTool();
				if (tooli.number == toolj.number) 
				{
					if (xyzFormat.areDifferent(tooli.diameter, toolj.diameter) ||
						xyzFormat.areDifferent(tooli.cornerRadius, toolj.cornerRadius) ||
						abcFormat.areDifferent(tooli.taperAngle, toolj.taperAngle) ||
						(tooli.numberOfFlutes != toolj.numberOfFlutes)) 
					{
						error(subst(
							localize("Using the same tool number for different cutter geometry for operation '%1' and '%2'."),
							sectioni.hasParameter("operation-comment") ? sectioni.getParameter("operation-comment") : ("#" + (i + 1)),
							sectionj.hasParameter("operation-comment") ? sectionj.getParameter("operation-comment") : ("#" + (j + 1))
							));
						return;
					}
				}
			}
		}
	}

	if ((getNumberOfSections() > 0) && (getSection(0).workOffset == 0)) 
	{
		for (var i = 0; i < getNumberOfSections(); ++i) 
		{
			if (getSection(i).workOffset > 0) 
			{
				error(localize("Using multiple work offsets is not possible if the initial work offset is 0."));
				return;
			}
		}
	}

	// absolute coordinates and feed per min
	// ADD gFormat.format(50) to the line below if this is a Tormach machine! -- MCJ
	writeBlock(gAbsIncModal.format(90), gFormat.format(54), gFormat.format(64), gPlaneModal.format(17), gFormat.format(40), gFormat.format(80), gFeedModeModal.format(94), gFormat.format(91.1), gFormat.format(49));

	switch (unit) 
	{
	case IN:
		writeBlock(gUnitModal.format(20), formatComment(localize("Inch")));
		break;
	case MM:
		writeBlock(gUnitModal.format(21), formatComment(localize("Metric")));
		break;
	}
  
	// at the start, we are not necessarily retracted
	retracted = false;

	// optional retract before start of program
	UserRetract(getProperty("retractOnProgramBegin"), "before start of program", false);

	// write probing variables
	writeComment("Probing control variables");
	writeBlock("#<_probeFastSpeed>=", xyzFormat.format((unit == MM ? 25.4 : 1) * getProperty("probeFastSpeed")));
	writeBlock("#<_probeSlowSpeed>=", xyzFormat.format((unit == MM ? 25.4 : 1) * getProperty("probeSlowSpeed")));
	writeBlock("#<_probeSlowDistance>=", xyzFormat.format((unit == MM ? 25.4 : 1) * getProperty("probeSlowDistance")));

	// turn on the g-code running output
	TurnOutputOn(getProperty("progRunningChannel"));

	if (getProperty("etsBeforeStart") != "none")
	{
		// some ets function requested before start of program
		writeComment("Use ETS to " + getProperty("etsBeforeStart") + " tools before start of run");
		var tools = getToolTable();
		for (var i = 0; i < tools.getNumberOfTools(); ++i) 
		{
			// fetch the tool we are going to check
			var tool = tools.getTool(i);

			// check if this tool can be used
			if (!UseToolWithETS(tool))
				continue;
			
			LoadTool(tool.number, tool.number);
//			writeComment("Load tool " + tool.number);
//			UserRetract(getProperty("retractOnTCBegin"), "prior to toolchange", true);
//			writeBlock("T" + toolFormat.format(tool.number), gFormat.format(43), hFormat.format(tool.number), mFormat.format(6));
//			onDwell(1.0);
//			UserRetract(getProperty("retractOnTCEnd"), "after tool change", false);

			switch (getProperty("etsBeforeStart"))
			{
			case "set":
				SetCurrentTool(tool);
				break;
				
			case "check":
				CheckCurrentTool(tool);
				break;
			}
		}
	}
  
	writeComment("End of pre-amble")

}

function WriteInspectionHeader()
{
	writeComment("LOGAPPEND,inspection.txt");
	writeComment("LOG,program=" + programName);
	writeComment("LOG,timestamp=#<_epochtime>")
	writeComment("LOG,comment=" + programComment);
	writeComment("LOG,unit=" + ((unit == MM) ? "mm" : "inch"));
	writeComment("LOGCLOSE");
	inspectionHeaderWritten = true;
}

function DoStartInspection()
{
	writeln("");
	writeComment("Starting inspection")

	// don't write 2 inspection headers
	if (!inspectionHeaderWritten)
	{
		WriteInspectionHeader();
		inspectPartno = 1;
		inspectFeatureno = 1;
	}

	inspectionRunning = true;
}

function DoStopInspection()
{
	writeln("");
	writeComment("Inspection stopped")
	inspectionRunning = false;
}

function DoInspectionCommand(command)
{
	switch (command)
	{
		case "start":
		case "on":
		case "begin":
			DoStartInspection();
			break;

		case "stop":
		case "off":
		case "end":
			DoStopInspection();
			break;

		default:
			error("Unknown Inspection command - " + command);
		}
}

function OnManualAction(command)
{
	var commands = String(command).toLowerCase().split(/[,= ]+/);

	if (commands[0] == "inspection")
		DoInspectionCommand(commands[1])
	else
		error("Unknown MaualNC action - " + command);

}

// handler for all ManualNC sections
function onManualNC(command, value)
{
	switch (command)
	{
	case COMMAND_ACTION:
		// pick up Action manualNC
		OnManualAction(value);
		break;

	case COMMAND_DISPLAY_MESSAGE:
		writeln("");
		writeComment("MSG," + value);
		break;

	default:
		// default handling for all other manual nc
		expandManualNC(command, value);
	}
}

var lastComment;

function onComment(message) 
{
  	var comments = String(message).split(";");
  	for (comment in comments) 
  	{
		lastComment = comments[comment];
    	writeComment(lastComment);
  	}
}

/** Force output of X, Y, and Z. */
function  forceXYZ()
{
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

/** Force output of A, B, and C. */
function forceABC() {
  aOutput.reset();
  bOutput.reset();
  cOutput.reset();
}

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {
  forceXYZ();
  forceABC();
  previousDPMFeed = 0;
  feedOutput.reset();
}

var currentWorkPlaneABC = undefined;

function forceWorkPlane() {
  currentWorkPlaneABC = undefined;
}

function setWorkPlane(abc) {
  if (!machineConfiguration.isMultiAxisConfiguration()) {
    return; // ignore
  }

  if (!((currentWorkPlaneABC == undefined) ||
        abcFormat.areDifferent(abc.x, currentWorkPlaneABC.x) ||
        abcFormat.areDifferent(abc.y, currentWorkPlaneABC.y) ||
        abcFormat.areDifferent(abc.z, currentWorkPlaneABC.z))) {
    return; // no change
  }

  onCommand(COMMAND_UNLOCK_MULTI_AXIS);

  // NOTE: add retract here

  writeBlock(
    gMotionModal.format(0),
    conditional(machineConfiguration.isMachineCoordinate(0), "A" + abcFormat.format(abc.x)),
    conditional(machineConfiguration.isMachineCoordinate(1), "B" + abcFormat.format(abc.y)),
    conditional(machineConfiguration.isMachineCoordinate(2), "C" + abcFormat.format(abc.z))
  );
  
  onCommand(COMMAND_LOCK_MULTI_AXIS);

  currentWorkPlaneABC = abc;
  //setCurrentABC(abc);
}

var closestABC = true; // choose closest machine angles
var currentMachineABC;

function getWorkPlaneMachineABC(workPlane) 
{
  	var W = workPlane; // map to global frame

  	var abc = machineConfiguration.getABC(W);
	if (closestABC) 
	{
		if (currentMachineABC) 
		{
      		abc = machineConfiguration.remapToABC(abc, currentMachineABC);
		} 
		else 
		{
      		abc = machineConfiguration.getPreferredABC(abc);
    	}
	} 
	else 
	{
    	abc = machineConfiguration.getPreferredABC(abc);
  	}
  
	try 
	{
    	abc = machineConfiguration.remapABC(abc);
    	currentMachineABC = abc;
	} 
	catch (e)
	{
    	error(
			localize("Machine angles not supported") + ":"
			+ conditional(machineConfiguration.isMachineCoordinate(0), " A" + abcFormat.format(abc.x))
			+ conditional(machineConfiguration.isMachineCoordinate(1), " B" + abcFormat.format(abc.y))
			+ conditional(machineConfiguration.isMachineCoordinate(2), " C" + abcFormat.format(abc.z))
			);
	}
  
  	var direction = machineConfiguration.getDirection(abc);
	if (!isSameDirection(direction, W.forward)) 
	{
    	error(localize("Orientation not supported."));
  	}
	  
	if (!machineConfiguration.isABCSupported(abc)) 
	{
    	error(
		localize("Work plane is not supported") + ":"
		+ conditional(machineConfiguration.isMachineCoordinate(0), " A" + abcFormat.format(abc.x))
		+ conditional(machineConfiguration.isMachineCoordinate(1), " B" + abcFormat.format(abc.y))
		+ conditional(machineConfiguration.isMachineCoordinate(2), " C" + abcFormat.format(abc.z))
		);
  	}

  	var tcp = false;
  	cancelTransformation();
	if (tcp)
	{
    	setRotation(W); // TCP mode
	}
	else
	{
    	var O = machineConfiguration.getOrientation(abc);
    	var R = machineConfiguration.getRemainingOrientation(abc, W);
    	var rotate = true;
    	var axis = machineConfiguration.getAxisU();
		if (axis.isEnabled() && axis.isTable())
		{
      		var ix = axis.getCoordinate();
      		var rotAxis = axis.getAxis();
      		if (isSameDirection(machineConfiguration.getDirection(abc), rotAxis) ||
				  isSameDirection(machineConfiguration.getDirection(abc), Vector.product(rotAxis, -1)))
			{
        		var direction = isSameDirection(machineConfiguration.getDirection(abc), rotAxis) ? 1 : -1;
        		abc.setCoordinate(ix, Math.atan2(R.right.y, R.right.x) * direction);
        		rotate = false;
      		}
    	}
		if (rotate)
		{
      		setRotation(R);
    	}
  	}
  	return abc;
}
var measureToolRequested = false;

function LoadTool(toolNumber, toolLengthOffset)
{
	writeComment("Loading tool " + toolNumber + " with offset " + toolLengthOffset);
	// change tool
	UserRetract(getProperty("retractOnTCBegin"), "prior to toolchange", true);
	TurnOutputOn(getProperty("toolChangeInProgressChannel"));

	if (getProperty("useM19")) 
	{
		writeBlock(mFormat.format(19),"R0"),
		writeBlock("T" + toolFormat.format(toolNumber),
		gFormat.format(43),
		hFormat.format(toolLengthOffset),
		mFormat.format(6));
	} 
	else 
	{
		writeBlock("T" + toolFormat.format(toolNumber),
		gFormat.format(43),
		hFormat.format(toolLengthOffset),
		mFormat.format(6));
	}

	TurnOutputOff(getProperty("toolChangeInProgressChannel"));
	UserRetract(getProperty("retractOnTCEnd"), "after toolchange", false);
}

function ChangeToTool(tool)
{
	forceWorkPlane();
	onCommand(COMMAND_COOLANT_OFF);
	onCommand(COMMAND_STOP_SPINDLE);

	if (tool.number > getProperty("maxTool")) 
	{
		warning(localize("Tool number exceeds maximum value."));
	}

	var lengthOffset = tool.lengthOffset;
	if (lengthOffset > getProperty("maxTool")) 
	{
		error(localize("Length offset out of range."));
		return;
	}

	// time to check the outgoing tool
	// ETS check of outgoing tool
	if (!isFirstSection())
	{
		var previousTool = getPreviousSection().getTool();
		switch (getProperty("etsAfterUse"))
		{
			case "check":
				CheckCurrentTool(previousTool);
				break;
			
			case "set":
				SetCurrentTool(previousTool);
				break;
		}
	}

	// change tool
	LoadTool(tool.number, lengthOffset);

	// time to do ets processing for the new tool
	switch (getProperty("etsBeforeUse"))
	{
		case "check":
			CheckCurrentTool(tool);
			break;
	
		case "set":
			SetCurrentTool(tool);
			break;
	}

	if (tool.comment) 
	{
		writeComment(tool.comment);
	}

	var showToolZMin = false;
	if (showToolZMin) 
	{
		if (is3D()) 
		{
			var numberOfSections = getNumberOfSections();
			var zRange = currentSection.getGlobalZRange();
			var number = tool.number;
			for (var i = currentSection.getId() + 1; i < numberOfSections; ++i) 
			{
				var section = getSection(i);
				if (section.getTool().number != number) 
				{
					break;
				}
				zRange.expandToRange(section.getGlobalZRange());
			}
			writeComment(localize("ZMIN") + "=" + zRange.getMinimum());
		}
	}
} // ChangeToTool


function onSection() 
{
	// remember if the current section is optional
	optionalSection = currentSection.isOptional();

	lastComment = null;
	// are we changing the tool ?
	var insertToolCall = isFirstSection() ||
		currentSection.getForceToolChange && currentSection.getForceToolChange() ||
		(tool.number != getPreviousSection().getTool().number);
  
//	retracted = false; // specifies that the tool has been retracted to the safe plane
	
	// are we changing the WCS
	var newWorkOffset = isFirstSection() ||
		(getPreviousSection().workOffset != currentSection.workOffset); // work offset changes
  
	// are we changing the work plane
	var newWorkPlane = isFirstSection() ||
		!isSameDirection(getPreviousSection().getGlobalFinalToolAxis(), currentSection.getGlobalInitialToolAxis()) ||
		(currentSection.isOptimizedForMachine() && getPreviousSection().isOptimizedForMachine() &&
		Vector.diff(getPreviousSection().getFinalToolAxisABC(), currentSection.getInitialToolAxisABC()).length > 1e-4) ||
		(!machineConfiguration.isMultiAxisConfiguration() && currentSection.isMultiAxis()) ||
		(!getPreviousSection().isMultiAxis() && currentSection.isMultiAxis() ||
		getPreviousSection().isMultiAxis() && !currentSection.isMultiAxis()); // force newWorkPlane between indexing and simultaneous operations

	if (insertToolCall || newWorkOffset || newWorkPlane) 
	{
		if (!isFirstSection() && !insertToolCall)
		{
//			if (newWorkOffset)
//				UserRetract(getProperty("retractOnWCSChange"), "new WCS", false);
		
//			if (newWorkPlane)
//				UserRetract(getProperty("retractOnWorkPlaneChange"), "new work plane", false);
		}
			
		forceWorkPlane();
	}
	
	writeln("");

	if (hasParameter("operation-comment")) 
	{
		var comment = getParameter("operation-comment");
		if (comment) 
		{
			if (getProperty("sequenceNumberOperation")) 
			{
				writeCommentSeqno(comment);
			} 
			else 
			{
				writeComment(comment);
			}
		}
	}

	// optional stop
	if (!isFirstSection() && ((insertToolCall && getProperty("optionalStopTool")) || getProperty("optionalStopOperation")))
	{
		onCommand(COMMAND_OPTIONAL_STOP);
	}

	// tool change
	if (insertToolCall) 
		ChangeToTool(tool);

	// manual nc requested tool measure
	if (measureToolRequested)
	{
		writeComment("Tool measure requested by ManulNC");
		measureToolRequested = false;
		SetCurrentTool(tool);
	}

	// Define coolant code
	var topOfPart = undefined;
	if (hasParameter("operation:surfaceZHigh")) 
	{
		topOfPart = getParameter("operation:surfaceZHigh"); // TAG: not safe
	}

	// set the coolant
	// don't attempt to set coolant for probes or non live tools
	if (IsLiveTool(tool) && getToolTypeName(tool.type) != "antasten")
	{
		var c = setCoolant(tool.coolant, topOfPart);
		writeBlock(c[0], c[1], c[2], c[3]);
	}
	else
		onCommand(COMMAND_COOLANT_OFF);

	// now set the spindle
	if (true ||
		insertToolCall ||
		isFirstSection() ||
		(rpmFormat.areDifferent(spindleSpeed, sOutput.getCurrent())) ||
		(tool.clockwise != getPreviousSection().getTool().clockwise)) 
	{
		if (spindleSpeed < 0) 
		{
			error(localize("Spindle speed out of range."));
			return;
		}

		if (spindleSpeed > 99999) 
		{
			warning(localize("Spindle speed exceeds maximum value."));
		}

		// would love to do this check, but Fusion 360 currently flags warnings if you set the spindle speed to 0 - even if it's a live tool
		// error if nonlivetool has non zero spindle speed
		if (!IsLiveTool(tool) && spindleSpeed > 0)
		{
			error("Non-zero spindle speed specified for non-live tool, tool number " + tool.number + ", " + getToolTypeName(tool.type));
			return;
		}

		if (!IsLiveTool(tool) || spindleSpeed == 0) 
		{
			onCommand(COMMAND_STOP_SPINDLE);
		} 
		else 
		{
			writeBlock(sOutput.format(spindleSpeed));
			onCommand(tool.clockwise ? COMMAND_SPINDLE_CLOCKWISE : COMMAND_SPINDLE_COUNTERCLOCKWISE);
			if ((spindleSpeed > 5000) && properties.waitForSpindle) 
			{
				onDwell(properties.waitForSpindle);
			}
		}
	} // set spindle

	// wcs
	if (insertToolCall && getProperty("forceWorkOffset")) 
	{ 
		// force work offset when changing tool
		currentWorkOffset = undefined;
	}

	var workOffset = currentSection.workOffset;
	if (workOffset == 0) 
	{
		warningOnce(localize("Work offset has not been specified. Using G54 as WCS."), WARNING_WORK_OFFSET);
		workOffset = 1;
	}

	if (!isFirstSection())
	{
		if (newWorkOffset)
			UserRetract(getProperty("retractOnWCSChange"), "new WCS", false);
	
		if (newWorkPlane)
			UserRetract(getProperty("retractOnWorkPlaneChange"), "new work plane", false);
	}

	if (workOffset > 0) 
	{
		var p = workOffset; // 1->... // G59 P1 is the same as G54 and so on
		if (p > MAX_WORK_OFFSET)
		{
			error(localize("Work offset out of range."));
			return;
		}

		if (workOffset != currentWorkOffset) 
		{
			if (p > 9) 
			{
				// new format for PathPilot V2.3.4 onward - G54.1 Pxxx
				writeBlock(gFormat.format(54.1), pFormat.format(workOffset));
			}
			else if (p > 6) 
			{
				// G59.xxx
				p = 59 + ((p - 6)/10.0);
				writeBlock(gFormat.format(p)); // G59.x
			} 
			else
			{
				// G54 .. G59
				writeBlock(gFormat.format(53 + workOffset)); // G54->G59
			}
			currentWorkOffset = workOffset;
		}
	}

	forceXYZ();

	if (machineConfiguration.isMultiAxisConfiguration()) 
	{ // use 5-axis indexing for multi-axis mode
		// set working plane after datum shift

		var abc = new Vector(0, 0, 0);
		if (currentSection.isMultiAxis()) 
		{
			forceWorkPlane();
			cancelTransformation();
			abc = currentSection.getInitialToolAxisABC();
		} 
		else 
		{
			abc = getWorkPlaneMachineABC(currentSection.workPlane);
		}
		
		setWorkPlane(abc);
	} 
	else 
	{ // pure 3D
		var remaining = currentSection.workPlane;
		if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) 
		{
			error(localize("Tool orientation is not supported."));
			return;
		}
		setRotation(remaining);
	}

	forceAny();
	gMotionModal.reset();

	var initialPosition = getFramePosition(currentSection.getInitialPosition());
	if (!retracted && !insertToolCall) 
	{
		if (getCurrentPosition().z < initialPosition.z) 
		{
			writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
		}
	}

	  // MCJ - Enable per-op G64 values based on operation tolerance
	if (hasParameter("operation-strategy") && (getParameter("operation-strategy") != "drill")) {
		if (properties.useOpToleranceAsG64) {
		  if (!g64Active) {
			writeBlock(gFormat.format(64), "P" + xyzFormat.format(getParameter("operation:tolerance")));
			g64Active = true;
		  }
		} else {
		  if (g64Active) {
			writeBlock(gFormat.format(61));
			g64Active = false;
		  }
		}
	  }
	  // MCJ - Added output of Fusion360/HSM Notes (custom G-code blocks in CAM) to comments which will pop up 
	  // messages in LinuxCNC if configured correctly. Useful for non-ATC machines with ETS where you need 
	  // a popup to help avoid loading the wrong tool
	  
	if (properties.showNotes && hasParameter("notes")) {
		var notes = getParameter("notes");
		if (notes) {
		  var lines = String(notes).split("\n");
		  var r1 = new RegExp("^[\\s]+", "g");
		  var r2 = new RegExp("[\\s]+$", "g");
		  for (line in lines) {
			var comment = lines[line].replace(r1, "").replace(r2, "");
			if (comment) {
			  writeComment(comment);
			}
		  }
		}
	  }

	if (!insertToolCall && retracted) 
	{ // G43 already called above on tool change
		var lengthOffset = tool.lengthOffset;
		if (lengthOffset > getProperty("maxTool")) 
		{
			error(localize("Length offset out of range."));
			return;
		}

		gMotionModal.reset();
		writeBlock(gPlaneModal.format(17));
	
		if (!machineConfiguration.isHeadConfiguration()) 
		{
			writeBlock(
			gAbsIncModal.format(90),
			gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y));
		
			writeBlock(gMotionModal.format(0), gFormat.format(43), zOutput.format(initialPosition.z), hFormat.format(lengthOffset));
		} 
		else 
		{
			writeBlock(
				gAbsIncModal.format(90),
				gMotionModal.format(0),
				gFormat.format(43), xOutput.format(initialPosition.x),
				yOutput.format(initialPosition.y),
				zOutput.format(initialPosition.z), hFormat.format(lengthOffset)
				);
		}
 	} 
 	else 
 	{
		writeBlock(
      		gAbsIncModal.format(90),
      		gMotionModal.format(0),
      		xOutput.format(initialPosition.x),
			yOutput.format(initialPosition.y)
			);
 	}
}

// allow manual insertion of comma delimited g-code
function onPassThrough(text) 
{
  	var commands = String(text).split(",");
	for (text in commands) 
	{
    	writeBlock(commands[text]);
  	}
}

function onDwell(seconds) 
{
	if (seconds > 99999.999) 
		warning(localize("Dwelling time is out of range."));

	if (getProperty("dwellInSeconds")) 
		writeBlock(gFormat.format(4), "P" + secFormat.format(seconds));
	else 
	{
		milliseconds = clamp(1, seconds * 1000, 99999999);
		writeBlock(gFormat.format(4), "P" + milliFormat.format(milliseconds));
	}
}

function onSpindleSpeed(spindleSpeed) 
{
  writeBlock(sOutput.format(spindleSpeed));
}

function setCoolant(coolant, topOfPart) 
{
	var coolCodes = ["", "", "", ""];
	coolantZHeight = 9999.0;
	var coolantCode = 9;

	if (getProperty("disableCoolant")) 
	{
		return coolCodes;
	}
  
	// Smart coolant is not enabled
	if (!getProperty("smartCoolEquipped")) 
	{
		if (coolant == COOLANT_OFF) 
		{
			coolantCode = 9;
		} 
		else 
		{
			coolantCode = 7; // default all coolant modes to flood
			if (coolant != COOLANT_MIST) 
			{
				warning(localize("Unsupported coolant setting. Defaulting to FLOOD."));
			}
		}
		
		coolCodes[0] = coolantOutput.format(coolantCode);
		//mFormat.format(coolantCode);
	} 
	else 
	{ // Smart coolant is enabled
		// must drive the output because of additional words to configure smart cool
		coolantOutput.reset();
		if ((coolant == COOLANT_MIST) || (coolant == COOLANT_AIR)) 
		{
			coolantCode = 7;
			coolCodes[0] = coolantOutput.format(coolantCode);
			// coolCodes[0] = mFormat.format(coolantCode);
		} 
		else if (coolant == COOLANT_FLOOD_MIST) 
		{ // flood with air blast
			coolantCode = 8;
			coolCodes[0] = coolantOutput.format(coolantCode);
			// coolCodes[0] = mFormat.format(coolantCode);
			if (getProperty("multiCoolEquipped")) 
			{
				if (getProperty("multiCoolAirBlastSeconds") != 0) 
				{
					coolCodes[3] = qFormat.format(getProperty("multiCoolAirBlastSeconds"));
				}
			} 
			else 
			{
				warning(localize("COOLANT_FLOOD_MIST programmed without Multi-Coolant support. Defaulting to FLOOD."));
			}
		} 
		else if (coolant == COOLANT_OFF) 
		{
			coolantCode = 9;
			coolCodes[0] = coolantOutput.format(coolantCode);
			// coolCodes[0] = mFormat.format(coolantCode);
		} 
		else 
		{
			coolantCode = 8;
			coolCodes[0] = coolantOutput.format(coolantCode);
			//coolCodes[0] = mFormat.format(coolantCode);
			if (coolant != COOLANT_FLOOD) 
			{
				warning(localize("Unsupported coolant setting. Defaulting to FLOOD."));
			}
		}

		// Determine Smart Coolant location based on machining operation
		if (hasParameter("operation-strategy")) 
		{
			var strategy = getParameter("operation-strategy");
			if (strategy) 
			{
				// Drilling strategy. Keep coolant at top of part
				if (strategy == "drill") 
				{
					if (topOfPart != undefined) 
					{
						coolantZHeight = topOfPart;
						coolCodes[1] = "E" + xyzFormat.format(coolantZHeight);
					}

					// Tool end point milling. Keep coolant at end of tool
				} 
				else if ((strategy == "face") ||
					(strategy == "engrave") ||
                   	(strategy == "contour_new") ||
                   	(strategy == "horizontal_new") ||
                   	(strategy == "parallel_new") ||
                   	(strategy == "scallop_new") ||
                   	(strategy == "pencil_new") ||
                   	(strategy == "radial_new") ||
                   	(strategy == "spiral_new") ||
                   	(strategy == "morphed_spiral") ||
                   	(strategy == "ramp") ||
                   	(strategy == "project")) 
				{
					coolCodes[1] = "P" + coolantOptionFormat.format(0);

					// Side Milling. Sweep the coolant along the length of the tool
				} 
				else 
				{
					coolCodes[1] = "P" + coolantOptionFormat.format(0);
					coolCodes[2] = "R" + xyzFormat.format(tool.fluteLength * (getProperty("smartCoolToolSweepPercentage") / 100.0));
				}
			}
		}
	}

	// sort out the io module for the selected collant mode
	switch (coolantCode)
	{
		case 7:
			// mist coolant
			TurnOutputOn(getProperty("mistCoolingOnChannel"));
			TurnOutputOff(getProperty("floodCoolingOnChannel"));
			break;
			
		case 8:
			// flood coolant
			TurnOutputOn(getProperty("floodCoolingOnChannel"));
			TurnOutputOff(getProperty("mistCoolingOnChannel"));
			break;
			
		case 9:
			// no coolant
			TurnOutputOff(getProperty("floodCoolingOnChannel"));
			TurnOutputOff(getProperty("mistCoolingOnChannel"));
			break;
	}
	
	currentCoolantMode = coolant;
	return coolCodes;
}

function onCycle() 
{
	 writeBlock(gPlaneModal.format(17));
}

function getCommonCycle(x, y, z, r) 
{
	forceXYZ();
	return [xOutput.format(x), yOutput.format(y),
		zOutput.format(z),
		"R" + xyzFormat.format(r)];
}


function expandTappingPoint(x, y, z) 
{
	onExpandedRapid(x, y, cycle.clearance);
	onExpandedLinear(x, y, z, cycle.feedrate);
	onExpandedLinear(x, y, cycle.clearance, cycle.feedrate * getProperty("reversingHeadFeed"));
}

// some functions to support probing operations
/* Convert approach to sign. */
function approach(value)
{
  validate((value == "positive") || (value == "negative"), "Invalid approach.");
  return (value == "positive") ? 1 : -1;
}

function IsInspectionSection(section)
{
	return section.hasParameter("operation-strategy") && (section.getParameter("operation-strategy") == "probe") && inspectionRunning;
//		&& section.hasParameter("probe-output-work-offset") && (section.getParameter("probe-output-work-offset") > MAX_WORK_OFFSET);
}

function isProbeOperation() 
{
  return hasParameter("operation-strategy") && (getParameter("operation-strategy") == "probe");
}

function onParameter(name, value) 
{
	switch (name)
	{
		case "probe-output-work-offset":
			probeOutputWorkOffset = inspectionRunning ? 1000 : ((value > 0) ? value : 1);
			break;

		case "display":
			writeComment("MSG, " + value);
			break;
	}
}

function ShowProbeHeader()
{
	// output only if this is an inspection operation
	if (IsInspectionSection(currentSection))
	{
		var comment = "Probe";
		if (hasParameter("operation-comment")) 
		{
			comment = getParameter("operation-comment");
			if (!comment) 
				comment = "Probe";
		}
  
  // some macro substitutions
		comment = comment.replace("[x]", xyzFormat.format(getCurrentPosition().x));
		comment = comment.replace("[y]", xyzFormat.format(getCurrentPosition().y));
		comment = comment.replace("[z]", xyzFormat.format(getCurrentPosition().z));

		writeComment("LOGAPPEND,inspection.txt");
		writeComment("LOG," + cycleType + "," + currentWorkOffset + "," + inspectPartno + "," + inspectFeatureno + "," + comment);
		writeComment("LOGCLOSE");

		// increment the part and feature number
		inspectFeatureno++;

		if (cycle.printResults && cycle.incrementComponent)
		{
			inspectPartno++;
			inspectFeatureno = 1;
		}
	}
}

function onCyclePoint(x, y, z) 
{
	if (!isSameDirection(getRotation().forward, new Vector(0, 0, 1))) 
	{
		expandCyclePoint(x, y, z);
		return;
	}

  	if (isFirstCyclePoint()) 
  	{
    	repositionToCycleClearance(cycle, x, y, z);
    
    	// return to initial Z which is clearance plane and set absolute mode

    	var F = cycle.feedrate;
    	var P = !cycle.dwell ? 0 : cycle.dwell; // in seconds

		// Adjust SmartCool to top of part if it changes    // Adjust SmartCool to top of part if it changes
		if (getProperty("smartCoolEquipped") && xyzFormat.areDifferent((z + cycle.depth), coolantZHeight)) 
		{
      		var c = setCoolant(currentCoolantMode, z + cycle.depth);
			if (c)
			{
        		writeBlock(c[0], c[1], c[2], c[3]);
      		}
    	}

		switch (cycleType) 
		{
			case "drilling":
				writeBlock(
					gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(81),
					getCommonCycle(x, y, z, cycle.retract),
					feedOutput.format(F)
				);
			break;

			case "counter-boring":
				if (P > 0) 
				{
					writeBlock(
					gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(82),
					getCommonCycle(x, y, z, cycle.retract),
					"P" + secFormat.format(P),
					feedOutput.format(F)
					);
				} 
				else 
				{
					writeBlock(
					gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(81),
					getCommonCycle(x, y, z, cycle.retract),
					feedOutput.format(F)
					);
				}
			break;

			case "chip-breaking":
				if ((P > 0) || (cycle.accumulatedDepth < cycle.depth)) 
				{
					expandCyclePoint(x, y, z);
				} 
				else 
				{
					writeBlock(
					gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(73),
					getCommonCycle(x, y, z, cycle.retract),
					"Q" + xyzFormat.format(cycle.incrementalDepth),
					feedOutput.format(F)
					);
				}
			break;

		case "deep-drilling":
		writeBlock(
			gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(83),
			getCommonCycle(x, y, z, cycle.retract),
			"Q" + xyzFormat.format(cycle.incrementalDepth),
			// conditional(P > 0, "P" + secFormat.format(P)),
			feedOutput.format(F)
		);
		break;
		case "tapping":
			if (getProperty("expandTapping"))
				expandCyclePoint(x, y, z);
			else if (getProperty("reversingHead")) 
			{
				expandTappingPoint(x, y, z);
			} 
			else 
			{
				if (!F) 
				{
					F = tool.getTappingFeedrate();
				}
				writeBlock(sOutput.format(spindleSpeed));
				writeBlock(
					gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format((tool.type == TOOL_TAP_LEFT_HAND) ? 74 : 84),
					getCommonCycle(x, y, z, cycle.retract),
					conditional(P > 0, "P" + secFormat.format(P)),
					feedOutput.format(F)
					);
			}
		break;
		case "left-tapping":
			if (getProperty("expandTapping"))
				expandCyclePoint(x, y, z);
			else if (getProperty("reversingHead")) 
			{
				expandTappingPoint(x, y, z);
			} 
			else 
			{
				if (!F) 
				{
					F = tool.getTappingFeedrate();
				}
				writeBlock(
					gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(74),
					getCommonCycle(x, y, z, cycle.retract),
					conditional(P > 0, "P" + secFormat.format(P)),
					feedOutput.format(F)
					);
			}
			break;
		case "right-tapping":
		if (getProperty("expandTapping"))
				expandCyclePoint(x, y, z);
		else if (getProperty("reversingHead")) {
			expandTappingPoint(x, y, z);
		} else {
			if (!F) {
			F = tool.getTappingFeedrate();
			}
			writeBlock(
			gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(84),
			getCommonCycle(x, y, z, cycle.retract),
			conditional(P > 0, "P" + secFormat.format(P)),
			feedOutput.format(F)
			);
		}
		break;
		case "fine-boring":
		writeBlock(
			gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(76),
			getCommonCycle(x, y, z, cycle.retract),
			"P" + secFormat.format(P),
			"Q" + xyzFormat.format(cycle.shift),
			feedOutput.format(F)
		);
		break;
		case "back-boring":
		var dx = (gPlaneModal.getCurrent() == 19) ? cycle.backBoreDistance : 0;
		var dy = (gPlaneModal.getCurrent() == 18) ? cycle.backBoreDistance : 0;
		var dz = (gPlaneModal.getCurrent() == 17) ? cycle.backBoreDistance : 0;
		writeBlock(
			gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(87),
			getCommonCycle(x - dx, y - dy, z - dz, cycle.bottom),
			"I" + xyzFormat.format(cycle.shift),
			"J" + xyzFormat.format(0),
			"P" + secFormat.format(P),
			feedOutput.format(F)
		);
		break;
		case "reaming":
		if (P > 0) {
			writeBlock(
			gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(89),
			getCommonCycle(x, y, z, cycle.retract),
			"P" + secFormat.format(P),
			feedOutput.format(F)
			);
		} else {
			writeBlock(
			gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(85),
			getCommonCycle(x, y, z, cycle.retract),
			feedOutput.format(F)
			);
		}
		break;
		case "stop-boring":
		writeBlock(
			gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(86),
			getCommonCycle(x, y, z, cycle.retract),
			"P" + secFormat.format(P),
			feedOutput.format(F)
		);
		break;
		case "manual-boring":
		writeBlock(
			gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(88),
			getCommonCycle(x, y, z, cycle.retract),
			"P" + secFormat.format(P),
			feedOutput.format(F)
		);
		break;
		case "boring":
		if (P > 0) {
			writeBlock(
			gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(89),
			getCommonCycle(x, y, z, cycle.retract),
			"P" + secFormat.format(P),
			feedOutput.format(F)
			);
		} else {
			writeBlock(
			gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(85),
			getCommonCycle(x, y, z, cycle.retract),
			feedOutput.format(F)
			);
		}
		break;
	// here come all the probing options

		case "probing-x":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(approach(cycle.approach1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
			 	formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			gMotionModal.reset();
		break;

		case "probing-y":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(approach(cycle.approach1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			gMotionModal.reset();
		break;

		case "probing-z":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(approach(cycle.approach1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			gMotionModal.reset();
		break;

		case "probing-x-wall":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
		break;

		case "probing-y-wall":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			break;

		case "probing-x-channel":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			break;

		case "probing-x-channel-with-island":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
		break;

		case "probing-y-channel":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			break;
			
		case "probing-y-channel-with-island":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			break;
			
		case "probing-xy-circular-boss":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
		break;
		
		case "probing-xy-circular-partial-boss":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				formatParameter(probeAngleFormat.format(cycle.partialCircleAngleA)),
				formatParameter(probeAngleFormat.format(cycle.partialCircleAngleB)),
				formatParameter(probeAngleFormat.format(cycle.partialCircleAngleC)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
		break;

		case "probing-xy-circular-hole":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			break;

		case "probing-xy-circular-hole-with-island":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			break;

		case "probing-xy-circular-partial-hole":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				formatParameter(probeAngleFormat.format(cycle.partialCircleAngleA)),
				formatParameter(probeAngleFormat.format(cycle.partialCircleAngleB)),
				formatParameter(probeAngleFormat.format(cycle.partialCircleAngleC)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
		break;

		case "probing-xy-circular-partial-hole-with-island":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				formatParameter(probeAngleFormat.format(cycle.partialCircleAngleA)),
				formatParameter(probeAngleFormat.format(cycle.partialCircleAngleB)),
				formatParameter(probeAngleFormat.format(cycle.partialCircleAngleC)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			break;

		case "probing-xy-rectangular-hole":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.width2)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			break;

		case "probing-xy-rectangular-boss":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.width2)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
		break;
		
		case "probing-xy-rectangular-hole-with-island":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(xyzFormat.format(cycle.width1)),
				formatParameter(xyzFormat.format(cycle.width2)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			break;

		case "probing-xy-inner-corner":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(approach(cycle.approach1)),
				formatParameter(approach(cycle.approach2)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			gMotionModal.reset();
			break;

		case "probing-xy-outer-corner":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(approach(cycle.approach1)),
				formatParameter(approach(cycle.approach2)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			gMotionModal.reset();
			break;

		case "probing-x-plane-angle":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(approach(cycle.approach1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				formatParameter(xyzFormat.format(cycle.probeSpacing)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			gMotionModal.reset();

			g68RotationMode = 1;
			break;
			
		case "probing-y-plane-angle":
			writeComment(cycleType);
			ShowProbeHeader();
			TurnOutputOn(getProperty("probeInUseChannel"));
			writeBlock(formatSubroutineCall(cycleType),
				formatParameter(xyzFormat.format(x)),
				formatParameter(xyzFormat.format(y)),
				formatParameter(xyzFormat.format(z)),
				formatParameter(xyzFormat.format(tool.diameter)),
				formatParameter(feedFormat.format(F)),
				formatParameter(xyzFormat.format(cycle.depth)),
				formatParameter(approach(cycle.approach1)),
				formatParameter(xyzFormat.format(cycle.probeClearance)),
				formatParameter(xyzFormat.format(cycle.probeOvertravel)),
				formatParameter(xyzFormat.format(cycle.retract)),
				formatParameter(probe100Format.format(probeOutputWorkOffset)),
				formatParameter(xyzFormat.format(cycle.probeSpacing)),
				getProbingArguments(cycle)
				);
			TurnOutputOff(getProperty("probeInUseChannel"));

			// probing may change the motion mode, so it needs to be re-established in the next move
			forceXYZ();
			gMotionModal.reset();

			g68RotationMode = 1;
			break;

		// end of probing

		default:
		expandCyclePoint(x, y, z);
		}
	} 
	else
	{
		if (cycleExpanded) 
		{
      		expandCyclePoint(x, y, z);
		} 
		else if (((cycleType == "tapping") || (cycleType == "right-tapping") || (cycleType == "left-tapping")) && getProperty("reversingHead"))
		{
      		expandTappingPoint(x, y, z);
		} 
		else 
		{
      		writeBlock(xOutput.format(x), yOutput.format(y));
    	}
  	}
}

function getProbingArguments(cycle) 
{
	return [
				// size tolerance
				formatParameter(xyzFormat.format(cycle.toleranceSize ? cycle.toleranceSize : 0)),
				formatParameter(cycle.wrongSizeAction == "stop-message" ? 1 : 0),

				// position tolerance
				formatParameter(xyzFormat.format(cycle.tolerancePosition ? cycle.tolerancePosition : 0)),
				formatParameter(cycle.outOfPositionAction == "stop-message" ? 1 : 0),

				// angular tolerance
				formatParameter(xyzFormat.format(cycle.toleranceAngle ? cycle.toleranceAngle : 0)),
				formatParameter(cycle.angleAskewAction == "stop-message" ? 1 : 0),

				// print results
				formatParameter(cycle.printResults ? (xyzFormat.format(2 + cycle.incrementComponent)) : 0)
			];
  }
  
function myExpandTapping(x, y, z)
{
	writeComment("Tapping with a " + (tool.clockwise ? "right hand" : "left hand") + " tap")
	// get the feedrate either from the cycle, or the tool
	var feedRate = cycle.feedRate;
	if (!feedRate)
		feedRate = tool.getTappingFeedrate();

	// rapid move above the hole
	onRapid(x, y, cycle.clearance);

	// spindle on
	onSpindleSpeed(tool.spindleRPM * getProperty("tapSpeedFactor"));
	if (tool.clockwise)
		onCommand(COMMAND_SPINDLE_CLOCKWISE);
	else
		onCommand(COMMAND_SPINDLE_COUNTERCLOCKWISE);

	// rapid down to retract height
	onRapid(x, y, cycle.retract);

	// linear down to slightly less than tapping depth
	onLinear(x, y, z + 2.0 * tool.getThreadPitch(), feedRate);
	
	// reverse the motor
	if (tool.clockwise)
		onCommand(COMMAND_SPINDLE_COUNTERCLOCKWISE);
	else
		onCommand(COMMAND_SPINDLE_CLOCKWISE);
	
	// short rapid movement to final depth
	onRapid(x, y, z);

	if (cycle.dwell > 0)
        writeBlock(gFormat.format(4), "P" + secFormat.format(cycle.dwell));
	
	// linear back up to retract height
	onLinear(x, y, cycle.retract, feedRate);
	
	// rapid back up to clearance
	onRapid(x, y, cycle.clearance);

    // spindle on forward again
	if (tool.clockwise)
		onCommand(COMMAND_SPINDLE_CLOCKWISE);
	else
		onCommand(COMMAND_SPINDLE_COUNTERCLOCKWISE);
}

function onCycleEnd() {
  if (!cycleExpanded) {
    writeBlock(gCycleModal.format(80));
    zOutput.reset();
  }
}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

function onMovement(movement) {
  movementType = movement;
}

function onRapid(_x, _y, _z) 
{
	var x = xOutput.format(_x);
	var y = yOutput.format(_y);
	var z = zOutput.format(_z);
	if (x || y || z) 
	{
		if (pendingRadiusCompensation >= 0) 
		{
			error(localize("Radius compensation mode cannot be changed at rapid traversal."));
			return;
		}
		writeBlock(gMotionModal.format(0), x, y, z);
		feedOutput.reset();
	}
}

function onLinear(_x, _y, _z, feed) 
{
	if (retracted)
//	 	if(properties.substituteRapidAfterRetract)
//		{
//			writeComment("Substituting Linear with rapid");
//			onRapid(_x, _y, _z);
//			return;
//		}
//		else
			writeComment("Linear move whilst retracted");

	var x = xOutput.format(_x);
	var y = yOutput.format(_y);
	var z = zOutput.format(_z);
	var f = feedOutput.format(feed);
	if (x || y || z) 
	{
		if (pendingRadiusCompensation >= 0) 
		{
			pendingRadiusCompensation = -1;
			var d = tool.diameterOffset;
			if (d > getProperty("maxTool")) 
			{
				warning(localize("The diameter offset exceeds the maximum value."));
			}
			writeBlock(gPlaneModal.format(17));
			switch (radiusCompensation) 
			{
				case RADIUS_COMPENSATION_LEFT:
					dOutput.reset();
					writeBlock(gFeedModeModal.format(94), gMotionModal.format(1), gFormat.format(41), x, y, z, dOutput.format(d), f);
					// error(localize("Radius compensation mode is not supported by the CNC control."));
					break;
		
				case RADIUS_COMPENSATION_RIGHT:
					dOutput.reset();
					writeBlock(gFeedModeModal.format(94), gMotionModal.format(1), gFormat.format(42), x, y, z, dOutput.format(d), f);
					// error(localize("Radius compensation mode is not supported by the CNC control."));
					break;
				default:
					writeBlock(gFeedModeModal.format(94), gMotionModal.format(1), gFormat.format(40), x, y, z, f);
			}
		} 
		else 
		{
			writeBlock(gFeedModeModal.format(94), gMotionModal.format(1), x, y, z, f);
		}
	} 
	else if (f) 
	{
		if (getNextRecord().isMotion()) 
		{ // try not to output feed without motion
			feedOutput.reset(); // force feed on next line
		}
		else 
		{
			writeBlock(gFeedModeModal.format(94), gMotionModal.format(1), f);
		}
	}
}

function onRapid5D(_x, _y, _z, _a, _b, _c) 
{
	if (retracted)
		writeComment("Rapid multi-axis while retracted");

	if (!currentSection.isOptimizedForMachine()) 
	{
    	error(localize("This post configuration has not been customized for 5-axis simultaneous toolpath."));
    	return;
  	}
  
	if (pendingRadiusCompensation >= 0) 
	{
    	error(localize("Radius compensation mode cannot be changed at rapid traversal."));
    	return;
  	}

	  var x = xOutput.format(_x);
	var y = yOutput.format(_y);
	var z = zOutput.format(_z);
	var a = aOutput.format(_a);
	var b = bOutput.format(_b);
	var c = cOutput.format(_c);
	writeBlock(gMotionModal.format(0), x, y, z, a, b, c);
	feedOutput.reset();
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) 
{
	if (retracted)
		writeComment("Linear multi-axis while retracted");

	if (!currentSection.isOptimizedForMachine()) 
	{
    	error(localize("This post configuration has not been customized for 5-axis simultaneous toolpath."));
    	return;
  	}
  
	if (pendingRadiusCompensation >= 0) 
	{
    	error(localize("Radius compensation cannot be activated/deactivated for 5-axis move."));
    	return;
  	}

	var x = xOutput.format(_x);
	var y = yOutput.format(_y);
	var z = zOutput.format(_z);
	var a = aOutput.format(_a);
	var b = bOutput.format(_b);
	var c = cOutput.format(_c);

	// get feedrate number
	var f = {frn:0, fmode:0};
	if (a || b || c) 
	{
		f = getMultiaxisFeed(_x, _y, _z, _a, _b, _c, feed);
		if (useInverseTimeFeed) 
		{
			f.frn = inverseTimeOutput.format(f.frn);
		} 
		else 
		{
			f.frn = feedOutput.format(f.frn);
		}
	} 
	else 
	{
		f.frn = feedOutput.format(feed);
		f.fmode = 94;
	}

	if (x || y || z || a || b || c) 
	{
		writeBlock(gFeedModeModal.format(f.fmode), gMotionModal.format(1), x, y, z, a, b, c, f.frn);
	} 
	else if (f.frn) 
	{
		if (getNextRecord().isMotion()) 
		{ // try not to output feed without motion
			feedOutput.reset(); // force feed on next line
		} 
		else 
		{
			writeBlock(gFeedModeModal.format(f.fmode), gMotionModal.format(1), f.frn);
		}
	}
}

// Start of multi-axis feedrate logic
/***** You can add 'properties.useInverseTime' if desired. *****/
/***** 'previousABC' can be added throughout to maintain previous rotary positions. Required for Mill/Turn machines. *****/
/***** 'headOffset' should be defined when a head rotary axis is defined. *****/
/***** The feedrate mode must be included in motion block output (linear, circular, etc.) for Inverse Time feedrate support. *****/
var dpmBPW = 0.1; // ratio of rotary accuracy to linear accuracy for DPM calculations
var inverseTimeUnits = 1.0; // 1.0 = minutes, 60.0 = seconds
var maxInverseTime = 99999.9999; // maximum value to output for Inverse Time feeds
var maxDPM = 9999.99; // maximum value to output for DPM feeds
var useInverseTimeFeed = true; // use 1/T feeds
var inverseTimeFormat = createFormat({decimals:4, forceDecimal:true});
var inverseTimeOutput = createVariable({prefix:"F", force:true}, inverseTimeFormat);
var previousDPMFeed = 0; // previously output DPM feed
var dpmFeedToler = 0.5; // tolerance to determine when the DPM feed has changed
// var previousABC = new Vector(0, 0, 0); // previous ABC position if maintained in post, don't define if not used
var forceOptimized = undefined; // used to override optimized-for-angles points (XZC-mode)

/** Calculate the multi-axis feedrate number. */
function getMultiaxisFeed(_x, _y, _z, _a, _b, _c, feed) {
  var f = {frn:0, fmode:0};
  if (feed <= 0) {
    error(localize("Feedrate is less than or equal to 0."));
    return f;
  }
  
  var length = getMoveLength(_x, _y, _z, _a, _b, _c);
  
  if (useInverseTimeFeed) { // inverse time
    f.frn = getInverseTime(length.tool, feed);
    f.fmode = 93;
    feedOutput.reset();
  } else { // degrees per minute
    f.frn = getFeedDPM(length, feed);
    f.fmode = 94;
  }
  return f;
}

/** Returns point optimization mode. */
function getOptimizedMode() {
  if (forceOptimized != undefined) {
    return forceOptimized;
  }
  // return (currentSection.getOptimizedTCPMode() != 0); // TAG:doesn't return correct value
  return true; // always return false for non-TCP based heads
}
  
/** Calculate the DPM feedrate number. */
function getFeedDPM(_moveLength, _feed) {
  if ((_feed == 0) || (_moveLength.tool < 0.0001) || (toDeg(_moveLength.abcLength) < 0.0005)) {
    previousDPMFeed = 0;
    return _feed;
  }
  var moveTime = _moveLength.tool / _feed;
  if (moveTime == 0) {
    previousDPMFeed = 0;
    return _feed;
  }

  var dpmFeed;
  var tcp = false; // !getOptimizedMode() && (forceOptimized == undefined);   // set to false for rotary heads
  if (tcp) { // TCP mode is supported, output feed as FPM
    dpmFeed = _feed;
  } else if (false) { // standard DPM
    dpmFeed = Math.min(toDeg(_moveLength.abcLength) / moveTime, maxDPM);
    if (Math.abs(dpmFeed - previousDPMFeed) < dpmFeedToler) {
      dpmFeed = previousDPMFeed;
    }
  } else if (true) { // combination FPM/DPM
    var length = Math.sqrt(Math.pow(_moveLength.xyzLength, 2.0) + Math.pow((toDeg(_moveLength.abcLength) * dpmBPW), 2.0));
    dpmFeed = Math.min((length / moveTime), maxDPM);
    if (Math.abs(dpmFeed - previousDPMFeed) < dpmFeedToler) {
      dpmFeed = previousDPMFeed;
    }
  } else { // machine specific calculation
    dpmFeed = _feed;
  }
  previousDPMFeed = dpmFeed;
  return dpmFeed;
}

/** Calculate the Inverse time feedrate number. */
function getInverseTime(_length, _feed) {
  var inverseTime;
  if (_length < 1.e-6) { // tool doesn't move
    if (typeof maxInverseTime === "number") {
      inverseTime = maxInverseTime;
    } else {
      inverseTime = 999999;
    }
  } else {
    inverseTime = _feed / _length / inverseTimeUnits;
    if (typeof maxInverseTime === "number") {
      if (inverseTime > maxInverseTime) {
        inverseTime = maxInverseTime;
      }
    }
  }
  return inverseTime;
}

/** Calculate radius for each rotary axis. */
function getRotaryRadii(startTool, endTool, startABC, endABC) {
  var radii = new Vector(0, 0, 0);
  var startRadius;
  var endRadius;
  var axis = new Array(machineConfiguration.getAxisU(), machineConfiguration.getAxisV(), machineConfiguration.getAxisW());
  for (var i = 0; i < 3; ++i) {
    if (axis[i].isEnabled()) {
      var startRadius = getRotaryRadius(axis[i], startTool, startABC);
      var endRadius = getRotaryRadius(axis[i], endTool, endABC);
      radii.setCoordinate(axis[i].getCoordinate(), Math.max(startRadius, endRadius));
    }
  }
  return radii;
}

/** Calculate the distance of the tool position to the center of a rotary axis. */
function getRotaryRadius(axis, toolPosition, abc) {
  if (!axis.isEnabled()) {
    return 0;
  }

  var direction = axis.getEffectiveAxis();
  var normal = direction.getNormalized();
  // calculate the rotary center based on head/table
  var center;
  var radius;
  if (axis.isHead()) {
    var pivot;
    if (typeof headOffset === "number") {
      pivot = headOffset;
    } else {
      pivot = tool.getBodyLength();
    }
    if (axis.getCoordinate() == machineConfiguration.getAxisU().getCoordinate()) { // rider
      center = Vector.sum(toolPosition, Vector.product(machineConfiguration.getDirection(abc), pivot));
      center = Vector.sum(center, axis.getOffset());
      radius = Vector.diff(toolPosition, center).length;
    } else { // carrier
      var angle = abc.getCoordinate(machineConfiguration.getAxisU().getCoordinate());
      radius = Math.abs(pivot * Math.sin(angle));
      radius += axis.getOffset().length;
    }
  } else {
    center = axis.getOffset();
    var d1 = toolPosition.x - center.x;
    var d2 = toolPosition.y - center.y;
    var d3 = toolPosition.z - center.z;
    var radius = Math.sqrt(
      Math.pow((d1 * normal.y) - (d2 * normal.x), 2.0) +
      Math.pow((d2 * normal.z) - (d3 * normal.y), 2.0) +
      Math.pow((d3 * normal.x) - (d1 * normal.z), 2.0)
    );
  }
  return radius;
}
  
/** Calculate the linear distance based on the rotation of a rotary axis. */
function getRadialDistance(radius, startABC, endABC) {
  // calculate length of radial move
  var delta = Math.abs(endABC - startABC);
  if (delta > Math.PI) {
    delta = 2 * Math.PI - delta;
  }
  var radialLength = (2 * Math.PI * radius) * (delta / (2 * Math.PI));
  return radialLength;
}
  
/** Calculate tooltip, XYZ, and rotary move lengths. */
function getMoveLength(_x, _y, _z, _a, _b, _c) {
  // get starting and ending positions
  var moveLength = {};
  var startTool;
  var endTool;
  var startXYZ;
  var endXYZ;
  var startABC;
  if (typeof previousABC !== "undefined") {
    startABC = new Vector(previousABC.x, previousABC.y, previousABC.z);
  } else {
    startABC = getCurrentDirection();
  }
  var endABC = new Vector(_a, _b, _c);
    
  if (!getOptimizedMode()) { // calculate XYZ from tool tip
    startTool = getCurrentPosition();
    endTool = new Vector(_x, _y, _z);
    startXYZ = startTool;
    endXYZ = endTool;

    // adjust points for tables
    if (!machineConfiguration.getTableABC(startABC).isZero() || !machineConfiguration.getTableABC(endABC).isZero()) {
      startXYZ = machineConfiguration.getOrientation(machineConfiguration.getTableABC(startABC)).getTransposed().multiply(startXYZ);
      endXYZ = machineConfiguration.getOrientation(machineConfiguration.getTableABC(endABC)).getTransposed().multiply(endXYZ);
    }

    // adjust points for heads
    if (machineConfiguration.getAxisU().isEnabled() && machineConfiguration.getAxisU().isHead()) {
      if (typeof getOptimizedHeads === "function") { // use post processor function to adjust heads
        startXYZ = getOptimizedHeads(startXYZ.x, startXYZ.y, startXYZ.z, startABC.x, startABC.y, startABC.z);
        endXYZ = getOptimizedHeads(endXYZ.x, endXYZ.y, endXYZ.z, endABC.x, endABC.y, endABC.z);
      } else { // guess at head adjustments
        var startDisplacement = machineConfiguration.getDirection(startABC);
        startDisplacement.multiply(headOffset);
        var endDisplacement = machineConfiguration.getDirection(endABC);
        endDisplacement.multiply(headOffset);
        startXYZ = Vector.sum(startTool, startDisplacement);
        endXYZ = Vector.sum(endTool, endDisplacement);
      }
    }
  } else { // calculate tool tip from XYZ, heads are always programmed in TCP mode, so not handled here
    startXYZ = getCurrentPosition();
    endXYZ = new Vector(_x, _y, _z);
    startTool = machineConfiguration.getOrientation(machineConfiguration.getTableABC(startABC)).multiply(startXYZ);
    endTool = machineConfiguration.getOrientation(machineConfiguration.getTableABC(endABC)).multiply(endXYZ);
  }

  // calculate axes movements
  moveLength.xyz = Vector.diff(endXYZ, startXYZ).abs;
  moveLength.xyzLength = moveLength.xyz.length;
  moveLength.abc = Vector.diff(endABC, startABC).abs;
  for (var i = 0; i < 3; ++i) {
    if (moveLength.abc.getCoordinate(i) > Math.PI) {
      moveLength.abc.setCoordinate(i, 2 * Math.PI - moveLength.abc.getCoordinate(i));
    }
  }
  moveLength.abcLength = moveLength.abc.length;

  // calculate radii
  moveLength.radius = getRotaryRadii(startTool, endTool, startABC, endABC);
  
  // calculate the radial portion of the tool tip movement
  var radialLength = Math.sqrt(
    Math.pow(getRadialDistance(moveLength.radius.x, startABC.x, endABC.x), 2.0) +
    Math.pow(getRadialDistance(moveLength.radius.y, startABC.y, endABC.y), 2.0) +
    Math.pow(getRadialDistance(moveLength.radius.z, startABC.z, endABC.z), 2.0)
  );
  
  // calculate the tool tip move length
  // tool tip distance is the move distance based on a combination of linear and rotary axes movement
  moveLength.tool = moveLength.xyzLength + radialLength;

  // debug
  if (false) {
    writeComment("DEBUG - tool   = " + moveLength.tool);
    writeComment("DEBUG - xyz    = " + moveLength.xyz);
    var temp = Vector.product(moveLength.abc, 180/Math.PI);
    writeComment("DEBUG - abc    = " + temp);
    writeComment("DEBUG - radius = " + moveLength.radius);
  }
  return moveLength;
}
// End of multi-axis feedrate logic

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
    return;
  }

  // controller does not handle transition between planes well
  if (((movementType == MOVEMENT_LEAD_IN) ||
       (movementType == MOVEMENT_LEAD_OUT)||
       (movementType == MOVEMENT_RAMP) ||
       (movementType == MOVEMENT_PLUNGE) ||
       (movementType == MOVEMENT_RAMP_HELIX) ||
       (movementType == MOVEMENT_RAMP_PROFILE) ||
       (movementType == MOVEMENT_RAMP_ZIG_ZAG)) &&
       (getCircularPlane() != PLANE_XY)) {
    linearize(tolerance);
    return;
  }

  var start = getCurrentPosition();

  if (isFullCircle()) {
    if (getProperty("useRadius") || isHelical()) { // radius mode does not support full arcs
      linearize(tolerance);
      return;
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gAbsIncModal.format(90), gPlaneModal.format(17), gFeedModeModal.format(94), gMotionModal.format(clockwise ? 2 : 3), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
      break;
    case PLANE_ZX:
      writeBlock(gAbsIncModal.format(90), gPlaneModal.format(18), gFeedModeModal.format(94), gMotionModal.format(clockwise ? 2 : 3), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      break;
    case PLANE_YZ:
      writeBlock(gAbsIncModal.format(90), gPlaneModal.format(19), gFeedModeModal.format(94), gMotionModal.format(clockwise ? 2 : 3), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else if (!getProperty("useRadius")) {
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gAbsIncModal.format(90), gPlaneModal.format(17), gFeedModeModal.format(94), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
      break;
    case PLANE_ZX:
      writeBlock(gAbsIncModal.format(90), gPlaneModal.format(18), gFeedModeModal.format(94), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      break;
    case PLANE_YZ:
      writeBlock(gAbsIncModal.format(90), gPlaneModal.format(19), gFeedModeModal.format(94), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else { // use radius mode
    var r = getCircularRadius();
    if (toDeg(getCircularSweep()) > (180 + 1e-9)) {
      r = -r; // allow up to <360 deg arcs
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gPlaneModal.format(17), gFeedModeModal.format(94), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), feedOutput.format(feed));
      break;
    case PLANE_ZX:
      writeBlock(gPlaneModal.format(18), gFeedModeModal.format(94), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), feedOutput.format(feed));
      break;
    case PLANE_YZ:
      writeBlock(gPlaneModal.format(19), gFeedModeModal.format(94), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  }
}

var mapCommand = {
  //COMMAND_STOP:0,
  //COMMAND_OPTIONAL_STOP:1,
  COMMAND_END:2,
  //COMMAND_SPINDLE_CLOCKWISE:3,
  //COMMAND_SPINDLE_COUNTERCLOCKWISE:4,
  //COMMAND_STOP_SPINDLE:5,
  COMMAND_ORIENTATE_SPINDLE:19,
  //COMMAND_LOAD_TOOL:6,
  //COMMAND_COOLANT_ON:8, // flood
  //COMMAND_COOLANT_OFF:9
};

function onCommand(command) 
{
	switch (command) 
	{
		case COMMAND_STOP:
			UserRetract(getProperty("retractOnManualNCStop"), "Manual NC Stop", true);
			if (lastComment != null)
			{
				writeBlock(mFormat.format(0), formatComment(lastComment));
				lastComment = null;
			}
			else
				writeBlock(mFormat.format(0));
			return;

		case COMMAND_OPTIONAL_STOP:
			UserRetract(getProperty("retractOnManualNCOptionalStop"), "Manual NC Optional Stop", true);
			if (lastComment != null)
			{
				writeBlock(mFormat.format(1), formatComment(lastComment));
				lastComment = null;
			}
			else
				writeBlock(mFormat.format(1));
			return;
	
		case COMMAND_START_SPINDLE:
			onCommand(tool.clockwise ? COMMAND_SPINDLE_CLOCKWISE : COMMAND_SPINDLE_COUNTERCLOCKWISE);
			return;

		case COMMAND_LOCK_MULTI_AXIS:
			return;

		case COMMAND_UNLOCK_MULTI_AXIS:
			return;

		case COMMAND_BREAK_CONTROL:
			CheckCurrentTool(tool);
			return;

		case COMMAND_TOOL_MEASURE:
			// measure the tool in the next section
			measureToolRequested = true;
			return;

		case COMMAND_SPINDLE_CLOCKWISE:
			writeComment("Spindle clockwise");
			TurnOutputOn(getProperty("spindleRunningChannel"));
			TurnOutputOff(getProperty("spindleReverseChannel"));
			writeBlock(spindleOutput.format(3));
			return;

		case COMMAND_SPINDLE_COUNTERCLOCKWISE:
			writeComment("Spindle anti-clockwise");
			TurnOutputOn(getProperty("spindleRunningChannel"));
			if (getProperty("spindleReverseChannel") == "0")
				writeBlock(spindleOutput.format(4));
			else
			{
				TurnOutputOn(getProperty("spindleReverseChannel"));
				writeBlock(spindleOutput.format(3));
			}
			return;

		case COMMAND_STOP_SPINDLE:
			TurnOutputOff(getProperty("spindleRunningChannel"));
			writeBlock(spindleOutput.format(5));
			return;

		case COMMAND_COOLANT_OFF:
			TurnOutputOff(getProperty("floodCoolingOnChannel"));
			TurnOutputOff(getProperty("mistCoolingOnChannel"));
			writeBlock(coolantOutput.format(9));
			return;
	}
  
	var stringId = getCommandStringId(command);
	var mcode = mapCommand[stringId];
	if (mcode != undefined) 
	{
		writeBlock(mFormat.format(mcode));
	} 
	else 
	{
		onUnsupportedCommand(command);
	}
}

function onSectionEnd() 
{
	writeBlock(gPlaneModal.format(17));

	if (currentSection.isMultiAxis()) 
	{
		writeBlock(gFeedModeModal.format(94)); // inverse time feed off
	}

	// process ets operations at end of section
	switch (getProperty("etsAfterOperation"))
	{
		case "check":
			onCommand(COMMAND_BREAK_CONTROL);
			break;
			
		case "set":
			if (UseToolWithETS(tool))
			{
				SetCurrentTool(tool);
			}
			break;
	}
	
	// is it the last section with this tool
	if (((getCurrentSectionId() + 1) >= getNumberOfSections()) ||
		(tool.number != getNextSection().getTool().number)) 
	{
		if (IsLiveTool(tool))
		{
			onCommand(COMMAND_STOP_SPINDLE);
			onCommand(COMMAND_COOLANT_OFF);
		}	

		// should we check for tool breakage
		if (tool.breakControl)
			onCommand(COMMAND_BREAK_CONTROL);
	}

	if (g64Active) { // MCJ
		writeBlock(gFormat.format(61)); // MCJ
		g64Active = false; // MCJ
	  }

	forceAny();

	
}

function UserRetract(retractMode, reason, spindleOff)
{
	if (retractMode != "none")
	{
		if (spindleOff)
		{
			onCommand(COMMAND_COOLANT_OFF);
			onCommand(COMMAND_STOP_SPINDLE);
		}
		writeComment("Retracting " + reason + " - " + retractMode);
	}

		switch (retractMode)
	{
		case "none":
			break;
			
		case "g30z":
			gMotionModal.reset();
			writeBlock(gFormat.format(53), gMotionModal.format(0), (unit==MM) ? "Z#5183" : "Z#5183");
			gMotionModal.reset();
			forceXYZ();
			retracted = true;
			break;

		case "g30zxy":
			gMotionModal.reset();
			writeBlock(gFormat.format(53), gMotionModal.format(0), (unit==MM) ? "Z#5183" : "Z#5183");
			writeBlock(gFormat.format(53), gMotionModal.format(0), (unit==MM) ? "X#5181 Y#5182" : "X#5181 Y#5182");
			gMotionModal.reset();
			forceXYZ();
			retracted = true;
			break;

		case "g28z":
			writeBlock(gAbsIncModal.format(91), gFormat.format(28), "Z" + xyzFormat.format(0.0));
			writeBlock(gAbsIncModal.format(90));
			gMotionModal.reset();
			forceXYZ();
			retracted = true;
			break;

		case "g28zxy":
			writeBlock(gAbsIncModal.format(91), gFormat.format(28), "Z" + xyzFormat.format(0.0));
			writeBlock(gAbsIncModal.format(91), gFormat.format(28), "X" + xyzFormat.format(0.0), "Y" + xyzFormat.format(0.0));
			writeBlock(gAbsIncModal.format(90));
			gMotionModal.reset();
			forceXYZ();
			retracted = true;
			break;
	}
}

function onClose() 
{
	writeln("");
	writeComment("Post-amble");
	onCommand(COMMAND_COOLANT_OFF);
	onCommand(COMMAND_STOP_SPINDLE);

	var changeMode = getProperty("toolChangeAtEnd");
	switch (changeMode)
	{
		case "none":
			break;

		case "first":
			LoadTool(getSection(0).getTool().number, getSection(0).getTool().lengthOffset);
			break;

		case "specific":
			LoadTool(getProperty("toolNumberAtEnd"), getProperty("toolNumberAtEnd"));
			break;

		default:
			writeComment("Don't understand " + changeMode);
			break;
	}

	UserRetract(getProperty("retractOnProgramEnd"), "after end of program", false);
	setWorkPlane(new Vector(0, 0, 0)); // reset working plane

	// turn off the g-code running output
	TurnOutputOff(getProperty("progRunningChannel"));
	
	onImpliedCommand(COMMAND_END);

	writeBlock(mFormat.format(30)); // stop program, spindle stop, coolant off
	writeln("%");
}

function setProperty(property, value) 
{
	properties[property].current = value;
}
  
