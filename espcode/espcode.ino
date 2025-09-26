/*#include "BluetoothSerial.h"

BluetoothSerial SerialBT;

void setup() {
  Serial.begin(115200);    // Serial to Arduino Nano
  SerialBT.begin("GARBOT"); // Bluetooth name
  Serial.println("ESP32 Ready for Bluetooth Commands");
}

void loop() {
  // 1 Receive from Bluetooth → Send to Nano
  if (SerialBT.available()) {
    String cmd = SerialBT.readStringUntil('\n');
    cmd.trim();
    Serial.println("From App: " + cmd); // Debug
    Serial.println(cmd); // Send to Nano
  }

  // 2 Receive from Nano → Send to Bluetooth
  if (Serial.available()) {
    String data = Serial.readStringUntil('\n');
    data.trim();
    Serial.println("From Nano: " + data); // Debug
    SerialBT.println(data); // Send to App
  }
}*/
#include "BluetoothSerial.h"

BluetoothSerial SerialBT;

void setup(){
  Serial.begin(9600);
  SerialBT.begin("GARBOT");
  Serial.println("GARBOT is ready to connect");
}
void loop(){
  if(SerialBT.available()){
    char data= SerialBT.read();
    Serial.write(data);
  }
}
