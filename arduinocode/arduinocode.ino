#include <Servo.h>

#define in1 2
#define in2 4
#define in3 7
#define in4 8
#define ena 3
#define enb 5

#define trigPin 12
#define echoPin 13

Servo baseServo;
Servo shoulderServo;
Servo elbowServo;
Servo gripperServo;

// Initial angles (manual ও default pose)
int baseAngle = 110;
int shoulderAngle = 45;
int elbowAngle = 30;
int gripperAngle = 180;

long duration;
int distance;
#define speed 120

bool automaticMode = false;   // auto flag
bool ultrasonicEnabled = true; // ultrasonic on/off

// ---------- Smooth servo params ----------
const int SERVO_STEP_DEG = 2;  
const int SERVO_STEP_MS  = 8; 

// ---------- Motor helpers ----------
void stopmotor() {
  digitalWrite(in1, LOW); digitalWrite(in2, LOW);
  digitalWrite(in3, LOW); digitalWrite(in4, LOW);
}
void forward() {
  analogWrite(ena, speed); digitalWrite(in1, HIGH); digitalWrite(in2, LOW);
  analogWrite(enb, speed); digitalWrite(in3, HIGH); digitalWrite(in4, LOW);
}
void backward() {
  analogWrite(ena, speed); digitalWrite(in1, LOW); digitalWrite(in2, HIGH);
  analogWrite(enb, speed); digitalWrite(in3, LOW); digitalWrite(in4, HIGH);
}
void right() {
  analogWrite(ena, 150); digitalWrite(in1, HIGH); digitalWrite(in2, LOW);
  analogWrite(enb, 150); digitalWrite(in3, LOW);  digitalWrite(in4, HIGH);
}
void left() {
  analogWrite(ena, 150); digitalWrite(in1, LOW);  digitalWrite(in2, HIGH);
  analogWrite(enb, 150); digitalWrite(in3, HIGH); digitalWrite(in4, LOW);
}

// ---------- Ultrasonic helpers ----------
void ultrasonicOn() {
  ultrasonicEnabled = true;
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  digitalWrite(trigPin, LOW);
}
void ultrasonicOff() {
  ultrasonicEnabled = false;
  digitalWrite(trigPin, LOW);
  pinMode(trigPin, INPUT);
  pinMode(echoPin, INPUT);
}

void measureDistance() {
  if (!ultrasonicEnabled) { distance = 0; return; }

  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  duration = pulseIn(echoPin, HIGH, 20000); // 20ms timeout
  distance = duration * 0.034 / 2;
  Serial.println(distance);
}

// ---------- Servo write + smooth ----------
void writeBase(int a){ baseAngle = constrain(a, 0, 180); baseServo.write(baseAngle); }
void writeShoulder(int a){ shoulderAngle = constrain(a, 0, 180); shoulderServo.write(shoulderAngle); }
void writeElbow(int a){ elbowAngle = constrain(a, 0, 180); elbowServo.write(elbowAngle); }
void writeGripper(int a){ gripperAngle = constrain(a, 0, 180); gripperServo.write(gripperAngle); }

void moveServoSmooth(void (*writer)(int), int* current, int target, int step=SERVO_STEP_DEG, int dly=SERVO_STEP_MS) {
  target = constrain(target, 0, 180);
  if (*current == target) return;
  int dir = (target > *current) ? 1 : -1;
  for (int a = *current; a != target; a += dir * step) {
    int next = a + dir * step;
    if ((dir == 1 && next > target) || (dir == -1 && next < target)) next = target;
    writer(next);
    delay(dly);
  }
}
// --- Slow servo moves with for loop and delay ---

void baseTo(int target) {
  target = constrain(target, 0, 180);
  if (baseAngle < target) {
    for (int a = baseAngle; a <= target; a++) {
      baseServo.write(a);
      delay(20);  
    }
  } else {
    for (int a = baseAngle; a >= target; a--) {
      baseServo.write(a);
      delay(20);
    }
  }
  baseAngle = target;
}

void shoulderTo(int target) {
  target = constrain(target, 0, 180);
  if (shoulderAngle < target) {
    for (int a = shoulderAngle; a <= target; a++) {
      shoulderServo.write(a);
      delay(20);
    }
  } else {
    for (int a = shoulderAngle; a >= target; a--) {
      shoulderServo.write(a);
      delay(20);
    }
  }
  shoulderAngle = target;
}

