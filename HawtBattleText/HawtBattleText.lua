-----------------------------------------------------------------------------------------------
-- Client Lua Script for FloatTextPanel
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Spell"
require "CombatFloater"
require "GameLib"
require "Unit"

local HawtScrollingBattleText = {}

local knTestingVulnerable = -1

function HawtScrollingBattleText:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function HawtScrollingBattleText:Init()
	Apollo.RegisterAddon(self)
end

function HawtScrollingBattleText:OnLoad() -- OnLoad then GetAsyncLoad then OnRestore
	Apollo.RegisterEventHandler("OptionsUpdated_Floaters", 					"OnOptionsUpdated", self)
	Apollo.RegisterEventHandler("InterfaceOptionsLoaded", 					"Initialize", self)
end

function HawtScrollingBattleText:Initialize()
	Apollo.RegisterEventHandler("LootedMoney", 								"OnLootedMoney", self)
	Apollo.RegisterEventHandler("SpellCastFailed", 							"OnSpellCastFailed", self)
	Apollo.RegisterEventHandler("DamageOrHealingDone",				 		"OnDamageOrHealing", self)
	Apollo.RegisterEventHandler("CombatMomentum", 							"OnCombatMomentum", self)
	Apollo.RegisterEventHandler("ExperienceGained", 						"OnExperienceGained", self)	-- UI_XPChanged ?
	Apollo.RegisterEventHandler("ElderPointsGained", 						"OnElderPointsGained", self)
	Apollo.RegisterEventHandler("UpdatePathXp", 							"OnPathExperienceGained", self)
	Apollo.RegisterEventHandler("AttackMissed", 							"OnMiss", self)
	Apollo.RegisterEventHandler("SubZoneChanged", 							"OnSubZoneChanged", self)
	Apollo.RegisterEventHandler("RealmBroadcastTierMedium", 				"OnRealmBroadcastTierMedium", self)
	Apollo.RegisterEventHandler("GenericError", 							"OnGenericError", self)
	Apollo.RegisterEventHandler("PrereqFailureMessage",					 	"OnPrereqFailed", self)
	Apollo.RegisterEventHandler("GenericFloater", 							"OnGenericFloater", self)
	Apollo.RegisterEventHandler("UnitEvaded", 								"OnUnitEvaded", self)
	Apollo.RegisterEventHandler("QuestShareFloater", 						"OnQuestShareFloater", self)
	Apollo.RegisterEventHandler("CountdownTick", 							"OnCountdownTick", self)
	Apollo.RegisterEventHandler("TradeSkillFloater",				 		"OnTradeSkillFloater", self)
	Apollo.RegisterEventHandler("FactionFloater", 							"OnFactionFloater", self)
	Apollo.RegisterEventHandler("CombatLogTransference", 					"OnCombatLogTransference", self)
	Apollo.RegisterEventHandler("CombatLogCCState", 						"OnCombatLogCCState", self)
	Apollo.RegisterEventHandler("ActionBarNonSpellShortcutAddFailed", 		"OnActionBarNonSpellShortcutAddFailed", self)
	Apollo.RegisterEventHandler("GenericEvent_GenericError",				"OnGenericError", self)

	-- set the max count of floater text
	CombatFloater.SetMaxFloaterCount(500)
	CombatFloater.SetMaxFloaterPerUnitCount(500)

	-- loading digit sprite sets
	Apollo.LoadSprites("UI\\SpriteDocs\\CRB_NumberFloaters.xml")
	Apollo.LoadSprites("UI\\SpriteDocs\\CRB_CritNumberFloaters.xml")

	self.iDigitSpriteSetNormal 		= CombatFloater.AddDigitSpriteSet("sprFloater_Normal")
	self.iDigitSpriteSetVulnerable 	= CombatFloater.AddDigitSpriteSet("sprFloater_Vulnerable")
	self.iDigitSpriteSetCritical 	= CombatFloater.AddDigitSpriteSet("sprFloater_Critical")
	self.iDigitSpriteSetHeal 		= CombatFloater.AddDigitSpriteSet("sprFloater_Heal")
	self.iDigitSpriteSetShields 	= CombatFloater.AddDigitSpriteSet("sprFloater_Shields")
	self.iDigitSpriteSetShieldsDown = CombatFloater.AddDigitSpriteSet("sprFloater_NormalNoShields")

	-- add bg sprite for text
	self.iFloaterBackerCritical 	= CombatFloater.AddTextBGSprite("sprFloater_BackerCritical")
	self.iFloaterBackerNormal 		= CombatFloater.AddTextBGSprite("sprFloater_BackerNormal")
	self.iFloaterBackerVulnerable 	= CombatFloater.AddTextBGSprite("sprFloater_BackerVulnerable")
	self.iFloaterBackerHeal 		= CombatFloater.AddTextBGSprite("sprFloater_BackerHeal")
	self.iFloaterBackerShieldsDown 	= CombatFloater.AddTextBGSprite("sprFloater_BackerNormalNoShields")

	-- float text queue for delayed text
	self.tDelayedFloatTextQueue = Queue:new()
	self.iTimerIndex = 1

	self.fLastDamageTime = GameLib.GetGameTime()
	self.fLastOffset = 0

	self.bSpellErrorMessages = g_InterfaceOptions.Carbine.bSpellErrorMessages
	
	if tLocalAppData == nil then tLocalAppData = self:GetDefaultAppData() end
	SendVarToRover("appdata_hawt", tLocalAppData)
end

function HawtScrollingBattleText:OnOptionsUpdated()
	self.bSpellErrorMessages = g_InterfaceOptions.Carbine.bSpellErrorMessages
end

