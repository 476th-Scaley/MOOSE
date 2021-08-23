--- **Ops** - Legion Warehouse.
--
-- Parent class of Airwings and Brigades.
--
-- ===
--
-- ### Author: **funkyfranky**
-- @module Ops.Legion
-- @image OPS_Legion.png


--- LEGION class.
-- @type LEGION
-- @field #string ClassName Name of the class.
-- @field #number verbose Verbosity of output.
-- @field #string lid Class id string for output to DCS log file.
-- @field #table missionqueue Mission queue table.
-- @field #table transportqueue Transport queue.
-- @field #table cohorts Cohorts of this legion.
-- @field Ops.Commander#COMMANDER commander Commander of this legion.
-- @extends Functional.Warehouse#WAREHOUSE

--- Be surprised!
--
-- ===
--
-- # The LEGION Concept
-- 
-- The LEGION class contains all functions that are common for the AIRWING, BRIGADE and XXX classes, which inherit the LEGION class.
-- 
-- An LEGION consists of multiple COHORTs. These cohorts "live" in a WAREHOUSE, i.e. a physical structure that can be destroyed or captured.
--
-- @field #LEGION
LEGION = {
  ClassName      = "LEGION",
  verbose        =     0,
  lid            =   nil,
  missionqueue   =    {},
  transportqueue =    {},
  cohorts        =    {},
}

