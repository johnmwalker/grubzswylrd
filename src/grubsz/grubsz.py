

from pyglet import gl
from pyglet.window import key
import random
import math
import numpy as np

from src.grubsz.brain.neuralnetwork import NeuralNetwork
from src.constants import GRUB_RADIUS, GRUB_MAX_HEALTH, GRUB_MAX_ENERGY, WIDTH, HEIGHT, FOOD_ENERGY, ATTACK_DAMAGE, ATTACK_RANGE

class Grub:
    def __init__(self, x, y, name=None, drops=None):
        self.x = x
        self.y = y
        self.radius = GRUB_RADIUS
        self.mass = self.radius  # Simplified mass
        self.health = GRUB_MAX_HEALTH
        self.energy = GRUB_MAX_ENERGY
        self.angle = random.uniform(0, 2 * math.pi)
        self.brain = NeuralNetwork()
        self.drops = drops
        self.name = name
    
    def move(self):
        # Simple movement logic
        self.x += math.cos(self.angle)
        self.y += math.sin(self.angle)
        self.x = max(self.radius, min(WIDTH - self.radius, self.x))
        self.y = max(self.radius, min(HEIGHT - self.radius, self.y))
    
    def update(self, foods, poisons, grubs):
        # Sensory inputs (simplified)
        nearest_food = min(foods, key=lambda f: (f.x - self.x) ** 2 + (f.y - self.y) ** 2, default=None)
        nearest_poison = min(poisons, key=lambda p: (p.x - self.x) ** 2 + (p.y - self.y) ** 2, default=None)
        
        inputs = [
            1.0 if nearest_food and ((nearest_food.x - self.x) ** 2 + (nearest_food.y - self.y) ** 2) < 100 ** 2 else 0.0,
            1.0 if nearest_poison and ((nearest_poison.x - self.x) ** 2 + (nearest_poison.y - self.y) ** 2) < 100 ** 2 else 0.0,
            self.health / GRUB_MAX_HEALTH,
            self.energy / GRUB_MAX_ENERGY,
            random.random()  # Random noise for exploration
        ]
        
        outputs = self.brain.activate(inputs)
        
        # Simple action mapping
        if outputs[0] > 0.5: self.angle += 0.1  # Rotate left
        if outputs[1] > 0.5: self.angle -= 0.1  # Rotate right
        if outputs[2] > 0.5: self.move()        # Move forward
        if outputs[3] > 0.5: self.attack(grubs) # Attack
    
    def eat(self, food):
        self.energy += FOOD_ENERGY
        self.energy = min(self.energy, GRUB_MAX_ENERGY)
    
    def take_damage(self, damage):
        self.health -= damage
        if self.health <= 0:
            self.die()
    
    def attack(self, grubs):
        # Find a target grub within the attack range
        target = None
        for grub in grubs:
            if grub != self:
                distance = math.sqrt((grub.x - self.x) ** 2 + (grub.y - self.y) ** 2)
                if distance < ATTACK_RANGE:
                    target = grub
                    break
        
        if target:
            target.take_damage(ATTACK_DAMAGE)
    
    def die(self):
        # Drop food and poison particles
        return self.drops(self.x, self.y)