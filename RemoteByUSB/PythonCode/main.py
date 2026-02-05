import pygame
import serial
import sys
import time

pygame.init()
screen = pygame.display.set_mode((400, 300))
pygame.display.set_caption("MatrixMini Control")
clock = pygame.time.Clock()

SERIAL_PORT = 'COM3'  # Измените!
BAUDRATE = 9600

try:
    ser = serial.Serial(SERIAL_PORT, BAUDRATE, timeout=1)
    time.sleep(2)
    print(f"MatrixMini на {SERIAL_PORT}")
except Exception as e:
    print(f"Ошибка: {e}")
    sys.exit(1)

SPEED = 100
SPEED_STEP = 10

def send_motors(m1, m2):
    cmd = f"m1 {m1} m2 {m2}\n"
    ser.write(cmd.encode())
    print(cmd.strip())

running = True
last_key = None

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_UP:
                SPEED = min(100, SPEED + SPEED_STEP)
                ser.write(f"speed {SPEED}\n".encode())
            elif event.key == pygame.K_DOWN:
                SPEED = max(10, SPEED - SPEED_STEP)
                ser.write(f"speed {SPEED}\n".encode())
            elif event.key == pygame.K_SPACE:
                ser.write(b"stop\n")

    keys = pygame.key.get_pressed()
    current_key = None
    
    if keys[pygame.K_w]:
        send_motors(SPEED, SPEED)
        current_key = 'w'
    elif keys[pygame.K_s]:
        send_motors(-SPEED, -SPEED)
        current_key = 's'
    elif keys[pygame.K_a]:
        send_motors(-SPEED, SPEED)
        current_key = 'a'
    elif keys[pygame.K_d]:
        send_motors(SPEED, -SPEED)
        current_key = 'd'
    elif last_key:
        ser.write(b"stop\n")
        current_key = None
    
    last_key = current_key
    
    if ser.in_waiting > 0:
        response = ser.readline().decode('utf-8').strip()
        print(f"Arduino: {response}")
    
    # Экран
    screen.fill((20, 20, 40))
    font = pygame.font.Font(None, 36)
    text = font.render(f"Скорость: {SPEED}", True, (0, 255, 100))
    screen.blit(text, (80, 120))
    pygame.display.flip()
    clock.tick(30)

ser.write(b"stop\n")
ser.close()
pygame.quit()