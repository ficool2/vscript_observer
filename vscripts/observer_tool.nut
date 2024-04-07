// by ficool2

IncludeScript("keyvalues");

if ("ObserverClear" in this)
	ObserverClear([]);
	
Host <- GetListenServerHost();

ObserverToolMode <- 0;
ObserverCameras <- [];
ObserverID <- 0;

class ObserverProperties
{
	function constructor(observer)
	{
		if (observer)
		{
			local scope = observer.GetScriptScope();
			team_num = observer.GetTeam();
			fov = scope.fov;
			name = scope.name;
			parent = scope.parent;
			associate_entity = scope.associate_entity;
			welcome_point = scope.welcome_point;
			match_summary = scope.match_summary;
			start_disabled = scope.start_disabled;
		}
		else
		{
			team_num = 0;
			fov = 0.0;
			name = "";
			parent = "";
			associate_entity = "";
			welcome_point = false;
			match_summary = false;
			start_disabled = false;
			glow_color = "0 255 0 255";	
		}
		
		id = -1;
	}
	
	function Parse(args)
	{
		for (local i = 1; i < args.len(); i++)
		{
			local pair = split(args[i], "=");
			local key = pair[0];
			if (key == "team")
			{
				local team = pair[1];
				if (team == "spectator")
					team_num = 1;				
				else if (team == "red")
					team_num = 2;
				else if (team == "blue")
					team_num = 3;
			}
			else if (key == "name")
			{
				name = pair[1];
			}
			else if (key == "parent")
			{
				parent = pair[1];
			}	
			else if (key == "associate")
			{
				associate_entity = pair[1];
			}		
			else if (key == "welcome")
			{
				welcome_point = !!pair[1].tointeger();
			}
			else if (key == "summary")
			{
				match_summary = !!pair[1].tointeger();
			}
			else if (key == "disable")
			{
				start_disabled = !!pair[1].tointeger();
			}		
			else if (key == "fov")
			{
				fov = pair[1].tofloat();
			}
			else if (key == "id")
			{
				id = pair[1].tointeger();
			}			
			else
			{
				ClientPrint(null, 3, "* Unknown key: " + key);
			}
		}	
		
		if (team_num == 1)
			glow_color = "255 255 255 255";
		else if (team_num == 2)
			glow_color = "255 0 0 255";
		else if (team_num == 3)
			glow_color = "0 0 255 255";	
		else
			glow_color = "0 255 0 255";
	}
	
	team_num = null;
	fov = null;
	name = null;
	parent = null;
	associate_entity = null;
	welcome_point = null;
	match_summary = null;
	start_disabled = null;
	glow_color = null;
	id = null;
}

function ObserverPlace(args)
{
	local props = ObserverProperties(null);
	props.Parse(args);
	
	local label = "__observer" + ObserverID++;
	local observer = SpawnEntityFromTable("prop_dynamic",
	{
		targetname = label,
		classname = "point_commentary_node", // preserve
		model = "models/editor/camera.mdl",
		origin = Host.EyePosition(),
		angles = Host.EyeAngles(),
		teamnum = props.team_num,
	})
	observer.ValidateScriptScope();
	observer.GetScriptScope().name <- props.name;
	observer.GetScriptScope().parent <- props.parent;
	observer.GetScriptScope().fov <- props.fov;
	observer.GetScriptScope().associate_entity <- props.associate_entity;	
	observer.GetScriptScope().welcome_point <- props.welcome_point;
	observer.GetScriptScope().match_summary <- props.match_summary;
	observer.GetScriptScope().start_disabled <- props.start_disabled;
	
	local glow = SpawnEntityFromTable("tf_glow",
	{
		classname = "point_commentary_node", // preserve
		target = label,
		origin = observer.GetOrigin(),
		GlowColor = props.glow_color
	});
	EntFireByHandle(glow, "SetParent", "!activator", -1, observer, observer);
	observer.GetScriptScope().glow <- glow;

	ObserverCameras.append(observer);
}

function ObserverFindCrosshair()
{
	local origin = Host.EyePosition();
	local forward = Host.EyeAngles().Forward();
	
	local closest, closest_dist = 1e30;
	foreach (observer in ObserverCameras)
	{	
		local dir = observer.GetOrigin() - origin;
		local dist = dir.Norm();
		
		if (forward.Dot(dir) < 0.99)
			continue;
			
		if (dist < closest_dist)
		{
			closest = observer;
			closest_dist = dist;
		}	
	}
	
	return closest;
}

function ObserverModify(args)
{
	local observer = ObserverFindCrosshair();
	if (!observer)
	{
		ClientPrint(null, 3, "No observer found under crosshair");
		return;
	}

	local props = ObserverProperties(observer);
	props.Parse(args);	
	
	observer.SetTeam(props.team_num);
	observer.GetScriptScope().name = props.name;
	observer.GetScriptScope().parent = props.parent;
	observer.GetScriptScope().fov = props.fov;
	observer.GetScriptScope().associate_entity = props.associate_entity;	
	observer.GetScriptScope().welcome_point = props.welcome_point;
	observer.GetScriptScope().match_summary = props.match_summary;
	observer.GetScriptScope().start_disabled = props.start_disabled;
	observer.GetScriptScope().glow.KeyValueFromString("GlowColor", props.glow_color);
	
	if (props.id >= 0)
	{
		if (props.id < ObserverCameras.len())
		{
			local swap_observer = ObserverCameras[props.id];
			local current_id = ObserverCameras.find(observer);
			ObserverCameras[props.id] = observer;
			ObserverCameras[current_id] = swap_observer;
		}
		else
		{
			ClientPrint(null, 3, format("Swap ID %d is out of bounds, ignoring", props.id));
		}
	}
	
	ClientPrint(null, 3, "Modified observer successfully");
}

