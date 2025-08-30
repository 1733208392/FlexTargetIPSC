// Simple WebSocket server in Node.js that sends periodic data
const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 8080 });

const dataPayload = {
  type: 'data',
  data: [
    { t: 630, x: 134, y: 233, a: 1069 },
    ],
};

wss.on('connection', function connection(ws) {
  console.log('Client connected');
  const interval = setInterval(() => {
    ws.send(JSON.stringify(dataPayload));
  }, 1000); // send every 1 second

  // Simulate control messages with 2s pause between each, repeat forever
  const controlMessages = [
    { type: 'control', directive: 'down' },
    { type: 'control', directive: 'down' },
    { type: 'control', directive: 'up' },
    { type: 'control', directive: 'up' },
    { type: 'control', directive: 'enter' }
  ];
  let controlIndex = 0;
  function sendNextControl() {
    ws.send(JSON.stringify(controlMessages[controlIndex]));
    controlIndex = (controlIndex + 1) % controlMessages.length;
    setTimeout(sendNextControl, 2000);
  }
  sendNextControl();

  ws.on('close', () => {
    clearInterval(interval);
    console.log('Client disconnected');
  });
});

console.log('WebSocket server running on ws://localhost:8080');