function HawtScrollingBattleText:GetDefaultTextOption()
	local tTextOption =
	{
		strFontFace 				= "CRB_FloaterLarge",
		fDuration 					= 2,
		fScale 						= 0.9,
		fExpand 					= 1,
		fVibrate 					= 0,
		fSpinAroundRadius 			= 0,
		fFadeInDuration 			= 0,
		fFadeOutDuration 			= 0,
		fVelocityDirection 			= 0,
		fVelocityMagnitude 			= 0,
		fAccelDirection 			= 0,
		fAccelMagnitude 			= 0,
		fEndHoldDuration 			= 0,
		eLocation 					= CombatFloater.CodeEnumFloaterLocation.Top,
		fOffsetDirection 			= 0,
		fOffset 					= -0.5,
		eCollisionMode 				= CombatFloater.CodeEnumFloaterCollisionMode.Horizontal,
		fExpandCollisionBoxWidth 	= 1,
		fExpandCollisionBoxHeight 	= 1,
		nColor 						= 0xFFFFFF,
		iUseDigitSpriteSet 			= nil,
		bUseScreenPos 				= false,
		bShowOnTop 					= false,
		fRotation 					= 0,
		fDelay 						= 0,
		nDigitSpriteSpacing 		= 0,
	}
	return tTextOption
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnSpellCastFailed( eMessageType, eCastResult, unitTarget, unitSource, strMessage )
	if unitTarget == nil or not Apollo.GetConsoleVariable("ui.showCombatFloater") then
		return
	end

	-- modify the text to be shown
	local tTextOption = self:GetDefaultTextOption()
	tTextOption.bUseScreenPos = true
	tTextOption.fOffset = -80
	tTextOption.nColor = 0xFFFFFF
	tTextOption.strFontFace = "CRB_Interface16_BO"
	tTextOption.bShowOnTop = true
	tTextOption.arFrames =
	{
		[1] = {fTime = 0,		fScale = 1.5,	fAlpha = 0.8,},
		[2] = {fTime = 0.1,		fScale = 1,	fAlpha = 0.8,},
		[3] = {fTime = 1.1,		fScale = 1,	fAlpha = 0.8,	fVelocityDirection = 0,},
		[4] = {fTime = 1.3,		fScale = 1,	fAlpha = 0.0,	fVelocityDirection = 0,},
	}

	if self.bSpellErrorMessages then -- This is set by interface options
		self:RequestShowTextFloater(LuaEnumMessageType.SpellCastError, unitSource, strMessage, tTextOption)
	end
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnSubZoneChanged(idZone, strZoneName)
	-- if you're in a taxi, don't show zone change
	if GameLib.GetPlayerTaxiUnit() then
		return
	end

	local tTextOption = self:GetDefaultTextOption()
	tTextOption.bUseScreenPos = true
	tTextOption.fOffset = -280
	tTextOption.nColor = 0x80ffff
	tTextOption.strFontFace = "CRB_HeaderGigantic_O"
	tTextOption.bShowOnTop = true
	tTextOption.arFrames=
	{
		[1] = {fTime = 0,	fAlpha = 0,		fScale = .8,},
		[2] = {fTime = 0.6, fAlpha = 1.0,},
		[3] = {fTime = 4.6,	fAlpha = 1.0,},
		[4] = {fTime = 5.2, fAlpha = 0,},
	}

	self:RequestShowTextFloater( LuaEnumMessageType.ZoneName, GameLib.GetControlledUnit(), strZoneName, tTextOption )
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnRealmBroadcastTierMedium(strMessage)
	local tTextOption = self:GetDefaultTextOption()
	tTextOption.bUseScreenPos = true
	tTextOption.fOffset = -180
	tTextOption.nColor = 0x80ffff
	tTextOption.strFontFace = "CRB_HeaderGigantic_O"
	tTextOption.bShowOnTop = true
	tTextOption.arFrames=
	{
		[1] = {fTime = 0,	fAlpha = 0,		fScale = .8,},
		[2] = {fTime = 0.6, fAlpha = 1.0,},
		[3] = {fTime = 4.6,	fAlpha = 1.0,},
		[4] = {fTime = 5.2, fAlpha = 0,},
	}

	self:RequestShowTextFloater( LuaEnumMessageType.RealmBroadcastTierMedium, GameLib.GetControlledUnit(), strMessage, tTextOption )
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnActionBarNonSpellShortcutAddFailed()
	local strMessage = Apollo.GetString("HawtScrollingBattleText_ActionBarAddFail")
	self:OnSpellCastFailed( LuaEnumMessageType.GenericPlayerInvokedError, nil, GameLib.GetControlledUnit(), GameLib.GetControlledUnit(), strMessage )
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnGenericError(eError, strMessage)
	local arExciseListItem =  -- index is enums to respond to, value is optional (UNLOCALIZED) replacement string (otherwise the passed string is used)
	{
		[GameLib.CodeEnumGenericError.DbFailure] 						= "",
		[GameLib.CodeEnumGenericError.Item_BadId] 						= "",
		[GameLib.CodeEnumGenericError.Vendor_StackSize] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_SoldOut] 					= "",
		[GameLib.CodeEnumGenericError.Vendor_UnknownItem] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_FailedPreReq] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_NotAVendor] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_TooFar] 					= "",
		[GameLib.CodeEnumGenericError.Vendor_BadItemRec] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_NotEnoughToFillQuantity] 	= "",
		[GameLib.CodeEnumGenericError.Vendor_NotEnoughCash] 			= "",
		[GameLib.CodeEnumGenericError.Vendor_UniqueConstraint] 			= "",
		[GameLib.CodeEnumGenericError.Vendor_ItemLocked] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_IWontBuyThat] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_NoQuantity] 				= "",
		[GameLib.CodeEnumGenericError.Vendor_BagIsNotEmpty] 			= "",
		[GameLib.CodeEnumGenericError.Vendor_CuratorOnlyBuysRelics] 	= "",
		[GameLib.CodeEnumGenericError.Vendor_CannotBuyRelics] 			= "",
		[GameLib.CodeEnumGenericError.Vendor_NoBuyer] 					= "",
		[GameLib.CodeEnumGenericError.Vendor_NoVendor] 					= "",
		[GameLib.CodeEnumGenericError.Vendor_Buyer_NoActionCC] 			= "",
		[GameLib.CodeEnumGenericError.Vendor_Vendor_NoActionCC] 		= "",
		[GameLib.CodeEnumGenericError.Vendor_Vendor_Disposition] 		= "",
	}

	if arExciseListItem[eError] then -- list of errors we don't want to show floaters for
		return
	end

	self:OnSpellCastFailed( LuaEnumMessageType.GenericPlayerInvokedError, nil, GameLib.GetControlledUnit(), GameLib.GetControlledUnit(), strMessage )
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnPrereqFailed(strMessage)
	self:OnGenericError(nil, strMessage)
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnGenericFloater(unitTarget, strMessage)
	-- modify the text to be shown
	local tTextOption = self:GetDefaultTextOption()
	tTextOption.fDuration = 2
	tTextOption.bUseScreenPos = true
	tTextOption.fOffset = 0
	tTextOption.nColor = 0x00FFFF
	tTextOption.strFontFace = "CRB_HeaderLarge_O"
	tTextOption.bShowOnTop = true

	CombatFloater.ShowTextFloater( unitTarget, strMessage, tTextOption )
end

