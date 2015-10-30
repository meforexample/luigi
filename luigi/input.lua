local ROOT = (...):gsub('[^.]*$', '')

local Base = require(ROOT .. 'base')
local Event = require(ROOT .. 'event')
local Renderer = require(ROOT .. 'renderer')

local Input = Base:extend()

local weakValueMeta = { __mode = 'v' }

function Input:constructor (layout)
    self.layout = layout
    self.pressedWidgets = setmetatable({}, weakValueMeta)
    self.passedWidgets = setmetatable({}, weakValueMeta)
end

function Input:bubbleEvent (eventName, widget, data)
    local event = Event[eventName]
    for ancestor in widget:getAncestors(true) do
        local result = event:emit(ancestor, data)
        if result ~= nil then return result end
    end
    return event:emit(self.layout, data)
end

function Input:handleDisplay ()
    local root = self.layout.root
    if root then Renderer:render(root) end
    Event.Display:emit(self.layout)
end

function Input:handleKeyPress (key, x, y)
    local widget = self.layout.focusedWidget or self.layout:getWidgetAt(x, y)
    local result = self:bubbleEvent('KeyPress', widget, {
        target = widget,
        key = key, x = x, y = y
    })
    if result ~= nil then return result end

    local acceleratedWidget = self.layout.accelerators[key]

    if acceleratedWidget then
        acceleratedWidget.hovered = true
        self:handlePressStart(key, x, y, acceleratedWidget, key)
    end
end

function Input:handleKeyRelease (key, x, y)
    local widget = self.layout.focusedWidget or self.layout:getWidgetAt(x, y)
    local result = self:bubbleEvent('KeyRelease', widget, {
        target = widget,
        key = key, x = x, y = y
    })
    if result ~= nil then return result end

    local acceleratedWidget = self.layout.accelerators[key]

    if acceleratedWidget then
        acceleratedWidget.hovered = false
        self:handlePressEnd(key, x, y, acceleratedWidget, key)
    end
end

function Input:handleTextInput (text, x, y)
    local widget = self.layout.focusedWidget or self.layout:getWidgetAt(x, y)
    self:bubbleEvent('TextInput', widget, {
        target = widget,
        text = text, x = x, y = y
    })
end

function Input:handleMove (x, y)
    local widget = self.layout:getWidgetAt(x, y)
    local previousWidget = self.previousMoveWidget
    if not widget.hovered then
        if previousWidget then
            previousWidget.hovered = nil
        end
        widget.hovered = true
    end
    self:bubbleEvent('Move', widget, {
        target = widget,
        oldTarget = previousWidget,
        x = x, y = y
    })
    if widget ~= previousWidget then
        if previousWidget then
            self:bubbleEvent('Leave', previousWidget, {
                target = previousWidget,
                newTarget = widget,
                x = x, y = y
            })
        end
        self:bubbleEvent('Enter', widget, {
            target = widget,
            oldTarget = previousWidget,
            x = x, y = y
        })
        self.previousMoveWidget = widget
    end
end

function Input:handlePressedMove (x, y)
    local widget = self.layout:getWidgetAt(x, y)
    for button = 1, 3 do
        local originWidget = self.pressedWidgets[button]
        local passedWidget = self.passedWidgets[button]
        if originWidget then
            self:bubbleEvent('PressDrag', originWidget, {
                target = originWidget,
                newTarget = widget,
                button = button,
                x = x, y = y
            })
            if (widget == passedWidget) then
                self:bubbleEvent('PressMove', widget, {
                    target = widget,
                    origin = originWidget,
                    button = button,
                    x = x, y = y
                })
            else
                originWidget.pressed = (widget == originWidget) or nil
                if passedWidget then
                    self:bubbleEvent('PressLeave', passedWidget, {
                        target = passedWidget,
                        newTarget = widget,
                        origin = originWidget,
                        button = button,
                        x = x, y = y
                    })
                end
                self:bubbleEvent('PressEnter', widget, {
                        target = widget,
                        oldTarget = passedWidget,
                        origin = originWidget,
                        button = button,
                        x = x, y = y
                    })
                self.passedWidgets[button] = widget
            end
        end
    end
end

function Input:handlePressStart (button, x, y, widget, accelerator)
    local widget = widget or self.layout:getWidgetAt(x, y)
    widget.pressed = true
    self.pressedWidgets[button] = widget
    self.passedWidgets[button] = widget
    self:bubbleEvent('PressStart', widget, {
        target = widget,
        button = button,
        accelerator = accelerator,
        x = x, y = y
    })
end

function Input:handlePressEnd (button, x, y, widget, accelerator)
    local widget = widget or self.layout:getWidgetAt(x, y)
    local originWidget = self.pressedWidgets[button]
    originWidget.pressed = nil
    self:bubbleEvent('PressEnd', widget, {
        target = widget,
        origin = originWidget,
        accelerator = accelerator,
        button = button, x = x, y = y
    })
    if (widget == originWidget) then
        self:bubbleEvent('Press', widget, {
            target = widget,
            button = button,
            accelerator = accelerator,
            x = x, y = y
        })
    end
    self.pressedWidgets[button] = nil
    self.passedWidgets[button] = nil
end

function Input:handleReshape (width, height)
    local root = self.layout.root

    root.width = width
    root.height = height
    root:reshape()
end

return Input
