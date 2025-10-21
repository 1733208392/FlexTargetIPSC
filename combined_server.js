// Combined Server: HttpServerSim + BLE_WS_SIM
// Merges HTTP server for game data and netlink operations with WebSocket/BLE proxy for Godot-Mobile App communication

const http = require('http');
const fs = require('fs');
const url = require('url');
const bleno = require('@abandonware/bleno');
const WebSocket = require('ws');

// Netlink state variables (shared between HTTP and WS/BLE)
let netlinkStarted = true;
let netlinkChannel = 0;
let netlinkWorkMode = "master";
let netlinkDeviceName = "cjyw01";
let netlinkBluetoothName = "cjyw01-bluetooth";
let netlinkWifiIp = "192.168.1.100"; // Mock IP for simulation

// BLE Configuration
const SERVICE_UUID = '0000ffc9-0000-1000-8000-00805f9b34fb';
const NOTIFY_CHARACTERISTIC_UUID = '0000ffe1-0000-1000-8000-00805f9b34fb';
const WRITE_CHARACTERISTIC_UUID = '0000ffe2-0000-1000-8000-00805f9b34fb';

// BLE Advertising Configuration
const BLE_DEVICE_NAME = 'BLE-WS-SIM Proxy';
const ADVERTISING_INTERVAL_MS = 10000; // Re-advertise every 10 seconds

// WebSocket Configuration
const WS_PATH = '/websocket';

// Embedded System State (for /system/embedded/status endpoint)
let embeddedSystemState = {
  heartbeat: Math.floor(Date.now() / 1000), // Last heartbeat timestamp
  threshold: 1000, // Sensor threshold value
  temperature: 28, // Temperature in Celsius
  version: "v1.0.0" // Hardware version
};

// Global state management for WS/BLE
let mobileAppBLEClient = null;
let godotWSClient = null;
const connectedGodotClients = new Set();

console.log('[CombinedServer] Starting Combined HTTP/WebSocket/BLE Proxy Simulation...');
console.log('[CombinedServer] HTTP server on port 80, WebSocket on path /websocket, BLE advertising service UUID:', SERVICE_UUID);

// ============================================================================
// HTTP SERVER (for game data and netlink operations)
// ============================================================================

