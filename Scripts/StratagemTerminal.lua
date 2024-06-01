---@class StratagemTerminal : ShapeClass
StratagemTerminal = class()

---@param caller Player
function StratagemTerminal:sv_tryPurchase(uuid, caller)
    local inventory = caller:getInventory()
    local userData = GetStratagemUserdata(uuid)
    for k, v in pairs(userData.cost) do
        if not inventory:canSpend(v.uuid, v.amount) then
            return
        end
    end

    sm.event.sendToTool(sm.HELLDIVERSBACKEND, "sv_purchaseStratagem", { player = caller, uuid = uuid, int = self.interactable })
end



function StratagemTerminal:client_onInteract(char, state)
    if not state then return end

    g_stratagemTerminal = self.interactable
    self.selectedStratagem = 0
    self.offset = 0

    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/StratagemTerminal.layout", true)
    self.gui:setOnCloseCallback("cl_onClose")
    self.gui:setButtonCallback("Purchase", "cl_purchase")

    for i = 1, 6 do
        local widget = "stratagem"..i
        self.gui:setButtonCallback(widget, "cl_select")
    end

    self.range = GetStratagemPages()
    self.gui:createVerticalSlider("StratagemScroll", self.range, self.range - 1, "cl_scroll")

    local matGrid = {
		type = "materialGrid",
		layout = "$GAME_DATA/Gui/Layouts/Interactable/Interactable_CraftBot_IngredientItem.layout",
		itemWidth = 44,
		itemHeight = 60,
		itemCount = 4,
	}
	self.gui:createGridFromJson( "MaterialGrid", matGrid )
	self.gui:setContainer( "", sm.localPlayer.getPlayer():getInventory())

    self:cl_scroll(self.range - 1)

    self.gui:open()
end

function StratagemTerminal:cl_onClose()
    g_stratagemTerminal = nil
end

function StratagemTerminal:cl_purchase()
    self.network:sendToServer("sv_tryPurchase", GetStratagem(self.page * 6 + self.selectedStratagem).uuid)
end

function StratagemTerminal:cl_select(button)
    local value = tonumber(button:sub(10,10))

    self.gui:setVisible("stratagem"..self.selectedStratagem.."_border", false)
    self.gui:setVisible("stratagem"..value.."_border", true)

    self.selectedStratagem = value
    self:cl_updateInfo(self.page * 6 + value)
end

function StratagemTerminal:cl_scroll(value, noReset)
    local page = self.range - value - 1
    self.page = page
    for i = 1, 6 do
        local widget = "stratagem"..i
        local stratagem = GetStratagem(page * 6 + i)

        self.gui:setVisible(widget, stratagem ~= nil)
        if stratagem then
            local userData = GetStratagemUserdata(stratagem.uuid)
            self.gui:setText(widget.."_name", userData.name)

            local unlocked = GetClStratagemProgression(stratagem.uuid).unlocked
            self.gui:setVisible(widget.."_border", false)
            self.gui:setVisible(widget.."_completed", unlocked)
            self.gui:setVisible(widget.."_locked", not unlocked)
        end
    end

    if noReset then return end
    self:cl_updateInfo(-1)
    self.selectedStratagem = 0
end

function StratagemTerminal:cl_updateInfo(index)
    if index > 0 then
        local userData, uuid = GetStratagemUserdata(index)
        self.gui:setText("Type", GetTypeFullName(userData.type))
        self.gui:setText("Name", userData.name)
        self.gui:setText("Description", userData.description)

        local progression = GetClStratagemProgression(uuid)
        self.gui:setText("Charges", "Charges: "..progression.charges)

        for idx, ingredient in ipairs( userData.cost ) do
            self.gui:setGridItem( "MaterialGrid", idx - 1, {
                itemId = tostring( ingredient.uuid ),
                quantity = ingredient.amount,
            })
        end

        self.gui:setVisible("Purchase", true)
    else
        self.gui:setText("Type", "")
        self.gui:setText("Name", "")
        self.gui:setText("Description", "")
        self.gui:setText("Charges", "")
        self.gui:setVisible("Purchase", false)

        for idx = 1, 4 do
            self.gui:setGridItem( "MaterialGrid", idx - 1, nil )
        end
    end
end

function StratagemTerminal:cl_refresh()
    self:cl_scroll(self.range - self.page - 1, true)
    self:cl_updateInfo(self.page * 6 + self.selectedStratagem)
end