-- gradient.lua
-- Random animated cyan gradient engine for CC:Tweaked
--
-- Colour range:
--   #001419 -> #00D4FF
--
-- Features:
--   * 12 animations
--   * Random animation selection
--   * Smooth crossfades
--   * All monitors synchronized
--   * Automatically detects newly attached monitors
--   * Restores monitor palettes when stopped

--------------------------------------------------
-- CONFIGURATION
--------------------------------------------------

local TEXT_SCALE = 0.5

-- Lower values are smoother but use more computer time.
local FRAME_DELAY = 0.10

-- How long each animation remains active.
local MIN_ANIMATION_TIME = 6
local MAX_ANIMATION_TIME = 11

-- Crossfade duration between animations.
local TRANSITION_TIME = 1.5

-- How often to search for attached monitors.
local RESCAN_INTERVAL = 2

--------------------------------------------------
-- COLOURS
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

-- CC:Tweaked blit colour characters.
local BLIT_CHARACTERS = "0123456789abcdef"

--------------------------------------------------
-- INTERNAL STATE
--------------------------------------------------

local monitors = {}
local configured = {}
local originalSettings = {}

--------------------------------------------------
-- GENERAL FUNCTIONS
--------------------------------------------------

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    elseif value > maximum then
        return maximum
    end

    return value
end

local function lerp(a, b, amount)
    return a + (b - a) * amount
end

local function smoothstep(value)
    value = clamp(value, 0, 1)
    return value * value * (3 - 2 * value)
end

local function fract(value)
    return value - math.floor(value)
end

local function wave(value)
    return 0.5 + 0.5 * math.sin(value * math.pi * 2)
end

local function triangle(value)
    return 1 - math.abs(fract(value) * 2 - 1)
end

local function hash(x, y, seed)
    local value = math.sin(
        x * 12.9898 +
        y * 78.233 +
        seed * 37.719
    ) * 43758.5453

    return fract(value)
end

--------------------------------------------------
-- ANIMATIONS
--------------------------------------------------

local animations = {}

--------------------------------------------------
-- 1. HORIZONTAL OCEAN
--------------------------------------------------

animations[#animations + 1] = {
    name = "Horizontal Ocean",

    draw = function(nx, ny, time)
        return wave(
            nx * 2.2 -
            time * 0.38
        )
    end
}

--------------------------------------------------
-- 2. VERTICAL FLOW
--------------------------------------------------

animations[#animations + 1] = {
    name = "Vertical Flow",

    draw = function(nx, ny, time)
        return wave(
            ny * 2.5 -
            time * 0.42
        )
    end
}

--------------------------------------------------
-- 3. DIAGONAL SWEEP
--------------------------------------------------

animations[#animations + 1] = {
    name = "Diagonal Sweep",

    draw = function(nx, ny, time)
        return wave(
            nx * 1.8 +
            ny * 1.8 -
            time * 0.45
        )
    end
}

--------------------------------------------------
-- 4. REVERSE DIAGONAL
--------------------------------------------------

animations[#animations + 1] = {
    name = "Reverse Diagonal",

    draw = function(nx, ny, time)
        return wave(
            nx * 1.8 -
            ny * 1.8 +
            time * 0.45
        )
    end
}

--------------------------------------------------
-- 5. PLASMA
--------------------------------------------------

animations[#animations + 1] = {
    name = "Cyan Plasma",

    draw = function(nx, ny, time)
        local first = math.sin(
            (nx * 3.2 + time * 0.35) *
            math.pi * 2
        )

        local second = math.sin(
            (ny * 3.0 - time * 0.29) *
            math.pi * 2
        )

        local third = math.sin(
            ((nx + ny) * 2.1 + time * 0.22) *
            math.pi * 2
        )

        return clamp(
            0.5 + (first + second + third) / 6,
            0,
            1
        )
    end
}

--------------------------------------------------
-- 6. PULSE RINGS
--------------------------------------------------

