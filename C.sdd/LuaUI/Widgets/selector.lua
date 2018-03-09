--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    selector.lua
--  brief:   the widget selector, loads and unloads widgets
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- changes:
--   jK (April@2009) - updated to new font system
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "WidgetSelector",
    desc      = "Widget selection widget",
    author    = "trepan",
    date      = "Jan 8, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = math.huge,
    hidden    = true, -- don't show in the widget selector
    handler   = true, -- needs the real widgetHandler
    enabled   = true, -- loaded by default?
    api       = true;
    before    = {"all"},
    after     = {"TweakMode"},
  }
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

require "colors.lua"
require "keysym.lua"
require "fonts.lua"


local floor = math.floor

local widgetsList = {}
local fullWidgetsList = {}

local vsx, vsy = widgetHandler:GetViewSizes()

local maxEntries = 20
local startEntry = 1
local pageStep  = math.floor(maxEntries / 2) - 1

local fontSize = 12
local fontSpace = 5
local yStep = fontSize + fontSpace

local maxWidth = 0.01
local borderx = yStep * 0.75
local bordery = yStep * 0.75

local midx = vsx * 0.5
local minx = vsx * 0.4
local maxx = vsx * 0.6
local midy = vsy * 0.5
local miny = vsy * 0.4
local maxy = vsy * 0.6

local sbposx = 0.0
local sbposy = 0.0
local sbsizex = 0.0
local sbsizey = 0.0
local sby1 = 0.0
local sby2 = 0.0
local sbsize = 0.0
local sbheight = 0.0
local activescrollbar = false
local scrollbargrabpos = 0.0


-------------------------------------------------------------------------------

local enabled = true

local function Disable()
  if (not enabled) then
    return
  end


  for ciName,v in pairs(widget) do --// the widget table contains the _full_ enviroment!!! (math.xyz, table.xyz, Spring.xyz, ...)
    if (ciName ~= "TextCommand")and(widgetHandler.knownCallIns[ciName]) then
      widgetHandler:RemoveWidgetCallIn(ciName, widget)
    end
  end

  enabled = false
end


local function Enable()
  if (enabled) then
    return
  end

  for ciName,v in pairs(widget) do --// the widget table contains the _full_ enviroment!!! (math.xyz, table.xyz, Spring.xyz, ...)
    if (ciName ~= "TextCommand")and(widgetHandler.knownCallIns[ciName]) then
      widgetHandler:UpdateWidgetCallIn(ciName, widget)
    end
  end

  --// search for new widgets
  widgetHandler:SearchForNew(true)

  enabled = true
end

-------------------------------------------------------------------------------

function widget:Initialize()
  Spring.SendCommands(
    "unbindkeyset  Any+f11",
    "bind    f11  luaui selector"
  )
  Spring.Echo("LuaUI: bound F11 to the widget selector")
  Disable()
end


-------------------------------------------------------------------------------

