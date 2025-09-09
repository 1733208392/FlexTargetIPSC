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
  { t: 630, x: 186, y: 361, a: 1069 },
  { t: 630, x: 190, y: 261, a: 1069 },
  { t: 630, x: 100, y: 200, a: 1069 }
];

const connectedClients = new Set();

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
    directive = 'enter';
  } else if (keyStr === 'B' || keyStr === 'b') { // B - send random data
    const randomData = randomDataOptions[Math.floor(Math.random() * randomDataOptions.length)];
    const randomDataPayload = {
      type: 'data',
      data: [randomData]
    };
    connectedClients.forEach(client => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify(randomDataPayload));
      }
    });
    console.log(`Sent random data: ${JSON.stringify(randomData)}`);
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