const httpServer = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  
  // Log all incoming requests
  console.log(`[HttpServer] ${new Date().toISOString()} - ${req.method} ${pathname}`);

  if (pathname === '/game/save' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const { data_id, content, namespace = 'default' } = data;

        if (!data_id || !content) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Missing data_id or content" }));
          return;
        }

        const fileName = `${data_id}.json`;
        
        // Debug logging for settings save
        console.log(`[HttpServer] Saving file: ${fileName}`);
        console.log(`[HttpServer] Content to save: ${content}`);
        if (data_id === 'settings') {
          console.log(`[HttpServer] SETTINGS UPDATE DETECTED!`);
          try {
            const parsedContent = JSON.parse(content);
            console.log(`[HttpServer] Settings drill_sequence: ${parsedContent.drill_sequence}`);
            console.log(`[HttpServer] Settings language: ${parsedContent.language}`);
          } catch (e) {
            console.log(`[HttpServer] Failed to parse settings content for debugging: ${e.message}`);
          }
        }
        
        fs.writeFile(fileName, content, 'utf8', (err) => {
          if (err) {
            console.error('Error saving file:', err);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 1, msg: "Failed to save file" }));
          } else {
            console.log(`[HttpServer] Successfully saved: ${fileName}`);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 0, msg: "" }));
          }
        });
      } catch (error) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON" }));
      }
    });
  } else if (pathname === '/game/load' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const { data_id, namespace = 'default' } = data;

        if (!data_id) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Missing data_id" }));
          return;
        }

        const fileName = `${data_id}.json`;
        
        // Debug logging for settings load
        console.log(`[HttpServer] Loading file: ${fileName}`);
        if (data_id === 'settings') {
          console.log(`[HttpServer] SETTINGS LOAD REQUEST DETECTED!`);
        }
        
        fs.readFile(fileName, 'utf8', (err, content) => {
          if (err) {
            console.error('Error loading file:', err);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 0, data: "{}", msg: "OK" }));
          } else {
            console.log(`[HttpServer] Successfully loaded: ${fileName}`);
            if (data_id === 'settings') {
              console.log(`[HttpServer] Settings content loaded: ${content}`);
              try {
                const parsedContent = JSON.parse(content);
                console.log(`[HttpServer] Loaded settings drill_sequence: ${parsedContent.drill_sequence}`);
                console.log(`[HttpServer] Loaded settings language: ${parsedContent.language}`);
              } catch (e) {
                console.log(`[HttpServer] Failed to parse loaded settings for debugging: ${e.message}`);
              }
            }
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 0, data: content }));
          }
        });
      } catch (error) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON" }));
      }
    });
  } else if (pathname === '/netlink/wifi/scan' && req.method === 'POST') {
    const ssidList = ["cjyw", "cjyw2", "cjyw5G", "cjyw", "cjyw2", "cjyw5G", "cjyw", "cjyw2", "cjyw5G", "cjyw", "cjyw2", "cjyw5G", "cjyw", "cjyw2", "cjyw5G"];
    console.log(`[HttpServer] Starting WiFi scan simulation (15s delay)...`);
    // Simulate 15 second delay for WiFi scanning
    setTimeout(() => {
      console.log(`[HttpServer] WiFi scan completed`);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ code: 0, msg: "", data: { ssid_list: ssidList } }));
    }, 10000);
  } else if (pathname === '/netlink/wifi/connect' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const requestData = JSON.parse(body);

        // Accept both simple payload and legacy wrapped payload
        let ssid = null;
        let password = null;

        if (requestData && typeof requestData === 'object') {
          if (requestData.ssid && requestData.password) {
            ssid = requestData.ssid;
            password = requestData.password;
          } else if (requestData.type === 'netlink' && requestData.action === 'forward' && requestData.content) {
            try {
              const parsedContent = JSON.parse(requestData.content);
              ssid = parsedContent.ssid;
              password = parsedContent.password;
            } catch (e) {
              // content was not valid JSON
              ssid = null;
              password = null;
            }
          }
        }

        if (!ssid || !password) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: 'Missing ssid or password' }));
          return;
        }

        // Simulate WiFi connection with 10 second delay
        console.log(`[HttpServer] Connecting to WiFi: SSID=${ssid} (10s delay)...`);
        setTimeout(() => {
          console.log(`[HttpServer] WiFi connection completed for SSID=${ssid}`);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 0, data: {}, msg: '' }));
        }, 10000);
      } catch (error) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: 'Invalid JSON' }));
      }
    });
  } else if (pathname === '/netlink/config' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const { channel, work_mode, device_name } = data;

        // Validate channel: must be int between 1 and 254
        if (typeof channel !== 'number' || !Number.isInteger(channel) || channel < 1 || channel > 254) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Invalid channel: must be integer between 1 and 254" }));
          return;
        }

        // Validate work_mode: must be "master" or "slave"
        if (typeof work_mode !== 'string' || (work_mode !== 'master' && work_mode !== 'slave')) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Invalid work_mode: must be 'master' or 'slave'" }));
          return;
        }

        // Validate device_name: must be string
        if (typeof device_name !== 'string') {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Invalid device_name: must be string" }));
          return;
        }

        // Simulate configuration with 10 second delay
        console.log(`[HttpServer] Starting netlink configuration: channel=${channel}, work_mode=${work_mode}, device_name=${device_name} (10s delay)...`);
        
        setTimeout(() => {
          // Store the configuration
          netlinkChannel = channel;
          netlinkWorkMode = work_mode;
          netlinkDeviceName = device_name;
          netlinkBluetoothName = device_name; // Use device_name as bluetooth_name for simulation
          
          console.log(`[HttpServer] Netlink configuration completed`);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 0, msg: "Configuration successful" }));
        }, 10000);
      } catch (error) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON" }));
      }
    });
  } else if (pathname === '/netlink/start' && req.method === 'POST') {
    // Start netlink service
    netlinkStarted = true;
    console.log(`[HttpServer] Netlink service started`);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ code: 0, msg: "" }));
  } else if (pathname === '/netlink/stop' && req.method === 'POST') {
    // Stop netlink service
    netlinkStarted = false;
    console.log(`[HttpServer] Netlink service stopped`);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ code: 0, msg: "" }));
  } else if (pathname === '/netlink/status' && req.method === 'POST') {
    // Get netlink service status
    console.log(`[HttpServer] Netlink status requested`);
    // Commented out original response to simulate started=false scenario
    
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      code: 0,
      msg: "",
      data: {
        wifi_ip: netlinkWifiIp,
        channel: netlinkChannel,
        work_mode: netlinkWorkMode,
        device_name: netlinkDeviceName,
        bluetooth_name: netlinkBluetoothName,
        started: netlinkStarted
      }
    }));
    
    // Simulate started=false scenario
    // res.writeHead(200, { 'Content-Type': 'application/json' });
    // res.end(JSON.stringify({
    //   code: 0,
    //   msg: "",
    //   data: {
    //     wifi_ip: netlinkWifiIp,
    //     channel: 0,
    //     work_mode: "",
    //     device_name: "",
    //     bluetooth_name: "",
    //     started: false
    //   }
    // }));
  } else if (pathname === '/netlink/forward-data' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const content = JSON.parse(body);

        if (!content) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Missing content" }));
          return;
        }

        // Use the parsed content directly as envelope, change action and ensure device/type
        const envelope = content;
        envelope.action = 'forward'; // Change action for BLE compatibility
        envelope.device = netlinkDeviceName; // Ensure device is the server's device name
        envelope.type = 'netlink'; // Ensure type is set

        console.log(`[HttpServer] Forwarding data to BLE:`, envelope);

        // Split message into chunks and send via BLE
        sendMessageInChunks(envelope);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 0, msg: "" }));
      } catch (error) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON" }));
      }
    });
  } else if (pathname === '/system/embedded/status' && req.method === 'POST') {
    // Query embedded system status
    // Update heartbeat to current timestamp
    embeddedSystemState.heartbeat = Math.floor(Date.now() / 1000);
    
    console.log(`[HttpServer] /system/embedded/status called`);
    console.log(`[HttpServer] Embedded system state:`, embeddedSystemState);

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      code: 0,
      msg: "Success",
      data: {
        heartbeat: embeddedSystemState.heartbeat,
        threshold: embeddedSystemState.threshold,
        temperature: embeddedSystemState.temperature,
        version: embeddedSystemState.version
      }
    }));
  } else if (pathname === '/system/embedded/threshold' && req.method === 'POST') {
    // Set sensor threshold
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const value = data.value;

        // Validate that value is provided
        if (value === undefined || value === null) {
          console.log(`[HttpServer] /system/embedded/threshold - Missing 'value' parameter`);
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Missing 'value' parameter" }));
          return;
        }

        // Validate that value is a number and within range (700-2000)
        const numValue = parseInt(value);
        if (isNaN(numValue)) {
          console.log(`[HttpServer] /system/embedded/threshold - Invalid value type: ${value}`);
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Invalid value type (must be integer)" }));
          return;
        }

        if (numValue < 700 || numValue > 2000) {
          console.log(`[HttpServer] /system/embedded/threshold - Value out of range: ${numValue} (must be 700-2000)`);
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Value must be between 700 and 2000" }));
          return;
        }

        // Update threshold value
        embeddedSystemState.threshold = numValue;
        console.log(`[HttpServer] /system/embedded/threshold set to: ${numValue}`);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 0, msg: "Threshold set successfully" }));
      } catch (error) {
        console.log(`[HttpServer] /system/embedded/threshold - JSON parse error: ${error.message}`);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON format" }));
      }
    });
  } else {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ code: 0, msg: "" }));
    });
  }
});

