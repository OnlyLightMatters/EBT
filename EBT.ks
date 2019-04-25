CLEARSCREEN.
CLEARVECDRAWS().

GLOBAL PROGRAM_RELEASE to "v0.8".

GLOBAL GUI_WIDTH to 330.
GLOBAL GUI_BOX2_WIDTH to 313.
GLOBAL GUI_BOX2_HEIGTH to 70.
GLOBAL GUI_MAX_MESSAGES to 10.
GLOBAL GUI_FONT_MESSAGES to "Courier New".
GLOBAL GUI_ON_LABEL to "<color=#00ff00><b>ACTIVE</b></color>".
GLOBAL GUI_OFF_LABEL to "<color=#880000><b>OFF</b></color>".
GLOBAL GUI_TITLE_LABEL to "<b><size=14><color=#ffaa00FF>Engine Balancing Tool</color></size></b>".
GLOBAL GUI_LEGEND_LABEL to "<color=#ffffff>©Kerbal Foundries</color>".

// Global for Balancing behaviour Active / OFF 
GLOBAL isActive to false.

// GLOBAL for Exit behaviour
GLOBAL isFinished to false.

// Messages Management
set message_list to list().

// Defining the GUI
set mygui to GUI(GUI_WIDTH).

set box1 to mygui:ADDHLAYOUT().

set mytitle to box1:addlabel(GUI_TITLE_LABEL).
set button_onoff to box1:addbutton(GUI_OFF_LABEL).

set box2 to mygui:ADDHLAYOUT().
set box2:style:width to GUI_BOX2_WIDTH.
set box2:style:height to GUI_BOX2_HEIGTH.
set sb to box2:addscrollbox().
set sb:style:margin:H to 0.
set sb:style:margin:V to 0.
set sb:style:padding:H to 0.
set sb:style:padding:V to 0.
set sb:VALWAYS to true.

set box3 to mygui:ADDHLAYOUT().
set button_showhide to box3:addbutton("Hide").
set mylegend to box3:addlabel(GUI_LEGEND_LABEL).
set mylegend:STYLE:ALIGN TO "CENTER".
set button_exit to box3:addbutton("Exit").



function addNewMessage
{
	parameter message.
	set nb to message_list:length.
	message_list:add(sb:addlabel(message)).
	set message_list[nb]:style:font to GUI_FONT_MESSAGES.

	if message_list:length > GUI_MAX_MESSAGES
	{
		message_list[0]:dispose().
		message_list:remove(0).
	}
} // addNewMessage()

function cbOnOffButton
{
	if isActive
	{
		set isActive to false.
		set button_onoff:text to GUI_OFF_LABEL.
	}
	else
	{
		set isActive to true.
		set button_onoff:text to GUI_ON_LABEL.
	}

} // cbOnOffButton()

function cbExitButton
{
	set isFinished to true.
} // cbExitButton()

function cbShowHideButton
{
	//mygui:showonly(button_showhide).
	addNewMessage("Not implemented yet.").
} // cbShowHideButton()


SET button_onoff:ONCLICK     TO cbOnOffButton@. 
SET button_exit:ONCLICK      TO cbExitButton@. 
SET button_showhide:ONCLICK  TO cbShowHideButton@. 


// ----------------- END GUI DESINGNING -----------------

// ----------------- BALANCING PROGRAM ------------------
// Variables
global partInCommandUID to 0.

global CoM to SHIP:position.
GLOBAL MAX_ENGINE_ANGLE to 45.

GLOBAL MAX_DEVIATON TO 0.10.     // meters
GLOBAL AVG_DEVIATON TO 0.01.     // meters
GLOBAL MIN_DEVIATON TO 0.001.     // meters

GLOBAL THRUST_PCT_MAXSTEP TO 2.      // %thrustlimit is updated per 2%    step
GLOBAL THRUST_PCT_AVGSTEP TO 0.5.    // %thrustlimit is updated per 0.5%  step
GLOBAL THRUST_PCT_MINSTEP TO 0.25.   // %thrustlimit is updated per 0.25% step

global current_thrust_pct_step to THRUST_PCT_MAXSTEP.


// -------------- Engine Balancing Functions -------------