animations[#animations + 1] = {
    name = "Pulse Rings",

    draw = function(nx, ny, time, x, y, width, height)
        local aspect = width / math.max(height, 1)

        local dx = (nx - 0.5) * aspect
        local dy = ny - 0.5

        local distance = math.sqrt(
            dx * dx + dy * dy
        )

        return wave(
            distance * 4.5 -
            time * 0.55
        )
    end
}

--------------------------------------------------
-- 7. DIAMOND RIPPLE
--------------------------------------------------

animations[#animations + 1] = {
    name = "Diamond Ripple",

    draw = function(nx, ny, time, x, y, width, height)
        local aspect = width / math.max(height, 1)

        local dx = math.abs(
            (nx - 0.5) * aspect
        )

        local dy = math.abs(ny - 0.5)

        local distance = dx + dy

        return wave(
            distance * 4 -
            time * 0.58
        )
    end
}

--------------------------------------------------
-- 8. CYAN SCANNER
--------------------------------------------------

animations[#animations + 1] = {
    name = "Cyan Scanner",

    draw = function(nx, ny, time)
        local scannerPosition =
            triangle(time * 0.16)

        local distance =
            math.abs(nx - scannerPosition)

        local beam =
            math.exp(-distance * 16)

        local trail =
            math.exp(-math.abs(
                nx - scannerPosition + 0.12
            ) * 8) * 0.35

        local background =
            wave(ny * 1.5 + time * 0.1) * 0.12

        return clamp(
            0.04 + beam + trail + background,
            0,
            1
        )
    end
}

--------------------------------------------------
-- 9. BOUNCING GLOW
--------------------------------------------------

animations[#animations + 1] = {
    name = "Bouncing Glow",

    draw = function(nx, ny, time, x, y, width, height)
        local aspect = width / math.max(height, 1)

        local centreX =
            0.5 +
            math.sin(time * 0.83) * 0.37

        local centreY =
            0.5 +
            math.sin(time * 1.17) * 0.34

        local dx =
            (nx - centreX) * aspect

        local dy =
            ny - centreY

        local distance = math.sqrt(
            dx * dx + dy * dy
        )

        local glow =
            math.exp(-distance * 6.5)

        local ring =
            wave(distance * 3 - time * 0.4) *
            0.18

        return clamp(
            0.03 + glow + ring,
            0,
            1
        )
    end
}

--------------------------------------------------
-- 10. CROSS WAVES
--------------------------------------------------

animations[#animations + 1] = {
    name = "Cross Waves",

    draw = function(nx, ny, time)
        local horizontal = wave(
            nx * 3.2 -
            time * 0.35
        )

        local vertical = wave(
            ny * 3.2 +
            time * 0.31
        )

        local diagonal = wave(
            (nx + ny) * 2.2 -
            time * 0.23
        )

        return clamp(
            horizontal * 0.4 +
            vertical * 0.4 +
            diagonal * 0.2,
            0,
            1
        )
    end
}

--------------------------------------------------
-- 11. DIGITAL RAIN
--------------------------------------------------

animations[#animations + 1] = {
    name = "Digital Rain",

    draw = function(nx, ny, time, x, y, width, height)
        local columnSeed =
            hash(x, 1, 7)

        local columnSpeed =
            0.45 + hash(x, 2, 11) * 0.75

        local head =
            fract(
                time * columnSpeed * 0.18 +
                columnSeed
            ) * 1.4 - 0.2

        local distanceBehind =
            head - ny

        local brightness = 0.025

        if distanceBehind >= 0 and
           distanceBehind < 0.48 then

            brightness =
                math.exp(-distanceBehind * 7)
        end

        local frame =
            math.floor(time * 8)

        local sparkle =
            hash(x, y, frame)

        if sparkle > 0.965 then
            brightness =
                math.max(brightness, 0.7)
        end

        return clamp(brightness, 0, 1)
    end
}

--------------------------------------------------
-- 12. AURORA
--------------------------------------------------