function HawtScrollingBattleText:OnUnitEvaded(unitSource, unitTarget, eReason, strMessage)
	local tTextOption = self:GetDefaultTextOption()
	tTextOption.fScale = 1.0
	tTextOption.fDuration = 2
	tTextOption.nColor = 0xbaeffb
	tTextOption.strFontFace = "CRB_FloaterSmall"
	tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.IgnoreCollision
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Chest
	tTextOption.fOffset = -0.8
	tTextOption.fOffsetDirection = 0

	tTextOption.arFrames =
	{
		[1] = {fTime = 0,		fScale = 2.0,	fAlpha = 1.0,	nColor = 0xFFFFFF,},
		[2] = {fTime = 0.15,	fScale = 0.9,	fAlpha = 1.0,},
		[3] = {fTime = 1.1,		fScale = 0.9,	fAlpha = 1.0,	fVelocityDirection = 0,	fVelocityMagnitude = 5,},
		[4] = {fTime = 1.3,						fAlpha = 0.0,	fVelocityDirection = 0,},
	}

	CombatFloater.ShowTextFloater( unitSource, strMessage, tTextOption )
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnAlertTitle(strMessage)
	local tTextOption = self:GetDefaultTextOption()
	tTextOption.fDuration = 2
	tTextOption.fFadeInDuration = 0.2
	tTextOption.fFadeOutDuration = 0.5
	tTextOption.fVelocityMagnitude = 0.2
	tTextOption.fOffset = 0.2
	tTextOption.nColor = 0xFFFF00
	tTextOption.strFontFace = "CRB_HeaderLarge_O"
	tTextOption.bShowOnTop = true
	tTextOption.fScale = 1
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Top

	CombatFloater.ShowTextFloater( GameLib.GetControlledUnit(), strMessage, tTextOption )
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnQuestShareFloater(unitTarget, strMessage)
	local tTextOption = self:GetDefaultTextOption()
	tTextOption.fDuration = 2
	tTextOption.fFadeInDuration = 0.2
	tTextOption.fFadeOutDuration = 0.5
	tTextOption.fVelocityMagnitude = 0.2
	tTextOption.fOffset = 0.2
	tTextOption.nColor = 0xFFFF00
	tTextOption.strFontFace = "CRB_HeaderLarge_O"
	tTextOption.bShowOnTop = true
	tTextOption.fScale = 1
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Top

	CombatFloater.ShowTextFloater( unitTarget, strMessage, tTextOption )
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnCountdownTick(strMessage)
	local tTextOption = self:GetDefaultTextOption()
	tTextOption.fDuration = 1
	tTextOption.fFadeInDuration = 0.2
	tTextOption.fFadeOutDuration = 0.2
	tTextOption.fVelocityMagnitude = 0.2
	tTextOption.fOffset = 0.2
	tTextOption.nColor = 0x00FF00
	tTextOption.strFontFace = "CRB_HeaderLarge_O"
	tTextOption.bShowOnTop = true
	tTextOption.fScale = 1
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Top

	CombatFloater.ShowTextFloater( GameLib.GetControlledUnit(), strMessage, tTextOption )
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnDeath()
	local tTextOption = self:GetDefaultTextOption()
	tTextOption.fDuration = 2
	tTextOption.fFadeOutDuration = 1.5
	tTextOption.fScale = 1.2
	tTextOption.nColor = 0xFFFFFF
	tTextOption.strFontFace = "CRB_HeaderLarge_O"
	tTextOption.bShowOnTop = true
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Top
	tTextOption.fOffset = 1

	CombatFloater.ShowTextFloater( GameLib.GetControlledUnit(), Apollo.GetString("Player_Incapacitated"), tTextOption )
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnCombatLogTransference(tEventArgs)
	local bCritical = tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical
	if tEventArgs.unitCaster == GameLib.GetControlledUnit() then -- Target does the transference to the source
		self:OnDamageOrHealing( tEventArgs.unitCaster, tEventArgs.unitTarget, tEventArgs.eDamageType, math.abs(tEventArgs.nDamageAmount), 0, 0, bCritical )
	else -- creature taking damage
		self:OnPlayerDamageOrHealing( tEventArgs.unitTarget, tEventArgs.eDamageType, math.abs(tEventArgs.nDamageAmount), 0, 0, bCritical )
	end

	-- healing data is stored in a table where each subtable contains a different vital that was healed
	for _, tHeal in ipairs(tEventArgs.tHealData) do
		if tEventArgs.unitCaster == GameLib.GetPlayerUnit() then -- source recieves the transference from the taker
			self:OnPlayerDamageOrHealing( tEventArgs.unitCaster, tEventArgs.eDamageType, math.abs(tHeal.nHealAmount), 0, 0, bCritical )
		else
			self:OnDamageOrHealing(tEventArgs.unitTarget, tEventArgs.unitCaster, tEventArgs.eDamageType, math.abs(tHeal.nHealAmount), 0, 0, bCritical )
		end
	end
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnCombatMomentum( eMomentumType, nCount, strText )
	-- Passes: type enum, player's total count for that bonus type, string combines these things (ie. "3 Evade")
	local arMomentumStrings =
	{
		[CombatFloater.CodeEnumCombatMomentum.Impulse] 				= "HawtScrollingBattleText_Impulse",
		[CombatFloater.CodeEnumCombatMomentum.KillingPerformance] 	= "HawtScrollingBattleText_KillPerformance",
		[CombatFloater.CodeEnumCombatMomentum.KillChain] 			= "HawtScrollingBattleText_KillChain",
		[CombatFloater.CodeEnumCombatMomentum.Evade] 				= "HawtScrollingBattleText_Evade",
		[CombatFloater.CodeEnumCombatMomentum.Interrupt] 			= "HawtScrollingBattleText_Interrupt",
		[CombatFloater.CodeEnumCombatMomentum.CCBreak] 				= "HawtScrollingBattleText_StateBreak",
	}

	if not Apollo.GetConsoleVariable("ui.showCombatFloater") or arMomentumStrings[eMomentumType] == nil  then
		return
	end

	local nBaseColor = 0x7eff8f
	local tTextOption = self:GetDefaultTextOption()
	tTextOption.fScale = 0.8
	tTextOption.fDuration = 2
	tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Vertical
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Back
	tTextOption.fOffset = 2.0
	tTextOption.fOffsetDirection = 90
	tTextOption.strFontFace = "CRB_FloaterSmall"
	tTextOption.arFrames =
	{
		[1] = {fTime = 0,		nColor = 0xFFFFFF,		fAlpha = 0,		fVelocityDirection = 90,	fVelocityMagnitude = 5,		fScale = 0.8},
		[2] = {fTime = 0.15,							fAlpha = 1.0,	fVelocityDirection = 90,	fVelocityMagnitude = .2,},
		[3] = {fTime = 0.5,		nColor = nBaseColor,},
		[4] = {fTime = 1.0,		nColor = nBaseColor,},
		[5] = {fTime = 1.1,		nColor = 0xFFFFFF,		fAlpha = 1.0,	fVelocityDirection 	= 90,	fVelocityMagnitude 	= 5,},
		[6] = {fTime = 1.3,		nColor 	= nBaseColor,	fAlpha 	= 0.0,},
	}

	local unitToAttachTo = GameLib.GetControlledUnit()
	local strMessage = String_GetWeaselString(Apollo.GetString(arMomentumStrings[eMomentumType]), nCount)
	if eMomentumType == CombatFloater.CodeEnumCombatMomentum.KillChain and nCount == 2 then
		strMessage = Apollo.GetString("HawtScrollingBattleText_DoubleKill")
		tTextOption.strFontFace = "CRB_FloaterMedium"
	elseif eMomentumType == CombatFloater.CodeEnumCombatMomentum.KillChain and nCount == 3 then
		strMessage = Apollo.GetString("HawtScrollingBattleText_TripleKill")
		tTextOption.strFontFace = "CRB_FloaterMedium"
	elseif eMomentumType == CombatFloater.CodeEnumCombatMomentum.KillChain and nCount == 5 then
		strMessage = Apollo.GetString("HawtScrollingBattleText_PentaKill")
		tTextOption.strFontFace = "CRB_FloaterHuge"
	elseif eMomentumType == CombatFloater.CodeEnumCombatMomentum.KillChain and nCount > 5 then
		tTextOption.strFontFace = "CRB_FloaterHuge"
	end

	CombatFloater.ShowTextFloater(unitToAttachTo, strMessage, tTextOption)
end