// ============================================================================
// WEBSOCKET SERVER (for Godot Game communication)
// ============================================================================

const wss = new WebSocket.Server({ server: httpServer, path: WS_PATH });

// Shot data simulation (from Low Level HW to Godot)
const randomDataOptions = [
  { t: 630, x: 100, y: 200, a: 1069 },
  { t: 630, x: 40, y: 300, a: 1069 },
  { t: 630, x: 250, y: 300, a: 1069 },
  { t: 630, x: 200, y: 300, a: 1069 },
  { t: 630, x: 200, y: 200, a: 1069 },
  { t: 630, x: 200, y: 100, a: 1069 },
  { t: 630, x: 170, y: 200, a: 1069 },
  { t: 630, x: 134, y: 238.2, a: 1069 }
];

// Bullet variance for realistic simulation
const BULLET_VARIANCE = {
  maxX: 10.0,
  maxY: 10.0,
};

function addBulletVariance(bulletData) {
  const variedBullet = { ...bulletData };
  const u1 = Math.random();
  const u2 = Math.random();
  const z0 = Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
  const z1 = Math.sqrt(-2 * Math.log(u1)) * Math.sin(2 * Math.PI * u2);
  
  variedBullet.x = Math.round((bulletData.x + (z0 * BULLET_VARIANCE.maxX * 0.33)) * 10) / 10;
  variedBullet.y = Math.round((bulletData.y + (z1 * BULLET_VARIANCE.maxY * 0.33)) * 10) / 10;
  
  return variedBullet;
}

