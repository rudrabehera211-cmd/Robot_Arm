#include <WiFi.h>
#include <HTTPClient.h>
#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>
#include <ArduinoJson.h>

const char* ssid = "Android";
const char* password = "12345678";

const char* flaskServer = "http://10.252.205.82:5000";

Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver();

#define SERVOMIN 150
#define SERVOMAX 600
#define PIR_PIN 4

unsigned long lastMotionTime = 0;
const unsigned long MOTION_COOLDOWN = 10000;

int pulse(int angle) { return map(angle, 0, 180, SERVOMIN, SERVOMAX); }
void moveServo(uint8_t channel, int angle) { pwm.setPWM(channel, 0, pulse(angle)); }

void connectWiFi() {
    WiFi.begin(ssid, password);
    Serial.print("Connecting to WiFi");
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 40) {
        delay(500);
        Serial.print(".");
        attempts++;
    }
    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nConnected! IP: " + WiFi.localIP().toString());
    } else {
        Serial.println("\nFailed to connect, restarting...");
        ESP.restart();
    }
}

void setup() {
    Serial.begin(115200);
    Wire.begin(21, 22);
    pwm.begin();
    pwm.setPWMFreq(50);
    
    pinMode(PIR_PIN, INPUT);
    
    moveServo(0, 90);
    moveServo(1, 90);
    moveServo(2, 0);
    moveServo(3, 90);
    
    connectWiFi();
    Serial.println("Server: " + String(flaskServer));
}

void loop() {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("WiFi disconnected, reconnecting...");
        connectWiFi();
        return;
    }
    
    if (digitalRead(PIR_PIN) == HIGH && millis() - lastMotionTime > MOTION_COOLDOWN) {
        lastMotionTime = millis();
        HTTPClient http;
        http.begin(String(flaskServer) + "/motion");
        http.addHeader("Content-Type", "application/json");
        int httpResponseCode = http.POST("{\"source\":\"esp32\"}");
        if (httpResponseCode > 0) {
            Serial.println("Motion alert sent");
        }
        http.end();
    }
    
    HTTPClient http;
    http.begin(String(flaskServer) + "/command");
    int httpResponseCode = http.GET();
    
    if (httpResponseCode == 200) {
        String payload = http.getString();
        
        StaticJsonDocument<128> doc;
        DeserializationError error = deserializeJson(doc, payload);
        
        if (!error && !doc.containsKey("idle")) {
            int channel = doc["channel"];
            int angle = doc["angle"];
            
            channel = constrain(channel, 0, 3);
            
            if (channel == 0) angle = constrain(angle, 0, 180);
            if (channel == 1) angle = constrain(angle, 90, 180);
            if (channel == 2) angle = constrain(angle, 0, 90);
            if (channel == 3) angle = constrain(angle, 90, 130);
            
            moveServo(channel, angle);
            Serial.printf("Servo %d -> %d\n", channel, angle);
        }
    }
    
    http.end();
    delay(200);
}