local function UpdateGeometry()
  midx  = vsx * 0.5
  midy  = vsy * 0.5

  local halfWidth = maxWidth * fontSize * 0.5
  halfWidth = math.max(60, halfWidth)
  minx = floor(midx - halfWidth - borderx)
  maxx = floor(midx + halfWidth + borderx)

  local ySize = yStep * (#widgetsList)
  miny = floor(midy - (0.5 * ySize) - bordery - fontSize * 0.5)
  maxy = floor(midy + (0.5 * ySize) + bordery)
end


local function UpdateListScroll()
  local wCount = #fullWidgetsList
  local lastStart = wCount - maxEntries + 1
  if (lastStart < 1) then lastStart = 1 end
  if (startEntry > lastStart) then startEntry = lastStart end
  if (startEntry < 1) then startEntry = 1 end

  widgetsList = {}
  local se = startEntry
  local ee = se + maxEntries - 1
  local n = 1
  for i = se, ee do
    widgetsList[n],n = fullWidgetsList[i],n+1
  end
end


local function ScrollUp(step)
  startEntry = startEntry - step
  UpdateListScroll()
end


local function ScrollDown(step)
  startEntry = startEntry + step
  UpdateListScroll()
end


function widget:MouseWheel(up, value)
  local a,c,m,s = Spring.GetModKeyState()
  if (a or m) then
    return false  -- alt and meta allow normal control
  end
  local step = (s and 4) or (c and 1) or 2
  if (up) then
    ScrollUp(step)
  else
    ScrollDown(step)
  end
  return true
end


local function SortWidgetListFunc(nd1, nd2)
  if (nd1[2].fromZip ~= nd2[2].fromZip) then
    return nd1[2].fromZip  -- mod widgets first
  end
  return (nd1[1] < nd2[1]) -- sort by name
end


local lastUpdate = -1
local function UpdateList()
  if (widgetHandler.knownChanged == lastUpdate) then
    return
  end
  lastUpdate = widgetHandler.knownChanged

  local myName = widget:GetInfo().name
  maxWidth = 0
  fullWidgetsList = {}
  for name,data in pairs(widgetHandler.knownAddons) do
    if (not data.hidden and not data.blocked) then
      table.insert(fullWidgetsList, { name, data })
      -- look for the maxWidth
      local width = fontSize * gl.GetTextWidth(name)
      if (width > maxWidth) then
        maxWidth = width
      end
    end
  end

  maxWidth = maxWidth / fontSize
--[[
  local myCount = #fullWidgetsList
  if (widgetHandler.knownCount ~= (myCount + 1)) then
    error('knownCount mismatch')
  end
--]]
  table.sort(fullWidgetsList, SortWidgetListFunc)

  UpdateListScroll()
  UpdateGeometry()
end


function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY

  UpdateListScroll()
  UpdateGeometry()
end


-------------------------------------------------------------------------------

function widget:TextCommand(cmd)
  if (cmd == 'selector') then
    Enable()
    return true
  end
end


function widget:KeyPress(key, mods, isRepeat)
  if ((key == KEYSYMS.ESCAPE) or
      ((key == KEYSYMS.F11) and not isRepeat and
       not (mods.alt or mods.ctrl or mods.meta or mods.shift)))
  then
    Disable()
    return true
  end
  if (key == KEYSYMS.PAGEUP) then
    ScrollUp(pageStep)
    return true
  end
  if (key == KEYSYMS.PAGEDOWN) then
    ScrollDown(pageStep)
    return true
  end
  return false
end


local function DrawButton(x1,y1,x2,y2)
  gl.Color(0, 0, 0, 0.3)
  gl.Rect(x1, y1, x2, y2)

  gl.Color(0, 0, 0, 0.6)
  gl.Shape(GL.LINE_STRIP, {
    {v = { x1, y1 }},
    {v = { x2, y1 }},
    {v = { x2, y2 }},
    {v = { x1, y2 }},
    {v = { x1, y1 }},
  })
end


local function DrawButtons()
  -- draw the widget labels
  local mx,my,lmb,mmb,rmb = Spring.GetMouseState()

  local btnWidth = (maxx - minx) * 0.3

  local tcol = WhiteStr
  if minx < mx and mx < minx + btnWidth and miny - 20 < my and my < miny then
    tcol = '\255\031\031\255'
  end
  DrawButton(minx, miny, minx + btnWidth, miny - 20)
  gl.Text(tcol .. 'All', minx + btnWidth * 0.5, miny - 15, fontSize * 1.25, "sc")

  tcol = WhiteStr
  if minx + btnWidth < mx and mx < maxx - btnWidth and miny - 20 < my and my < miny then
    tcol = '\255\031\031\255'
  end
  DrawButton(minx + btnWidth, miny, maxx - btnWidth, miny - 20)
  gl.Text(tcol .. 'Reload', (maxx + minx) * 0.5, miny - 15, fontSize * 1.25, "sc")

  tcol = WhiteStr
  if maxx - btnWidth < mx and mx < maxx and miny - 20 < my and my < miny then
    tcol = '\255\031\031\255'
  end
  DrawButton(maxx - btnWidth, miny, maxx, miny - 20)
  gl.Text(tcol .. 'None', maxx - btnWidth * 0.5, miny - 15, fontSize * 1.25, "sc")
end


function widget:DrawScreen()
  UpdateList()
  gl.BeginText()

  -- draw the header
  gl.Text("Widget Selector", midx, maxy + 5, fontSize * 1.25, "snc")

  -- draw the box
  gl.Color(0.3, 0.3, 0.3, 1.0)
  gl.Texture(":n:bitmaps/detailtex.bmp")
  local ts = (2.0 / 512)  --  texture scale
  gl.Shape(GL.QUADS, {
    { v = { minx, miny }, t = { minx * ts, miny * ts } },
    { v = { maxx, miny }, t = { maxx * ts, miny * ts } },
    { v = { maxx, maxy }, t = { maxx * ts, maxy * ts } },
    { v = { minx, maxy }, t = { minx * ts, maxy * ts } }
  })
  gl.Texture(false)

  DrawButtons()

  -- draw the widget labels
  local mx,my,lmb,mmb,rmb = Spring.GetMouseState()

  local nd = not widgetHandler.tweakMode and self:AboveLabel(mx, my)
  local pointedY = nil
  local pointedEnabled = false
  local pointedName = (nd and nd[1]) or nil
  local posy = maxy - yStep - bordery
  sby1 = posy + fontSize + fontSpace * 0.5
  for _,namedata in ipairs(widgetsList) do
    local name = namedata[1]
    local data = namedata[2]
    local color = ''
    local pointed = (pointedName == name)
    local order = widgetHandler.orderList[name]
    local enabled = order and (order > 0)
    local active = data.active
    if (pointed and not activescrollbar) then
      pointedY = posy
      pointedEnabled = data.active
      if (lmb or mmb or rmb) then
        color = WhiteStr
      else
        color = (active  and '\255\128\255\128') or
                (enabled and '\255\255\255\128') or '\255\255\128\128'
      end
    else
      color = (active  and '\255\064\224\064') or
              (enabled and '\255\200\200\064') or '\255\224\064\064'
    end

    local tmpName
    if (data.fromZip) then
      -- FIXME: extra chars not counted in text length
      tmpName = WhiteStr .. '*' .. color .. name .. WhiteStr .. '*'
    else
      tmpName = color .. name
    end

    gl.Text(color..tmpName, midx, posy + fontSize * 0.5, fontSize, "vcn")
    posy = posy - yStep
  end

  if #widgetsList < #fullWidgetsList then
    sby2 = posy + yStep - fontSpace * 0.5
    sbheight = sby1 - sby2
    sbsize = sbheight * #widgetsList / #fullWidgetsList
    if activescrollbar then
    	startEntry = math.max(0, math.min(
    	math.floor(#fullWidgetsList *
    	((sby1 - sbsize) -
    	(my - math.min(scrollbargrabpos, sbsize)))
    	 / sbheight + 0.5),
                         #fullWidgetsList - maxEntries)) + 1
    end
    local sizex = maxx - minx
    sbposx = minx + sizex + 1.0
    sbposy = sby1 - sbsize - sbheight * (startEntry - 1) / #fullWidgetsList
    sbsizex = yStep
    sbsizey = sbsize

    gl.Color(0.0, 0.0, 0.0, 0.8)
    gl.Shape(GL.QUADS, {
      { v = { sbposx, miny } }, { v = { sbposx, maxy } },
      { v = { sbposx + sbsizex, maxy } }, { v = { sbposx + sbsizex, miny } }
    })

    gl.Color(1.0, 1.0, 1.0, 0.8)
    gl.Shape(GL.TRIANGLES, {
      { v = { sbposx + sbsizex / 2, miny } }, { v = { sbposx, sby2 - 1 } },
      { v = { sbposx + sbsizex, sby2 - 1 } }
    })

    gl.Shape(GL.TRIANGLES, {
      { v = { sbposx + sbsizex / 2, maxy } }, { v = { sbposx + sbsizex, sby2 + sbheight + 1 } },
      { v = { sbposx, sby2 + sbheight + 1 } }
    })

    if (sbposx < mx and mx < sbposx + sbsizex and miny < my and my < maxy) or activescrollbar then
      gl.Color(0.2, 0.2, 1.0, 0.6)
      gl.Blending(false)
      gl.Shape(GL.LINE_LOOP, {
        { v = { sbposx, miny } }, { v = { sbposx, maxy } },
        { v = { sbposx + sbsizex, maxy } }, { v = { sbposx + sbsizex, miny } }
      })
      gl.Blending(GL.SRC_ALPHA, GL.ONE)
      gl.Shape(GL.QUADS, {
        { v = { sbposx + 0.5, miny + 0.5 } }, { v = { sbposx + 0.5, maxy - 0.5 } },
        { v = { sbposx + sbsizex - 0.5, maxy - 0.5 } }, { v = { sbposx + sbsizex - 0.5, miny + 0.5 } }
      })
      gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    end

    if (sbposx < mx and mx < sbposx + sbsizex and sby2 < my and my < sby2 + sbheight) then
      gl.Color(0.2, 0.2, 1.0, 0.2)
      gl.Blending(false)
      gl.Shape(GL.LINE_LOOP, {
        { v = { sbposx, sbposy } }, { v = { sbposx, sbposy + sbsizey } },
        { v = { sbposx + sbsizex, sbposy + sbsizey } }, { v = { sbposx + sbsizex, sbposy } }
      })
      gl.Blending(GL.SRC_ALPHA, GL.ONE)
      gl.Shape(GL.QUADS, {
        { v = { sbposx + 0.5, sbposy + 0.5 } }, { v = { sbposx + 0.5, sbposy + sbsizey - 0.5 } },
        { v = { sbposx + sbsizex - 0.5, sbposy + sbsizey - 0.5 } }, { v = { sbposx + sbsizex - 0.5, sbposy + 0.5 } }
      })
      gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    end

    gl.Color(0.25, 0.25, 0.25, 0.8)
    gl.Shape(GL.QUADS, {
      { v = { sbposx, sby2 } }, { v = { sbposx, sby2 + sbheight } },
      { v = { sbposx + sbsizex, sby2 + sbheight } }, { v = { sbposx + sbsizex, sby2 } }
    })
    gl.Color(1.0, 1.0, 1.0, 0.4)
    gl.Shape(GL.LINE_LOOP, {
      { v = { sbposx, sby2 } }, { v = { sbposx, sby2 + sbheight } },
      { v = { sbposx + sbsizex, sby2 + sbheight } }, { v = { sbposx + sbsizex, sby2 } }
    })

    gl.Color(0.8, 0.8, 0.8, 0.8)
    gl.Shape(GL.QUADS, {
      { v = { sbposx, sbposy } }, { v = { sbposx, sbposy + sbsizey } },
      { v = { sbposx + sbsizex, sbposy + sbsizey } }, { v = { sbposx + sbsizex, sbposy } }
    })
    if activescrollbar or (sbposx < mx and mx < sbposx + sbsizex and sbposy < my and my < sbposy + sbsizey) then
      gl.Color(0.2, 0.2, 1.0, 0.2)
      gl.Blending(false)
      gl.Shape(GL.LINE_LOOP, {
        { v = { sbposx, sbposy } }, { v = { sbposx, sbposy + sbsizey } },
        { v = { sbposx + sbsizex, sbposy + sbsizey } }, { v = { sbposx + sbsizex, sbposy } }
      })
      gl.Blending(GL.SRC_ALPHA, GL.ONE)
      gl.Shape(GL.QUADS, {
        { v = { sbposx + 0.5, sbposy + 0.5 } }, { v = { sbposx + 0.5, sbposy + sbsizey - 0.5 } },
        { v = { sbposx + sbsizex - 0.5, sbposy + sbsizey - 0.5 } }, { v = { sbposx + sbsizex - 0.5, sbposy + 0.5 } }
      })
      gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    end
  else
    sbposx = 0.0
    sbposy = 0.0
    sbsizex = 0.0
    sbsizey = 0.0
  end


  -- outline the highlighted label
  if (pointedY) then
    if (lmb or mmb or rmb) then
      if (pointedEnabled) then
        gl.Color(1.0, 0.2, 0.2, 0.2)
      else
        gl.Color(0.2, 1.0, 1.0, 0.2)
      end
    else
      gl.Color(0.2, 0.2, 1.0, 0.2)
    end
    local xn = minx + 0.5
    local xp = maxx - 0.5
    local yn = pointedY - fontSpace * 0.5
    local yp = pointedY + fontSize + fontSpace * 0.5
    gl.Blending(false)
    gl.Shape(GL.LINE_LOOP, {
      { v = { xn, yn } }, { v = { xp, yn } },
      { v = { xp, yp } }, { v = { xn, yp } }
    })
    xn = minx
    xp = maxx
    yn = yn + 0.5
    yp = yp - 0.5
    gl.Blending(GL.SRC_ALPHA, GL.ONE)
    gl.Shape(GL.QUADS, {
      { v = { xn, yn } }, { v = { xp, yn } },
      { v = { xp, yp } }, { v = { xn, yp } }
    })
    gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
  end

  -- outline the box
  xn = minx - 0.5
  yn = miny - 0.5
  xp = maxx + 0.5
  yp = maxy + 0.5
  gl.Color(1, 1, 1)
  gl.Shape(GL.LINE_LOOP, {
    { v = { xn, yn } }, { v = { xp, yn } },
    { v = { xp, yp } }, { v = { xn, yp } }
  })
  xn = xn - 1
  yn = yn - 1
  xp = xp + 1
  yp = yp + 1
  gl.Color(0, 0, 0)
  gl.Shape(GL.LINE_LOOP, {
    { v = { xn, yn } }, { v = { xp, yn } },
    { v = { xp, yp } }, { v = { xn, yp } }
  })

  gl.EndText()
end


function widget:MousePress(x, y, button)
  if (Spring.IsGUIHidden()) then
    return false
  end

  if button == 1 then
    --// Hovering "all | reload | none" buttons?
    if minx < x and x < maxx and miny - 20 < y and y < miny then
      return true
    end

    --// Scrollbar?
    if sbposx < x and x < sbposx + sbsizex and sbposy < y and y < sbposy + sbsizey then
      activescrollbar = true
      scrollbargrabpos = y - sbposy
      return true
    elseif sbposx < x and x < sbposx + sbsizex and sby2 < y and y < sby2 + sbheight then
      if y > sbposy + sbsizey then
        startEntry = math.max(1, math.min(startEntry - maxEntries, #fullWidgetsList - maxEntries + 1))
      elseif y < sbposy then
        startEntry = math.max(1, math.min(startEntry + maxEntries, #fullWidgetsList - maxEntries + 1))
      end
      UpdateListScroll()
      return true
    end
  end

  if ((x >= minx) and (x <= maxx + yStep)) then
    if ((y >= (maxy - bordery)) and (y <= maxy)) then
      if x > maxx then
        ScrollUp(1)
      else
        ScrollUp(pageStep)
      end
      return true
    elseif ((y >= miny) and (y <= miny + bordery)) then
      if x > maxx then
        ScrollDown(1)
      else
        ScrollDown(pageStep)
      end
      return true
    end
  end

  local namedata = self:AboveLabel(x, y)
  if (not namedata) then
    return false
  end

  return true
end


function widget:MouseMove(x, y, dx, dy, button)
  if activescrollbar then
    local foo = #fullWidgetsList * (sby1 - sbsize - y + math.min(scrollbargrabpos, sbsize)) / sbheight
    foo = math.floor(foo + 0.5)
    startEntry = 1 + math.max(0, math.min(#fullWidgetsList - maxEntries, foo))
    UpdateListScroll()
  end
  return false
end


function widget:MouseRelease(x, y, button)
  if (Spring.IsGUIHidden()) then
    return -1
  end

  --// Scrollbar
  if button == 1 and activescrollbar then
    activescrollbar = false
    scrollbargrabpos = 0.0
    return -1
  end

  --// Special buttons at bottom
  if button == 1 then
    local btnWidth = (maxx - minx) * 0.3

    --// enable all
    if minx < x and x < minx + btnWidth and miny - 20 < y and y < miny then
      for _,namedata in ipairs(fullWidgetsList) do
        widgetHandler:EnableWidget(namedata[1])
      end
      return -1
    end

    --// reload widgetlist
    if minx + btnWidth < x and x < maxx - btnWidth and miny - 20 < y and y < miny then
      widgetHandler:SearchForNew()
      UpdateList()
      return -1
    end

    --// disable all
    if maxx - btnWidth < x and x < maxx and miny - 20 < y and y < miny then
      for _,namedata in ipairs(fullWidgetsList) do
        widgetHandler:DisableWidget(namedata[1])
      end
      return -1
    end
  end

  --// Widget List
  if (button == 1) then
    local namedata = self:AboveLabel(x, y)
    if (namedata) then
      local name = namedata[1]
      local data = namedata[2]
      widgetHandler:ToggleWidget(name)
      return -1
    end
  end

  return false
end


function widget:AboveLabel(x, y)
  if ((x < minx) or (y < (miny + bordery)) or
      (x > maxx) or (y > (maxy - bordery))) then
    return nil
  end
  local count = #widgetsList
  if (count < 1) then return nil end

  local i = floor(1 + ((maxy - bordery) - y) / yStep)
  if     (i < 1)     then i = 1
  elseif (i > count) then i = count end

  return widgetsList[i]
end


function widget:IsAbove(x, y)
  UpdateList()
  if ((x < minx) or (x > maxx + yStep) or
      (y < miny - 20) or (y > maxy)) then
    return false
  end
  return true
end


function widget:GetTooltip(x, y)
  UpdateList()
  local namedata = self:AboveLabel(x, y)
  if (not namedata) then
    return '\255\200\255\200'..'Widget Selector\n'  ..
           '\255\255\255\200'..'LMB: toggle widget'
  end

  local n = namedata[1]
  local d = namedata[2]

  local order = widgetHandler.orderList[n]
  local enabled = order and (order > 0)

  local tt = (d.active and GreenStr) or (enabled  and YellowStr) or RedStr
  tt = tt .. d.name ..  " (v" .. d.version .. ")" .. "\n"
  tt = d.desc   and tt..WhiteStr..d.desc..'\n' or tt
  tt = d.author and tt..BlueStr..'Author:  '..CyanStr..d.author..'\n' or tt
  tt = tt..MagentaStr..d.basename
  if (d.fromZip) then
    tt = tt..RedStr..' (mod widget)'
  end

  return tt
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
