// BLE_WS_SIM - Proxy server between Mobile App (BLE), Godot Game (WebSocket), and Low Level HW
const bleno = require('@abandonware/bleno');
const WebSocket = require('ws');

// BLE Configuration
const SERVICE_UUID = '0000ffc9-0000-1000-8000-00805f9b34fb';
const NOTIFY_CHARACTERISTIC_UUID = '0000ffe1-0000-1000-8000-00805f9b34fb';
const WRITE_CHARACTERISTIC_UUID = '0000ffe2-0000-1000-8000-00805f9b34fb';

// WebSocket Configuration
const WS_PORT = 8080;

// Global state management
let mobileAppBLEClient = null;
let godotWSClient = null;
const connectedGodotClients = new Set();

console.log('[BLE_WS_SIM] Starting BLE-WebSocket Proxy Simulation...');

// ============================================================================
// WEBSOCKET SERVER (for Godot Game communication)
// ============================================================================

const wss = new WebSocket.Server({ port: WS_PORT });

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
  console.log(`[BLE_WS_SIM] WebSocket server listening on port ${WS_PORT}`);
});

wss.on('connection', (ws) => {
  console.log('[BLE_WS_SIM] Godot client connected via WebSocket');
  connectedGodotClients.add(ws);
  godotWSClient = ws; // Keep reference to latest client

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message.toString());
      console.log('[BLE_WS_SIM] Received from Godot:', data);
      
      // Handle netlink forward messages from Godot to Mobile App
      if (data.type === 'netlink' && data.action === 'forward') {
        console.log('[BLE_WS_SIM] Forwarding netlink forward message from Godot to Mobile App');
        forwardToMobileApp(data);
      } else {
        // Forward other messages from Godot to Mobile App via BLE
        forwardToMobileApp(data);
      }
    } catch (error) {
      console.log('[BLE_WS_SIM] Invalid JSON from Godot:', error.message);
    }
  });

  ws.on('close', () => {
    console.log('[BLE_WS_SIM] Godot client disconnected');
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
      console.log('[BLE_WS_SIM] Manual bullet sent via keyboard');
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
      console.log('[BLE_WS_SIM] Center bullet sent via keyboard');
    }
    return;
  } else if (keyStr === '\u001B[A') { // Arrow Up
    directive = 'up';
  } else if (keyStr === '\u001B[B') { // Arrow Down
    directive = 'down';
  } else if (keyStr === '\u001B[C') { // Arrow Right
    directive = 'right';
  } else if (keyStr === '\u001B[D') { // Arrow Left
    directive = 'left';
  } else if (keyStr === '\r') { // Enter
    directive = 'enter';
  } else if (keyStr === 'H' || keyStr === 'h') { // H - homepage
    directive = 'homepage';
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
    console.log(`[BLE_WS_SIM] Sent control directive: ${directive}`);
  }
  });
}

// Function to send data to Godot clients
function sendToGodot(data) {
  const message = JSON.stringify(data);
  connectedGodotClients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
      console.log('[BLE_WS_SIM] Sent to Godot:', message);
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
    console.log('[BLE_WS_SIM] Mobile App read request on notify characteristic');
    callback(bleno.Characteristic.RESULT_SUCCESS, this._value);
  }

  onSubscribe(maxValueSize, updateValueCallback) {
    console.log('[BLE_WS_SIM] Mobile App subscribed to BLE notifications');
    this._updateValueCallback = updateValueCallback;
    mobileAppBLEClient = this;
  }

  onUnsubscribe() {
    console.log('[BLE_WS_SIM] Mobile App unsubscribed from BLE notifications');
    this._updateValueCallback = null;
    mobileAppBLEClient = null;
  }

  // Method to send data to Mobile App
  sendToMobileApp(data) {
    if (this._updateValueCallback) {
      this._value = Buffer.from(JSON.stringify(data));
      this._updateValueCallback(this._value);
      console.log('[BLE_WS_SIM] Sent to Mobile App via BLE:', JSON.stringify(data));
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
  }

  onWriteRequest(data, offset, withoutResponse, callback) {
    const receivedData = data.toString('utf8');
    console.log('[BLE_WS_SIM] Received from Mobile App via BLE:', receivedData);

    try {
      const parsedData = JSON.parse(receivedData);
      
      // Handle netlink forward messages from Mobile App to Godot
      if (parsedData.type === 'netlink' && parsedData.action === 'forward' && parsedData.content) {
        console.log('[BLE_WS_SIM] Forwarding netlink message from Mobile App to Godot');
        const wsMessage = {
          type: 'netlink',
          data: parsedData.content
        };
        sendToGodot(wsMessage);
      } else {
        // Forward other messages from Mobile App to Godot via WebSocket
        sendToGodot(parsedData);
      }
      
      // Handle specific commands
      if (parsedData.type === 'netlink' && parsedData.action === 'query_device_list') {
        console.log('[BLE_WS_SIM] Processing query_device_list from Mobile App');
        const response = {
          type: 'netlink',
          action: 'device_list',
          data: [
            { name: 'A', mode: 'master' },
            { name: 'B', mode: 'slave' },
            { name: 'C', mode: 'slave' }
          ]
        };
        
        // Send response back to Mobile App
        if (this.notifyCharacteristic) {
          this.notifyCharacteristic.sendToMobileApp(response);
          console.log('[BLE_WS_SIM] Sent device_list response to Mobile App');
        } else {
          console.log('[BLE_WS_SIM] Cannot send device_list response: notify characteristic not available');
        }
      }

    } catch (error) {
      console.log('[BLE_WS_SIM] Failed to parse BLE data from Mobile App:', error.message);
    }

    callback(bleno.Characteristic.RESULT_SUCCESS);
  }
}