// WebSocket server event handlers
wss.on('listening', () => {
  console.log(`[CombinedServer] WebSocket server listening on path ${WS_PATH}`);
});

wss.on('connection', (ws) => {
  console.log('[CombinedServer] Godot client connected via WebSocket');
  connectedGodotClients.add(ws);
  godotWSClient = ws; // Keep reference to latest client

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message.toString());
      console.log('[CombinedServer] Received from Godot:', data);
      
      // Handle netlink forward messages from Godot to Mobile App
      if (data.type === 'netlink' && data.action === 'forward') {
        console.log('[CombinedServer] Forwarding netlink forward message from Godot to Mobile App');
        forwardToMobileApp(data);
      } else {
        // Forward other messages from Godot to Mobile App via BLE
        forwardToMobileApp(data);
      }
    } catch (error) {
      console.log('[CombinedServer] Invalid JSON from Godot:', error.message);
    }
  });

  ws.on('close', () => {
    console.log('[CombinedServer] Godot client disconnected');
    connectedGodotClients.delete(ws);
    if (godotWSClient === ws) {
      godotWSClient = null;
    }
  });
});

// Add keyboard input for remote control directives (only if we have a controlling terminal)
if (process.stdin.isTTY) {
  process.stdin.setRawMode(true);
  process.stdin.resume();
  process.stdin.setEncoding('utf8');

  // Debounce mechanism for Enter key to prevent double firing
  let lastEnterTime = 0;
  const ENTER_DEBOUNCE_MS = 50; // 50ms debounce

  // Burst mode configuration
  let burstMode = false;
  let burstInterval = null;
  const BURST_RATE_MS = 50; // 50ms = 20 bullets per second (1000ms / 20)

  process.stdin.on('data', (key) => {
    const keyStr = key.toString();
  let directive = null;

  // Map keys to directives (from original WebSocket server)
  if (keyStr === 'B' || keyStr === 'b') { // B - Send single random bullet
    if (connectedGodotClients.size > 0) {
      const baseData = randomDataOptions[Math.floor(Math.random() * randomDataOptions.length)];
      const shotData = addBulletVariance(baseData);
      const bulletMessage = {
        type: 'data',
        data: [shotData]
      };
      sendToGodot(bulletMessage);
      console.log('[CombinedServer] Manual bullet sent via keyboard');
    }
    return;
  } else if (keyStr === 'C' || keyStr === 'c') { // C - Send center screen bullet
    if (connectedGodotClients.size > 0) {
      const centerBullet = { t: 630, x: 134, y: 238.2, a: 1069 };
      const bulletMessage = {
        type: 'data',
        data: [centerBullet]
      };
      sendToGodot(bulletMessage);
      console.log('[CombinedServer] Center bullet sent via keyboard');
    }
    return;
  } else if (keyStr === 'F' || keyStr === 'f') { // F - toggle burst mode (20 bullets/second)
    if (burstMode) {
      // Stop burst mode
      if (burstInterval) {
        clearInterval(burstInterval);
        burstInterval = null;
      }
      burstMode = false;
      console.log('[CombinedServer] Burst mode stopped');
    } else {
      // Start burst mode
      burstMode = true;
      burstInterval = setInterval(() => {
        if (connectedGodotClients.size > 0) {
          const randomData = randomDataOptions[Math.floor(Math.random() * randomDataOptions.length)];
          const variedData = addBulletVariance(randomData);
          const randomDataPayload = {
            type: 'data',
            data: [variedData]
          };
          sendToGodot(randomDataPayload);
        }
      }, BURST_RATE_MS);
      console.log(`[CombinedServer] Burst mode started - firing at 20 bullets/second (${BURST_RATE_MS}ms intervals)`);
    }
    return; // Don't send control message
  } else if (keyStr === '\u001B[A') { // Arrow Up
    directive = 'up';
  } else if (keyStr === '\u001B[B') { // Arrow Down
    directive = 'down';
  } else if (keyStr === '\u001B[C') { // Arrow Right
    directive = 'right';
  } else if (keyStr === '\u001B[D') { // Arrow Left
    directive = 'left';
  } else if (keyStr === '\r') { // Enter
    // Debounce Enter key to prevent double firing
    const now = Date.now();
    if (now - lastEnterTime > ENTER_DEBOUNCE_MS) {
      directive = 'enter';
      lastEnterTime = now;
    } else {
      return; // Skip duplicate Enter within debounce period
    }
  } else if (keyStr === 'H' || keyStr === 'h') { // H - homepage
    directive = 'homepage';
  } else if (keyStr === 'M' || keyStr === 'm') { // M - compose
    directive = 'compose';
  } else if (keyStr === 'V' || keyStr === 'v') { // V - volume_up
    directive = 'volume_up';
  } else if (keyStr === 'D' || keyStr === 'd') { // D - volume_down
    directive = 'volume_down';
  } else if (keyStr === 'P' || keyStr === 'p') { // P - power
    directive = 'power';
  } else if (keyStr === '\u0003') { // Ctrl+C
    process.exit();
  }

  if (directive) {
    const controlMessage = { type: 'control', directive };
    sendToGodot(controlMessage);
    console.log(`[CombinedServer] Sent control directive: ${directive}`);
  }
  });
}