function HawtScrollingBattleText:OnExperienceGained(eReason, unitTarget, strText, fDelay, nAmount)
	if not Apollo.GetConsoleVariable("ui.showCombatFloater") or nAmount < 0 then
		return
	end

	local strFormatted = ""
	local eMessageType = LuaEnumMessageType.XPAwarded
	local unitToAttachTo = GameLib.GetControlledUnit() -- unitTarget potentially nil

	local tContent = {}
	tContent.eType = LuaEnumMessageType.XPAwarded
	tContent.nNormal = 0
	tContent.nRested = 0

	local tTextOption = self:GetDefaultTextOption()
	tTextOption.fScale = 0.8
	tTextOption.fDuration = 2
	tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Vertical
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Back
	tTextOption.fOffset = 4.0 -- GOTCHA: Different
	tTextOption.fOffsetDirection = 90
	tTextOption.strFontFace = "CRB_FloaterSmall"
	tTextOption.arFrames =
	{
		[1] = {fTime = 0,			fAlpha = 0,		fVelocityDirection = 90,	fVelocityMagnitude = 5,		fScale = 0.8},
		[2] = {fTime = 0.15,		fAlpha = 1.0,	fVelocityDirection = 90,	fVelocityMagnitude = .2,},
		[3] = {fTime = 0.5,	},
		[4] = {fTime = 1.0,	},
		[5] = {fTime = 1.1,			fAlpha = 1.0,	fVelocityDirection 	= 90,	fVelocityMagnitude 	= 5,},
		[6] = {fTime = 1.3,			fAlpha 	= 0.0,},
	}

	-- GOTCHA: UpdateOrAddXpFloater will stomp on these text formats anyways (TODO REFACTOR)
	if eReason == CombatFloater.CodeEnumExpReason.KillPerformance or eReason == CombatFloater.CodeEnumExpReason.MultiKill or eReason == CombatFloater.CodeEnumExpReason.KillingSpree then
		return -- should not be delivered via the XP event
	elseif eReason == CombatFloater.CodeEnumExpReason.Rested then
		tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Vertical
		strFormatted = String_GetWeaselString(Apollo.GetString("HawtScrollingBattleText_RestXPGained"), nAmount)
		tContent.nRested = nAmount
	else
		tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Vertical
		strFormatted = String_GetWeaselString(Apollo.GetString("HawtScrollingBattleText_XPGained"), nAmount)
		tContent.nNormal = nAmount
	end

	self:RequestShowTextFloater(eMessageType, unitToAttachTo, strFormatted, tTextOption, fDelay, tContent)
end

function HawtScrollingBattleText:OnElderPointsGained(nAmount)
	if not Apollo.GetConsoleVariable("ui.showCombatFloater") or nAmount < 0 then
		return
	end

	local tContent = {}
	tContent.eType = LuaEnumMessageType.XPAwarded
	tContent.nNormal = nAmount
	tContent.nRested = 0

	local tTextOption = self:GetDefaultTextOption()
	tTextOption.fScale = 0.8
	tTextOption.fDuration = 2
	tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Vertical
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Back
	tTextOption.fOffset = 4.0 -- GOTCHA: Different
	tTextOption.fOffsetDirection = 90
	tTextOption.strFontFace = "CRB_FloaterSmall"
	tTextOption.arFrames =
	{
		[1] = {fTime = 0,			fAlpha = 0,		fVelocityDirection = 90,	fVelocityMagnitude = 5,		fScale = 0.8},
		[2] = {fTime = 0.15,		fAlpha = 1.0,	fVelocityDirection = 90,	fVelocityMagnitude = .2,},
		[3] = {fTime = 0.5,	},
		[4] = {fTime = 1.0,	},
		[5] = {fTime = 1.1,			fAlpha = 1.0,	fVelocityDirection 	= 90,	fVelocityMagnitude 	= 5,},
		[6] = {fTime = 1.3,			fAlpha 	= 0.0,},
	}

	local eMessageType = LuaEnumMessageType.XPAwarded
	local unitToAttachTo = GameLib.GetControlledUnit()
	local strFormatted = String_GetWeaselString(Apollo.GetString("HawtScrollingBattleText_EPGained"), nAmount)

	self:RequestShowTextFloater(eMessageType, unitToAttachTo, strFormatted, tTextOption, 0, tContent)
end