--- LEGION class version.
-- @field #string version
LEGION.version="0.0.1"

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ToDo list
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TODO: A lot.
-- TODO: Make general so it can be inherited by AIRWING and BRIGADE classes.

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constructor
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Create a new LEGION class object.
-- @param #LEGION self
-- @param #string WarehouseName Name of the warehouse STATIC or UNIT object representing the warehouse.
-- @param #string LegionName Name of the legion.
-- @return #LEGION self
function LEGION:New(WarehouseName, LegionName)

  -- Inherit everything from WAREHOUSE class.
  local self=BASE:Inherit(self, WAREHOUSE:New(WarehouseName, LegionName)) -- #LEGION

  -- Nil check.
  if not self then
    BASE:E(string.format("ERROR: Could not find warehouse %s!", WarehouseName))
    return nil
  end

  -- Set some string id for output to DCS.log file.
  self.lid=string.format("LEGION %s | ", self.alias)

  -- Add FSM transitions.
  --                 From State  -->   Event        -->     To State
  self:AddTransition("*",             "MissionRequest",     "*")           -- Add a (mission) request to the warehouse.
  self:AddTransition("*",             "MissionCancel",      "*")           -- Cancel mission.
  
  self:AddTransition("*",             "TransportRequest",   "*")           -- Add a (mission) request to the warehouse.
  
  self:AddTransition("*",             "OpsOnMission",       "*")           -- An OPSGROUP was send on a Mission (AUFTRAG).
  self:AddTransition("*",             "FlightOnMission",    "*")           -- An OPSGROUP was send on a Mission (AUFTRAG).
  self:AddTransition("*",             "ArmyOnMission",      "*")           -- An OPSGROUP was send on a Mission (AUFTRAG).
  self:AddTransition("*",             "NavyOnMission",      "*")           -- An OPSGROUP was send on a Mission (AUFTRAG).
  
  self:AddTransition("*",             "AssetReturned",      "*")           -- An asset returned (from a mission) to the Legion warehouse.
  
  -- Defaults:
  -- TODO

  ------------------------
  --- Pseudo Functions ---
  ------------------------

  --- Triggers the FSM event "Start". Starts the LEGION. Initializes parameters and starts event handlers.
  -- @function [parent=#LEGION] Start
  -- @param #LEGION self

  --- Triggers the FSM event "Start" after a delay. Starts the LEGION. Initializes parameters and starts event handlers.
  -- @function [parent=#LEGION] __Start
  -- @param #LEGION self
  -- @param #number delay Delay in seconds.

  --- Triggers the FSM event "Stop". Stops the LEGION and all its event handlers.
  -- @param #LEGION self

  --- Triggers the FSM event "Stop" after a delay. Stops the LEGION and all its event handlers.
  -- @function [parent=#LEGION] __Stop
  -- @param #LEGION self
  -- @param #number delay Delay in seconds.


  --- Triggers the FSM event "MissionCancel".
  -- @function [parent=#LEGION] MissionCancel
  -- @param #LEGION self
  -- @param Ops.Auftrag#AUFTRAG Mission The mission.

  --- On after "MissionCancel" event.
  -- @function [parent=#LEGION] OnAfterMissionCancel
  -- @param #LEGION self
  -- @param #string From From state.
  -- @param #string Event Event.
  -- @param #string To To state.
  -- @param Ops.Auftrag#AUFTRAG Mission The mission.


  return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- User Functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Set verbosity level.
-- @param #LEGION self
-- @param #number VerbosityLevel Level of output (higher=more). Default 0.
-- @return #LEGION self
function LEGION:SetVerbosity(VerbosityLevel)
  self.verbose=VerbosityLevel or 0
  return self
end

--- Add a mission for the legion. It will pick the best available assets for the mission and lauch it when ready. 
-- @param #LEGION self
-- @param Ops.Auftrag#AUFTRAG Mission Mission for this legion.
-- @return #LEGION self
function LEGION:AddMission(Mission)

  -- Set status to QUEUED. This event is only allowed for the first legion that calls it.
  Mission:Queued()
  
  -- Set legion status.
  Mission:SetLegionStatus(self, AUFTRAG.Status.QUEUED)
  
  -- Add legion to mission.
  Mission:AddLegion(self)
  
  --[[
  if Mission.opstransport then
    Mission.opstransport:SetPickupZone(self.spawnzone)
    Mission.opstransport:SetEmbarkZone(self.spawnzone)
    self:AddOpsTransport(Mission.opstransport)
  end
  ]]

  -- Add mission to queue.
  table.insert(self.missionqueue, Mission)

  -- Info text.
  local text=string.format("Added mission %s (type=%s). Starting at %s. Stopping at %s",
  tostring(Mission.name), tostring(Mission.type), UTILS.SecondsToClock(Mission.Tstart, true), Mission.Tstop and UTILS.SecondsToClock(Mission.Tstop, true) or "INF")
  self:T(self.lid..text)

  return self
end

--- Remove mission from queue.
-- @param #LEGION self
-- @param Ops.Auftrag#AUFTRAG Mission Mission to be removed.
-- @return #LEGION self
function LEGION:RemoveMission(Mission)

  for i,_mission in pairs(self.missionqueue) do
    local mission=_mission --Ops.Auftrag#AUFTRAG

    if mission.auftragsnummer==Mission.auftragsnummer then
      mission:RemoveLegion(self)
      table.remove(self.missionqueue, i)
      break
    end

  end

  return self
end

--- Add transport assignment to queue. 
-- @param #LEGION self
-- @param Ops.OpsTransport#OPSTRANSPORT OpsTransport Transport assignment.
-- @return #LEGION self
function LEGION:AddOpsTransport(OpsTransport)

  -- Is not queued at a legion.
  OpsTransport:Queued()

  -- Add mission to queue.
  table.insert(self.transportqueue, OpsTransport)

  -- Info text.
  local text=string.format("Added Transport %s. Starting at %s-%s",
  tostring(OpsTransport.uid), UTILS.SecondsToClock(OpsTransport.Tstart, true), OpsTransport.Tstop and UTILS.SecondsToClock(OpsTransport.Tstop, true) or "INF")
  self:T(self.lid..text)

  return self
end


--- Get cohort by name.
-- @param #LEGION self
-- @param #string CohortName Name of the platoon.
-- @return Ops.Cohort#COHORT The Cohort object.
function LEGION:_GetCohort(CohortName)

  for _,_cohort in pairs(self.cohorts) do
    local cohort=_cohort --Ops.Cohort#COHORT

    if cohort.name==CohortName then
      return cohort
    end

  end

  return nil
end

--- Get cohort of an asset.
-- @param #LEGION self
-- @param Functional.Warehouse#WAREHOUSE.Assetitem Asset The asset.
-- @return Ops.Cohort#COHORT The Cohort object.
function LEGION:_GetCohortOfAsset(Asset)
  local cohort=self:_GetCohort(Asset.squadname)
  return cohort
end


--- Check if a BRIGADE class is calling.
-- @param #LEGION self
-- @return #boolean If true, this is a BRIGADE.
function LEGION:IsBrigade()
  local is=self.ClassName==BRIGADE.ClassName
  return is
end

--- Check if the AIRWING class is calling.
-- @param #LEGION self
-- @return #boolean If true, this is an AIRWING.
function LEGION:IsAirwing()
  local is=self.ClassName==AIRWING.ClassName
  return is
end


-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Start & Status
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Start LEGION FSM.
-- @param #LEGION self
function LEGION:onafterStart(From, Event, To)

  -- Start parent Warehouse.
  self:GetParent(self, LEGION).onafterStart(self, From, Event, To)

  -- Info.
  self:I(self.lid..string.format("Starting LEGION v%s", LEGION.version))

end



--- Check if mission is not over and ready to cancel.
-- @param #LEGION self
function LEGION:_CheckMissions()

  -- Loop over missions in queue.
  for _,_mission in pairs(self.missionqueue) do
    local mission=_mission --Ops.Auftrag#AUFTRAG

    if mission:IsNotOver() and mission:IsReadyToCancel() then
      mission:Cancel()
    end
  end

end

--- Get next mission.
-- @param #LEGION self
-- @return Ops.Auftrag#AUFTRAG Next mission or `#nil`.
function LEGION:_GetNextMission()

  -- Number of missions.
  local Nmissions=#self.missionqueue

  -- Treat special cases.
  if Nmissions==0 then
    return nil
  end

  -- Sort results table wrt prio and start time.
  local function _sort(a, b)
    local taskA=a --Ops.Auftrag#AUFTRAG
    local taskB=b --Ops.Auftrag#AUFTRAG
    return (taskA.prio<taskB.prio) or (taskA.prio==taskB.prio and taskA.Tstart<taskB.Tstart)
  end
  table.sort(self.missionqueue, _sort)

  -- Look for first mission that is SCHEDULED.
  local vip=math.huge
  for _,_mission in pairs(self.missionqueue) do
    local mission=_mission --Ops.Auftrag#AUFTRAG
    if mission.importance and mission.importance<vip then
      vip=mission.importance
    end
  end

  -- Current time.
  local time=timer.getAbsTime()

  -- Look for first task that is not accomplished.
  for _,_mission in pairs(self.missionqueue) do
    local mission=_mission --Ops.Auftrag#AUFTRAG

    -- Firstly, check if mission is due?
    if mission:IsQueued(self) and mission:IsReadyToGo() and (mission.importance==nil or mission.importance<=vip) then

      -- Check if legion can do the mission and gather required assets.
      local can, assets=self:CanMission(mission)

      -- Check that mission is still scheduled, time has passed and enough assets are available.
       if can then
       
        -- Number of required assets.
        local Nassets=mission:GetRequiredAssets(self)

        -- Optimize the asset selection. Most useful assets will come first. We do not include the payload as some assets have and some might not.
        self:_OptimizeAssetSelection(assets, mission, false)

        -- Assign assets to mission.
        local remove={}
        local gotpayload={}                
        if self:IsAirwing() then
          for i=1,#assets do
            local asset=assets[i] --Functional.Warehouse#WAREHOUSE.Assetitem
  
            -- Get payload for the asset.
            if not asset.payload then
              local payload=self:FetchPayloadFromStock(asset.unittype, mission.type, mission.payloads)
              if payload then
                asset.payload=payload
                table.insert(gotpayload, asset.uid)
              else
                table.insert(remove, asset.uid)
              end
            end
          end
          self:T(self.lid..string.format("Provided %d assets with payloads. Could not get payload for %d assets", #gotpayload, #remove))
  
          -- Now remove assets for which we don't have a payload.
          for i=#assets,1,-1 do
            local asset=assets[i] --Functional.Warehouse#WAREHOUSE.Assetitem
            for _,uid in pairs(remove) do
              if uid==asset.uid then
                table.remove(assets, i)
              end
            end
          end
  
          -- Another check.
          if #assets<mission.nassets then
            self:E(self.lid..string.format("ERROR: Not enough payloads for mission assets! Can only do %d/%d", #assets, mission.nassets))
          end
  
          -- Optimize the asset selection. Now we include the payload performance as this could change the result.
          self:_OptimizeAssetSelection(assets, mission, true)
          
        end

        -- Check that mission.assets table is clean.
        if mission.assets and #mission.assets>0 then
          self:E(self.lid..string.format("ERROR: mission %s of type %s has already assets attached!", mission.name, mission.type))
        end
        --mission.assets={}

        -- Assign assets to mission.
        for i=1,Nassets do
          local asset=assets[i] --Functional.Warehouse#WAREHOUSE.Assetitem

          -- Should not happen as we just checked!
          if self:IsAirwing() and not asset.payload then
            self:E(self.lid.."ERROR: No payload for asset! This should not happen!")
          end

          -- Add asset to mission.
          mission:AddAsset(asset)
        end

        -- Now return the remaining payloads.
        if self:IsAirwing() then
          for i=Nassets+1,#assets do
            local asset=assets[i] --Functional.Warehouse#WAREHOUSE.Assetitem
            for _,uid in pairs(gotpayload) do
              if uid==asset.uid then
                self:ReturnPayloadFromAsset(asset)
                break
              end
            end
          end
        end

        return mission
      end

    end -- mission due?
  end -- mission loop

  return nil
end

--- Get next transport.
-- @param #LEGION self
-- @return Ops.OpsTransport#OPSTRANSPORT Next transport or `#nil`.
function LEGION:_GetNextTransport()

  -- Number of missions.
  local Ntransports=#self.transportqueue

  -- Treat special cases.
  if Ntransports==0 then
    return nil
  end


  local function getAssets(n)
    local assets={}
  
    -- Loop over assets.
    for _,_cohort in pairs(self.cohorts) do
      local cohort=_cohort --Ops.Cohort#COHORT
      
      if cohort:CheckMissionCapability({AUFTRAG.Type.OPSTRANSPORT}, cohort.missiontypes) then
      
        for _,_asset in pairs(cohort.assets) do  
          local asset=_asset --Functional.Warehouse#WAREHOUSE.Assetitem
                  
          -- Check if asset is currently on a mission (STARTED or QUEUED).
          if not asset.spawned then
          
            -- Add to assets.    
            table.insert(assets, asset)
            
            if #assets==n then
              return assets
            end
          end
          
        end
        
      end
    end
  end

  
  -- Look for first task that is not accomplished.
  for _,_transport in pairs(self.transportqueue) do
    local transport=_transport --Ops.OpsTransport#OPSTRANSPORT

    -- Check if transport is still queued and ready.
    if transport:IsQueued() and transport:IsReadyToGo() then
    
      local assets=getAssets(1)

      if #assets>0 then
        transport.assets=assets  
        return transport    
      end
       
    end
    
  end
  
  
  return nil
end

--- Calculate the mission score of an asset.
-- @param #LEGION self
-- @param Functional.Warehouse#WAREHOUSE.Assetitem asset Asset
-- @param Ops.Auftrag#AUFTRAG Mission Mission for which the best assets are desired.
-- @param #boolean includePayload If true, include the payload in the calulation if the asset has one attached.
-- @return #number Mission score.
function LEGION:CalculateAssetMissionScore(asset, Mission, includePayload)

  local score=0

  -- Prefer highly skilled assets.
  if asset.skill==AI.Skill.AVERAGE then
    score=score+0
  elseif asset.skill==AI.Skill.GOOD then
    score=score+10
  elseif asset.skill==AI.Skill.HIGH then
    score=score+20
  elseif asset.skill==AI.Skill.EXCELLENT then
    score=score+30
  end

  -- Add mission performance to score.
  local cohort=self:_GetCohortOfAsset(asset)
  local missionperformance=cohort:GetMissionPeformance(Mission.type)
  score=score+missionperformance

  -- Add payload performance to score.
  if includePayload and asset.payload then
    score=score+self:GetPayloadPeformance(asset.payload, Mission.type)
  end

  -- Intercepts need to be carried out quickly. We prefer spawned assets.
  if Mission.type==AUFTRAG.Type.INTERCEPT then
    if asset.spawned then
      self:T(self.lid.."Adding 25 to asset because it is spawned")
      score=score+25
    end
  end

  -- TODO: This could be vastly improved. Need to gather ideas during testing.
  -- Calculate ETA? Assets on orbit missions should arrive faster even if they are further away.
  -- Max speed of assets.
  -- Fuel amount?
  -- Range of assets?

  return score
end

--- Optimize chosen assets for the mission at hand.
-- @param #LEGION self
-- @param #table assets Table of (unoptimized) assets.
-- @param Ops.Auftrag#AUFTRAG Mission Mission for which the best assets are desired.
-- @param #boolean includePayload If true, include the payload in the calulation if the asset has one attached.
function LEGION:_OptimizeAssetSelection(assets, Mission, includePayload)

  local TargetVec2=Mission:GetTargetVec2()

  local dStock=UTILS.VecDist2D(TargetVec2, self:GetVec2())

  -- Calculate distance to mission target.
  local distmin=math.huge
  local distmax=0
  for _,_asset in pairs(assets) do
    local asset=_asset --Functional.Warehouse#WAREHOUSE.Assetitem

    if asset.spawned then
      local group=GROUP:FindByName(asset.spawngroupname)
      asset.dist=UTILS.VecDist2D(group:GetVec2(), TargetVec2)
    else
      asset.dist=dStock
    end

    if asset.dist<distmin then
      distmin=asset.dist
    end

    if asset.dist>distmax then
      distmax=asset.dist
    end

  end

  -- Calculate the mission score of all assets.
  for _,_asset in pairs(assets) do
    local asset=_asset --Functional.Warehouse#WAREHOUSE.Assetitem
    asset.score=self:CalculateAssetMissionScore(asset, Mission, includePayload)
  end

  --- Sort assets wrt to their mission score. Higher is better.
  local function optimize(a, b)
    local assetA=a --Functional.Warehouse#WAREHOUSE.Assetitem
    local assetB=b --Functional.Warehouse#WAREHOUSE.Assetitem

    -- Higher score wins. If equal score ==> closer wins.
    -- TODO: Need to include the distance in a smarter way!
    return (assetA.score>assetB.score) or (assetA.score==assetB.score and assetA.dist<assetB.dist)
  end
  table.sort(assets, optimize)

  -- Remove distance parameter.
  local text=string.format("Optimized assets for %s mission (payload=%s):", Mission.type, tostring(includePayload))
  for i,Asset in pairs(assets) do
    local asset=Asset --Functional.Warehouse#WAREHOUSE.Assetitem
    text=text..string.format("\n%s %s: score=%d, distance=%.1f km", asset.squadname, asset.spawngroupname, asset.score, asset.dist/1000)
    asset.dist=nil
    asset.score=nil
  end
  self:T2(self.lid..text)

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- FSM Events
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- On after "MissionRequest" event. Performs a self request to the warehouse for the mission assets. Sets mission status to REQUESTED.
-- @param #LEGION self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Ops.Auftrag#AUFTRAG Mission The requested mission.
function LEGION:onafterMissionRequest(From, Event, To, Mission)

  -- Set mission status from QUEUED to REQUESTED.
  Mission:Requested()
  
  -- Set legion status. Ensures that it is not considered in the next selection.
  Mission:SetLegionStatus(self, AUFTRAG.Status.REQUESTED)

  ---
  -- Some assets might already be spawned and even on a different mission (orbit).
  -- Need to dived to set into spawned and instock assets and handle the other
  ---

  -- Assets to be requested.
  local Assetlist={}

  for _,_asset in pairs(Mission.assets) do
    local asset=_asset --Functional.Warehouse#WAREHOUSE.Assetitem

    -- Check that this asset belongs to this Legion warehouse.
    if asset.wid==self.uid then

      if asset.spawned then
  
        if asset.flightgroup then
  
          -- Add new mission.
          asset.flightgroup:AddMission(Mission)
  
          -- Trigger event.
          self:__OpsOnMission(5, asset.flightgroup, Mission)
  
        else
          self:E(self.lid.."ERROR: flight group for asset does NOT exist!")
        end
  
      else
        -- These assets need to be requested and spawned.
        table.insert(Assetlist, asset)
      end
      
    end
  end

  -- Add request to legion warehouse.
  if #Assetlist>0 then

    --local text=string.format("Requesting assets for mission %s:", Mission.name)
    for i,_asset in pairs(Assetlist) do
      local asset=_asset --Functional.Warehouse#WAREHOUSE.Assetitem

      -- Set asset to requested! Important so that new requests do not use this asset!
      asset.requested=true

      if Mission.missionTask then
        asset.missionTask=Mission.missionTask
      end

    end

    -- TODO: Get/set functions for assignment string.
    local assignment=string.format("Mission-%d", Mission.auftragsnummer)

    -- Add request to legion warehouse.
    self:AddRequest(self, WAREHOUSE.Descriptor.ASSETLIST, Assetlist, #Assetlist, nil, nil, Mission.prio, assignment)

    -- The queueid has been increased in the onafterAddRequest function. So we can simply use it here.
    Mission.requestID[self.alias]=self.queueid
  end

end

--- On after "MissionRequest" event. Performs a self request to the warehouse for the mission assets. Sets mission status to REQUESTED.
-- @param #LEGION self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Ops.OpsTransport#OPSTRANSPORT Opstransport The requested mission.
function LEGION:onafterTransportRequest(From, Event, To, OpsTransport)

  -- Set mission status from QUEUED to REQUESTED.
  OpsTransport:Requested()
  
  -- Set legion status. Ensures that it is not considered in the next selection.
  --Mission:SetLegionStatus(self, AUFTRAG.Status.REQUESTED)

  -- Add request to legion warehouse.
  if #OpsTransport.assets>0 then

    --local text=string.format("Requesting assets for mission %s:", Mission.name)
    for i,_asset in pairs(OpsTransport.assets) do
      local asset=_asset --Functional.Warehouse#WAREHOUSE.Assetitem

      -- Set asset to requested! Important so that new requests do not use this asset!
      asset.requested=true
      
      -- Check max required transports.
      if i==1 then
        break
      end
      
    end
    
    -- TODO: Get/set functions for assignment string.
    local assignment=string.format("Transport-%d", OpsTransport.uid)

    -- Add request to legion warehouse.
    self:AddRequest(self, WAREHOUSE.Descriptor.ASSETLIST, OpsTransport.assets, #OpsTransport.assets, nil, nil, OpsTransport.prio, assignment)

    -- The queueid has been increased in the onafterAddRequest function. So we can simply use it here.
    OpsTransport.requestID=OpsTransport.requestID or {}
    OpsTransport.requestID[self.alias]=self.queueid
  end

end

--- On after "MissionCancel" event. Cancels the missions of all flightgroups. Deletes request from warehouse queue.
-- @param #LEGION self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Ops.Auftrag#AUFTRAG Mission The mission to be cancelled.
function LEGION:onafterMissionCancel(From, Event, To, Mission)

  -- Info message.
  self:I(self.lid..string.format("Cancel mission %s", Mission.name))

  -- Set status to cancelled.
  Mission:SetLegionStatus(self, AUFTRAG.Status.CANCELLED)

  for _,_asset in pairs(Mission.assets) do
    local asset=_asset --Functional.Warehouse#WAREHOUSE.Assetitem
    
    -- Asset should belong to this legion.
    if asset.wid==self.uid then

      local opsgroup=asset.flightgroup

      if opsgroup then
        opsgroup:MissionCancel(Mission)
      end
      
      -- TODO: remove asset from mission

      -- Not requested any more (if it was).
      asset.requested=nil
      
    end      
  end

  -- Remove queued request (if any).
  if Mission.requestID[self.alias] then
    self:_DeleteQueueItemByID(Mission.requestID[self.alias], self.queue)
  end

end

--- On after "OpsOnMission".
-- @param #LEGION self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Ops.OpsGroup#OPSGROUP OpsGroup Ops group on mission
-- @param Ops.Auftrag#AUFTRAG Mission The requested mission.
function LEGION:onafterOpsOnMission(From, Event, To, OpsGroup, Mission)
  -- Debug info.
  self:T2(self.lid..string.format("Group %s on %s mission %s", OpsGroup:GetName(), Mission:GetType(), Mission:GetName()))

  if self:IsAirwing() then
    -- Trigger event for Airwings.
    self:FlightOnMission(OpsGroup, Mission)
  elseif self:IsBrigade() then
    -- Trigger event for Brigades.
    self:ArmyOnMission(OpsGroup, Mission)
  else
  end

end

--- On after "NewAsset" event. Asset is added to the given cohort (asset assignment).
-- @param #LEGION self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Functional.Warehouse#WAREHOUSE.Assetitem asset The asset that has just been added.
-- @param #string assignment The (optional) assignment for the asset.
function LEGION:onafterNewAsset(From, Event, To, asset, assignment)

  -- Call parent WAREHOUSE function first.
  self:GetParent(self, LEGION).onafterNewAsset(self, From, Event, To, asset, assignment)

  -- Debug text.
  local text=string.format("New asset %s with assignment %s and request assignment %s", asset.spawngroupname, tostring(asset.assignment), tostring(assignment))
  self:T3(self.lid..text)

  -- Get cohort.
  local cohort=self:_GetCohort(asset.assignment)

  -- Check if asset is already part of the squadron. If an asset returns, it will be added again! We check that asset.assignment is also assignment.
  if cohort then

    if asset.assignment==assignment then
    
      ---
      -- Asset is added to the COHORT for the first time
      ---

      local nunits=#asset.template.units

      -- Debug text.
      local text=string.format("Adding asset to squadron %s: assignment=%s, type=%s, attribute=%s, nunits=%d %s", cohort.name, assignment, asset.unittype, asset.attribute, nunits, tostring(cohort.ngrouping))
      self:T(self.lid..text)

      -- Adjust number of elements in the group.
      if cohort.ngrouping then
        local template=asset.template

        local N=math.max(#template.units, cohort.ngrouping)

        -- Handle units.
        for i=1,N do

          -- Unit template.
          local unit = template.units[i]

          -- If grouping is larger than units present, copy first unit.
          if i>nunits then
            table.insert(template.units, UTILS.DeepCopy(template.units[1]))
          end

          -- Remove units if original template contains more than in grouping.
          if cohort.ngrouping<nunits and i>nunits then
            unit=nil
          end
        end

        asset.nunits=cohort.ngrouping
      end

      -- Set takeoff type.
      asset.takeoffType=cohort.takeoffType
      
      -- Set parking IDs.
      asset.parkingIDs=cohort.parkingIDs

      -- Create callsign and modex (needs to be after grouping).
      cohort:GetCallsign(asset)
      cohort:GetModex(asset)

      -- Set spawn group name. This has to include "AID-" for warehouse.
      asset.spawngroupname=string.format("%s_AID-%d", cohort.name, asset.uid)

      -- Add asset to cohort.
      cohort:AddAsset(asset)

      -- TODO
      --asset.terminalType=AIRBASE.TerminalType.OpenBig
    else

      ---
      -- Asset is returned to the COHORT
      ---
      
      -- Trigger event.
      self:AssetReturned(cohort, asset)

    end

  end
end

--- On after "AssetReturned" event. Triggered when an asset group returned to its legion.
-- @param #LEGION self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Ops.Cohort#COHORT Cohort The cohort the asset belongs to.
-- @param Functional.Warehouse#WAREHOUSE.Assetitem Asset The asset that returned.
function LEGION:onafterAssetReturned(From, Event, To, Cohort, Asset)
  -- Debug message.
  self:T(self.lid..string.format("Asset %s from Cohort %s returned! asset.assignment=\"%s\"", Asset.spawngroupname, Cohort.name, tostring(Asset.assignment)))

  -- Stop flightgroup.
  if Asset.flightgroup and not Asset.flightgroup:IsStopped() then
    Asset.flightgroup:Stop()
  end

  -- Return payload.
  if Asset.flightgroup:IsFlightgroup() then
    self:ReturnPayloadFromAsset(Asset)
  end

  -- Return tacan channel.
  if Asset.tacan then
    Cohort:ReturnTacan(Asset.tacan)
  end

  -- Set timestamp.
  Asset.Treturned=timer.getAbsTime()
  
  if self:IsAirwing() then
    -- Trigger airwing/squadron event.
    self:SquadronAssetReturned(Cohort, Asset)
  elseif self:IsBrigade() then
    -- Trigger brigade/platoon event.
    self:PlatoonAssetReturned(Cohort, Asset)
  end
end


--- On after "AssetSpawned" event triggered when an asset group is spawned into the cruel world.
-- Creates a new flightgroup element and adds the mission to the flightgroup queue.
-- @param #LEGION self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Wrapper.Group#GROUP group The group spawned.
-- @param Functional.Warehouse#WAREHOUSE.Assetitem asset The asset that was spawned.
-- @param Functional.Warehouse#WAREHOUSE.Pendingitem request The request of the dead asset.
function LEGION:onafterAssetSpawned(From, Event, To, group, asset, request)

  -- Call parent warehouse function first.
  self:GetParent(self, LEGION).onafterAssetSpawned(self, From, Event, To, group, asset, request)

  -- Get the COHORT of the asset.
  local cohort=self:_GetCohortOfAsset(asset)

  -- Check if we have a cohort or if this was some other request.
  if cohort then

    -- Create a flight group.
    local flightgroup=self:_CreateFlightGroup(asset)

    ---
    -- Asset
    ---

    -- Set asset flightgroup.
    asset.flightgroup=flightgroup

    -- Not requested any more.
    asset.requested=nil

    -- Did not return yet.
    asset.Treturned=nil

    ---
    -- Cohort
    ---

    -- Get TACAN channel.
    local Tacan=cohort:FetchTacan()
    if Tacan then
      asset.tacan=Tacan
      --flightgroup:SetDefaultTACAN(Tacan,Morse,UnitName,Band,OffSwitch)
      flightgroup:SwitchTACAN(Tacan, Morse, UnitName, Band)
    end

    -- Set radio frequency and modulation
    local radioFreq, radioModu=cohort:GetRadio()
    if radioFreq then
      flightgroup:SwitchRadio(radioFreq, radioModu)
    end

    if cohort.fuellow then
      flightgroup:SetFuelLowThreshold(cohort.fuellow)
    end

    if cohort.fuellowRefuel then
      flightgroup:SetFuelLowRefuel(cohort.fuellowRefuel)
    end

    -- Assignment.
    local assignment=request.assignment
    
    if string.find(assignment, "Mission-") then

      ---
      -- Mission
      ---
      
      local uid=UTILS.Split(assignment, "-")[2]
  
      -- Get Mission (if any).
      local mission=self:GetMissionByID(uid)
  
      -- Add mission to flightgroup queue.
      if mission then
  
        if Tacan then
          --mission:SetTACAN(Tacan, Morse, UnitName, Band)
        end
        
        -- Add mission to flightgroup queue. If mission has an OPSTRANSPORT attached, all added OPSGROUPS are added as CARGO for a transport.
        flightgroup:AddMission(mission)        
          
        -- Trigger event.
        self:__OpsOnMission(5, flightgroup, mission)
  
      else
  
        if Tacan then
          --flightgroup:SwitchTACAN(Tacan, Morse, UnitName, Band)
        end
  
      end
  
      -- Add group to the detection set of the CHIEF (INTEL).
      if self.commander and self.commander.chief then
        self.commander.chief.detectionset:AddGroup(asset.flightgroup.group)
      end
      
    elseif string.find(assignment, "Transport-") then
    
      ---
      -- Transport
      ---
      
      local uid=UTILS.Split(assignment, "-")[2] 

            -- Get Mission (if any).
      local transport=self:GetTransportByID(uid)
  
      -- Add mission to flightgroup queue.
      if transport then
        flightgroup:AddOpsTransport(transport)
      end
  
    end
    
  end
  
end

--- On after "AssetDead" event triggered when an asset group died.
-- @param #LEGION self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Functional.Warehouse#WAREHOUSE.Assetitem asset The asset that is dead.
-- @param Functional.Warehouse#WAREHOUSE.Pendingitem request The request of the dead asset.
function LEGION:onafterAssetDead(From, Event, To, asset, request)

  -- Call parent warehouse function first.
  self:GetParent(self, LEGION).onafterAssetDead(self, From, Event, To, asset, request)
  
  -- Remove group from the detection set of the CHIEF (INTEL).
  if self.commander and self.commander.chief then
    self.commander.chief.detectionset:RemoveGroupsByName({asset.spawngroupname})
  end  

  -- Remove asset from mission is done via Mission:AssetDead() call from flightgroup onafterFlightDead function
  -- Remove asset from squadron same
end

--- On after "Destroyed" event. Remove assets from cohorts. Stop cohorts.
-- @param #LEGION self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function LEGION:onafterDestroyed(From, Event, To)

  -- Debug message.
  self:I(self.lid.."Legion warehouse destroyed!")

  -- Cancel all missions.
  for _,_mission in pairs(self.missionqueue) do
    local mission=_mission --Ops.Auftrag#AUFTRAG
    mission:Cancel()
  end

  -- Remove all cohort assets.
  for _,_cohort in pairs(self.cohorts) do
    local cohort=_cohort --Ops.Cohort#COHORT
    -- Stop Cohort. This also removes all assets.
    cohort:Stop()
  end

  -- Call parent warehouse function first.
  self:GetParent(self, LEGION).onafterDestroyed(self, From, Event, To)

end


--- On after "Request" event.
-- @param #LEGION self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Functional.Warehouse#WAREHOUSE.Queueitem Request Information table of the request.
function LEGION:onafterRequest(From, Event, To, Request)

  -- Assets
  local assets=Request.cargoassets

  -- Get Mission
  local Mission=self:GetMissionByID(Request.assignment)

  if Mission and assets then

    for _,_asset in pairs(assets) do
      local asset=_asset --Functional.Warehouse#WAREHOUSE.Assetitem
      -- This would be the place to modify the asset table before the asset is spawned.
    end

  end

  -- Call parent warehouse function after assets have been adjusted.
  self:GetParent(self, LEGION).onafterRequest(self, From, Event, To, Request)

end

--- On after "SelfRequest" event.
-- @param #LEGION self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Core.Set#SET_GROUP groupset The set of asset groups that was delivered to the warehouse itself.
-- @param Functional.Warehouse#WAREHOUSE.Pendingitem request Pending self request.
function LEGION:onafterSelfRequest(From, Event, To, groupset, request)

  -- Call parent warehouse function first.
  self:GetParent(self, LEGION).onafterSelfRequest(self, From, Event, To, groupset, request)

  -- Get Mission
  local mission=self:GetMissionByID(request.assignment)

  for _,_asset in pairs(request.assets) do
    local asset=_asset --Functional.Warehouse#WAREHOUSE.Assetitem
  end

  for _,_group in pairs(groupset:GetSet()) do
    local group=_group --Wrapper.Group#GROUP
  end

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Misc Functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Create a new flight group after an asset was spawned.
-- @param #LEGION self
-- @param Functional.Warehouse#WAREHOUSE.Assetitem asset The asset.
-- @return Ops.FlightGroup#FLIGHTGROUP The created flightgroup object.
function LEGION:_CreateFlightGroup(asset)

  -- Create flightgroup.
  local flightgroup=nil --Ops.OpsGroup#OPSGROUP  
  if self:IsAirwing() then
    flightgroup=FLIGHTGROUP:New(asset.spawngroupname)
  elseif self:IsBrigade() then
    flightgroup=ARMYGROUP:New(asset.spawngroupname)
  else
    self:E(self.lid.."ERROR: not airwing or brigade!")
  end

  -- Set legion.
  flightgroup:_SetLegion(self)

  -- Set cohort.
  flightgroup.cohort=self:_GetCohortOfAsset(asset)

  -- Set home base.
  flightgroup.homebase=self.airbase

  return flightgroup
end


--- Check if an asset is currently on a mission (STARTED or EXECUTING).
-- @param #LEGION self
-- @param Functional.Warehouse#WAREHOUSE.Assetitem asset The asset.
-- @param #table MissionTypes Types on mission to be checked. Default all.
-- @return #boolean If true, asset has at least one mission of that type in the queue.
function LEGION:IsAssetOnMission(asset, MissionTypes)

  if MissionTypes then
    if type(MissionTypes)~="table" then
      MissionTypes={MissionTypes}
    end
  else
    -- Check all possible types.
    MissionTypes=AUFTRAG.Type
  end

  if asset.flightgroup and asset.flightgroup:IsAlive() then

    -- Loop over mission queue.
    for _,_mission in pairs(asset.flightgroup.missionqueue or {}) do
      local mission=_mission --Ops.Auftrag#AUFTRAG

      if mission:IsNotOver() then

        -- Get flight status.
        local status=mission:GetGroupStatus(asset.flightgroup)

        -- Only if mission is started or executing.
        if (status==AUFTRAG.GroupStatus.STARTED or status==AUFTRAG.GroupStatus.EXECUTING) and self:CheckMissionType(mission.type, MissionTypes) then
          return true
        end

      end

    end

  end

  -- Alternative: run over all missions and compare to mission assets.
  --[[
  for _,_mission in pairs(self.missionqueue) do
    local mission=_mission --Ops.Auftrag#AUFTRAG

    if mission:IsNotOver() then
      for _,_asset in pairs(mission.assets) do
        local sqasset=_asset --Functional.Warehouse#WAREHOUSE.Assetitem

        if sqasset.uid==asset.uid then
          return true
        end

      end
    end

  end
  ]]

  return false
end

--- Get the current mission of the asset.
-- @param #LEGION self
-- @param Functional.Warehouse#WAREHOUSE.Assetitem asset The asset.
-- @return Ops.Auftrag#AUFTRAG Current mission or *nil*.
function LEGION:GetAssetCurrentMission(asset)

  if asset.flightgroup then
    return asset.flightgroup:GetMissionCurrent()
  end

  return nil
end

--- Count payloads in stock.
-- @param #LEGION self
-- @param #table MissionTypes Types on mission to be checked. Default *all* possible types `AUFTRAG.Type`.
-- @param #table UnitTypes Types of units.
-- @param #table Payloads Specific payloads to be counted only.
-- @return #number Count of available payloads in stock.
function LEGION:CountPayloadsInStock(MissionTypes, UnitTypes, Payloads)

  if MissionTypes then
    if type(MissionTypes)=="string" then
      MissionTypes={MissionTypes}
    end
  end

  if UnitTypes then
    if type(UnitTypes)=="string" then
      UnitTypes={UnitTypes}
    end
  end

  local function _checkUnitTypes(payload)
    if UnitTypes then
      for _,unittype in pairs(UnitTypes) do
        if unittype==payload.aircrafttype then
          return true
        end
      end
    else
      -- Unit type was not specified.
      return true
    end
    return false
  end

  local function _checkPayloads(payload)
    if Payloads then
      for _,Payload in pairs(Payloads) do
        if Payload.uid==payload.uid then
          return true
        end
      end
    else
      -- Payload was not specified.
      return nil
    end
    return false
  end

  local n=0
  for _,_payload in pairs(self.payloads or {}) do
    local payload=_payload --#LEGION.Payload

    for _,MissionType in pairs(MissionTypes) do

      local specialpayload=_checkPayloads(payload)
      local compatible=self:CheckMissionCapability(MissionType, payload.capabilities)

      local goforit = specialpayload or (specialpayload==nil and compatible)

      if goforit and _checkUnitTypes(payload) then

        if payload.unlimited then
          -- Payload is unlimited. Return a BIG number.
          return 999
        else
          n=n+payload.navail
        end

      end

    end
  end

  return n
end

--- Count missions in mission queue.
-- @param #LEGION self
-- @param #table MissionTypes Types on mission to be checked. Default *all* possible types `AUFTRAG.Type`.
-- @return #number Number of missions that are not over yet.
function LEGION:CountMissionsInQueue(MissionTypes)

  MissionTypes=MissionTypes or AUFTRAG.Type

  local N=0
  for _,_mission in pairs(self.missionqueue) do
    local mission=_mission --Ops.Auftrag#AUFTRAG

    -- Check if this mission type is requested.
    if mission:IsNotOver() and self:CheckMissionType(mission.type, MissionTypes) then
      N=N+1
    end

  end

  return N
end

--- Count total number of assets of the legion.
-- @param #LEGION self
-- @param #boolean InStock If true, only assets that are in the warehouse stock/inventory are counted.
-- @param #table MissionTypes (Optional) Count only assest that can perform certain mission type(s). Default is all types.
-- @param #table Attributes (Optional) Count only assest that have a certain attribute(s), e.g. `WAREHOUSE.Attribute.AIR_BOMBER`.
-- @return #number Amount of asset groups in stock.
function LEGION:CountAssets(InStock, MissionTypes, Attributes)

  local N=0

  for _,_cohort in pairs(self.cohorts) do
    local cohort=_cohort --Ops.Cohort#COHORT
    N=N+cohort:CountAssets(InStock, MissionTypes, Attributes)
  end

  return N
end

--- Count total number of assets in LEGION warehouse stock that also have a payload.
-- @param #LEGION self
-- @param #boolean Payloads (Optional) Specifc payloads to consider. Default all.
-- @param #table MissionTypes (Optional) Count only assest that can perform certain mission type(s). Default is all types.
-- @param #table Attributes (Optional) Count only assest that have a certain attribute(s), e.g. `WAREHOUSE.Attribute.AIR_BOMBER`.
-- @return #number Amount of asset groups in stock.
function LEGION:CountAssetsWithPayloadsInStock(Payloads, MissionTypes, Attributes)

  -- Total number counted.
  local N=0
  
  -- Number of payloads in stock per aircraft type.
  local Npayloads={}
  
  -- First get payloads for aircraft types of squadrons.
  for _,_cohort in pairs(self.cohorts) do
    local cohort=_cohort --Ops.Cohort#COHORT
    if Npayloads[cohort.aircrafttype]==nil then    
      Npayloads[cohort.aircrafttype]=self:CountPayloadsInStock(MissionTypes, cohort.aircrafttype, Payloads)
      env.info(string.format("FF got Npayloads=%d for type=%s",Npayloads[cohort.aircrafttype], cohort.aircrafttype))
    end
  end

  for _,_cohort in pairs(self.cohorts) do
    local cohort=_cohort --Ops.Cohort#COHORT
    
    -- Number of assets in stock.
    local n=cohort:CountAssets(true, MissionTypes, Attributes)
    
    -- Number of payloads.
    local p=Npayloads[cohort.aircrafttype] or 0
    
    -- Only the smaller number of assets or paylods is really available.        
    local m=math.min(n, p)
    
    env.info("FF n="..n)
    env.info("FF p="..p)
    
    -- Add up what we have. Could also be zero.
    N=N+m
    
    -- Reduce number of available payloads.
    Npayloads[cohort.aircrafttype]=Npayloads[cohort.aircrafttype]-m
  end

  return N
end

--- Count assets on mission.
-- @param #LEGION self
-- @param #table MissionTypes Types on mission to be checked. Default all.
-- @param Ops.Cohort#COHORT Cohort Only count assets of this cohort. Default count assets of all cohorts.
-- @return #number Number of pending and queued assets.
-- @return #number Number of pending assets.
-- @return #number Number of queued assets.
function LEGION:CountAssetsOnMission(MissionTypes, Cohort)

  local Nq=0
  local Np=0

  for _,_mission in pairs(self.missionqueue) do
    local mission=_mission --Ops.Auftrag#AUFTRAG

    -- Check if this mission type is requested.
    if self:CheckMissionType(mission.type, MissionTypes or AUFTRAG.Type) then

      for _,_asset in pairs(mission.assets or {}) do
        local asset=_asset --Functional.Warehouse#WAREHOUSE.Assetitem
        
        -- Ensure asset belongs to this letion.
        if asset.wid==self.uid then

          if Cohort==nil or Cohort.name==asset.squadname then
  
            local request, isqueued=self:GetRequestByID(mission.requestID[self.alias])
  
            if isqueued then
              Nq=Nq+1
            else
              Np=Np+1
            end
  
          end
          
        end
      end
    end
  end

  --env.info(string.format("FF N=%d Np=%d, Nq=%d", Np+Nq, Np, Nq))
  return Np+Nq, Np, Nq
end

--- Count assets on mission.
-- @param #LEGION self
-- @param #table MissionTypes Types on mission to be checked. Default all.
-- @return #table Assets on pending requests.
function LEGION:GetAssetsOnMission(MissionTypes)

  local assets={}
  local Np=0

  for _,_mission in pairs(self.missionqueue) do
    local mission=_mission --Ops.Auftrag#AUFTRAG

    -- Check if this mission type is requested.
    if self:CheckMissionType(mission.type, MissionTypes) then

      for _,_asset in pairs(mission.assets or {}) do
        local asset=_asset --Functional.Warehouse#WAREHOUSE.Assetitem
        
        -- Ensure asset belongs to this legion.
        if asset.wid==self.uid then

          table.insert(assets, asset)
          
        end

      end
    end
  end

  return assets
end

--- Get the unit types of this legion. These are the unit types of all assigned cohorts.
-- @param #LEGION self
-- @param #boolean onlyactive Count only the active ones.
-- @param #table cohorts Table of cohorts. Default all.
-- @return #table Table of unit types.
function LEGION:GetAircraftTypes(onlyactive, cohorts)

  -- Get all unit types that can do the job.
  local unittypes={}

  -- Loop over all cohorts.
  for _,_cohort in pairs(cohorts or self.cohorts) do
    local cohort=_cohort --Ops.Cohort#COHORT

    if (not onlyactive) or cohort:IsOnDuty() then

      local gotit=false
      for _,unittype in pairs(unittypes) do
        if cohort.aircrafttype==unittype then
          gotit=true
          break
        end
      end
      if not gotit then
        table.insert(unittypes, cohort.aircrafttype)
      end

    end
  end

  return unittypes
end

--- Check if assets for a given mission type are available.
-- @param #LEGION self
-- @param Ops.Auftrag#AUFTRAG Mission The mission.
-- @return #boolean If true, enough assets are available.
-- @return #table Assets that can do the required mission.
function LEGION:CanMission(Mission)

  -- Assume we CAN and NO assets are available.
  local Can=true
  local Assets={}
  
  -- Squadrons for the job. If user assigned to mission or simply all.
  local cohorts=Mission.squadrons or self.cohorts
  
  -- Number of required assets.
  local Nassets=Mission:GetRequiredAssets(self)

  -- Get aircraft unit types for the job.
  local unittypes=self:GetAircraftTypes(true, cohorts)

  -- Count all payloads in stock.
  if self:IsAirwing() then
  
    -- Number of payloads in stock.
    local Npayloads=self:CountPayloadsInStock(Mission.type, unittypes, Mission.payloads)
  
    if Npayloads<Nassets then
      self:T(self.lid..string.format("INFO: Not enough PAYLOADS available! Got %d but need at least %d", Npayloads, Nassets))
      return false, Assets
    end
  end

  for cohortname,_cohort in pairs(cohorts) do
    local cohort=_cohort --Ops.Cohort#COHORT

    -- Check if this squadron can.
    local can=cohort:CanMission(Mission)

    if can then

      -- Number of payloads available.
      local Npayloads=self:IsAirwing() and self:CountPayloadsInStock(Mission.type, cohort.aircrafttype, Mission.payloads) or 999

      -- Recruit assets.
      local assets=cohort:RecruitAssets(Mission, Npayloads)

      -- Total number.
      for _,asset in pairs(assets) do
        table.insert(Assets, asset)
      end

      -- Debug output.
      local text=string.format("Mission=%s, cohort=%s, payloads=%d, can=%s, assets=%d. Found %d/%d", Mission.type, cohort.name, Npayloads, tostring(can), #assets, #Assets, Mission.nassets)
      self:T(self.lid..text)

    end

  end

  -- Check if required assets are present.
  if Nassets>#Assets then
    self:T(self.lid..string.format("INFO: Not enough assets available! Got %d but need at least %d", #Assets, Mission.nassets))
    Can=false
  end

  return Can, Assets
end

--- Check if assets for a given mission type are available.
-- @param #LEGION self
-- @param Ops.Auftrag#AUFTRAG Mission The mission.
-- @return #table Assets that can do the required mission.
function LEGION:RecruitAssets(Mission)

end


--- Check if a mission type is contained in a list of possible types.
-- @param #LEGION self
-- @param #string MissionType The requested mission type.
-- @param #table PossibleTypes A table with possible mission types.
-- @return #boolean If true, the requested mission type is part of the possible mission types.
function LEGION:CheckMissionType(MissionType, PossibleTypes)

  if type(PossibleTypes)=="string" then
    PossibleTypes={PossibleTypes}
  end

  for _,canmission in pairs(PossibleTypes) do
    if canmission==MissionType then
      return true
    end
  end

  return false
end

--- Check if a mission type is contained in a list of possible capabilities.
-- @param #LEGION self
-- @param #string MissionType The requested mission type.
-- @param #table Capabilities A table with possible capabilities.
-- @return #boolean If true, the requested mission type is part of the possible mission types.
function LEGION:CheckMissionCapability(MissionType, Capabilities)

  for _,cap in pairs(Capabilities) do
    local capability=cap --Ops.Auftrag#AUFTRAG.Capability
    if capability.MissionType==MissionType then
      return true
    end
  end

  return false
end

--- Get payload performance for a given type of misson type.
-- @param #LEGION self
-- @param #LEGION.Payload Payload The payload table.
-- @param #string MissionType Type of mission.
-- @return #number Performance or -1.
function LEGION:GetPayloadPeformance(Payload, MissionType)

  if Payload then

    for _,Capability in pairs(Payload.capabilities) do
      local capability=Capability --Ops.Auftrag#AUFTRAG.Capability
      if capability.MissionType==MissionType then
        return capability.Performance
      end
    end

  else
    self:E(self.lid.."ERROR: Payload is nil!")
  end

  return -1
end

--- Get mission types a payload can perform.
-- @param #LEGION self
-- @param #LEGION.Payload Payload The payload table.
-- @return #table Mission types.
function LEGION:GetPayloadMissionTypes(Payload)

  local missiontypes={}

  for _,Capability in pairs(Payload.capabilities) do
    local capability=Capability --Ops.Auftrag#AUFTRAG.Capability
    table.insert(missiontypes, capability.MissionType)
  end

  return missiontypes
end

--- Returns the mission for a given mission ID (Autragsnummer).
-- @param #LEGION self
-- @param #number mid Mission ID (Auftragsnummer).
-- @return Ops.Auftrag#AUFTRAG Mission table.
function LEGION:GetMissionByID(mid)

  for _,_mission in pairs(self.missionqueue) do
    local mission=_mission --Ops.Auftrag#AUFTRAG

    if mission.auftragsnummer==tonumber(mid) then
      return mission
    end

  end

  return nil
end

--- Returns the mission for a given ID.
-- @param #LEGION self
-- @param #number uid Transport UID.
-- @return Ops.OpsTransport#OPSTRANSPORT Transport assignment.
function LEGION:GetTransportByID(uid)

  for _,_transport in pairs(self.transportqueue) do
    local transport=_transport --Ops.OpsTransport#OPSTRANSPORT

    if transport.uid==tonumber(uid) then
      return transport
    end

  end

  return nil
end

--- Returns the mission for a given request ID.
-- @param #LEGION self
-- @param #number RequestID Unique ID of the request.
-- @return Ops.Auftrag#AUFTRAG Mission table or *nil*.
function LEGION:GetMissionFromRequestID(RequestID)
  for _,_mission in pairs(self.missionqueue) do
    local mission=_mission --Ops.Auftrag#AUFTRAG
    local mid=mission.requestID[self.alias]
    if  mid and mid==RequestID then
      return mission
    end
  end
  return nil
end

--- Returns the mission for a given request.
-- @param #LEGION self
-- @param Functional.Warehouse#WAREHOUSE.Queueitem Request The warehouse request.
-- @return Ops.Auftrag#AUFTRAG Mission table or *nil*.
function LEGION:GetMissionFromRequest(Request)
  return self:GetMissionFromRequestID(Request.uid)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------