import numpy as np

# Window
WIDTH, HEIGHT = 800, 600
SECONDS_PER_FRAME = 1/60

# Environment
GRUB_COUNT = 20
FOOD_COUNT = 30
POISON_COUNT = 20
DROP_NOISE = 5
FOOD_ENERGY = 20
POISON_DAMAGE = 30

# Grubsz
GRUB_RADIUS = 10
GRUB_MAX_HEALTH = 100
GRUB_MAX_ENERGY = 100
REPRODUCTION_THRESHOLD = 80
ATTACK_DAMAGE = 20
ATTACK_RANGE = 20
FOOD_DROP_COUNT = 3
POISON_DROP_COUNT = 1
DEATH_PARTICLE_COUNT = 1

# Colors
WHITE       = np.array((255, 255, 255))/255
BLACK       = np.array((0, 0, 0))/255
RED         = np.array((255,   0,   0))/255
PURPLE      = np.array((139, 0, 139))/255
GREEN       = np.array((0, 255, 0))/255
YELLOW      = np.array((255, 255,   0))/255
BLUE        = np.array((0,   0, 255))/255
ORANGE      = np.array((255, 165,   0))/255
PINK        = np.array((255, 192, 203))/255
GRAY        = np.array((128, 128, 128))/255
DARK_RED    = np.array((139, 0, 0))/255
DARK_GREEN  = np.array((0, 100, 0))/255
DARK_BLUE   = np.array((0,   0, 139))/255
DARK_YELLOW = np.array((157, 248, 0))/255
DARK_PINK   = np.array((255, 69, 192))/255
DARK_GRAY   = np.array((105, 105, 105))/255