// Function to send data to Godot clients
function sendToGodot(data) {
  const message = JSON.stringify(data);
  connectedGodotClients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
      console.log('[CombinedServer] Sent to Godot:', message);
    }
  });
}

// ============================================================================
// BLE PERIPHERAL (for Mobile App communication)
// ============================================================================

// BLE Notify Characteristic (Mobile App reads data)
class NotifyCharacteristic extends bleno.Characteristic {
  constructor() {
    super({
      uuid: NOTIFY_CHARACTERISTIC_UUID,
      properties: ['read', 'notify'],
      value: null
    });

    this._value = Buffer.from(JSON.stringify({ type: 'ready' }));
    this._updateValueCallback = null;
  }

  onReadRequest(offset, callback) {
    console.log('[CombinedServer] Mobile App read request on notify characteristic');
    callback(bleno.Characteristic.RESULT_SUCCESS, this._value);
  }

  onSubscribe(maxValueSize, updateValueCallback) {
    console.log('[CombinedServer] Mobile App subscribed to BLE notifications');
    this._updateValueCallback = updateValueCallback;
    mobileAppBLEClient = this;
  }

  onUnsubscribe() {
    console.log('[CombinedServer] Mobile App unsubscribed from BLE notifications');
    this._updateValueCallback = null;
    mobileAppBLEClient = null;
  }

  // Method to send data to Mobile App
  sendToMobileApp(data) {
    if (this._updateValueCallback) {
      this._value = Buffer.from(JSON.stringify(data) + "\r\n");
      this._updateValueCallback(this._value);
      console.log('[CombinedServer] Sent to Mobile App via BLE:', JSON.stringify(data));
    }
  }
}

// BLE Write Characteristic (Mobile App sends data)
class WriteCharacteristic extends bleno.Characteristic {
  constructor(notifyCharacteristic) {
    super({
      uuid: WRITE_CHARACTERISTIC_UUID,
      properties: ['write'],
      value: null
    });
    this.notifyCharacteristic = notifyCharacteristic;
    this.messageBuffer = ''; // Buffer for accumulating split message packets
  }

