-- Tetris game implementation


-- Grid and block size configuration
local gridWidth, gridHeight = 10, 20 -- Width and height of the game grid
local blockSize = 35 -- Size of each block in pixels

-- Detect if the game is running on a touch device
local isTouchDevice = love.system.getOS() == "Android" or love.system.getOS() == "iOS"

-- Define interface width for PC
local interfaceWidth = 250

-- Define interface width for touch device
if isTouchDevice then
  local screenWidth, screenHeight = love.graphics.getDimensions()
  interfaceWidth = screenWidth * 0.3
  local availableWidth = screenWidth - interfaceWidth
  blockSize = math.min(availableWidth / gridWidth, screenHeight / gridHeight)
end

-- Board initialization
local board = {}
for y = 1, gridHeight do
  board[y] = {}
  for x = 1, gridWidth do
    board[y][x] = { shape = 0, color = 0 } -- Initialize each cell with no shape and color
  end
end

-- Tetromino definitions
-- Each shape is represented as a matrix of 0s and 1s
local shapes = {
  { {0, 0, 0, 0}, {1, 1, 1, 1}, {0, 0, 0, 0}, {0, 0, 0, 0}, color = 1 },  -- I
  { {0, 0}, {1, 1}, {1, 1}, color = 2 },  -- O
  { {0, 0, 0}, {1, 1, 1}, {0, 1, 0}, color = 3 }, -- T
  { {0, 0, 0}, {1, 1, 0}, {0, 1, 1}, color = 4 }, -- Z
  { {0, 0, 0}, {0, 1, 1}, {1, 1, 0}, color = 5 }, -- S
  { {0, 0, 0}, {1, 1, 1}, {1, 0, 0}, color = 6 }, -- L
  { {0, 0, 0}, {1, 1, 1}, {0, 0, 1}, color = 7 } -- J
}

-- Color definitions for each Tetromino
-- Colors are defined in RGB format
local colors = {
  {0, 1, 1},   -- Cyan (I)
  {1, 1, 0},   -- Yellow (O)
  {0.5, 0, 1}, -- Purple (T)
  {1, 0, 0},   -- Red (Z)
  {0, 1, 0},   -- Green (S)
  {1, 0.5, 0},  -- Orange (L)
  {0, 0, 1}   -- Blue (J)
}

-- State variables for game mechanics
local currentShape, shapeX, shapeY, shapeColor, rotationState
local nextShape
local nextShapes = {}
local fallTimer = 0
local clearAnimation = false
local clearAnimationTime = 0
local clearLines = {}
local level = 1
local score = 0
local gameOver = false

-- File path for saving game state
local saveFilePath = "tetris_save.txt"

-- Variables for music
local backgroundMusic
local clearSound
local loseSound
local moveSound
local placeSound
local rotateSound

-- Button definitions for touch controls
local buttons = {
  reset = {x = 0, y = 0, width = 100, height = 25, label = "Reset"},
  save = {x = 0, y = 0, width = 100, height = 25, label = "Save"},
  load = {x = 0, y = 0, width = 100, height = 25, label = "Load"}
}


-- Helper functions