function HawtScrollingBattleText:OnPathExperienceGained( nAmount, strText )
	if not Apollo.GetConsoleVariable("ui.showCombatFloater") then
		return
	end

	local eMessageType = LuaEnumMessageType.PathXp
	local unitToAttachTo = GameLib.GetControlledUnit()
	local strFormatted = String_GetWeaselString(Apollo.GetString("HawtScrollingBattleText_PathXP"), nAmount)

	local tContent =
	{
		eType = LuaEnumMessageType.PathXp,
		nAmount = nAmount,
	}

	local tTextOption = self:GetDefaultTextOption()
	tTextOption.fScale = 0.8
	tTextOption.fDuration = 2
	tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Vertical
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Back
	tTextOption.fOffset = 4.0 -- GOTCHA: Different
	tTextOption.fOffsetDirection = 90
	tTextOption.strFontFace = "CRB_FloaterSmall"
	tTextOption.arFrames =
	{
		[1] = {fTime = 0,			fAlpha = 0,		fVelocityDirection = 90,	fVelocityMagnitude = 5,		fScale = 0.8},
		[2] = {fTime = 0.15,		fAlpha = 1.0,	fVelocityDirection = 90,	fVelocityMagnitude = .2,},
		[3] = {fTime = 0.5,	},
		[4] = {fTime = 1.0,	},
		[5] = {fTime = 1.1,			fAlpha = 1.0,	fVelocityDirection 	= 90,	fVelocityMagnitude 	= 5,},
		[6] = {fTime = 1.3,			fAlpha 	= 0.0,},
	}

	local unitToAttachTo = GameLib.GetControlledUnit() -- make unitToAttachTo to controlled unit because with the message system,
	self:RequestShowTextFloater( eMessageType, unitToAttachTo, strFormatted, tTextOption, 0, tContent )
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnFactionFloater(unitTarget, strMessage, nAmount, strFactionName, idFaction) -- Reputation Floater
	if not Apollo.GetConsoleVariable("ui.showCombatFloater") or strFactionName == nil or nAmount < 1 then
		return
	end

	local eMessageType = LuaEnumMessageType.ReputationIncrease
	local unitToAttachTo = unitTarget or GameLib.GetControlledUnit()
	local strFormatted = String_GetWeaselString(Apollo.GetString("HawtScrollingBattleText_Rep"), nAmount, strFactionName)

	local tContent = {}
	tContent.eType = LuaEnumMessageType.ReputationIncrease
	tContent.nAmount = nAmount
	tContent.idFaction = idFaction
	tContent.strName = strFactionName

	local tTextOption = self:GetDefaultTextOption()
	tTextOption.fScale = 0.8
	tTextOption.fDuration = 2
	tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Vertical
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Back
	tTextOption.fOffset = 5.0 -- GOTCHA: Extra Different
	tTextOption.fOffsetDirection = 90
	tTextOption.strFontFace = "CRB_FloaterSmall"
	tTextOption.arFrames =
	{
		[1] = {fTime = 0,			fAlpha = 0,		fVelocityDirection = 90,	fVelocityMagnitude = 5,		fScale = 0.8},
		[2] = {fTime = 0.15,		fAlpha = 1.0,	fVelocityDirection = 90,	fVelocityMagnitude = .2,},
		[3] = {fTime = 0.5,	},
		[4] = {fTime = 1.0,	},
		[5] = {fTime = 1.1,			fAlpha = 1.0,	fVelocityDirection 	= 90,	fVelocityMagnitude 	= 5,},
		[6] = {fTime = 1.3,			fAlpha 	= 0.0,},
	}

	self:RequestShowTextFloater(eMessageType, GameLib.GetControlledUnit(), strFormatted, tTextOption, 0, tContent)
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnLootedMoney(monLooted) -- karCurrencyTypeToString filters to most alternate currencies but Money. Money displays in LootNotificationWindow.
	if not monLooted then
		return
	end
	
	local arCurrencyTypeToString =
	{
		[Money.CodeEnumCurrencyType.Renown] 			= "CRB_Renown",
		[Money.CodeEnumCurrencyType.ElderGems] 			= "CRB_Elder_Gems",
		[Money.CodeEnumCurrencyType.Prestige] 			= "CRB_Prestige",
		[Money.CodeEnumCurrencyType.CraftingVouchers]	= "CRB_Crafting_Vouchers",
	}

	local strCurrencyType = arCurrencyTypeToString[monLooted:GetMoneyType()] or ""
	if strCurrencyType == "" then
		return
	else
		strCurrencyType = Apollo.GetString(strCurrencyType)
	end

	-- TODO
	local eMessageType = LuaEnumMessageType.AlternateCurrency
	local strFormatted = String_GetWeaselString(Apollo.GetString("HawtScrollingBattleText_AlternateMoney"), monLooted:GetAmount(), strCurrencyType)

	local tTextOption = self:GetDefaultTextOption()
	tTextOption.fScale = 1.0
	tTextOption.fDuration = 2
	tTextOption.strFontFace = "CRB_FloaterSmall"
	tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Vertical
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Bottom
	tTextOption.fOffset = -1
	tTextOption.fOffsetDirection = 0
	tTextOption.arFrames =
	{
		[1] = {fScale = 0.8,	fTime = 0,		fAlpha = 0.0,	fVelocityDirection = 0,		fVelocityMagnitude = 0,	},
		[2] = {fScale = 0.8,	fTime = 0.1,	fAlpha = 1.0,	fVelocityDirection = 0,		fVelocityMagnitude = 0,	},
		[3] = {fScale = 0.8,	fTime = 0.5,	fAlpha = 1.0,														},
		[4] = {					fTime = 1,		fAlpha = 1.0,	fVelocityDirection = 180,	fVelocityMagnitude = 3,	},
		[5] = {					fTime = 1.5,	fAlpha = 0.0,	fVelocityDirection = 180,							},
	}

	local tContent =
	{
		eType = LuaEnumMessageType.AlternateCurrency,
		nAmount = monLooted:GetAmount(),
	}

	self:RequestShowTextFloater(eMessageType, GameLib.GetControlledUnit(), strFormatted, tTextOption, 0, tContent)
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnTradeSkillFloater(unitTarget, strMessage)
	if not Apollo.GetConsoleVariable("ui.showCombatFloater") then
		return
	end

	local eMessageType = LuaEnumMessageType.TradeskillXp
	local tTextOption = self:GetDefaultTextOption()
	local unitToAttachTo = GameLib.GetControlledUnit()

	-- XP Defaults
	tTextOption.fScale = 1.0
	tTextOption.fDuration = 2
	tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Horizontal
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Top
	tTextOption.fOffset = -0.3
	tTextOption.fOffsetDirection = 0

	tTextOption.nColor = 0xffff80
	tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Vertical --Horizontal  --IgnoreCollision
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Top
	tTextOption.fOffset = -0.3
	tTextOption.fOffsetDirection = 0

	-- scale and movement
	tTextOption.arFrames =
	{
		[1] = {fTime = 0,	fScale = 1.0,	fAlpha = 0.0,},
		[2] = {fTime = 0.1,	fScale = 0.7,	fAlpha = 0.8,},
		[3] = {fTime = 0.9,	fScale = 0.7,	fAlpha = 0.8,	fVelocityDirection = 0,},
		[4] = {fTime = 1.0,	fScale = 1.0,	fAlpha = 0.0,	fVelocityDirection = 0,},
	}


	local unitToAttachTo = GameLib.GetControlledUnit()
	self:RequestShowTextFloater( eMessageType, unitToAttachTo, strMessage, tTextOption, 0 )
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnMiss( unitCaster, unitTarget, eMissType )
	if unitTarget == nil or not Apollo.GetConsoleVariable("ui.showCombatFloater") then
		return
	end

	-- modify the text to be shown
	local tTextOption = self:GetDefaultTextOption()
	if GameLib.IsControlledUnit( unitTarget ) or unitTarget:GetType() == "Mount" then -- if the target unit is player's char
		tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Horizontal --Vertical--Horizontal  --IgnoreCollision
		tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Chest
		tTextOption.nColor = 0xbaeffb
		tTextOption.fOffset = -0.6
		tTextOption.fOffsetDirection = 0
		tTextOption.arFrames =
		{
			[1] = {fScale = 1.0,	fTime = 0,						fVelocityDirection = 0,		fVelocityMagnitude = 0,},
			[2] = {fScale = 0.6,	fTime = 0.05,	fAlpha = 1.0,},
			[3] = {fScale = 0.6,	fTime = .2,		fAlpha = 1.0,	fVelocityDirection = 180,	fVelocityMagnitude = 3,},
			[4] = {fScale = 0.6,	fTime = .45,	fAlpha = 0.2,	fVelocityDirection = 180,},
		}
	else

		tTextOption.fScale = 1.0
		tTextOption.fDuration = 2
		tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.IgnoreCollision --Horizontal
		tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Chest
		tTextOption.fOffset = -0.8
		tTextOption.fOffsetDirection = 0
		tTextOption.arFrames =
		{
			[1] = {fScale = 1.1,	fTime = 0,		fAlpha = 1.0,	nColor = 0xb0b0b0,},
			[2] = {fScale = 0.7,	fTime = 0.1,	fAlpha = 1.0,},
			[3] = {					fTime = 0.3,	},
			[4] = {fScale = 0.7,	fTime = 0.8,	fAlpha = 1.0,},
			[5] = {					fTime = 0.9,	fAlpha = 0.0,},
		}
	end

	-- display the text
	local strText = (eMissType == GameLib.CodeEnumMissType.Dodge) and Apollo.GetString("CRB_Dodged") or Apollo.GetString("CRB_Blocked")
	CombatFloater.ShowTextFloater( unitTarget, strText, tTextOption )
end

---------------------------------------------------------------------------------------------------
function HawtScrollingBattleText:OnDamageOrHealing( unitCaster, unitTarget, eDamageType, nDamage, nShieldDamaged, nAbsorptionAmount, bCritical )
	if unitTarget == nil or not Apollo.GetConsoleVariable("ui.showCombatFloater") or nDamage == nil then
		return
	end

	
	if GameLib.IsControlledUnit(unitTarget) or unitTarget == GameLib.GetPlayerMountUnit() or GameLib.IsControlledUnit(unitTarget:GetUnitOwner()) then
		self:OnPlayerDamageOrHealing( unitTarget, eDamageType, nDamage, nShieldDamaged, nAbsorptionAmount, bCritical )
		return
	end
	
	--[[ IF COMBINING SHIELD DAMAGE DO
	local nTotalDamage = nDamage
	if type(nShieldDamaged) == "number" and nShieldDamaged > 0 then
		nTotalDamage = nDamage + nShieldDamaged
	end
	]]

	local tTextOption = self:GetDefaultTextOption()
	
	-- Scale
	local fStartScale = tLocalAppData.tTextPrefs.tOutgoing.tDamage.fStartScale
	local fEndScaleMultiplier = tLocalAppData.tTextPrefs.tOutgoing.tDamage.fEndScaleMultiplier
	-- Move
	local velocityDirection = tLocalAppData.tTextPrefs.tOutgoing.tDamage.fVelocityDirection
	local velocityMagnitude = tLocalAppData.tTextPrefs.tOutgoing.tDamage.fVelocityMagnitude
	-- Color
	local nColorStart = tLocalAppData.tTextPrefs.tOutgoing.tDamage.tN.nColorStart
	local nColorEnd = tLocalAppData.tTextPrefs.tOutgoing.tDamage.tN.nColorEnd
	-- Time
	local fDisplayTime = tLocalAppData.tTextPrefs.tOutgoing.tDamage.fDisplayTime
	local fVelocityTime = .5
	-- Set Text Options
	tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Vertical
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Chest
	tTextOption.fVelocityDirection = fVelocityDirection
	tTextOption.fOffsetDirection = 90 
	tTextOption.fOffset = 7
	--
	
	tTextOption.arFrames = 
	{
	[1] = {								fTime = 0, fVelocityDirection = velocityDirection,	fVelocityMagnitude = velocityMagnitude,},
	[2] = {fScale = (fStartScale) * fEndScaleMultiplier,	fTime = 0,									nColor = nColorStart,	},
	[3] = {fScale = fStartScale,	fTime = fDisplayTime,									nColor = nColorEnd,	},
	[4] = {								fTime = fVelocityTime,	fVelocityDirection = velocityDirection, fVelocityMagnitude = .2,},
	[5] = {fScale = fStartScale,			fTime = fDisplayTime,				fAlpha = 1.0,},
	[6] = {								fTime = 0.7,	fAlpha = 0.0,},
	}

	if not bHeal then
		self.fLastDamageTime = GameLib.GetGameTime()
	end
	
	CombatFloater.ShowTextFloater( GameLib.GetPlayerUnit(), nDamage, tTextOption )