function ObserverDelete(args)
{
	local observer = ObserverFindCrosshair();
	if (!observer)
	{
		ClientPrint(null, 3, "No observer found under crosshair");
		return;
	}
	
	ObserverCameras.remove(ObserverCameras.find(observer));
	observer.Kill();
	
	ClientPrint(null, 3, "Deleted observer successfully");
}

function ObserverSave(args)
{
	local vmf_name = GetMapName() + "_observers.vmf";
	local map_kv = KeyValues(vmf_name);

	foreach (observer in ObserverCameras)
	{
		local scope = observer.GetScriptScope();
		local entity_kv = KeyValues("entity", map_kv);
		entity_kv.Set("classname", "info_observer_point");
		entity_kv.Set("targetname", scope.name);
		entity_kv.Set("parentname", scope.parent);
		entity_kv.Set("origin", observer.GetOrigin());
		entity_kv.Set("angles", observer.GetAbsAngles());
		entity_kv.Set("teamnum", observer.GetTeam());
		entity_kv.Set("defaultwelcome", scope.welcome_point ? 1 : 0);
		entity_kv.Set("fov", scope.fov);
		entity_kv.Set("match_summary", scope.match_summary ? 1 : 0);
		entity_kv.Set("associated_team_entity", scope.associate_entity);
		entity_kv.Set("StartDisabled", scope.start_disabled ? 1 : 0);
	}

	map_kv.SaveToFile(true);
	
	ClientPrint(null, 3, format("Saved %d observers to tf/scriptdata/%s", ObserverCameras.len(), vmf_name));
}
    
function ObserverClear(args)
{
	ClientPrint(null, 3, format("Clearing %d observers", ObserverCameras.len()));
	
	foreach (observer in ObserverCameras)
		if (observer.IsValid())
			observer.Kill();
	ObserverCameras.clear();
}

function ObserverHelp(args)
{
	ClientPrint(null, 3, "* !place\nPlaces observer at current eye position and angles");
	ClientPrint(null, 3, "Optional arguments: team=red/blue/spectator parent=STR associate=STR welcome=0/1 summary=0/1 disable=0/1 fov=FLOAT");
	ClientPrint(null, 3, "Example usage: !place team=red welcome=1 fov=45");
	
	ClientPrint(null, 3, "* !modify\nModify observer under crosshair");
	ClientPrint(null, 3, "Optional arguments: team=INT parent=STR associate=STR welcome=0/1 summary=0/1 disable=0/1 fov=FLOAT");
	ClientPrint(null, 3, "id=INT (Specify the ID of another observer to swap with, for manipulating spectator order)");
	ClientPrint(null, 3, "Example usage: !modify team=blue id=0");

	ClientPrint(null, 3, "* !delete\nDeletes observer under crosshair");
	ClientPrint(null, 3, "* !clear\nDelete all observers");
		
	ClientPrint(null, 3, "* !save\nWrites observers to VMF");
}

function ObserverThink()
{
	local duration = 0.03;
	local offset = -4.0;
	
	foreach (i, observer in ObserverCameras)
	{
		local origin = observer.GetOrigin();
		if ((origin - Host.EyePosition()).Length() > 256)
			continue;
			
		local scope = observer.GetScriptScope();
		
		local team = observer.GetTeam();
		local team_text = "Unassigned";
		if (team == 1)
			team_text = "Spectator";
		else if (team == 2)
			team_text = "RED";
		else if (team == 3)
			team_text = "BLU";

		DebugDrawText(origin, "ID: " + i, false, duration); origin.z += offset;
		DebugDrawText(origin, "Name: " + scope.name, false, duration); origin.z += offset;
		DebugDrawText(origin, "Team: " + team_text, false, duration); origin.z += offset;		
		DebugDrawText(origin, "Origin: " + observer.GetOrigin().ToKVString(), false, duration); origin.z += offset;
		DebugDrawText(origin, "Angles: " + observer.GetAbsAngles().ToKVString(), false, duration); origin.z += offset;
		DebugDrawText(origin, "Start Disabled: " + (scope.start_disabled ? "Yes" : "No"), false, duration); origin.z += offset;
		DebugDrawText(origin, "Parent: " + scope.parent, false, duration); origin.z += offset;
		DebugDrawText(origin, "Associated Team Entity: " + scope.associate_entity, false, duration); origin.z += offset;
		DebugDrawText(origin, "Welcome Point: " + (scope.welcome_point ? "Yes" : "No"), false, duration); origin.z += offset;
		DebugDrawText(origin, "FOV: " + scope.fov, false, duration); origin.z += offset;		
		DebugDrawText(origin, "Match Summary: " + (scope.match_summary ? "Yes" : "No"), false, duration); origin.z += offset;		
	}
	
	return -1;
}

function OnGameEvent_player_say(params)
{
	local player = GetPlayerFromUserID(params.userid);
	if (player == null)
		return;
	
	local text = params.text;
	local args = split(text, " ");
	if (startswith(text, "!place"))
	{
		ObserverPlace(args);
	}
	else if (startswith(text, "!modify"))
	{
		ObserverModify(args);
	}	
	else if (startswith(text, "!delete"))
	{
		ObserverDelete(args);
	}	
	else if (startswith(text, "!save"))
	{
		ObserverSave(args);
	}
	else if (startswith(text, "!clear"))
	{
		ObserverClear(args);
	}
	else if (startswith(text, "!help"))
	{
		ObserverHelp(args);
	}
}
__CollectGameEventCallbacks(this);

AddThinkToEnt(Entities.FindByClassname(null, "worldspawn"), "ObserverThink");

ClientPrint(null, 3, "** Observer Tool loaded");
ClientPrint(null, 3, "** Type !help to see commands");