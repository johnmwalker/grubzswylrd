import pyglet
import moderngl
from pyglet import gl
from pyglet.window import key
import random
import math
import numpy as np
from time import time
import friendlywords as fw
from pyglet.text import Label

from src.grubsz.grubsz import Grub
from src.environment.environment import Food, Poison
# from src.particles.death_particle import DeathParticle
from src.constants import *

class DeathParticle:
    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.radius = 0
        self.creation_time = time()
        self.lifetime = 0.5  # Half a second

    def update(self):
        elapsed_time = time() - self.creation_time
        if elapsed_time < self.lifetime:
            self.radius = elapsed_time * 20  # Expand the radius over time
        else:
            self.radius = 0

    def is_alive(self):
        return (time() - self.creation_time) < self.lifetime

def grubsz_drops(x, y):
    foods = [Food(x + random.uniform(-DROP_NOISE, DROP_NOISE), y + random.uniform(-DROP_NOISE, DROP_NOISE)) for _ in range(FOOD_DROP_COUNT)]
    poisons = [Poison(x + random.uniform(-DROP_NOISE, DROP_NOISE), y + random.uniform(-DROP_NOISE, DROP_NOISE)) for _ in range(POISON_DROP_COUNT)]
    deathbits = [DeathParticle(x, y) for _ in range(DEATH_PARTICLE_COUNT)]
    return foods + poisons + deathbits

class Simulation(pyglet.window.Window):
    def __init__(self):
        super().__init__(WIDTH, HEIGHT, "Grub Simulation")
        fw.preload()
        self.ctx = moderngl.create_context()
        self.program = self.ctx.program(
            vertex_shader='''
                #version 330
                in vec2 in_position;
                in vec2 in_radius;
                in vec3 in_color;
                out vec3 color;
                uniform vec2 screen_size;
                void main() {
                    vec2 position = in_position + in_radius;
                    gl_Position = vec4(2.0 * position / screen_size - 1.0, 0.0, 1.0);
                    color = in_color;
                }
            ''',
            fragment_shader='''
                #version 330
                in vec3 color;
                out vec4 fragColor;
                void main() {
                    fragColor = vec4(color, 1.0);
                }
            ''',
        )
        self.screen_size = self.program['screen_size']
        self.screen_size.value = (WIDTH, HEIGHT)
        
        self.grubs = [Grub(random.randint(0, WIDTH), random.randint(0, HEIGHT), fw.generate(2), grubsz_drops) for _ in range(GRUB_COUNT)]
        self.foods = [Food(random.randint(0, WIDTH), random.randint(0, HEIGHT)) for _ in range(FOOD_COUNT)]
        self.poisons = [Poison(random.randint(0, WIDTH), random.randint(0, HEIGHT)) for _ in range(POISON_COUNT)]
        self.death_particles = []

    def draw_circle(self, x, y, radius, color):
        num_segments = 32
        theta = 2 * 3.1415926 / num_segments
        c = math.cos(theta)
        s = math.sin(theta)
        cx, cy = radius, 0
        
        vertices = []
        for _ in range(num_segments):
            vertices.extend([x + cx, y + cy, *color])
            t = cx
            cx = c * cx - s * cy
            cy = s * t + c * cy
        
        vertex_data = np.array(vertices, dtype='f4')
        vbo = self.ctx.buffer(vertex_data)
        vao = self.ctx.simple_vertex_array(self.program, vbo, 'in_position', 'in_color')
        vao.render(moderngl.TRIANGLE_FAN)
    
    def on_draw(self):
        self.clear()
        self.ctx.clear(0.0, 0.0, 0.0)
        
        for food in self.foods:
            self.draw_circle(food.x, food.y, food.radius, GREEN)
        
        for poison in self.poisons:
            self.draw_circle(poison.x, poison.y, poison.radius, PURPLE)
        
        for grub in self.grubs:
            self.draw_circle(grub.x, grub.y, grub.radius, WHITE)
        
        for particle in self.death_particles:
            if particle.is_alive():
                self.draw_circle(particle.x, particle.y, particle.radius, PURPLE)
    
    def update(self, dt):
        for grub in self.grubs:
            grub.update(self.foods, self.poisons, self.grubs)
            print(grub.name)
            label = Label(grub.name, font_size=16, x=grub.x, y=grub.y, anchor_x='center', anchor_y='center')
            label.draw()
            grub.move()
        
        # Handle deaths and new particles
        new_particles = []
        self.grubs = [grub for grub in self.grubs if grub.health > 0]
        for grub in self.grubs:
            if grub.health <= 0:
                new_particles.extend(grub.die())
        
        for particle in new_particles:
            if isinstance(particle, Food):
                self.foods.append(particle)
            elif isinstance(particle, Poison):
                self.poisons.append(particle)
            elif isinstance(particle, DeathParticle):
                self.death_particles.append(particle)

        
        
        # Update and remove expired death particles
        self.death_particles = [particle for particle in self.death_particles if particle.is_alive()]
        for particle in self.death_particles:
            particle.update()
    
    def on_key_press(self, symbol, modifiers):
        if symbol == key.ESCAPE:
            self.close()

if __name__ == "__main__":
    window = Simulation()
    pyglet.clock.schedule_interval(window.update, SECONDS_PER_FRAME)
    pyglet.app.run()
