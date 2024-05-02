function buildCastle() {
    const width: number = 21;
    const height: number = 7;
    const length: number = 21;

    const playerPos = player.position();
    const playerDirection = Math.round(player.getOrientation());
    let offsetX: number = 0;
    let offsetZ: number = 0;

    if (playerDirection >= 45 && playerDirection < 135) {
        offsetX = -29
        offsetZ = -(width / 2)
    } else if (playerDirection >= 135 || playerDirection < -135) {
        offsetX = -(width / 2)
        offsetZ = -34
    } else if (playerDirection >= -135 && playerDirection < -45) {
        offsetX = 14
        offsetZ = -(width / 2)
    } else {
        offsetX = -(width / 2)
        offsetZ = 14
    }

    const castleX: number = playerPos.getValue(Axis.X) + offsetX;
    const castleY: number = playerPos.getValue(Axis.Y) - 1;
    const castleZ: number = playerPos.getValue(Axis.Z) + offsetZ;

    buildFloor(castleX, castleY, castleZ, width, length);
    buildWalls(castleX, castleY, castleZ, width, height, length);
    buildRoof(castleX, castleY, castleZ, width, height, length);
    placeGlowstone(castleX, castleY, castleZ, width, height, length);
}

function buildFloor(castleX: number, castleY: number, castleZ: number, width: number, length: number) {
    const floor = blocks.block(NETHERRACK);
    for (let i = 0; i < width; i++) {
        for (let j = 0; j < length; j++) {
            blocks.place(floor, world(castleX + i, castleY, castleZ + j));
        }
    }
}

function buildWalls(castleX: number, castleY: number, castleZ: number, width: number, height: number, length: number) {
    const bottomWall = blocks.block(BLACKSTONE);
    const wall = blocks.block(NETHER_BRICK);
    const corner = blocks.block(OBSIDIAN);
    for (let i = 0; i < width; i++) {
        for (let j = 0; j < height; j++) {
            const doorWidth = 3;
            const doorStart = Math.floor((width - doorWidth) / 2);
            if (i >= doorStart && i < doorStart + doorWidth && j < 3) {
                continue;
            }
            if (j === 0) {
                blocks.place(bottomWall, world(castleX + i, castleY + j + 1, castleZ));
            } else if (i === 0 || i === width - 1) {
                blocks.place(corner, world(castleX + i, castleY + j + 1, castleZ));
            } else {
                blocks.place(wall, world(castleX + i, castleY + j + 1, castleZ));
            }
        }
    }

    for (let i = 0; i < width; i++) {
        for (let j = 0; j < height; j++) {
            if (j === 0) {
                blocks.place(bottomWall, world(castleX + i, castleY + j + 1, castleZ + length - 1));
            } else if (i === 0 || i === width - 1) {
                blocks.place(corner, world(castleX + i, castleY + j + 1, castleZ + length - 1));
            } else {
                blocks.place(wall, world(castleX + i, castleY + j + 1, castleZ + length - 1));
            }
        }
    }

    for (let i = 1; i < length - 1; i++) {
        for (let j = 0; j < height; j++) {
            if (j === 0) {
                blocks.place(bottomWall, world(castleX, castleY + j + 1, castleZ + i));
                blocks.place(bottomWall, world(castleX + width - 1, castleY + j + 1, castleZ + i));
            } else {
                blocks.place(wall, world(castleX, castleY + j + 1, castleZ + i));
                blocks.place(wall, world(castleX + width - 1, castleY + j + 1, castleZ + i));
            }
        }
    }
}

function buildRoof(castleX: number, castleY: number, castleZ: number, width: number, height: number, length: number) {
    const roof = blocks.block(POLISHED_BLACKSTONE);
    for (let i = 0; i < width; i++) {
        for (let j = 0; j < length; j++) {
            blocks.place(roof, world(castleX + i, castleY + height + 1, castleZ + j));
        }
    }

    for (let i = 0; i < width; i++) {
        for (let j = 0; j < length; j++) {
            if (i === 0 || i === width - 1 || j === 0 || j === length - 1) {
                if ((i + j) % 2 === 0) {
                    blocks.place(roof, world(castleX + i, castleY + height + 2, castleZ + j));
                }
            }
        }
    }
}

function placeGlowstone(castleX: number, castleY: number, castleZ: number, width: number, height: number, length: number) {
    const glowstone = blocks.block(GLOWSTONE);
    blocks.place(glowstone, world(castleX + 1, castleY + height + 1, castleZ + 1));
    blocks.place(glowstone, world(castleX + width - 2, castleY + height + 1, castleZ + 1));
    blocks.place(glowstone, world(castleX + 1, castleY + height + 1, castleZ + length - 2));
    blocks.place(glowstone, world(castleX + width - 2, castleY + height + 1, castleZ + length - 2));
}

player.onChat("build", buildCastle);