// Function to forward data from Godot to Mobile App
function forwardToMobileApp(data) {
  if (mobileAppBLEClient) {
    mobileAppBLEClient.sendToMobileApp(data);
  } else {
    console.log('[BLE_WS_SIM] No Mobile App connected via BLE to forward message');
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

// BLE event handlers
bleno.on('stateChange', (state) => {
  console.log('[BLE_WS_SIM] BLE state change:', state);

  if (state === 'poweredOn') {
    bleno.startAdvertising('BLE-WS-SIM Proxy', [SERVICE_UUID]);
  } else {
    bleno.stopAdvertising();
  }
});

bleno.on('advertisingStart', (error) => {
  console.log('[BLE_WS_SIM] BLE advertising started:', error ? error : 'success');

  if (!error) {
    bleno.setServices([bleService]);
  }
});

bleno.on('accept', (clientAddress) => {
  console.log('[BLE_WS_SIM] Mobile App connected via BLE:', clientAddress);
});

bleno.on('disconnect', (clientAddress) => {
  console.log('[BLE_WS_SIM] Mobile App disconnected from BLE:', clientAddress);
});

// ============================================================================
// STARTUP AND LOGGING
// ============================================================================

console.log('[BLE_WS_SIM] Configuration:');
console.log('[BLE_WS_SIM] - BLE Service UUID:', SERVICE_UUID);
console.log('[BLE_WS_SIM] - BLE Notify Characteristic UUID:', NOTIFY_CHARACTERISTIC_UUID);
console.log('[BLE_WS_SIM] - BLE Write Characteristic UUID:', WRITE_CHARACTERISTIC_UUID);
console.log('[BLE_WS_SIM] - WebSocket Server Port:', WS_PORT);
console.log('[BLE_WS_SIM] ');
console.log('[BLE_WS_SIM] Proxy Functions:');
console.log('[BLE_WS_SIM] 1. Low Level HW → WebSocket → Godot Game');
console.log('[BLE_WS_SIM] 2. Mobile App → BLE → WebSocket → Godot Game');
console.log('[BLE_WS_SIM] 3. Godot Game → WebSocket → BLE → Mobile App');
console.log('[BLE_WS_SIM] ');
console.log('[BLE_WS_SIM] Keyboard Controls:');
console.log('[BLE_WS_SIM]   B - Send single random bullet');
console.log('[BLE_WS_SIM]   C - Send center screen bullet'); 
console.log('[BLE_WS_SIM]   Arrow keys - Send directional commands');
console.log('[BLE_WS_SIM]   Enter - Send enter command');
console.log('[BLE_WS_SIM]   H - Homepage command');
console.log('[BLE_WS_SIM]   V - Volume up command');
console.log('[BLE_WS_SIM]   D - Volume down command');
console.log('[BLE_WS_SIM]   P - Power command');
console.log('[BLE_WS_SIM]   Ctrl+C - Exit');