void elbowTo(int target) {
  target = constrain(target, 0, 180);
  if (elbowAngle < target) {
    for (int a = elbowAngle; a <= target; a++) {
      elbowServo.write(a);
      delay(20);
    }
  } else {
    for (int a = elbowAngle; a >= target; a--) {
      elbowServo.write(a);
      delay(20);
    }
  }
  elbowAngle = target;
}

void gripperTo(int target) {
  target = constrain(target, 0, 180);
  if (gripperAngle < target) {
    for (int a = gripperAngle; a <= target; a++) {
      gripperServo.write(a);
      delay(20);
    }
  } else {
    for (int a = gripperAngle; a >= target; a--) {
      gripperServo.write(a);
      delay(20);
    }
  }
  gripperAngle = target;
}


// ---------- Your requested obstacle routine (AUTO mode only) ----------
void handleObstacleRoutine() {
  // ultrasonic OFF
  ultrasonicOff();
  stopmotor();

  // gripper -> 20°
  gripperTo(20);
  // shoulder -> 180°
  shoulderTo(180);
  // gripper -> 140°
  gripperTo(140);
  // shoulder -> 70°
  shoulderTo(70);
  // base -> 0°
  baseTo(0);
  // gripper -> 50°
  gripperTo(50);
  // arm initial state (base=110, shoulder=45, elbow=30, gripper=180) — one by one
  baseTo(110);
  elbowTo(30);
  shoulderTo(45);
  gripperTo(180);

  // ultrasonic ON
  ultrasonicOn();
}

// ---------- Setup / Loop ----------
void setup() {
  ultrasonicOn();
  Serial.begin(9600);

  pinMode(in1, OUTPUT); pinMode(in2, OUTPUT);
  pinMode(in3, OUTPUT); pinMode(in4, OUTPUT);

  stopmotor();

  baseServo.attach(6);
  shoulderServo.attach(9);
  elbowServo.attach(10);
  gripperServo.attach(11);

  baseServo.write(baseAngle);
  shoulderServo.write(shoulderAngle);
  elbowServo.write(elbowAngle);
  gripperServo.write(gripperAngle);
}

void loop() {
  // Serial commands
  if (Serial.available()) {
    char cmd = Serial.read();

    if (cmd == '0') automaticMode = true;          // AUTO start
    else if (cmd == 'z') automaticMode = false;    // switch to MANUAL
    else {
      automaticMode = false;                       // any manual cmd disables auto
      handleManual(cmd);                           // keep manual as before
    }
  }

  // Automatic mode: forward; obstacle at <=10cm => run routine
  if (automaticMode) {
    measureDistance();
    if (distance > 10 || distance == 0) {
      forward();                                 
    } else {
      stopmotor();
      handleObstacleRoutine();                
    }
  }
}

// ---------- Manual command handler (UNCHANGED) ----------
void handleManual(char cmd) {
  switch(cmd) {
    case '1': forward();  delay(400); stopmotor(); break;
    case '2': backward(); delay(400); stopmotor(); break;
    case '3': right();    delay(150); stopmotor(); break;
    case '4': left();     delay(150); stopmotor(); break;

    case '5': baseAngle = constrain(baseAngle + 5, 0, 180); baseServo.write(baseAngle); break;
    case '6': baseAngle = constrain(baseAngle - 5, 0, 180); baseServo.write(baseAngle); break;

    case '7': shoulderAngle = constrain(shoulderAngle + 5, 0, 180); shoulderServo.write(shoulderAngle); break;
    case '8': shoulderAngle = constrain(shoulderAngle - 5, 0, 180); shoulderServo.write(shoulderAngle); break;

    case '9': elbowAngle = constrain(elbowAngle + 5, 0, 180); elbowServo.write(elbowAngle); break;
    case 'A': elbowAngle = constrain(elbowAngle - 5, 0, 180); elbowServo.write(elbowAngle); break;

    case 'B': gripperAngle = constrain(gripperAngle + 5, 0, 180); gripperServo.write(gripperAngle); break;
    case 'C': gripperAngle = constrain(gripperAngle - 5, 0, 180); gripperServo.write(gripperAngle); break;

    case 'D': right();    delay(400); stopmotor(); break;
    case 'E': left();     delay(400); stopmotor(); break;

    default: stopmotor(); break;
  }
}