// Get the whole activated engines with thrust being aligned (-45°< x <45°) with this part.
function identify_engines {
	if ( SHIP:CONTROLPART:UID <> partInCommandUID )
	{
        addNewMessage("Part in command is " + SHIP:CONTROLPART:name).
        set partInCommandUID to SHIP:CONTROLPART:UID.
	}

	set partInCommand to SHIP:CONTROLPART.
	list ENGINES in initial_list.
	local final_list to list().
    local current_max_thrust to 0.

	for i_engine in initial_list
	{
		// Condition is Engine has been activated AND orientation is within a 45° range to the direction pointed by the part in controll
        if ( i_engine:ignition and abs(vectorangle(i_engine:facing:forevector, partInCommand:facing:forevector)) < MAX_ENGINE_ANGLE)
        {
        	final_list:add(i_engine).
            set current_max_thrust to current_max_thrust + i_engine:possiblethrust.
        }
	}
    if ( final_list:length() = 0 )
    {
        addNewMessage("<color=#ff0000><b>Can't work with " + engineList:length() + " useful engine</b></color>").
        return list().
    }
    if ( current_max_thrust = 0 )
    // If there is no thrust available no balancing could be done.
    {
        addNewMessage("<color=#ff0000><b>Total thrust is 0!</b></color>").
        addNewMessage("<color=#ff0000><b>Check your engines!</b></color>").
        return list().
    }

	return final_list.
} // identify_engines()



function getThrustVector {
	// Returns a vec (relative xyz) of the gloabl Thrust
	// engines are considered active
	// value is calculate upon maximum possible thrust per engine with %throttle limit
	local v_g_thrust to v(0,0,0).

    for i_engine in engineList {
        set v_g_thrust to v_g_thrust + i_engine:facing:forevector * i_engine:possiblethrust.
    }

    return v_g_thrust - v(0,0,0).
} // getThrustVector()

function getCoT {
    // Returns a vec of CoT coordonates

    // The CoT is like a weighted average calculation based on
    // - Engine positions
    // - Effective thrust of engines regarding the global Thrust
    local tCoT to v(0,0,0).
 
    for i_engine in engineList {
        // engine points towards i_engine:facing:forevector
        // What we want is the angle between this vector and the global thrust vector
        set i_engine_angle to vectorangle(VGThrust, i_engine:facing:forevector).

        // Now the effective thrust of this engine regarding the GThrust Vector is
        // its own thrust * the cosinus of this angle = effective weight
        set tCoT to tCoT + i_engine:position * i_engine:possiblethrust * cos(i_engine_angle).

        //print "DEBUG angle of engine VS VGThrust = " + i_engine_angle.
    } 
    // We have now to divide tCoT by VGThrust:MAG which is the sum of every effective weight
    set tCoT to tCoT / VGThrust:MAG.

    return tCot.
} // getCoT()


function getVLeverage {
	// X is the nearest point to CoM on the Thrust line passing through the CoT
	// The function return the Vector from CoM to X
    
	local X to CoT + (CoM-CoT):MAG * cos (CoMToThrustAngle) * VGThrust:normalized.
    return (X - CoM).
} // getVLeverage()


function strenghtenEngineIfPossible {
// Returns true if the %thrustlimit of an engine has been be increased
// False if no engine has been processed
	local max_angle to 0.
	local target_engine to 0.
	local was_set to false.

    for i_engine in engineList
    {
    	// calculate angle from CoM->X and CoM->i_engine
        local i_engine_angle to vectorangle(VLeverage, (i_engine:position - CoM)).

        // We have to identify the engine at the "most" opposite to the thrust vector
        if i_engine_angle > max_angle {
            set target_engine to i_engine.
            set max_angle to i_engine_angle.
        }
    }

    if target_engine:thrustlimit < 100
    // Engine identified AND tweakable
    {
    	set target_engine:thrustlimit to target_engine:thrustlimit + current_thrust_pct_step.
    	set was_set to TRUE.
  		print "Debug throttle ++ to " + target_engine:thrustlimit.    
    }
         
    return was_set.
} // getIndexOfEngineToBeStrenghtened()


