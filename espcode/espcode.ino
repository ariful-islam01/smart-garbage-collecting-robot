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