-- Generates a random sequence of all tetromino shapes (I, O, T, Z, S, L, J)
local function refillBag()
  nextShapes = {}
  local bag = {1, 2, 3, 4, 5, 6, 7} -- All tetrominoes
  while #bag > 0 do
    local index = math.random(1, #bag)
    table.insert(nextShapes, shapes[bag[index]])
    table.remove(bag, index)
  end
end

-- Assigns the current shape from the next shape and generates a new next shape
function newShape()
  local shape

  if nextShape then
    shape = nextShape
  else
    if #nextShapes == 0 then
      refillBag()
    end
    shape = table.remove(nextShapes, 1)
  end

  if #nextShapes == 0 then
    refillBag()
  end
  nextShape = table.remove(nextShapes, 1)

  return shape, math.floor(gridWidth / 2) - math.floor(#shape[1] / 2) + 1, 0, shape.color, 1
end

-- Returns the fall speed based on the current level of the game
function calculateFallSpeed(level)
  local speeds = {
    [1] = 48, [2] = 43, [3] = 38, [4] = 33, [5] = 28,
    [6] = 23, [7] = 18, [8] = 13, [9] = 8, [10] = 6,
    [11] = 5, [12] = 5, [13] = 5, [14] = 4, [15] = 4,
    [16] = 4, [17] = 3, [18] = 3, [19] = 3, [20] = 2,
    [21] = 2, [22] = 2, [23] = 2, [24] = 2, [25] = 2,
    [26] = 2, [27] = 2, [28] = 2, [29] = 2, [30] = 1
  }

  -- Levels 30 and above have a speed value of 1
  level = math.min(level, 30)

  -- Calculate delay based on level (assuming 60fps)
  return speeds[level] / 60 or 1 / 60
end

-- Checks if the current shape collides with the walls or any other placed blocks
function checkCollision(shape, xOffset, yOffset)
  for y, row in ipairs(shape) do
    for x, cell in ipairs(row) do
      if cell == 1 then
        local boardX = shapeX + xOffset + x - 1
        local boardY = shapeY + yOffset + y - 1
        if boardX < 1 or boardX > gridWidth or boardY > gridHeight or (boardY > 0 and board[boardY][boardX].shape > 0) then
          return true
        end
      end
    end
  end
  return false
end

-- Places the current shape onto the game board
function placeShape()
  for y, row in ipairs(currentShape) do
    for x, cell in ipairs(row) do
      if cell == 1 then
        local boardX = shapeX + x - 1
        local boardY = shapeY + y - 1
        if boardY >= 1 then
          board[boardY][boardX] = { shape = 1, color = shapeColor }
        end
      end
    end
  end
  love.audio.stop(placeSound)
  love.audio.play(placeSound)
end

-- Starts the line-clearing animation by setting the necessary state variables
function startClearAnimation(lines)
  clearAnimation = true
  clearAnimationTime = 0
  clearLines = lines
end

-- Checks for and removes any complete lines on the game board, updating the score and level
function removeCompleteLines()
  local linesToClear = {}

  for y = 1, gridHeight do
    local full = true
    for x = 1, gridWidth do
      if board[y][x].shape == 0 then
        full = false
        break
      end
    end
    if full then
      table.insert(linesToClear, y)
    end
  end

  if #linesToClear > 0 then
    startClearAnimation(linesToClear)
  end
end

-- Resets the game to its initial state
function resetGame()
  board = {}
  for y = 1, gridHeight do
    board[y] = {}
    for x = 1, gridWidth do
      board[y][x] = {shape = 0, color = 0}
    end
  end

  score = 0
  level = 1
  fallTimer = 0
  gameOver = false

  refillBag()
  nextShape = table.remove(nextShapes, 1)
  currentShape, shapeX, shapeY, shapeColor, rotationState = newShape()

  -- Restart background music
  love.audio.stop(backgroundMusic)
  love.audio.play(backgroundMusic)
end

-- Rotates the given shape clockwise
function rotateShapeClockwise(shape)
  local newShape = {}
  for x = 1, #shape[1] do
    newShape[x] = {}
    for y = 1, #shape do
      newShape[x][y] = shape[#shape - y + 1][x]
    end
  end
  return newShape
end

-- Rotates the given shape counter-clockwise
function rotateShapeCounterClockwise(shape)
  local newShape = {}
  for x = 1, #shape[1] do
    newShape[x] = {}
    for y = 1, #shape do
      newShape[x][y] = shape[y][#shape[1] - x + 1]
    end
  end
  return newShape
end

-- Rotates the current shape
function rotateShape()
  if shapeColor == 2 then return end -- No rotation for O

  local newShape
  if shapeColor == 3 or shapeColor == 6 or shapeColor == 7 then -- T, L, or J
    newShape = rotateShapeClockwise(currentShape)
  else
    if rotationState == 1 then
      newShape = rotateShapeClockwise(currentShape)
      rotationState = 2
    else
      newShape = rotateShapeCounterClockwise(currentShape)
      rotationState = 1
    end
  end

  if not checkCollision(newShape, 0, 0) then
    currentShape = newShape
    love.audio.stop(rotateSound)
    love.audio.play(rotateSound)
  end
end

-- Utility function to check if a table contains a value
function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

-- Draws the current state of the game board
local function drawBoard()
  for y = 1, gridHeight do
    for x = 1, gridWidth do
      local block = board[y][x]
      if block.shape > 0 then
        local color = colors[block.color]
        
        if clearAnimation and table.contains(clearLines, y) then
          local alpha = 1 - (clearAnimationTime / 0.5)
          love.graphics.setColor(color[1], color[2], color[3], alpha)
        else
          love.graphics.setColor(color[1], color[2], color[3], 1)
        end

        -- Draw the main block
        love.graphics.rectangle("fill", (x - 1) * blockSize, (y - 1) * blockSize, blockSize, blockSize)
        
        -- Draw the border
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", (x - 1) * blockSize, (y - 1) * blockSize, blockSize, blockSize)
      end
    end
  end
end

-- Draws the current falling shape
local function drawShape()
  for y, row in ipairs(currentShape) do
    for x, cell in ipairs(row) do
      if cell == 1 then
        local color = colors[shapeColor]
        
        -- Draw the main block
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.rectangle("fill", (shapeX + x - 2) * blockSize, (shapeY + y - 2) * blockSize, blockSize, blockSize)
        
        -- Draw the border
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", (shapeX + x - 2) * blockSize, (shapeY + y - 2) * blockSize, blockSize, blockSize)
      end
    end
  end
end

-- Draws the next shape preview on the interface
local function drawNextShape(startX, interfaceY)
  for y, row in ipairs(nextShape) do
    for x, cell in ipairs(row) do
      if cell == 1 then
        local color = colors[nextShape.color]
        
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.rectangle("fill", startX + (x - 1) * blockSize, interfaceY + (y - 1) * blockSize, blockSize, blockSize)
        
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", startX + (x - 1) * blockSize, interfaceY + (y - 1) * blockSize, blockSize, blockSize)
      end
    end
  end
end

-- Draws the interface including level, score, next piece preview, controls, and game over message
function drawInterface()
  local screenWidth, screenHeight = love.graphics.getDimensions()
  local interfaceX = gridWidth * blockSize
  local interfaceHeight = gridHeight * blockSize
  local rectangleHeight = (screenHeight - interfaceHeight) / 2

  love.graphics.setColor(0.5, 0.5, 0.5, 1)
  love.graphics.rectangle("fill", interfaceX, rectangleHeight, interfaceWidth, interfaceHeight)
  love.graphics.setColor(1, 1, 1, 1)

  local function getTextWidth(text)
    return love.graphics.getFont():getWidth(text)
  end

  local centerX = interfaceX + (interfaceWidth / 2)
  local interfaceY = rectangleHeight

  if isTouchDevice then
    love.graphics.setFont(love.graphics.newFont(20))
  else
    love.graphics.setFont(love.graphics.newFont(30))
  end

  -- Display level
  local levelText = "Level: " .. level
  local levelTextWidth = getTextWidth(levelText)
  love.graphics.print(levelText, centerX - (levelTextWidth / 2), interfaceY)
  if isTouchDevice then
    interfaceY = interfaceY + 25
  else
    interfaceY = interfaceY + 50
  end

  if isTouchDevice then
    love.graphics.setFont(love.graphics.newFont(14))
  else
    love.graphics.setFont(love.graphics.newFont(20))
  end

  -- Display score
  local scoreText = "Score: " .. score
  local scoreTextWidth = getTextWidth(scoreText)
  love.graphics.print(scoreText, centerX - (scoreTextWidth / 2), interfaceY)
  if isTouchDevice then
    interfaceY = interfaceY + 35
  else
    interfaceY = interfaceY + 70
  end

  if isTouchDevice then
    love.graphics.setFont(love.graphics.newFont(18))
  else
    love.graphics.setFont(love.graphics.newFont(30))
  end

  -- Display next piece
  love.graphics.print("Next Piece:", centerX - (getTextWidth("Next Piece:") / 2), interfaceY)
  if isTouchDevice then
    interfaceY = interfaceY + 20
  else
    interfaceY = interfaceY + 30
  end
  local nextPieceWidth = #nextShape[1] * blockSize
  local startX = centerX - (nextPieceWidth / 2)
  drawNextShape(startX, interfaceY)

  if isTouchDevice then
    interfaceY = interfaceY + 120
  else
    interfaceY = interfaceY + 175
  end

  -- Display controls
  love.graphics.print("Controls:", centerX - (getTextWidth("Controls:") / 2), interfaceY)
  if isTouchDevice then
    interfaceY = interfaceY + 25
  else
    interfaceY = interfaceY + 50
  end
  if isTouchDevice then
    love.graphics.setFont(love.graphics.newFont(10))
  else
    love.graphics.setFont(love.graphics.newFont(20))
  end

  if isTouchDevice then
    love.graphics.print("Touch Left Side:", centerX - (getTextWidth("Touch Left Side:") / 2), interfaceY)
    interfaceY = interfaceY + 10
    love.graphics.print("Move Left", centerX - (getTextWidth("Move Left") / 2), interfaceY)
    interfaceY = interfaceY + 20
    love.graphics.print("Touch Right Side:", centerX - (getTextWidth("Touch Right Side:") / 2), interfaceY)
    interfaceY = interfaceY + 10
    love.graphics.print("Move Right", centerX - (getTextWidth("Move Right") / 2), interfaceY)
    interfaceY = interfaceY + 20
    love.graphics.print("Touch Top:", centerX - (getTextWidth("Touch Top:") / 2), interfaceY)
    interfaceY = interfaceY + 10
    love.graphics.print("Rotate", centerX - (getTextWidth("Rotate") / 2), interfaceY)
    interfaceY = interfaceY + 20
    love.graphics.print("Touch Bottom:", centerX - (getTextWidth("Touch Bottom:") / 2), interfaceY)
    interfaceY = interfaceY + 10
    love.graphics.print("Accelerate", centerX - (getTextWidth("Accelerate") / 2), interfaceY)
  else
    love.graphics.print("Left/Right Arrows: Move", centerX - (getTextWidth("Left/Right Arrows: Move") / 2), interfaceY)
    interfaceY = interfaceY + 30
    love.graphics.print("Up Arrow: Rotate", centerX - (getTextWidth("Up Arrow: Rotate") / 2), interfaceY)
    interfaceY = interfaceY + 30
    love.graphics.print("Down Arrow: Accelerate", centerX - (getTextWidth("Down Arrow: Accelerate") / 2), interfaceY)
    interfaceY = interfaceY + 30
    love.graphics.print("R: Reset", centerX - (getTextWidth("R: Reset") / 2), interfaceY)
    interfaceY = interfaceY + 30
    love.graphics.print("S: Save", centerX - (getTextWidth("S: Save") / 2), interfaceY)
    interfaceY = interfaceY + 30
    love.graphics.print("L: Load", centerX - (getTextWidth("L: Load") / 2), interfaceY)
    interfaceY = interfaceY + 70
  end

  -- Draw buttons for touch devices
  if isTouchDevice then
    interfaceY = interfaceY + 10
    buttons.reset.x = centerX - buttons.reset.width / 2
    buttons.reset.y = interfaceY + rectangleHeight
    interfaceY = interfaceY + buttons.reset.height + 10

    buttons.save.x = centerX - buttons.save.width / 2
    buttons.save.y = interfaceY + rectangleHeight
    interfaceY = interfaceY + buttons.save.height + 10

    buttons.load.x = centerX - buttons.load.width / 2
    buttons.load.y = interfaceY + rectangleHeight
    interfaceY = interfaceY + buttons.load.height + 10

    for _, button in pairs(buttons) do
      love.graphics.setColor(0.7, 0.7, 0.7, 1)
      love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.rectangle("line", button.x, button.y, button.width, button.height)
      love.graphics.printf(button.label, button.x, button.y + button.height / 4, button.width, "center")
    end
  end

  -- Display game over message
  if gameOver then
    love.graphics.setColor(1, 0, 0, 1)
    
    if isTouchDevice then
      local topRectangleCenterY = rectangleHeight / 2
      love.graphics.setFont(love.graphics.newFont(38))
      local gameOverText1 = "Game"
      local gameOverText2 = "Over!"
      local gameOverTextWidth1 = getTextWidth(gameOverText1)
      local gameOverTextWidth2 = getTextWidth(gameOverText2)
      love.graphics.print(gameOverText1, centerX - (gameOverTextWidth1 / 2), topRectangleCenterY - 60)
      love.graphics.print(gameOverText2, centerX - (gameOverTextWidth2 / 2), topRectangleCenterY - 20)
    else
      love.graphics.setFont(love.graphics.newFont(40))
      local gameOverText = "Game Over!"
      local gameOverTextWidth = getTextWidth(gameOverText)
      love.graphics.print(gameOverText, centerX - (gameOverTextWidth / 2), interfaceY)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.audio.stop(backgroundMusic)
    love.audio.play(loseSound)
  end
end

-- Save the game state to a file
function saveGame()
  local saveData = {
    board = board,
    currentShape = currentShape,
    shapeX = shapeX,
    shapeY = shapeY,
    shapeColor = shapeColor,
    rotationState = rotationState,
    nextShape = nextShape,
    nextShapes = nextShapes,
    fallTimer = fallTimer,
    level = level,
    score = score,
    gameOver = gameOver
  }

  local saveString = "return " .. tableToString(saveData)
  love.filesystem.write(saveFilePath, saveString)
end

-- Convert table to string
function tableToString(tbl)
  local result = "{"
  for k, v in pairs(tbl) do
    result = result .. "[" .. serialize(k) .. "]=" .. serialize(v) .. ","
  end
  result = result .. "}"
  return result
end

-- Serialize value to string
function serialize(value)
  local valueType = type(value)
  if valueType == "number" or valueType == "boolean" then
    return tostring(value)
  elseif valueType == "string" then
    return string.format("%q", value)
  elseif valueType == "table" then
    return tableToString(value)
  else
    error("Unsupported value type: " .. valueType)
  end
end

-- Load the game state from a file
function loadGame()
  if not love.filesystem.getInfo(saveFilePath) then
    return
  end

  local contents = love.filesystem.read(saveFilePath)
  local saveData = loadstring(contents)()

  board = saveData.board
  currentShape = saveData.currentShape
  shapeX = saveData.shapeX
  shapeY = saveData.shapeY
  shapeColor = saveData.shapeColor
  rotationState = saveData.rotationState
  nextShape = saveData.nextShape
  nextShapes = saveData.nextShapes
  fallTimer = saveData.fallTimer
  level = saveData.level
  score = saveData.score
  gameOver = saveData.gameOver

  love.audio.stop(backgroundMusic)
  love.audio.play(backgroundMusic)
end


-- Love2D callbacks

-- Initializes the game state when the game loads
function love.load()
  math.randomseed(os.time())
  refillBag()
  nextShape = table.remove(nextShapes, 1)
  currentShape, shapeX, shapeY, shapeColor, rotationState = newShape()

  backgroundMusic = love.audio.newSource("audio/background_music.mp3", "stream")
  backgroundMusic:setLooping(true)
  love.audio.play(backgroundMusic)

  clearSound = love.audio.newSource("audio/clear.wav", "static")
  loseSound = love.audio.newSource("audio/lose.ogg", "static")
  moveSound = love.audio.newSource("audio/move.wav", "static")
  placeSound = love.audio.newSource("audio/place.wav", "static")
  rotateSound = love.audio.newSource("audio/rotate.wav", "static")

  -- Detect if the game is running on a touch device
  isTouchDevice = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
end

function love.update(dt)
  local frameStart = love.timer.getTime()

  if clearAnimation then
    clearAnimationTime = clearAnimationTime + dt
    if clearAnimationTime >= 0.5 then
      -- Remove the lines
      local newBoard = {}
      for y = 1, gridHeight do
        if not table.contains(clearLines, y) then
          table.insert(newBoard, board[y])
        end
      end

      for i = 1, #clearLines do
        table.insert(newBoard, 1, {})
        for x = 1, gridWidth do
          newBoard[1][x] = { shape = 0, color = 0 }
        end
      end

      board = newBoard

      -- Update score and level
      score = score + #clearLines * 100
      level = math.floor(score / 1000) + 1

      love.audio.stop(clearSound)
      love.audio.play(clearSound)

      clearAnimation = false
      clearLines = {}
    end
  else
    if not gameOver then
      local currentFallSpeed = calculateFallSpeed(level)
      if love.keyboard.isDown("down") or isAccelerating then
        currentFallSpeed = currentFallSpeed / 20
      end
      
      fallTimer = fallTimer + dt

      if fallTimer >= currentFallSpeed then
        if checkCollision(currentShape, 0, 1) then
          placeShape()
          removeCompleteLines()
          currentShape, shapeX, shapeY, shapeColor, rotationState = newShape()
          if checkCollision(currentShape, 0, 0) then
            gameOver = true
          end
        else
          shapeY = shapeY + 1
        end
        fallTimer = 0
      end

      -- Adjust music playback speed based on the current level
      local playbackRate = 1 + (level - 1) * 0.1
      backgroundMusic:setPitch(playbackRate)
    end
  end

  -- Handles user inputs
  function love.keypressed(key)
    if key == "escape" then
      love.event.quit()
    elseif key == "r" then
      resetGame()
    elseif key == "s" then
      saveGame()
    elseif key == "l" then
      loadGame()
    elseif not gameOver then
      if key == "left" and not checkCollision(currentShape, -1, 0) then
        shapeX = shapeX - 1
        love.audio.stop(moveSound)
        love.audio.play(moveSound)
      elseif key == "right" and not checkCollision(currentShape, 1, 0) then
        shapeX = shapeX + 1
        love.audio.stop(moveSound)
        love.audio.play(moveSound)
      elseif key == "up" then
        rotateShape()
      end
    end
  end

  -- Handle touch inputs
  function love.touchpressed(id, x, y, dx, dy, pressure)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local topArea = screenHeight * 0.2
    local bottomArea = screenHeight * 0.8
    local interfaceHeight = gridHeight * blockSize
    local rectangleHeight = (screenHeight - interfaceHeight) / 2

    -- Check if the touch is within the grid area
    if y > rectangleHeight and y < screenHeight - rectangleHeight and x < screenWidth - interfaceWidth then
      if not gameOver then
        if y < topArea then
          rotateShape()
        elseif y > bottomArea then
          isAccelerating = true
        else
          if x < screenWidth / 2 then
            if not checkCollision(currentShape, -1, 0) then
              shapeX = shapeX - 1
              love.audio.stop(moveSound)
              love.audio.play(moveSound)
            end
          else
            if not checkCollision(currentShape, 1, 0) then
              shapeX = shapeX + 1
              love.audio.stop(moveSound)
              love.audio.play(moveSound)
            end
          end
        end
      end
    end

    -- Check if any button is pressed
    for _, button in pairs(buttons) do
      if x >= button.x and x <= button.x + button.width and y >= button.y and y <= button.y + button.height then
        if button.label == "Reset" then
          resetGame()
        elseif button.label == "Save" then
          saveGame()
        elseif button.label == "Load" then
          loadGame()
        end
      end
    end
  end

  function love.touchreleased(id, x, y, dx, dy, pressure)
    isAccelerating = false
  end

  -- Limit framerate to 60fps
  local frameEnd = love.timer.getTime()
  local frameDuration = frameEnd - frameStart
  if frameDuration < 1 / 60 then
    love.timer.sleep(1 / 60 - frameDuration)
  end
end

-- Draws the game board, current shape, and the game interface
function love.draw()
  local rectangleHeight = 0
  if isTouchDevice then
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local interfaceHeight = gridHeight * blockSize
    rectangleHeight = (screenHeight - interfaceHeight) / 2

    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("fill", 0, 0, screenWidth, rectangleHeight)
    love.graphics.rectangle("fill", 0, screenHeight - rectangleHeight, screenWidth, rectangleHeight)
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
  end

  love.graphics.push()
  love.graphics.translate(0, rectangleHeight)
  -- Clip the drawing area to exclude the top and bottom rectangles
  love.graphics.setScissor(0, rectangleHeight, love.graphics.getWidth(), love.graphics.getHeight() - 2 * rectangleHeight)
  drawBoard()
  drawShape()
  love.graphics.setScissor()
  love.graphics.pop()

  drawInterface()
end