end

------------------------------------------------------------------
function HawtScrollingBattleText:OnPlayerDamageOrHealing(unitPlayer, eDamageType, nDamage, nShieldDamaged, nAbsorptionAmount, bCritical)
	if unitPlayer == nil or not Apollo.GetConsoleVariable("ui.showCombatFloater") then
		return
	end

	-- If there is no damage, don't show a floater
	if nDamage == nil then
		return
	end

	local bShowFloater = true
	local tTextOption = self:GetDefaultTextOption()
	local tTextOptionAbsorb = self:GetDefaultTextOption()

	tTextOption.arFrames = {}
	tTextOptionAbsorb.arFrames = {}

	local nStallTime = .3

	if type(nAbsorptionAmount) == "number" and nAbsorptionAmount > 0 then --absorption is its own separate type
		tTextOptionAbsorb.nColor = 0xf8f3d7
		tTextOptionAbsorb.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Horizontal --Vertical--Horizontal  --IgnoreCollision
		tTextOptionAbsorb.eLocation = CombatFloater.CodeEnumFloaterLocation.Chest
		tTextOptionAbsorb.fOffset = -0.4
		tTextOptionAbsorb.fOffsetDirection = 0--125

		-- scale and movement
		tTextOptionAbsorb.arFrames =
		{
			[1] = {fScale = 1.1,	fTime = 0,									fVelocityDirection = 0,		fVelocityMagnitude = 0,},
			[2] = {fScale = 0.7,	fTime = 0.05,				fAlpha = 1.0,},
			[3] = {fScale = 0.7,	fTime = .2 + nStallTime,	fAlpha = 1.0,	fVelocityDirection = 180,	fVelocityMagnitude = 3,},
			[4] = {fScale = 0.7,	fTime = .45 + nStallTime,	fAlpha = 0.2,	fVelocityDirection = 180,},
		}
	end

	if type(nShieldDamaged) == "number" and nShieldDamaged > 0 then
		nDamage = nDamage + nShieldDamaged
	end

	local bHeal = eDamageType == GameLib.CodeEnumDamageType.Heal or eDamageType == GameLib.CodeEnumDamageType.HealShields
	local nBaseColor = 0xff6d6d
	local nHighlightColor = 0xff6d6d
	local fMaxSize = 0.8
	local nOffsetDirection = 0
	local fOffsetAmount = -0.6
	local fMaxDuration = .55
	local eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Horizontal

	if eDamageType == GameLib.CodeEnumDamageType.Heal then -- healing params
		nBaseColor = 0xb0ff6a
		nHighlightColor = 0xb0ff6a
		fOffsetAmount = -0.5

		if bCritical then
			fMaxSize = 1.2
			nBaseColor = 0xc6ff94
			nHighlightColor = 0xc6ff94
			fMaxDuration = .75
		end

	elseif eDamageType == GameLib.CodeEnumDamageType.HealShields then -- healing shields params
		nBaseColor = 0x6afff3
		fOffsetAmount = -0.5
		nHighlightColor = 0x6afff3

		if bCritical then
			fMaxSize = 1.2
			nBaseColor = 0xa6fff8
			nHighlightColor = 0xFFFFFF
			fMaxDuration = .75
		end

	else -- regular old damage (player)
		fOffsetAmount = -0.5

		if bCritical then
			fMaxSize = 1.2
			nBaseColor = 0xffab3d
			nHighlightColor = 0xFFFFFF
			fMaxDuration = .75
		end
	end

	tTextOptionAbsorb.fOffset = fOffsetAmount
	tTextOption.eCollisionMode = eCollisionMode
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Chest

	-- scale and movement
	tTextOption.arFrames =
	{
		[1] = {fScale = fMaxSize * .75,	fTime = 0,									nColor = nHighlightColor,	fVelocityDirection = 0,		fVelocityMagnitude = 0,},
		[2] = {fScale = fMaxSize * 1.5,	fTime = 0.05,								nColor = nHighlightColor,	fVelocityDirection = 0,		fVelocityMagnitude = 0,},
		[3] = {fScale = fMaxSize,		fTime = 0.1,				fAlpha = 1.0,	nColor = nBaseColor,},
		[4] = {							fTime = 0.3 + nStallTime,	fAlpha = 1.0,								fVelocityDirection = 180,	fVelocityMagnitude = 3,},
		[5] = {							fTime = 0.65 + nStallTime,	fAlpha = 0.2,								fVelocityDirection = 180,},
	}

	if type(nAbsorptionAmount) == "number" and nAbsorptionAmount > 0 then -- secondary "if" so we don't see absorption and "0"
		CombatFloater.ShowTextFloater( unitPlayer, String_GetWeaselString(Apollo.GetString("HawtScrollingBattleText_Absorbed"), nAbsorptionAmount), tTextOptionAbsorb )
	end

	if nDamage > 0 and bHeal then
		CombatFloater.ShowTextFloater( unitPlayer, String_GetWeaselString(Apollo.GetString("HawtScrollingBattleText_PlusValue"), nDamage), tTextOption )
	elseif nDamage > 0 then
		CombatFloater.ShowTextFloater( unitPlayer, nDamage, tTextOption )
	end
end