animations[#animations + 1] = {
    name = "Cyan Aurora",

    draw = function(nx, ny, time)
        local ribbonCentre =
            0.5 +
            math.sin(
                nx * math.pi * 3 +
                time * 0.8
            ) * 0.18 +
            math.sin(
                nx * math.pi * 7 -
                time * 0.42
            ) * 0.07

        local distance =
            math.abs(ny - ribbonCentre)

        local ribbon =
            math.exp(-distance * 10)

        local secondRibbonCentre =
            0.48 +
            math.sin(
                nx * math.pi * 4 -
                time * 0.55
            ) * 0.27

        local secondDistance =
            math.abs(ny - secondRibbonCentre)

        local secondRibbon =
            math.exp(-secondDistance * 14) *
            0.5

        local background =
            wave(nx * 1.3 + time * 0.08) *
            0.08

        return clamp(
            ribbon +
            secondRibbon +
            background,
            0,
            1
        )
    end
}

--------------------------------------------------
-- PALETTE
--------------------------------------------------

local function createPalette(monitor)
    for index = 0, 15 do
        local amount =
            smoothstep(index / 15)

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

        pcall(
            monitor.setPaletteColor,
            2 ^ index,
            red,
            green,
            blue
        )
    end
end

--------------------------------------------------
-- SAVE MONITOR SETTINGS
--------------------------------------------------

local function saveMonitorSettings(name, monitor)
    if originalSettings[name] then
        return
    end

    local saved = {
        palette = {}
    }

    local scaleSuccess, scale =
        pcall(monitor.getTextScale)

    if scaleSuccess then
        saved.scale = scale
    else
        saved.scale = TEXT_SCALE
    end

    for index = 0, 15 do
        local success, red, green, blue =
            pcall(
                monitor.getPaletteColor,
                2 ^ index
            )

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

--------------------------------------------------
-- CONFIGURE MONITOR
--------------------------------------------------

local function configureMonitor(name, monitor)
    saveMonitorSettings(name, monitor)

    pcall(monitor.setTextScale, TEXT_SCALE)
    pcall(monitor.setCursorBlink, false)

    createPalette(monitor)

    pcall(monitor.setBackgroundColor, colors.black)
    pcall(monitor.clear)
end

--------------------------------------------------
-- FIND ALL MONITORS
--------------------------------------------------

local function scanMonitors()
    local discovered = {}
    local present = {}

    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "monitor") then
            local monitor = peripheral.wrap(name)

            if monitor then
                present[name] = true

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

                discovered[#discovered + 1] = {
                    name = name,
                    device = monitor
                }
            end
        end
    end

    for name in pairs(configured) do
        if not present[name] then
            configured[name] = nil
        end
    end

    monitors = discovered
end

--------------------------------------------------
-- RENDER ANIMATION
--------------------------------------------------

local function drawMonitor(
    monitor,
    previousAnimation,
    currentAnimation,
    transitionAmount,
    time
)
    local width, height = monitor.getSize()

    local blankText = string.rep(" ", width)
    local textColours = string.rep("0", width)

    for y = 1, height do
        local background = {}

        local ny

        if height > 1 then
            ny = (y - 1) / (height - 1)
        else
            ny = 0.5
        end

        for x = 1, width do
            local nx

            if width > 1 then
                nx = (x - 1) / (width - 1)
            else
                nx = 0.5
            end

            local currentValue =
                currentAnimation.draw(
                    nx,
                    ny,
                    time,
                    x,
                    y,
                    width,
                    height
                )

            local finalValue = currentValue

            if previousAnimation then
                local previousValue =
                    previousAnimation.draw(
                        nx,
                        ny,
                        time,
                        x,
                        y,
                        width,
                        height
                    )

                finalValue = lerp(
                    previousValue,
                    currentValue,
                    transitionAmount
                )
            end

            finalValue = clamp(finalValue, 0, 1)

            local paletteIndex =
                math.floor(finalValue * 15 + 0.5)

            paletteIndex =
                clamp(paletteIndex, 0, 15)

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
-- RANDOM ANIMATION
--------------------------------------------------