function weakenEngineIfPossible {
// Returns true if the %thrustlimit of an engine has been be increased
// False if no engine has been processed
	local max_angle to 360.
	local target_engine to 0.
	local was_set to false.

    for i_engine in engineList
    {
    	// calculate angle from CoM->X and CoM->i_engine
        local i_engine_angle to vectorangle(VLeverage, (i_engine:position - CoM)).

        // We have to identify the engine the closest to the thrust vector
        if i_engine_angle < max_angle {
            set target_engine to i_engine.
            set max_angle to i_engine_angle.
        }
    }

    if target_engine:thrustlimit > 0
    // Engine identified AND tweakable
    {
    	set target_engine:thrustlimit to target_engine:thrustlimit - current_thrust_pct_step.
    	set was_set to TRUE.
  		print "Debug throttle -- to " + target_engine:thrustlimit.    
    }
         
    return was_set.
} // getIndexOfEngineToBeStrenghtened()



// MAIN
myGui:show().


addNewMessage("Program loaded " + PROGRAM_RELEASE).

// Engine Balancing Algorithm to align Thrust on CoM
//
// 1/ a/ Find the CoM (that's should be ok :o)
//    b/ Calculate the Global Thrust Vector based on individual engine thrust, position and facing
//    c/ Calculate the center of Thrust
//    d/ Find what I call the Leverage Vector who is responsible for the leverage behaviour.
//       The Leverage Vector is orthogonal to the Global Thrust Vector and starts at the CoM.
//       To avoid leverage, this vector should have a magnitude of 0
//
// 2/ In a loop which shall not exceed a maximum of iterations do
//        if the deviation is > MAXIMAL_DEVIATION_ALLOWED
//           a/ Does an engine exist in an opposit direction of the Deviation Vector ?
//              Does its thrustlimit can be increased ?
//           b/ Increase its %thrustlimit a little bit
//           c/ Recalculate the data found in 1/
//           d/ loop on 2a
//
//           e/ If no engine can be boosted, is there an engine in the direction of the leverage vector whose %thrustlimit can be lowered ?
//           f/ Lower the %thrustlimit a little bit
//           g/ Recalculate the data found in 1/
//           h/ loop on 2e
//
// 3/ attendre 1s
// 4/ loop on 2/

global engineList       to list().
global VGThrust         to v(0,0,0).
global CoT              to v(0,0,0).
global CoMToThrustAngle to v(0,0,0).
global VLeverage        to v(0,0,0).

function update_globals {
    set CoM              to ship:position.
    set VGThrust         to getThrustVector().
    set CoT              to getCoT().
    set CoMToThrustAngle to vectorangle(CoM-CoT, VGThrust).
    set VLeverage        to getVLeverage().

    if VLeverage:MAG < MIN_DEVIATON
    {
    	set current_thrust_pct_step to THRUST_PCT_MINSTEP.
    	//print "MINSTEP".
    }
    else if VLeverage:MAG < AVG_DEVIATON
    {
    	set current_thrust_pct_step to THRUST_PCT_AVGSTEP.
    	//print "AVGSTEP".
    }
    else
    {
    	set current_thrust_pct_step to THRUST_PCT_MAXSTEP.
      	//print "MAXSTEP".
    }
} // update_globals()



// THE LOOP
UNTIL isFinished
{
	UNTIL isFinished or not isActive
	// ending condition is isFinished & not active
	{
	    // Get fresh information about the current situation.
        set engineList to identify_engines().


        if ( engineList:length() <= 1)
        {
        	cbOnOffButton().
            break.
        }

        update_globals().

	    // 2 - On Boucle sur les moteurs à booster
   		UNTIL not isActive or (VLeverage:MAG < MIN_DEVIATON) or NOT strenghtenEngineIfPossible() {
        	update_globals().
        	//print "DEBUG : plus".
    	}


    	// 3 - Boucle sur les moteurs à nerfer
    	UNTIL not isActive or (VLeverage:MAG < MIN_DEVIATON) or NOT weakenEngineIfPossible() {
        	update_globals().
        	//print "DEBUG : moins".
    	}

    	print "End Loop, Deviation isMAG=" + VLeverage:MAG.


        wait 0.1.
    } // Engine balancing loop



	wait 1.
} // THE PROGRAM LOOP

myGui:dispose().