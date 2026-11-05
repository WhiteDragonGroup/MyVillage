-- 클라이언트 진입점

local Hud = require(script.Parent.Hud)
local BuildMode = require(script.Parent.BuildMode)
local CraftUi = require(script.Parent.CraftUi)
local ShopUi = require(script.Parent.ShopUi)
local EditMenu = require(script.Parent.EditMenu)
local BuildModeUi = require(script.Parent.BuildModeUi)
local Guide = require(script.Parent.Guide)
local VillageView = require(script.Parent.VillageView)
local AdminUi = require(script.Parent.AdminUi)

Hud.start()
CraftUi.start() -- 상점 프레임을 복제하므로 ShopUi보다 먼저 시작한다
ShopUi.start()
BuildMode.start()
EditMenu.start()
BuildModeUi.start()
Guide.start()
VillageView.start()
AdminUi.start()
