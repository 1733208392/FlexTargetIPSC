const WebSocket = require('ws');

const ws = new WebSocket('ws://localhost:8080');

ws.on('open', function open() {
    console.log('Connected to BLE_WS_SIM server');

    // Send a forward message from Godot to Mobile App
    const forwardMessage = {
        type: 'netlink',
        action: 'forward',
        data: {
            message: 'Hello from Godot!',
            timestamp: Date.now()
        }
    };

    console.log('Sending forward message:', JSON.stringify(forwardMessage, null, 2));
    ws.send(JSON.stringify(forwardMessage));
});

ws.on('message', function incoming(data) {
    console.log('Received from server:', data.toString());
});

ws.on('error', function error(err) {
    console.error('WebSocket error:', err);
});

ws.on('close', function close() {
    console.log('Disconnected from server');
});