------------------------------------------------------------------
function HawtScrollingBattleText:OnCombatLogCCState(tEventArgs)
	if not Apollo.GetConsoleVariable("ui.showCombatFloater") then
		return
	end

	-- removal of a CC state does not display floater text
	if tEventArgs.bRemoved or tEventArgs.bHideFloater then
		return
	end

	local nOffsetState = tEventArgs.eState
	if tEventArgs.eResult == nil then
		return
	end -- totally invalid

	if GameLib.IsControlledUnit( tEventArgs.unitTarget ) then
		-- Route to the player function
		self:OnCombatLogCCStatePlayer(tEventArgs)
		return
	end

	local arCCFormat =  --Removing an entry from this table means no floater is shown for that state.
	{
		[Unit.CodeEnumCCState.Stun] 			= 0xffe691, -- stun
		[Unit.CodeEnumCCState.Sleep] 			= 0xffe691, -- sleep
		[Unit.CodeEnumCCState.Root] 			= 0xffe691, -- root
		[Unit.CodeEnumCCState.Disarm] 			= 0xffe691, -- disarm
		[Unit.CodeEnumCCState.Silence] 			= 0xffe691, -- silence
		[Unit.CodeEnumCCState.Polymorph] 		= 0xffe691, -- polymorph
		[Unit.CodeEnumCCState.Fear] 			= 0xffe691, -- fear
		[Unit.CodeEnumCCState.Hold] 			= 0xffe691, -- hold
		[Unit.CodeEnumCCState.Knockdown] 		= 0xffe691, -- knockdown
		[Unit.CodeEnumCCState.Disorient] 		= 0xffe691,
		[Unit.CodeEnumCCState.Disable] 			= 0xffe691,
		[Unit.CodeEnumCCState.Taunt] 			= 0xffe691,
		[Unit.CodeEnumCCState.DeTaunt] 			= 0xffe691,
		[Unit.CodeEnumCCState.Blind] 			= 0xffe691,
		[Unit.CodeEnumCCState.Knockback] 		= 0xffe691,
		[Unit.CodeEnumCCState.Pushback ] 		= 0xffe691,
		[Unit.CodeEnumCCState.Pull] 			= 0xffe691,
		[Unit.CodeEnumCCState.PositionSwitch] 	= 0xffe691,
		[Unit.CodeEnumCCState.Tether] 			= 0xffe691,
		[Unit.CodeEnumCCState.Snare] 			= 0xffe691,
		[Unit.CodeEnumCCState.Interrupt] 		= 0xffe691,
		[Unit.CodeEnumCCState.Daze] 			= 0xffe691,
		[Unit.CodeEnumCCState.Subdue] 			= 0xffe691,
	}

	local tTextOption = self:GetDefaultTextOption()
	local strMessage = ""

	tTextOption.fScale = 1.0
	tTextOption.fDuration = 2
	tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Vertical --IgnoreCollision --Horizontal
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Chest
	tTextOption.fOffset = -0.8
	tTextOption.fOffsetDirection = 0
	tTextOption.arFrames={}

	local bUseCCFormat = false -- use CC formatting vs. message formatting

	if tEventArgs.eResult == CombatFloater.CodeEnumCCStateApplyRulesResult.Ok then -- CC applied
		strMessage = tEventArgs.strState
		if arCCFormat[nOffsetState] ~= nil then -- make sure it's one we want to show
			bUseCCFormat = true
		else
			return
		end
	elseif tEventArgs.eResult == CombatFloater.CodeEnumCCStateApplyRulesResult.Target_Immune then
		strMessage = Apollo.GetString("HawtScrollingBattleText_Immune")
	elseif tEventArgs.eResult == CombatFloater.CodeEnumCCStateApplyRulesResult.Target_InfiniteInterruptArmor then
		strMessage = Apollo.GetString("HawtScrollingBattleText_InfInterruptArmor")
	elseif tEventArgs.eResult == CombatFloater.CodeEnumCCStateApplyRulesResult.Target_InterruptArmorReduced then -- use with interruptArmorHit
		strMessage = String_GetWeaselString(Apollo.GetString("HawtScrollingBattleText_InterruptArmor"), tEventArgs.nInterruptArmorHit)
	elseif tEventArgs.eResult == CombatFloater.CodeEnumCCStateApplyRulesResult.DiminishingReturns_TriggerCap and tEventArgs.strTriggerCapCategory ~= nil then
		strMessage = Apollo.GetString("HawtScrollingBattleText_CC_DiminishingReturns_TriggerCap").." "..tEventArgs.strTriggerCapCategory
	else -- all invalid messages
		return
	end

	if not bUseCCFormat then -- CC didn't take
		tTextOption.nColor = 0xb0b0b0

		tTextOption.arFrames =
		{
			[1] = {fScale = 1.0,	fTime = 0,		fAlpha = 0.0},
			[2] = {fScale = 0.7,	fTime = 0.1,	fAlpha = 0.8},
			[3] = {fScale = 0.7,	fTime = 0.9,	fAlpha = 0.8,	fVelocityDirection = 0},
			[4] = {fScale = 1.0,	fTime = 1.0,	fAlpha = 0.0,	fVelocityDirection = 0},
		}
	else -- CC applied
		tTextOption.arFrames =
		{
			[1] = {fScale = 2.0,	fTime = 0,		fAlpha = 1.0,	nColor = 0xFFFFFF,},
			[2] = {fScale = 0.7,	fTime = 0.15,	fAlpha = 1.0,},
			[3] = {					fTime = 0.5,					nColor = arCCFormat[nOffsetState],},
			[4] = {fScale = 0.7,	fTime = 1.1,	fAlpha = 1.0,										fVelocityDirection = 0,	fVelocityMagnitude = 5,},
			[5] = {					fTime = 1.3,	fAlpha = 0.0,										fVelocityDirection = 0,},
		}
	end

	CombatFloater.ShowTextFloater( tEventArgs.unitTarget, strMessage, tTextOption )
end

------------------------------------------------------------------
function HawtScrollingBattleText:OnCombatLogCCStatePlayer(tEventArgs)
	if not Apollo.GetConsoleVariable("ui.showCombatFloater") then
		return
	end

	-- removal of a CC state does not display floater text
	if tEventArgs.bRemoved or tEventArgs.bHideFloater then
		return
	end

	local arCCFormatPlayer =
    --Removing an entry from this table means no floater is shown for that state.
	{
		[Unit.CodeEnumCCState.Stun] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.Sleep] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.Root] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.Disarm] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.Silence] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.Polymorph] 		= 0xff2b2b,
		[Unit.CodeEnumCCState.Fear] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.Hold] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.Knockdown] 		= 0xff2b2b,
		[Unit.CodeEnumCCState.Disorient] 		= 0xff2b2b,
		[Unit.CodeEnumCCState.Disable] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.Taunt] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.DeTaunt] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.Blind] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.Knockback] 		= 0xff2b2b,
		[Unit.CodeEnumCCState.Pushback] 		= 0xff2b2b,
		[Unit.CodeEnumCCState.Pull] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.PositionSwitch] 	= 0xff2b2b,
		[Unit.CodeEnumCCState.Tether] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.Snare] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.Interrupt] 		= 0xff2b2b,
		[Unit.CodeEnumCCState.Daze] 			= 0xff2b2b,
		[Unit.CodeEnumCCState.Subdue] 			= 0xff2b2b,
	}

	local nOffsetState = tEventArgs.eState

	local tTextOption = self:GetDefaultTextOption()
	local strMessage = ""

	tTextOption.fScale = 1.0
	tTextOption.fDuration = 2
	tTextOption.eCollisionMode = CombatFloater.CodeEnumFloaterCollisionMode.Horizontal
	tTextOption.eLocation = CombatFloater.CodeEnumFloaterLocation.Chest
	tTextOption.fOffset = -0.2
	tTextOption.fOffsetDirection = 0
	tTextOption.arFrames={}

	local bUseCCFormat = false -- use CC formatting vs. message formatting

	if tEventArgs.eResult == CombatFloater.CodeEnumCCStateApplyRulesResult.Ok then -- CC applied
		strMessage = tEventArgs.strState
		if arCCFormatPlayer[nOffsetState] ~= nil then -- make sure it's one we want to show
			bUseCCFormat = true
		else
			return
		end
	elseif tEventArgs.eResult == CombatFloater.CodeEnumCCStateApplyRulesResult.Target_Immune then
		strMessage = Apollo.GetString("HawtScrollingBattleText_Immune")
	elseif tEventArgs.eResult == CombatFloater.CodeEnumCCStateApplyRulesResult.Target_InfiniteInterruptArmor then
		strMessage = Apollo.GetString("HawtScrollingBattleText_InfInterruptArmor")
	elseif tEventArgs.eResult == CombatFloater.CodeEnumCCStateApplyRulesResult.Target_InterruptArmorReduced then -- use with interruptArmorHit
		strMessage = String_GetWeaselString(Apollo.GetString("HawtScrollingBattleText_InterruptArmor"), tEventArgs.nInterruptArmorHit)
	else -- all invalid messages
		return
	end

	if not bUseCCFormat then -- CC didn't take
		tTextOption.nColor = 0xd8f8f8
		tTextOption.arFrames =
		{
			[1] = {fScale = 1.0,	fTime = 0,		fAlpha = 0.0,},
			[2] = {fScale = 0.7,	fTime = 0.1,	fAlpha = 0.8,},
			[3] = {fScale = 0.7,	fTime = 0.9,	fAlpha = 0.8,	fVelocityDirection = 180,	fVelocityMagnitude = 3,},
			[4] = {fScale = 0.7,	fTime = 1.0,	fAlpha = 0.0,	fVelocityDirection = 180,},
		}
	else -- CC applied
		tTextOption.nColor = arCCFormatPlayer[nOffsetState]
		tTextOption.arFrames =
		{
			[1] = {fScale = 1.1,	fTime = 0,		nColor = 0xFFFFFF,},
			[2] = {fScale = 0.7,	fTime = 0.05,	nColor = arCCFormatPlayer[nOffsetState],	fAlpha = 1.0,},
			[3]	= {					fTime = 0.35,	nColor = 0xFFFFFF,},
			[4] = {					fTime = 0.7,	nColor = arCCFormatPlayer[nOffsetState],},
			[5] = {					fTime = 1.05,	nColor = 0xFFFFFF,},
			[6] = {fScale = 0.7,	fTime = 1.4,	nColor = arCCFormatPlayer[nOffsetState],	fAlpha = 1.0,	fVelocityDirection = 180,	fVelocityMagnitude = 3,},
			[7] = {fScale = 0.7,	fTime = 1.55,												fAlpha = 0.2,	fVelocityDirection = 180,},
		}
	end

	CombatFloater.ShowTextFloater( tEventArgs.unitTarget, strMessage, tTextOption )
