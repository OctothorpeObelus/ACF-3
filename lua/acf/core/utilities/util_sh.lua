local ACF = ACF

do -- Ricochet/Penetration materials
	local Materials = {}
	local MatCache = {}
	local Lookup = {}
	local Count = 0

	local function GetMaterial(Path)
		if not Path then return end
		if MatCache[Path] then return MatCache[Path] end

		local Object = Material(Path)

		MatCache[Path] = Object

		return Object
	end

	local function DefaultScale(Caliber)
		return Caliber * 0.1312 -- Default AP decal makes a 76.2mm hole, dividing by 7.62cm
	end

	function ACF.RegisterAmmoDecal(Type, PenPath, RicoPath, ScaleFunc)
		if not Type then return end

		if not Lookup[Type] then
			Count = Count + 1

			Materials[Count] = {
				Penetration = GetMaterial(PenPath),
				Ricochet = GetMaterial(RicoPath),
				Scale = ScaleFunc or DefaultScale,
				Index = Count,
				Type = Type,
			}

			Lookup[Type] = Materials[Count]
		else
			local Data = Lookup[Type]
			Data.Penetration = GetMaterial(PenPath)
			Data.Ricochet = GetMaterial(RicoPath)
			Data.Scale = ScaleFunc or DefaultScale
		end
	end

	function ACF.IsValidAmmoDecal(Key)
		if not Key then return false end
		if Lookup[Key] then return true end
		if Materials[Key] then return true end

		return false
	end

	function ACF.GetAmmoDecalIndex(Type)
		if not Type then return end
		if not Lookup[Type] then return end

		return Lookup[Type].Index
	end

	function ACF.GetAmmoDecalType(Index)
		if not Index then return end
		if not Materials[Index] then return end

		return Materials[Index].Type
	end

	function ACF.GetPenetrationDecal(Key)
		if not Key then return end

		if Lookup[Key] then
			return Lookup[Key].Penetration
		end

		if Materials[Key] then
			return Materials[Key].Penetration
		end
	end

	function ACF.GetRicochetDecal(Key)
		if not Key then return end

		if Lookup[Key] then
			return Lookup[Key].Ricochet
		end

		if Materials[Key] then
			return Materials[Key].Ricochet
		end
	end

	function ACF.GetDecalScale(Key, Caliber)
		if not Key then return end

		if Lookup[Key] then
			return Lookup[Key].Scale(Caliber)
		end

		if Materials[Key] then
			return Materials[Key].Scale(Caliber)
		end
	end
end

