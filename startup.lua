-- gradient.lua
-- Animated #001419 <-> #00D4FF gradient
-- Runs on every connected CC:Tweaked monitor.

--------------------------------------------------
-- CONFIGURATION
--------------------------------------------------

local TEXT_SCALE = 0.5

-- Animation delay in seconds.
local FRAME_DELAY = 0.10

-- Higher = faster movement.
local PHASE_STEP = 0.045

-- 1 moves one direction, -1 reverses it.
local DIRECTION = 1

-- Adds diagonal movement between rows.
-- Set to 0 for a purely horizontal gradient.
local DIAGONAL_SHIFT = 0.35

--------------------------------------------------
-- GRADIENT COLOURS
--------------------------------------------------

local START_COLOR = {
    r = 0x00 / 255,
    g = 0x14 / 255,
    b = 0x19 / 255
}

local END_COLOR = {
    r = 0x00 / 255,
    g = 0xD4 / 255,
    b = 0xFF / 255
}

local BLIT_CHARACTERS = "0123456789abcdef"

--------------------------------------------------
-- INTERNAL STATE
--------------------------------------------------

local monitors = {}
local configured = {}
local originalSettings = {}

--------------------------------------------------
-- COLOUR FUNCTIONS
--------------------------------------------------

local function lerp(a, b, amount)
    return a + (b - a) * amount
end

local function smoothstep(amount)
    return amount * amount * (3 - 2 * amount)
end

local function createPalette(monitor)
    for index = 0, 15 do
        local amount = smoothstep(index / 15)

        local red = lerp(
            START_COLOR.r,
            END_COLOR.r,
            amount
        )

        local green = lerp(
            START_COLOR.g,
            END_COLOR.g,
            amount
        )

        local blue = lerp(
            START_COLOR.b,
            END_COLOR.b,
            amount
        )

        monitor.setPaletteColor(
            2 ^ index,
            red,
            green,
            blue
        )
    end
end

--------------------------------------------------
-- MONITOR MANAGEMENT
--------------------------------------------------

local function saveOriginalSettings(name, monitor)
    if originalSettings[name] then
        return
    end

    local saved = {
        palette = {}
    }

    local scaleSuccess, scale = pcall(monitor.getTextScale)

    if scaleSuccess then
        saved.scale = scale
    else
        saved.scale = TEXT_SCALE
    end

    for index = 0, 15 do
        local success, red, green, blue =
            pcall(monitor.getPaletteColor, 2 ^ index)

        if not success then
            red, green, blue =
                term.nativePaletteColor(2 ^ index)
        end

        saved.palette[index] = {
            red,
            green,
            blue
        }
    end

    originalSettings[name] = saved
end

local function configureMonitor(name, monitor)
    saveOriginalSettings(name, monitor)

    pcall(monitor.setTextScale, TEXT_SCALE)
    pcall(monitor.setCursorBlink, false)

    createPalette(monitor)
end

local function scanMonitors()
    local discovered = {
        peripheral.find("monitor")
    }

    local newMonitorList = {}
    local currentlyPresent = {}

    for _, monitor in ipairs(discovered) do
        local name = peripheral.getName(monitor)

        currentlyPresent[name] = true

        if not configured[name] then
            local success = pcall(
                configureMonitor,
                name,
                monitor
            )

            if success then
                configured[name] = true
            end
        end

        newMonitorList[#newMonitorList + 1] = {
            name = name,
            device = monitor
        }
    end

    -- Allow a detached and reattached monitor to be configured again.
    for name in pairs(configured) do
        if not currentlyPresent[name] then
            configured[name] = nil
        end
    end

    monitors = newMonitorList
end

--------------------------------------------------
-- RENDERING
--------------------------------------------------

local function drawMonitor(monitor, phase)
    local width, height = monitor.getSize()

    local blankText = string.rep(" ", width)
    local textColours = string.rep("0", width)

    for y = 1, height do
        local background = {}

        local verticalPosition = 0

        if height > 1 then
            verticalPosition =
                ((y - 1) / (height - 1)) *
                DIAGONAL_SHIFT
        end

        for x = 1, width do
            local horizontalPosition = 0

            if width > 1 then
                -- Two phase units make one complete:
                -- dark -> cyan -> dark wave.
                horizontalPosition =
                    ((x - 1) / (width - 1)) * 2
            end

            local position =
                horizontalPosition +
                verticalPosition +
                phase

            -- Seamless triangular wave:
            -- 0 -> 1 -> 0
            local brightness =
                1 - math.abs((position % 2) - 1)

            local paletteIndex =
                math.floor(brightness * 15 + 0.5)

            if paletteIndex < 0 then
                paletteIndex = 0
            elseif paletteIndex > 15 then
                paletteIndex = 15
            end

            background[x] =
                BLIT_CHARACTERS:sub(
                    paletteIndex + 1,
                    paletteIndex + 1
                )
        end

        monitor.setCursorPos(1, y)

        monitor.blit(
            blankText,
            textColours,
            table.concat(background)
        )
    end
end

--------------------------------------------------
-- CLEANUP
--------------------------------------------------

local function restoreMonitors()
    for name, saved in pairs(originalSettings) do
        local monitor = peripheral.wrap(name)

        if monitor and peripheral.hasType(name, "monitor") then
            for index = 0, 15 do
                local rgb = saved.palette[index]

                pcall(
                    monitor.setPaletteColor,
                    2 ^ index,
                    rgb[1],
                    rgb[2],
                    rgb[3]
                )
            end

            pcall(monitor.setTextScale, saved.scale)
            pcall(monitor.setCursorBlink, false)
            pcall(monitor.setBackgroundColor, colors.black)
            pcall(monitor.clear)
        end
    end
end

--------------------------------------------------
-- MAIN LOOP
--------------------------------------------------

local function run()
    scanMonitors()

    term.clear()
    term.setCursorPos(1, 1)

    print("Animated gradient running.")
    print("Connected monitors: " .. #monitors)
    print("Hold Ctrl+T to stop.")

    local phase = 0
    local framesUntilScan = 0

    while true do
        -- Rescan approximately every two seconds.
        if framesUntilScan <= 0 then
            scanMonitors()
            framesUntilScan = 20
        end

        for _, entry in ipairs(monitors) do
            -- Prevent one disconnected monitor from
            -- crashing the entire animation.
            pcall(
                drawMonitor,
                entry.device,
                phase
            )
        end

        phase =
            (phase + PHASE_STEP * DIRECTION) % 2

        framesUntilScan = framesUntilScan - 1

        sleep(FRAME_DELAY)
    end
end

local success, errorMessage = pcall(run)

restoreMonitors()

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)

if not success then
    local message = tostring(errorMessage)

    if not message:find("Terminated", 1, true) then
        printError(message)
    end
end
