#include <LedControl.h>

const int DIN_PIN = 10;
const int CLK_PIN = 11;
const int CS_PIN = 9;
LedControl lc = LedControl(DIN_PIN, CLK_PIN, CS_PIN, 1);

const int BTN_UP = 2;
const int BTN_DOWN = 4;
const int BTN_LEFT = 3;
const int BTN_RIGHT = 5;

const int BUZZER_PIN = 6;


int snakeX[64], snakeY[64];
int snakeLength = 3;
int dirX = 1, dirY = 0;
int foodX, foodY;

int speedDelay = 50;
unsigned long lastUpdate = 0;

void setup() {
  pinMode(BTN_UP, INPUT);
  pinMode(BTN_DOWN, INPUT);
  pinMode(BTN_LEFT, INPUT);
  pinMode(BTN_RIGHT, INPUT);

  pinMode(BUZZER_PIN, OUTPUT);

  lc.shutdown(0, false);
  lc.setIntensity(0, 8);
  lc.clearDisplay(0);

  for (int i = 0; i < snakeLength; i++) {
    snakeX[i] = 3 - i;
    snakeY[i] = 3;
  }
  
  spawnFood();
}

void loop() {
  readButtons();
  \
  if (millis() - lastUpdate > speedDelay) {
    moveSnake();
    checkCollision();
    drawGame();
    lastUpdate = millis();
  }
}

void readButtons() {
  if (digitalRead(BTN_LEFT) == HIGH && dirX != 1) { 
    dirX = -1; dirY = 0; 
  }
  else if (digitalRead(BTN_RIGHT) == HIGH && dirX != -1) { 
    dirX = 1; dirY = 0; 
  }
  else if (digitalRead(BTN_UP) == HIGH && dirY != 1) { 
    dirX = 0; dirY = -1; 
  }
  else if (digitalRead(BTN_DOWN) == HIGH && dirY != -1) { 
    dirX = 0; dirY = 1; 
  }
}

void moveSnake() {
  for (int i = snakeLength - 1; i > 0; i--) {
    snakeX[i] = snakeX[i - 1];
    snakeY[i] = snakeY[i - 1];
  }
  snakeX[0] += dirX;
  snakeY[0] += dirY;
}

void checkCollision() {
  if (snakeX[0] < 0) snakeX[0] = 7;
  if (snakeX[0] > 7) snakeX[0] = 0;
  if (snakeY[0] < 0) snakeY[0] = 7;
  if (snakeY[0] > 7) snakeY[0] = 0;

  for (int i = 1; i < snakeLength; i++) {
    if (snakeX[0] == snakeX[i] && snakeY[0] == snakeY[i]) {
      gameOver();
    }
  }

  if (snakeX[0] == foodX && snakeY[0] == foodY) {
    tone(BUZZER_PIN, 1000, 100);

    snakeX[snakeLength] = snakeX[snakeLength - 1];
    snakeY[snakeLength] = snakeY[snakeLength - 1];
    
    snakeLength++;
    if(speedDelay > 100) speedDelay -= 15;
    spawnFood();
  }
}

void spawnFood() {
  bool validPos = false;
  while (!validPos) {
    foodX = random(0, 8);
    foodY = random(0, 8);
    validPos = true;
    for (int i = 0; i < snakeLength; i++) {
      if (snakeX[i] == foodX && snakeY[i] == foodY) {
        validPos = false;
        break;
      }
    }
  }
}

void drawGame() {
  lc.clearDisplay(0);
  
  lc.setLed(0, foodY, foodX, true);
  
  for (int i = 0; i < snakeLength; i++) {
    lc.setLed(0, snakeY[i], snakeX[i], true);
  }
}

void gameOver() {
  tone(BUZZER_PIN, 300, 200);
  delay(200);
  tone(BUZZER_PIN, 200, 200);
  delay(200);
  tone(BUZZER_PIN, 100, 400);
  
  for (int i = 0; i < 3; i++) {
    lc.clearDisplay(0);
    delay(200);
    for(int row=0; row<8; row++) {
      lc.setRow(0, row, B11111111);
    }
    delay(200);
  }
  
  snakeLength = 3;
  dirX = 1;
  dirY = 0;
  speedDelay = 300;
  for (int i = 0; i < snakeLength; i++) {
    snakeX[i] = 3 - i;
    snakeY[i] = 3;
  }
  spawnFood();
}