// Simple WebSocket server in Node.js that sends periodic data
const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 8080 });

// const dataPayload = {
//   type: 'data',
//   data: [
//     { t: 630, x: 186, y: 361, a: 1069 },
//     ],
// };

const randomDataOptions = [
  { t: 630, x: 100, y: 200, a: 1069 },
  { t: 630, x: 40, y: 300, a: 1069 },
  { t: 630, x: 250, y: 300, a: 1069 },
  { t: 630, x: 200, y: 300, a: 1069 },
  { t: 630, x: 200, y: 200, a: 1069 },
  { t: 630, x: 200, y: 100, a: 1069 },
  { t: 630, x: 170, y: 200, a: 1069 },
  { t: 630, x: 134, y: 238.2, a: 1069 }// Center screen
];

const connectedClients = new Set();

// Bullet variance configuration for realistic shooting simulation
const BULLET_VARIANCE = {
  maxX: 10.0,  // Maximum horizontal variance in pixels (±10 pixels)
  maxY: 10.0,  // Maximum vertical variance in pixels (±10 pixels)
};

// Function to add realistic bullet variance
function addBulletVariance(bulletData) {
  // Create a copy to avoid modifying the original
  const variedBullet = { ...bulletData };
  
  // Add random variance using normal distribution approximation
  // Using Box-Muller transform for more realistic gaussian distribution
  const u1 = Math.random();
  const u2 = Math.random();
  const z0 = Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
  const z1 = Math.sqrt(-2 * Math.log(u1)) * Math.sin(2 * Math.PI * u2);
  
  // Apply variance (multiply by 0.33 to keep most shots within ±1 standard deviation)
  variedBullet.x = Math.round((bulletData.x + (z0 * BULLET_VARIANCE.maxX * 0.33)) * 10) / 10;
  variedBullet.y = Math.round((bulletData.y + (z1 * BULLET_VARIANCE.maxY * 0.33)) * 10) / 10;
  
  return variedBullet;
}

// Debounce mechanism for Enter key to prevent double firing
let lastEnterTime = 0;
const ENTER_DEBOUNCE_MS = 50; // 50ms debounce

// Burst mode configuration
let burstMode = false;
let burstInterval = null;
const BURST_RATE_MS = 50; // 50ms = 20 bullets per second (1000ms / 20)

wss.on('connection', function connection(ws) {
  console.log('Client connected');
  connectedClients.add(ws);

  // // Send initial data immediately
  // ws.send(JSON.stringify(dataPayload));

  // const interval = setInterval(() => {
  //   ws.send(JSON.stringify(dataPayload));
  // }, 1000); // send every 1 second

  ws.on('close', () => {
    // clearInterval(interval);
    connectedClients.delete(ws);
    console.log('Client disconnected');
  });
});

// Handle keyboard input
process.stdin.setRawMode(true);
process.stdin.resume();
process.stdin.on('data', (key) => {
  const keyStr = key.toString();
  let directive = null;
  if (keyStr === '\u001b[A') { // Up arrow
    directive = 'up';
  } else if (keyStr === '\u001b[B') { // Down arrow
    directive = 'down';
  } else if (keyStr === '\u001b[D') { // Left arrow
    directive = 'left';
  } else if (keyStr === '\u001b[C') { // Right arrow
    directive = 'right';
  } else if (keyStr === '\n' || keyStr === '\r') { // Enter key
    // Debounce Enter key to prevent double firing from \r\n sequence
    const now = Date.now();
    if (now - lastEnterTime > ENTER_DEBOUNCE_MS) {
      directive = 'enter';
      lastEnterTime = now;
    } else {
      return; // Skip duplicate Enter within debounce period
    }
  } else if (keyStr === 'B' || keyStr === 'b') { // B - send random data
    const randomData = randomDataOptions[Math.floor(Math.random() * randomDataOptions.length)];
    const variedData = addBulletVariance(randomData);
    const randomDataPayload = {
      type: 'data',
      data: [variedData]
    };
    connectedClients.forEach(client => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify(randomDataPayload));
      }
    });
    console.log(`Sent random data with variance: ${JSON.stringify(variedData)}`);
    return; // Don't send control message
  } else if (keyStr === 'C' || keyStr === 'c') { // C - send center screen bullet
    const centerData = { t: 630, x: 134, y: 238.2, a: 1069 };
    const variedCenterData = addBulletVariance(centerData);
    const centerDataPayload = {
      type: 'data',
      data: [variedCenterData]
    };
    connectedClients.forEach(client => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify(centerDataPayload));
      }
    });
    console.log(`Sent center screen bullet with variance: ${JSON.stringify(variedCenterData)}`);
    return; // Don't send control message
  } else if (keyStr === 'F' || keyStr === 'f') { // F - toggle burst mode (20 bullets/second)
    if (burstMode) {
      // Stop burst mode
      if (burstInterval) {
        clearInterval(burstInterval);
        burstInterval = null;
      }
      burstMode = false;
      console.log('Burst mode stopped');
    } else {
      // Start burst mode
      burstMode = true;
      burstInterval = setInterval(() => {
        const randomData = randomDataOptions[Math.floor(Math.random() * randomDataOptions.length)];
        const variedData = addBulletVariance(randomData);
        const randomDataPayload = {
          type: 'data',
          data: [variedData]
        };
        connectedClients.forEach(client => {
          if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify(randomDataPayload));
          }
        });
      }, BURST_RATE_MS);
      console.log(`Burst mode started - firing at 20 bullets/second (${BURST_RATE_MS}ms intervals)`);
    }
    return; // Don't send control message
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
    connectedClients.forEach(client => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify(controlMessage));
      }
    });
    console.log(`Sent control message: ${directive}`);
  }
});

console.log('WebSocket server running on ws://localhost:8080');
console.log('Controls:');
console.log('  B - Send single random bullet');
console.log('  C - Send center screen bullet');
console.log('  F - Toggle burst mode (20 bullets/second)');
console.log('  Arrow keys - Send directional commands');
console.log('  Enter - Send enter command');
console.log('  H - Homepage command');
console.log('  V - Volume up command');
console.log('  D - Volume down command');
console.log('  P - Power command');
console.log('  Ctrl+C - Exit');
