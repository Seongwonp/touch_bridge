#include <WiFi.h>
#include <WiFiClient.h>
#include <WiFiServer.h>
#include "BluetoothSerial.h"

#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth is not enabled! Please run `make menuconfig` to enable it
#endif

// -------------------------------------------------------------------
// 1. 무선 네트워크 및 서비스 설정 정의
// -------------------------------------------------------------------
const char* ap_ssid = "Touch_Bridge_CNC_WiFi";

#define TCP_PORT 8080
WiFiServer tcpServer(TCP_PORT);
WiFiClient tcpClient;

BluetoothSerial SerialBT;

#define RX2_PIN 16
#define TX2_PIN 17

#define GRBL_BAUD 115200
#define PC_BAUD 115200

void setup() {
  Serial.begin(PC_BAUD);
  delay(1000);
  
  Serial.println("\n=======================================================");
  Serial.println("  [Touch Bridge] Dual Wireless (WiFi+BT) UART Bridge  ");
  Serial.println("=======================================================");
  
  Serial2.begin(GRBL_BAUD, SERIAL_8N1, RX2_PIN, TX2_PIN);
  Serial.printf("[SYSTEM] UART2 (Uno GRBL) Init: RX=%d, TX=%d @ %d bps\n", RX2_PIN, TX2_PIN, GRBL_BAUD);

  Serial.println("[SYSTEM] Starting WiFi Access Point...");
  WiFi.softAP(ap_ssid);
  IPAddress apIP = WiFi.softAPIP();
  Serial.printf("[SUCCESS] WiFi AP Started. SSID: %s, IP: %s\n", ap_ssid, apIP.toString().c_str());

  tcpServer.begin();
  Serial.printf("[SYSTEM] TCP Server Started on Port %d\n", TCP_PORT);

  Serial.println("[SYSTEM] Starting Bluetooth SPP Service...");
  if (SerialBT.begin("Touch_Bridge_CNC")) {
    Serial.println("[SUCCESS] Bluetooth 'Touch_Bridge_CNC' is Online.");
  } else {
    Serial.println("[ERROR] Bluetooth Initialization Failed.");
  }
  
  Serial.println("-------------------------------------------------------");
  Serial.println("Bridge initialized. Dual Wireless Channels active!");
  Serial.println("=======================================================\n");
}

void loop() {
  // A. WiFi TCP 클라이언트 관리
  if (tcpServer.hasClient()) {
    if (!tcpClient || !tcpClient.connected()) {
      if (tcpClient) tcpClient.stop();
      tcpClient = tcpServer.available();
      Serial.println("\n[CONNECT] WiFi TCP Client connected!");
      tcpClient.println("Welcome to Touch Bridge Wireless CNC!");
    } else {
      WiFiClient rejectedClient = tcpServer.available();
      rejectedClient.stop();
    }
  }

  // B. 입력 채널 -> Uno GRBL (Serial2)
  
  // 1. Bluetooth -> Uno (Logging added)
  if (SerialBT.available()) {
    Serial.print("[LOG][BT->UNO] ");
    while (SerialBT.available()) {
      char inChar = (char)SerialBT.read();
      Serial2.write(inChar);
      Serial.write(inChar);
    }
    Serial.println();
  }

  // 2. WiFi -> Uno (Logging added)
  if (tcpClient && tcpClient.connected() && tcpClient.available()) {
    Serial.print("[LOG][WIFI->UNO] ");
    while (tcpClient.available()) {
      char inChar = (char)tcpClient.read();
      Serial2.write(inChar);
      Serial.write(inChar);
    }
    Serial.println();
  }

  // 3. PC USB -> Uno
  if (Serial.available()) {
    while (Serial.available()) {
      char inChar = (char)Serial.read();
      Serial2.write(inChar);
    }
  }

  // C. Uno GRBL -> 모든 채널 (Logging added)
  if (Serial2.available()) {
    String resp = "";
    while (Serial2.available()) {
      char outChar = (char)Serial2.read();
      resp += outChar;
      
      Serial.write(outChar);
      if (SerialBT.hasClient()) SerialBT.write(outChar);
      if (tcpClient && tcpClient.connected()) tcpClient.write(outChar);
    }
    // GRBL 응답 로그 출력 (불필요한 빈 라인 제외)
    if (resp.trim().length() > 0) {
      // Serial.write에서 이미 출력했으므로 별도 prefix 로그만 추가
      // Serial.print("\n[LOG][UNO->ALL] "); 
    }
  }

  // D. 연결 단절 알림
  if (tcpClient && !tcpClient.connected()) {
    Serial.println("\n[DISCONNECT] WiFi TCP Client disconnected.");
    tcpClient.stop();
  }
}