end

------------------------------------------------------------------
-- send show text request to message manager with a delay in milliseconds
function HawtScrollingBattleText:RequestShowTextFloater( eMessageType, unitTarget, strText, tTextOption, fDelay, tContent ) -- addtn'l parameters for XP/rep
	local tParams =
	{
		unitTarget 	= unitTarget,
		strText 	= strText,
		tTextOption = TableUtil:Copy( tTextOption ),
		tContent 	= tContent,
	}

	if not fDelay or fDelay == 0 then -- just display if no delay
		Event_FireGenericEvent("Float_RequestShowTextFloater", eMessageType, tParams, tContent )
	else
		tParams.nTime = os.time() + fDelay
		tParams.eMessageType = eMessageType

		-- insert the text in the delayed queue in order of how fast they'll need to be shown
		local nInsert = 0
		for key, value in pairs(self.tDelayedFloatTextQueue:GetItems()) do
			if value.nTime > tParams.nTime then
				nInsert = key
				break
			end
		end
		if nInsert > 0 then
			self.tDelayedFloatTextQueue:InsertAbsolute( nInsert, tParams )
		else
			self.tDelayedFloatTextQueue:Push( tParams )
		end
		self.iTimerIndex = self.iTimerIndex + 1
		if self.iTimerIndex > 9999999 then
			self.iTimerIndex = 1
		end

		Apollo.CreateTimer("DelayedFloatTextTimer".. self.iTimerIndex, fDelay, false) -- create the timer to show the text
		Apollo.RegisterTimerHandler("DelayedFloatTextTimer"..self.iTimerIndex, "OnDelayedFloatTextTimer", self)
	end
end

------------------------------------------------------------------
function HawtScrollingBattleText:OnDelayedFloatTextTimer()
	local tParams = self.tDelayedFloatTextQueue:Pop()
	Event_FireGenericEvent("Float_RequestShowTextFloater", tParams.eMessageType, tParams, tParams.tContent) -- TODO: Event!!!!
end

local HawtScrollingBattleTextInst = HawtScrollingBattleText:new()
HawtScrollingBattleTextInst:Init()

--------------------------------
--- Hawt Battle Text
--------------------------------

local tLocalAppData = nil

function HawtScrollingBattleText:GetDefaultAppData()

	local tData = {
		tUserPrefs = {
			bScrollFromTarget = false
		},
		tTextPrefs = {
			tIncoming = {
		},
			tOutgoing = {
				tDamage = {
				fStartScale = 1,
				fEndScaleMultiplier = 1.5,
				fDirection = 90,
				fOffset = 10,
				fDisplayTime = 0,
				fVelocityDirection = 0,
				fVelocityMagnitude = 10,
				fVelocityDisplayTime = .5,
				bCombineShield = false,
				bVibrateOnCrit = true,
					tN = {
						strFont = "CRB_FloaterHuge_O",
						nColorStart = 0xCC66FF,
						nColorEnd = 0xCC9900,
						strFormat = "%s"
					},
					tA = {
						strFont = "CRB_FloaterHuge_O",
						nColorStart = 0x0000FF,
						nColorEnd = 0x6666FF,
						strFormat = "%s (Absorb)"
					},
					tC = {
						strFont = "CRB_FloaterHuge_O",
						nColorStart = 0xCC0000,
						nColorEnd = 0xD63333,
						strFormat = "%s (Crit)"
					},
					tS = {
						strFont = "CRB_FloaterHuge_O",
						nColorStart = 0x0000FF,
						nColorEnd = 0x6666FF,
						strFormat = "%s (Shield)"
					}
				},
				tHealing = {
					tN = {
						strFont = "CRB_FloaterHuge_O",
						nColorStart = 0x00CC00,
						nColorEnd = 0x4DDB4D,
						strFormat = "+ %s"
					},
					tC = {
						strFont = "CRB_FloaterHuge_O",
						nColorStart = 0x00CC00,
						nColorEnd = 0x4DDB4D,
						strFormat = "+ %s (Crit)"
					}
			   }
			}
		}
	}

	return tData
end

---------------
--- Utils
---------------

function tableLength(T)
	local count = 0
	for _ in pairs(T) do count = count +1 end
	return count
end

function table.removekey(table, key)
    local element = table[key]
    table[key] = nil
    return element
end

-----------------
--- Save Restore
-----------------
--[[function HawtScrollingBattleText:OnSave(eType)
  -- eType is one of:
  -- GameLib.CodeEnumAddonSaveLevel.General
  -- GameLib.CodeEnumAddonSaveLevel.Account
  -- GameLib.CodeEnumAddonSaveLevel.Realm
  -- GameLib.CodeEnumAddonSaveLevel.Character
 
  if eType == GameLib.CodeEnumAddonSaveLevel.Character then
    return tAppData
  end
end
 
function HawtScrollingBattleText:OnRestore(eType, tSavedData)
if tSavedData == nil or tableLength(tSavedData) <= 0 then
	tSavedData = self:GetDefaultAppData()
end
  if eType == GameLib.CodeEnumAddonSaveLevel.Character then
    for k,v in pairs(tSavedData) do
      tAppData[k] = v
    end
  end
end
]]