  onWriteRequest(data, offset, withoutResponse, callback) {
    const receivedData = data.toString('utf8');
    
    // Accumulate data in buffer
    this.messageBuffer += receivedData;
    
    console.log('[CombinedServer] BLE data received, buffer now:', this.messageBuffer);
    
    // Check if we have a complete message (ends with \r\n)
    if (this.messageBuffer.endsWith('\r\n')) {
      // Remove the \r\n terminator and process the complete message
      const completeMessage = this.messageBuffer.slice(0, -2);
      
      console.log('[CombinedServer] ===========================================');
      console.log('[CombinedServer] COMPLETE BLE MESSAGE RECEIVED');
      console.log('[CombinedServer] Raw data:', completeMessage);
      console.log('[CombinedServer] ===========================================');

      try {
        const parsedData = JSON.parse(completeMessage);
        console.log('[CombinedServer] Parsed BLE message:');
        console.log(JSON.stringify(parsedData, null, 2));
        console.log('[CombinedServer] ===========================================');
        
        // Handle netlink forward messages from Mobile App to Godot
        if (parsedData.action === 'netlink_forward' && parsedData.content) {
          console.log('[CombinedServer] Forwarding netlink message from Mobile App to Godot');
          sendToGodot({ type: 'netlink', data: parsedData.content });
        }
        
        // Handle specific commands
        if (parsedData.action === 'netlink_query_device_list') {
          console.log('[CombinedServer] Processing query_device_list from Mobile App');
          const response = {
            type: 'netlink',
            action: 'device_list',
            data: [
              { mode: 'master', name: 'cjyw01' },
              { mode: 'slave', name: 'yang02' }
            ]
          };
          
          // Send response back to Mobile App
          if (this.notifyCharacteristic) {
            this.notifyCharacteristic.sendToMobileApp(response);
            console.log('[CombinedServer] Sent device_list response to Mobile App');
          } else {
            console.log('[CombinedServer] Cannot send device_list response: notify characteristic not available');
          }
        }

      } catch (error) {
        console.log('[CombinedServer] ERROR: Failed to parse BLE data from Mobile App:', error.message);
        console.log('[CombinedServer] Raw data was:', completeMessage);
        console.log('[CombinedServer] ===========================================');
      }
      
      // Clear the buffer after processing
      this.messageBuffer = '';
    } else {
      console.log('[CombinedServer] Waiting for more data to complete message...');
    }

    callback(bleno.Characteristic.RESULT_SUCCESS);
  }
}

// Function to split message into chunks and send via BLE
function sendMessageInChunks(data) {
  if (!mobileAppBLEClient || !mobileAppBLEClient._updateValueCallback) {
    console.log('[CombinedServer] No Mobile App connected via BLE to forward message');
    return;
  }

  const jsonString = JSON.stringify(data);
  const maxChunkSize = 100;
  const chunks = [];
  
  // Split the message into chunks of max 100 bytes
  for (let i = 0; i < jsonString.length; i += maxChunkSize) {
    chunks.push(jsonString.slice(i, i + maxChunkSize));
  }
  
  console.log(`[CombinedServer] Splitting message into ${chunks.length} chunks`);
  
  // Send all chunks with delay to ensure proper ordering
  chunks.forEach((chunk, index) => {
    setTimeout(() => {
      const isLastChunk = index === chunks.length - 1;
      const chunkToSend = isLastChunk ? chunk + '\r\n' : chunk;
      
      const buffer = Buffer.from(chunkToSend);
      mobileAppBLEClient._updateValueCallback(buffer);
      
      console.log(`[CombinedServer] Sent chunk ${index + 1}/${chunks.length} (${buffer.length} bytes)${isLastChunk ? ' [END]' : ''}: ${chunkToSend}`);
    }, index * 50); // 50ms delay between chunks
  });
}

// Function to forward data from Godot to Mobile App
function forwardToMobileApp(data) {
  if (mobileAppBLEClient) {
    mobileAppBLEClient.sendToMobileApp(data);
  } else {
    console.log('[CombinedServer] No Mobile App connected via BLE to forward message');
  }
}

// Create BLE service
const notifyCharacteristic = new NotifyCharacteristic();
const writeCharacteristic = new WriteCharacteristic(notifyCharacteristic);

const bleService = new bleno.PrimaryService({
  uuid: SERVICE_UUID,
  characteristics: [
    notifyCharacteristic,
    writeCharacteristic
  ]
});

// BLE advertising management
let advertisingInterval = null;

function startActiveAdvertising() {
  console.log('[CombinedServer] Starting active advertising with service UUID:', SERVICE_UUID);
  
  // Start advertising with service UUID prominently featured
  bleno.startAdvertising(BLE_DEVICE_NAME, [SERVICE_UUID], (error) => {
    if (error) {
      console.error('[CombinedServer] Advertising error:', error);
    } else {
      console.log('[CombinedServer] Successfully advertising service UUID:', SERVICE_UUID);
    }
  });
  
  // Set up periodic re-advertising to ensure visibility
  if (advertisingInterval) {
    clearInterval(advertisingInterval);
  }
  
  advertisingInterval = setInterval(() => {
    if (bleno.state === 'poweredOn') {
      console.log('[CombinedServer] Re-advertising service UUID:', SERVICE_UUID);
      bleno.startAdvertising(BLE_DEVICE_NAME, [SERVICE_UUID]);
    }
  }, ADVERTISING_INTERVAL_MS);
}

