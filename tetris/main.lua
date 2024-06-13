-- Tetris game implementation


-- Grid and block size configuration
local gridWidth, gridHeight = 10, 20 -- Width and height of the game grid
local blockSize = 35 -- Size of each block in pixels

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
local level = 1
local score = 0
local gameOver = false

-- File path for saving game state
local saveFilePath = "tetris_save.txt"


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
end

-- Checks for and removes any complete lines on the game board, updating the score and level
function removeCompleteLines()
  local newBoard = {}

  for y = 1, gridHeight do
    local full = true
    for x = 1, gridWidth do
      if board[y][x].shape == 0 then
        full = false
        break
      end
    end

    if not full then
      table.insert(newBoard, board[y])
    end
  end

  local linesRemoved = gridHeight - #newBoard

  for i = 1, linesRemoved do
    table.insert(newBoard, 1, {})
    for x = 1, gridWidth do
      newBoard[1][x] = { shape = 0, color = 0 }
    end
  end

  board = newBoard

  -- Update score and level based on removed lines
  score = score + linesRemoved * 100
  level = math.floor(score / 1000) + 1
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
  end
end

-- Draws the current state of the game board
local function drawBoard()
  for y = 1, gridHeight do
    for x = 1, gridWidth do
      local block = board[y][x]
      if block.shape > 0 then
        local color = colors[block.color]
        
        -- Draw the main block
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", (x - 1) * blockSize, (y - 1) * blockSize, blockSize, blockSize)
        
        -- Draw the border
        love.graphics.setColor(0, 0, 0)
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
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", (shapeX + x - 2) * blockSize, (shapeY + y - 2) * blockSize, blockSize, blockSize)
        
        -- Draw the border
        love.graphics.setColor(0, 0, 0)
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
        
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", startX + (x - 1) * blockSize, interfaceY + (y - 1) * blockSize, blockSize, blockSize)
        
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("line", startX + (x - 1) * blockSize, interfaceY + (y - 1) * blockSize, blockSize, blockSize)
      end
    end
  end
end

-- Draws the interface including level, score, next piece preview, controls, and game over message
function drawInterface()
  local interfaceX = gridWidth * blockSize
  local interfaceY = 0
  local interfaceWidth = 250
  local interfaceHeight = love.graphics.getHeight()

  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.rectangle("fill", interfaceX, interfaceY, interfaceWidth, interfaceHeight)
  love.graphics.setColor(1, 1, 1)

  local function getTextWidth(text)
    return love.graphics.getFont():getWidth(text)
  end

  local centerX = interfaceX + (interfaceWidth / 2)

  love.graphics.setFont(love.graphics.newFont(30))

  -- Display level
  local levelText = "Level: " .. level
  local levelTextWidth = getTextWidth(levelText)
  love.graphics.print(levelText, centerX - (levelTextWidth / 2), interfaceY)
  interfaceY = interfaceY + 50

  love.graphics.setFont(love.graphics.newFont(20))

  -- Display score
  local scoreText = "Score: " .. score
  local scoreTextWidth = getTextWidth(scoreText)
  love.graphics.print(scoreText, centerX - (scoreTextWidth / 2), interfaceY)
  interfaceY = interfaceY + 100

  love.graphics.setFont(love.graphics.newFont(30))

  -- Display next piece
  love.graphics.print("Next Piece:", centerX - (getTextWidth("Next Piece:") / 2), interfaceY)
  local nextPieceWidth = #nextShape[1] * blockSize
  local startX = centerX - (nextPieceWidth / 2)
  interfaceY = interfaceY + 25
  drawNextShape(startX, interfaceY)
  interfaceY = interfaceY + 175

  -- Display controls
  love.graphics.print("Controls:", centerX - (getTextWidth("Controls:") / 2), interfaceY)
  interfaceY = interfaceY + 50
  love.graphics.setFont(love.graphics.newFont(20))
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
  interfaceY = interfaceY + 30
  love.graphics.print("Esc: Exit", centerX - (getTextWidth("Esc: Exit") / 2), interfaceY)
  interfaceY = interfaceY + 50

  -- Display game over message
  if gameOver then
    love.graphics.setColor(1, 0, 0)
    love.graphics.setFont(love.graphics.newFont(40))
    local gameOverText = "Game Over!"
    local gameOverTextWidth = getTextWidth(gameOverText)
    love.graphics.print(gameOverText, centerX - (gameOverTextWidth / 2), interfaceY)
    love.graphics.setColor(1, 1, 1)
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
end


-- Love2D callbacks

-- Initializes the game state when the game loads
function love.load()
  math.randomseed(os.time())
  refillBag()
  nextShape = table.remove(nextShapes, 1)
  currentShape, shapeX, shapeY, shapeColor, rotationState = newShape()
end

function love.update(dt)
  local frameStart = love.timer.getTime()

  if not gameOver then
    local currentFallSpeed = calculateFallSpeed(level)
    if love.keyboard.isDown("down") then
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
      elseif key == "right" and not checkCollision(currentShape, 1, 0) then
        shapeX = shapeX + 1
      elseif key == "up" then
        rotateShape()
      end
    end
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
  drawBoard()
  drawShape()
  drawInterface()
end