local function chooseRandomAnimation(currentIndex)
    if #animations <= 1 then
        return 1
    end

    local selected

    repeat
        selected = math.random(1, #animations)
    until selected ~= currentIndex

    return selected
end

local function chooseDuration()
    return math.random(
        MIN_ANIMATION_TIME * 10,
        MAX_ANIMATION_TIME * 10
    ) / 10
end

--------------------------------------------------
-- COMPUTER STATUS DISPLAY
--------------------------------------------------

local function displayStatus(animationName)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)

    print("CYAN GRADIENT ENGINE")
    print("--------------------")
    print("Animation:")
    print(animationName)
    print("")
    print("Monitors: " .. #monitors)
    print("Effects:  " .. #animations)
    print("")
    print("Hold Ctrl+T to stop")
end

--------------------------------------------------
-- RESTORE MONITORS
--------------------------------------------------

local function restoreMonitors()
    for name, saved in pairs(originalSettings) do
        if peripheral.hasType(name, "monitor") then
            local monitor = peripheral.wrap(name)

            if monitor then
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

                pcall(
                    monitor.setTextScale,
                    saved.scale
                )

                pcall(
                    monitor.setCursorBlink,
                    false
                )

                pcall(
                    monitor.setBackgroundColor,
                    colors.black
                )

                pcall(monitor.clear)
            end
        end
    end
end

--------------------------------------------------
-- MAIN LOOP
--------------------------------------------------

local function run()
    local seed

    if os.epoch then
        seed =
            os.epoch("utc") +
            os.getComputerID()
    else
        seed =
            math.floor(os.clock() * 100000) +
            os.getComputerID()
    end

    math.randomseed(seed)

    scanMonitors()

    local currentIndex =
        math.random(1, #animations)

    local previousIndex = nil

    local animationStarted =
        os.clock()

    local transitionStarted = nil

    local animationDuration =
        chooseDuration()

    local nextMonitorScan = 0

    displayStatus(
        animations[currentIndex].name
    )

    while true do
        local currentTime = os.clock()

        --------------------------------------------------
        -- RESCAN MONITORS
        --------------------------------------------------

        if currentTime >= nextMonitorScan then
            local previousMonitorCount = #monitors

            scanMonitors()

            nextMonitorScan =
                currentTime + RESCAN_INTERVAL

            if #monitors ~= previousMonitorCount then
                displayStatus(
                    animations[currentIndex].name
                )
            end
        end

        --------------------------------------------------
        -- CHANGE ANIMATION
        --------------------------------------------------

        if currentTime - animationStarted >=
           animationDuration then

            previousIndex = currentIndex

            currentIndex =
                chooseRandomAnimation(currentIndex)

            animationStarted = currentTime
            transitionStarted = currentTime

            animationDuration =
                chooseDuration()

            displayStatus(
                animations[currentIndex].name
            )
        end

        --------------------------------------------------
        -- CALCULATE TRANSITION
        --------------------------------------------------

        local previousAnimation = nil
        local transitionAmount = 1

        if previousIndex and transitionStarted then
            local transitionElapsed =
                currentTime - transitionStarted

            if transitionElapsed <
               TRANSITION_TIME then

                transitionAmount =
                    smoothstep(
                        transitionElapsed /
                        TRANSITION_TIME
                    )

                previousAnimation =
                    animations[previousIndex]
            else
                previousIndex = nil
                transitionStarted = nil
            end
        end

        --------------------------------------------------
        -- DRAW ON EVERY MONITOR
        --------------------------------------------------

        for _, entry in ipairs(monitors) do
            pcall(
                drawMonitor,
                entry.device,
                previousAnimation,
                animations[currentIndex],
                transitionAmount,
                currentTime
            )
        end

        sleep(FRAME_DELAY)
    end
end

--------------------------------------------------
-- START AND CLEAN UP
--------------------------------------------------

local success, errorMessage = pcall(run)

restoreMonitors()

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)

if not success then
    local message = tostring(errorMessage)

    if not message:find(
        "Terminated",
        1,
        true
    ) then
        printError(message)
    else
        print("Gradient engine stopped.")
    end
end