function stopActiveAdvertising() {
  console.log('[CombinedServer] Stopping active advertising');
  
  if (advertisingInterval) {
    clearInterval(advertisingInterval);
    advertisingInterval = null;
  }
  
  bleno.stopAdvertising();
}

// BLE event handlers
bleno.on('stateChange', (state) => {
  console.log('[CombinedServer] BLE state change:', state);

  if (state === 'poweredOn') {
    startActiveAdvertising();
  } else {
    stopActiveAdvertising();
  }
});

bleno.on('advertisingStart', (error) => {
  console.log('[CombinedServer] BLE advertising started:', error ? error : 'success');
  
  if (!error) {
    bleno.setServices([bleService], (error) => {
      if (error) {
        console.error('[CombinedServer] Error setting services:', error);
      } else {
        console.log('[CombinedServer] BLE services set successfully');
        console.log('[CombinedServer] Service UUID actively advertised:', SERVICE_UUID);
      }
    });
  }
});

bleno.on('advertisingStop', () => {
  console.log('[CombinedServer] Advertising stopped');
});

bleno.on('accept', (clientAddress) => {
  console.log('[CombinedServer] Mobile App connected via BLE:', clientAddress);
  // Continue advertising even when connected to remain discoverable
  console.log('[CombinedServer] Maintaining advertising for discoverability');
});

bleno.on('disconnect', (clientAddress) => {
  console.log('[CombinedServer] Mobile App disconnected from BLE:', clientAddress);
  // Ensure we restart advertising after disconnect
  if (bleno.state === 'poweredOn') {
    setTimeout(() => {
      startActiveAdvertising();
    }, 1000);
  }
});

// ============================================================================
// STARTUP
// ============================================================================

httpServer.listen(80, () => {
  console.log('[CombinedServer] HTTP server listening on port 80');
});

console.log('[CombinedServer] Configuration:');
console.log('[CombinedServer] - HTTP Server Port: 80');
console.log('[CombinedServer] - WebSocket Server Path:', WS_PATH);
console.log('[CombinedServer] - BLE Device Name:', BLE_DEVICE_NAME);
console.log('[CombinedServer] - BLE Service UUID (Actively Advertised):', SERVICE_UUID);
console.log('[CombinedServer] - BLE Notify Characteristic UUID:', NOTIFY_CHARACTERISTIC_UUID);
console.log('[CombinedServer] - BLE Write Characteristic UUID:', WRITE_CHARACTERISTIC_UUID);
console.log('[CombinedServer] - Advertising Interval:', ADVERTISING_INTERVAL_MS + 'ms');
console.log('[CombinedServer] ');
console.log('[CombinedServer] Proxy Functions:');
console.log('[CombinedServer] 1. Low Level HW → WebSocket → Godot Game');
console.log('[CombinedServer] 2. Mobile App → BLE → WebSocket → Godot Game');
console.log('[CombinedServer] 3. Godot Game → WebSocket → BLE → Mobile App');
console.log('[CombinedServer] 4. HTTP API for game data save/load and netlink operations');
console.log('[CombinedServer] ');
console.log('[CombinedServer] BLE Advertising Features:');
console.log('[CombinedServer] - Service UUID actively advertised before and during connections');
console.log('[CombinedServer] - Periodic re-advertising for maximum discoverability');
console.log('[CombinedServer] - Automatic restart of advertising after disconnection');
console.log('[CombinedServer] ');
console.log('[CombinedServer] Keyboard Controls:');
console.log('[CombinedServer]   B - Send single random bullet');
console.log('[CombinedServer]   C - Send center screen bullet'); 
console.log('[CombinedServer]   F - Toggle burst mode (20 bullets/second)');
console.log('[CombinedServer]   Arrow keys - Send directional commands');
console.log('[CombinedServer]   Enter - Send enter command');
console.log('[CombinedServer]   H - Homepage command');
console.log('[CombinedServer]   V - Volume up command');
console.log('[CombinedServer]   D - Volume down command');
console.log('[CombinedServer]   P - Power command');
console.log('[CombinedServer]   Ctrl+C - Exit');