do -- Mobility functions
	local Clamp = math.Clamp

	-- Calculates a position along a catmull-rom spline (as defined on https://www.mvps.org/directx/articles/catmull/)
	function ACF.GetTorque(Points, Pos)
		local Count = #Points

		if Count < 3 then return 0 end

		Pos = Clamp(Pos, 0, 1)

		local T       = (Pos * (Count - 1)) % 1
		local Current = math.floor(Pos * (Count - 1) + 1)
		local P0      = Points[Clamp(Current - 1, 1, Count - 2)]
		local P1      = Points[Clamp(Current, 1, Count - 1)]
		local P2      = Points[Clamp(Current + 1, 2, Count)]
		local P3      = Points[Clamp(Current + 2, 3, Count)]

		return 0.5 * ((2 * P1) +
			(P2 - P0) * T +
			(2 * P0 - 5 * P1 + 4 * P2 - P3) * T ^ 2 +
			(3 * P1 - P0 - 3 * P2 + P3) * T ^ 3)
	end

	-- Calculates the performance characteristics of an engine, given a torque curve, max torque (in nm), idle, and redline RPM
	function ACF.AddEnginePerformanceData(Class)
		local Curve          = Class.TorqueCurve
		local MaxTq          = Class.Torque
		local Idle           = Class.RPM.Idle
		local Redline        = Class.RPM.Limit
		local CurveFactor    = (Redline - Idle) / Redline --Torque curves all start after idle RPM is reached
		local PeakTq         = 0
		local PeakPower      = 0
		local PowerbandPeak  = 0 -- Highest value of (torque + power) / 2
		local PowerTable     = {} -- Power at each point on the curve for use in powerband calc
		local PowerbandTable = {} -- (torque + power) / 2 at each point on the curve
		local Iterations     = 32 -- Iterations for use in calculating the curve, higher is more accurate
		local PeakTqRPM
		local PeakPowerRPM
		local PowerbandMinRPM
		local PowerbandMaxRPM

		-- Calculate peak torque/Power RPM.
		for I = 0, Iterations do
			local RPM   = I / Iterations * Redline
			local Perc  = (RPM - Idle) / CurveFactor / Redline
			local CurTq = ACF.GetTorque(Curve, Perc)
			local Power = MaxTq * CurTq * RPM / 9548.8

			PowerTable[I] = Power

			if Power > PeakPower then
				PeakPower    = Power
				PeakPowerRPM = RPM
			end

			if Clamp(CurTq, 0, 1) > PeakTq then
				PeakTq    = CurTq
				PeakTqRPM = RPM
			end
		end

		-- Loop two, to calculate the powerband's peak.
		for I = 0, Iterations do
			local Power     = PowerTable[I] / PeakPower
			local Torque    = ACF.GetTorque(Curve, I / Iterations)
			local Powerband = Power + Torque -- No solid definition of powerband, so this seemed to work alright

			PowerbandTable[I] = Powerband

			if Powerband > PowerbandPeak then
				PowerbandPeak = Powerband
			end
		end

		-- Loop three, to actually figure out where the bounds of the powerband are (within 10% of max).
		for I = 0, Iterations do
			local Powerband = PowerbandTable[I] / PowerbandPeak
			local RPM       = I / Iterations * Redline

			if Powerband > 0.9 and not PowerbandMinRPM then
				PowerbandMinRPM = RPM
			end

			if (PowerbandMinRPM and Powerband < 0.9 and not PowerbandMaxRPM) or (I == Iterations and not PowerbandMaxRPM) then
				PowerbandMaxRPM = RPM
			end
		end

		Class.PeakTqRPM    = PeakTqRPM
		Class.PeakPower    = PeakPower
		Class.PeakPowerRPM = math.Round(PeakPowerRPM)
		Class.RPM.PeakMin  = math.Round(PowerbandMinRPM, -1)
		Class.RPM.PeakMax  = math.Round(PowerbandMaxRPM, -1)
		Class.CurveFactor  = (Class.RPM.Limit - Class.RPM.Idle) / Class.RPM.Limit
	end
end

do -- Unit conversion
	local Units = {
		{ Unit = "year", Reduction = 1970 },
		{ Unit = "month", Reduction = 1 },
		{ Unit = "day", Reduction = 1 },
		{ Unit = "hour", Reduction = 0 },
		{ Unit = "min", Reduction = 0 },
		{ Unit = "sec", Reduction = 0 },
	}

	local function LocalToUTC()
		return os.time(os.date("!*t", os.time()))
	end

	function ACF.GetTimeLapse(Date)
		if not Date then return end

		local Time = LocalToUTC() - Date
		local DateData = os.date("!*t", Time)

		-- Negative values to os.date will return nil
		-- LocalToUTC() is most likely flawed, will need testing with people from different timezones.
		if Time <= 0 then return "now" end

		for _, Data in ipairs(Units) do
			Time = DateData[Data.Unit] - Data.Reduction

			if Time > 0 then
				return Time .. " " .. Data.Unit .. (Time ~= 1 and "s" or "") .. " ago"
			end
		end
	end

	function ACF.GetProperMass(Kilograms)
		local Unit, Mult = "g", 1000

		if Kilograms >= 1000 then
			Unit, Mult = "t", 0.001
		elseif Kilograms >= 1 then
			Unit, Mult = "kg", 1
		end

		return math.Round(Kilograms * Mult, 2) .. " " .. Unit
	end
end

do -- Trace functions
	local TraceLine = util.TraceLine

	function ACF.Trace(TraceData)
		local T = TraceLine(TraceData)

		if T.HitNonWorld and ACF.CheckClips(T.Entity, T.HitPos) then
			TraceData.filter[#TraceData.filter + 1] = T.Entity

			return ACF.Trace(TraceData)
		end

		return T
	end

	-- Generates a copy of and uses it's own filter instead of using the existing one
	function ACF.TraceF(TraceData)
		local Original = TraceData.filter
		local Filter = {}

		if istable(Original) then
			for K, V in pairs(Original) do Filter[K] = V end -- Quick copy
		elseif isentity(Original) then
			Filter[1] = Original
		else
			Filter = Original
		end

		TraceData.filter = Filter -- Temporarily replace filter

		local T = ACF.Trace(TraceData)

		TraceData.filter = Original -- Restore filter

		return T, Filter
	end
end

-- Pretty much unused, should be moved into the ACF namespace or just removed
function switch(cases, arg)
	local Var = cases[arg]

	if Var ~= nil then return Var end

	return cases.default
end

function ACF.RandomVector(Min, Max)
	local X = math.Rand(Min.x, Max.x)
	local Y = math.Rand(Min.y, Max.y)
	local Z = math.Rand(Min.z, Max.z)

	return Vector(X, Y, Z)
end

do -- ACF.GetHitAngle
	-- This includes workarounds for traces starting and/or ending inside an object
	-- Whenever a trace ends inside an object the hitNormal will be 0,0,0
	-- If the trace also starts inside the normal (direction) will be 1,0,0 and the fraction 0
	
	-- Whenever a trace starts inside an object, a ray-mesh intersection will be used to calculate the real hitNormal
	-- Additionally, the trace.Normal is unreliable and rayNormal (bullet.Flight) will be used instead

	local v0       = Vector()
	local toDegree = math.deg
	local acos     = math.acos

	local function rayMeshIntersect(ent, rayOrigin, rayDir)
		local mesh        = ent:GetPhysicsObject():GetMeshConvexes()
		local minDistance = math.huge
		local minNormal

		-- Translate the ray to the local space of the mesh
		local rayOrigin = ent:WorldToLocal(rayOrigin)
		local rayDir    = ent:WorldToLocalAngles(rayDir:Angle()):Forward()

		for _, hull in ipairs(mesh) do
			local hc = #hull

			for i = 1, hc, 3 do
				local p1, p2, p3   = hull[i].pos, hull[i + 1].pos, hull[i + 2].pos
				local edge1, edge2 = p2 - p1, p3 - p1
				local center = (p1 + p2 + p3) / 3

				-- check if surfaceNormal is facing towards the ray
				local surfaceNormal = edge2:GetNormalized():Cross(edge1:GetNormalized())

				if rayDir:Dot(surfaceNormal) > 0.001 then continue end
				
				-- check if ray passes through triangle
				local h = rayDir:Cross(edge2)
				local a = edge1:Dot(h)
				local f = 1 / a
				local s = rayOrigin - p1
				local u = f * s:Dot(h)

				if u < 0 or u > 1 then continue end		

				local q = s:Cross(edge1)
				local v = f * rayDir:Dot(q)

				if v < 0 or u + v > 1 then continue end

				-- length of the ray from rayOrigin to the point of intersection
				local length = f * edge2:Dot(q)

				if length > 0.0001 and length < minDistance then
					minDistance = length
					minNormal   = surfaceNormal
				end
			end
		end

		return ent:LocalToWorldAngles(minNormal:Angle()):Forward()
	end

	function ACF.GetHitAngle(trace, rayNormal)
		local hitNormal = trace.HitNormal

		if hitNormal == v0 then
			local rayNormal = rayNormal:GetNormalized()
			local rayOrigin = trace.HitPos - rayNormal * 5000

			hitNormal = rayMeshIntersect(trace.Entity, rayOrigin, rayNormal)
		end

		return toDegree(acos(rayNormal:Dot(hitNormal)))
	end
end

do -- Native type verification functions
	function ACF.CheckNumber(Value, Default)
		if not Value then return Default end

		return tonumber(Value) or Default
	end

	function ACF.CheckString(Value, Default)
		if Value == nil then return Default end

		return tostring(Value) or Default
	end
end

do -- Hitbox storing and retrieval functions
	ACF.Hitboxes = ACF.Hitboxes or {}

	local Hitboxes = ACF.Hitboxes

	local function IsValidModel(Model)
		if not isstring(Model) then return false end

		return not IsUselessModel(Model)
	end

	local function GetModelTable(Model)
		local Result = Hitboxes[Model]

		if not Result then
			Result = {}

			Hitboxes[Model] = Result
		end

		return Result
	end

	local function AddHitbox(Model, Name, Data)
		local Table = GetModelTable(Model)

		Table[Name] = {
			Pos       = Vector(Data.Pos),
			Scale     = Vector(Data.Scale),
			Angle     = Angle(Data.Angle),
			Sensitive = tobool(Data.Sensitive),
		}
	end

	local function GetProperScale(Scale)
		if not Scale then return 1 end
		if isnumber(Scale) then return Scale end

		return Vector(Scale)
	end

	local function GetCopy(Hitbox, Scale)
		if not Hitbox then return end

		return {
			Pos       = Vector(Hitbox.Pos) * Scale,
			Scale     = Vector(Hitbox.Scale) * Scale,
			Angle     = Angle(Hitbox.Angle),
			Sensitive = tobool(Hitbox.Sensitive),
		}
	end

	function ACF.AddHitbox(Model, Name, Data)
		if not IsValidModel(Model) then return end
		if not isstring(Name) then return end
		if not istable(Data) then return end

		AddHitbox(Model, Name, Data)
	end

	function ACF.AddHitboxes(Model, Data)
		if not IsValidModel(Model) then return end
		if not istable(Data) then return end

		for Name, Hitbox in pairs(Data) do
			if not isstring(Name) then continue end

			AddHitbox(Model, Name, Hitbox)
		end
	end

	function ACF.RemoveHitbox(Model, Name)
		if not IsValidModel(Model) then return end
		if not isstring(Name) then return end

		local Table = Hitboxes[Model]

		if not Table then return end

		Table[Name] = nil
	end

	function ACF.RemoveHitboxes(Model)
		if not IsValidModel(Model) then return end

		local Table = Hitboxes[Model]

		if not Table then return end

		for K in pairs(Table) do
			Table[K] = nil
		end

		Hitboxes[Model] = nil
	end

	function ACF.GetHitbox(Model, Name, Scale)
		if not IsValidModel(Model) then return end
		if not isstring(Name) then return end

		local Table = Hitboxes[Model]

		if Table then
			Scale = GetProperScale(Scale)

			return GetCopy(Table[Name], Scale)
		end
	end

	function ACF.GetHitboxes(Model, Scale)
		if not IsValidModel(Model) then return end

		local Table = Hitboxes[Model]

		if Table then
			local Result = {}

			Scale = GetProperScale(Scale)

			for Name, Data in pairs(Table) do
				Result[Name] = GetCopy(Data, Scale)
			end

			return Result
		end
	end
end

do -- Attachment storage
	local IsUseless = IsUselessModel
	local EntMeta   = FindMetaTable("Entity")
	local GetAttach = EntMeta.GetAttachment
	local GetAll    = EntMeta.GetAttachments
	local Lookup    = EntMeta.LookupAttachment
	local Models    = {}

	local function GetModelData(Model, NoCreate)
		local Table = Models[Model]

		if not (Table or NoCreate) then
			Table = {}

			Models[Model] = Table
		end

		return Table
	end

	local function SaveAttachments(Model, Attachments, Clear)
		if IsUseless(Model) then return end

		local Data  = GetModelData(Model)
		local Count = Clear and 0 or #Data

		if Clear then
			for K in pairs(Data) do Data[K] = nil end
		end

		for I, Attach in ipairs(Attachments) do
			local Index = Count + I
			local Name  = ACF.CheckString(Attach.Name, "Unnamed" .. Index)

			Data[Index] = {
				Index = Index,
				Name  = Name,
				Pos   = Attach.Pos or Vector(),
				Ang   = Attach.Ang or Angle(),
				Bone  = Attach.Bone,
			}
		end

		if not next(Data) then
			Models[Model] = nil
		end
	end

	local function GetAttachData(Entity)
		local Model = Entity:GetModel()

		if not Model or IsUseless(Model) then return end

		local Data  = Entity.AttachData

		if not Data or Data.Model ~= Model then
			local Attachments = GetModelData(Model)

			Data = {
				Model = Model,
			}

			if next(Attachments) then
				Data.Attachments  = Attachments
				Entity.AttachData = Data
			end
		end

		return Data.Attachments
	end

	-------------------------------------------------------------------

	function ACF.AddCustomAttachment(Model, Name, Pos, Ang, Bone)
		if not isstring(Model) then return end

		SaveAttachments(Model, {{
			Name = Name,
			Pos  = Pos,
			Ang  = Ang,
			Bone = Bone,
		}})
	end

	function ACF.AddCustomAttachments(Model, Attachments)
		if not isstring(Model) then return end
		if not istable(Attachments) then return end

		SaveAttachments(Model, Attachments)
	end

	function ACF.SetCustomAttachment(Model, Name, Pos, Ang, Bone)
		if not isstring(Model) then return end

		SaveAttachments(Model, {{
			Name = Name,
			Pos  = Pos,
			Ang  = Ang,
			Bone = Bone,
		}}, true)
	end

	function ACF.SetCustomAttachments(Model, Attachments)
		if not isstring(Model) then return end
		if not istable(Attachments) then return end

		SaveAttachments(Model, Attachments, true)
	end

	function ACF.RemoveCustomAttachment(Model, Index)
		if not isstring(Model) then return end

		local Data = GetModelData(Model, true)

		if not Data then return end

		table.remove(Data, Index)

		if not next(Data) then
			Models[Model] = nil
		end
	end

	function ACF.RemoveCustomAttachments(Model)
		if not isstring(Model) then return end

		local Data = GetModelData(Model, true)

		if not Data then return end

		for K in pairs(Data) do
			Data[K] = nil
		end

		Models[Model] = nil
	end

	function EntMeta:GetAttachment(Index, ...)
		local Data = GetAttachData(self)

		if not Data then
			return GetAttach(self, Index, ...)
		end

		local Attachment = Data[Index]

		if not Attachment then return end

		local Pos = Attachment.Pos

		if self.Scale then
			Pos = Pos * self.Scale
		end

		return {
			Pos = self:LocalToWorld(Pos),
			Ang = self:LocalToWorldAngles(Attachment.Ang),
		}
	end

	function EntMeta:GetAttachments(...)
		local Data = GetAttachData(self)

		if not Data then
			return GetAll(self, ...)
		end

		local Result = {}

		for Index, Info in ipairs(Data) do
			Result[Index] = {
				id   = Index,
				name = Info.Name,
			}
		end

		return Result
	end

	function EntMeta:LookupAttachment(Name, ...)
		local Data = GetAttachData(self)

		if not Data then
			return Lookup(self, Name, ...)
		end

		for Index, Info in ipairs(Data) do
			if Info.Name == Name then
				return Index
			end
		end

		return 0
	end
end

do -- File creation
	function ACF.FolderExists(Path, Create)
		if not isstring(Path) then return end

		local Exists = file.Exists(Path, "DATA")

		if not Exists and Create then
			file.CreateDir(Path)

			return true
		end

		return Exists
	end

	function ACF.SaveToJSON(Path, Name, Table, GoodFormat)
		if not isstring(Path) then return end
		if not isstring(Name) then return end
		if not istable(Table) then return end

		ACF.FolderExists(Path, true) -- Creating the folder if it doesn't exist

		local FullPath = Path .. "/" .. Name

		file.Write(FullPath, util.TableToJSON(Table, GoodFormat))
	end

	function ACF.LoadFromFile(Path, Name)
		if not isstring(Path) then return end
		if not isstring(Name) then return end

		local FullPath = Path .. "/" .. Name

		if not file.Exists(FullPath, "DATA") then return end

		return util.JSONToTable(file.Read(FullPath, "DATA"))
	end
end

do -- Entity metatable method overriding
	-- One of the limitation of the entity __index metamethod is that you cannot override methods that exist on it
	-- So having, for example, a custom ENT:SetPos method for a single class was impossible since it would never be called
	-- With this hook, all you need to do is set the ENT.UseCustomIndex flag to true
	-- You might still need to call the original function from the entity metatable inside yours.

	local EntMeta = FindMetaTable("Entity")
	local Index   = EntMeta.__index
	local SENTs   = scripted_ents
	local Custom  = {}

	function EntMeta:__index(Key, ...)
		local Class = Custom[self]

		if Class and Key then
			local Value = SENTs.GetMember(Class, Key)

			if Value ~= nil then return Value end
		end

		return Index(self, Key, ...)
	end

	hook.Add("OnEntityCreated", "ACF Custom __index Metamethod", function(Entity)
		if not Entity.UseCustomIndex then return end

		Custom[Entity] = Entity:GetClass()

		Entity:CallOnRemove("ACF Custom Index", function()
			Custom[Entity] = nil
		end)
	end)
end
