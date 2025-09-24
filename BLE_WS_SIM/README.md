# BLE_WS_SIM - Bluetooth-WebSocket Proxy Simulation

A unified proxy server that bridges communication between Mobile App (Bluetooth LE), Godot Game (WebSocket), and Low Level Hardware simulation.

## Architecture

```
Mobile App (BLE) ←→ BLE_WS_SIM ←→ Godot Game (WebSocket)
                        ↑
                 Low Level HW (Simulated)
```

## Features

### 1. **Low Level HW → Godot Game**
- Simulates hardware sending shot data to Godot via WebSocket
- Realistic bullet variance and timing
- Periodic shot data with random intervals

### 2. **Mobile App → Godot Game** 
- Receives BLE messages from Mobile App
- Forwards messages to Godot via WebSocket
- **Handles netlink device queries with mock responses**

### 3. **Godot Game → Mobile App**
- Receives WebSocket messages from Godot
- Forwards messages to Mobile App via BLE notifications
- **Handles netlink forward messages with format conversion**
- Bidirectional communication bridge

### 4. **Message Forwarding**
- **Bidirectional forwarding** between Godot (WebSocket) and Mobile App (BLE)
- **Netlink forward messages** with device targeting support
- **Transparent message routing** with format conversion when needed

## Configuration

- **BLE Device Name**: "BLE-WS-SIM Proxy"
- **BLE Service UUID**: `0000ffc9-0000-1000-8000-00805f9b34fb`
- **BLE Notify Characteristic**: `0000ffe1-0000-1000-8000-00805f9b34fb`
- **BLE Write Characteristic**: `0000ffe2-0000-1000-8000-00805f9b34fb`
- **WebSocket Port**: `8080`

## Usage

### Start the Proxy Server
```bash
cd BLE_WS_SIM
npm start
```

### Connect Clients
1. **Mobile App**: Scan for BLE device "BLE-WS-SIM Proxy" and connect
2. **Godot Game**: Connect WebSocket client to `ws://localhost:8080`

### Message Flow Examples

#### Mobile App → Godot
Mobile App sends via BLE Write:
```json
{"type": "netlink", "action": "query_device_list"}
```

Forwarded to Godot via WebSocket:
```json
{"type": "netlink", "action": "query_device_list"}
```

**Device List Query Response** (direct BLE response):
```json
{"type": "netlink", "action": "device_list", "data": [{"name": "A", "mode": "master"}, {"name": "B", "mode": "slave"}, {"name": "C", "mode": "slave"}]}
```

#### Godot → Mobile App (Forward)
Godot sends forward message via WebSocket:
```json
{"type": "netlink", "action": "forward", "device": "A", "content": {"command": "start"}}
```

Forwarded to Mobile App via BLE Notify:
```json
{"type": "netlink", "action": "forward", "device": "A", "content": {"command": "start"}}
```

#### Mobile App → Godot (Forward)
Mobile App sends forward message via BLE Write:
```json
{"type": "netlink", "action": "forward", "device": "all", "content": {"status": "ready"}}
```

Forwarded to Godot via WebSocket:
```json
{"type": "netlink", "data": {"status": "ready"}}
```

#### Netlink Message Forwarding
**Godot → Mobile App:**
- WebSocket: `{"type": "netlink", "data": <payload>}`
- BLE: `{"type": "netlink", "action": "forward", "device": "all", "content": <payload>}`

**Mobile App → Godot:**
- BLE: `{"type": "netlink", "action": "forward", "device": "<device_id>", "content": <payload>}`
- WebSocket: `{"type": "netlink", "data": <payload>}`

#### Godot → Mobile App (Netlink Forward)
Godot sends via WebSocket:
```json
{"type": "netlink", "data": {"command": "start_game", "level": 1}}
```

BLE_WS_SIM converts and forwards via BLE Notify:
```json
{"type": "netlink", "action": "forward", "device": "all", "content": {"command": "start_game", "level": 1}}
```

#### Mobile App → Godot (Netlink Forward)
Mobile App sends via BLE Write:
```json
{"type": "netlink", "action": "forward", "device": "A", "content": {"status": "ready", "score": 100}}
```

BLE_WS_SIM converts and forwards via WebSocket:
```json
{"type": "netlink", "data": {"status": "ready", "score": 100}}
```

#### Low Level HW → Godot
Automatic shot data simulation:
```json
{
  "type": "data",
  "data": [{"t": 630, "x": 134.2, "y": 238.2, "a": 1069}]
}
```

#### Remote Control Directives
Keyboard controls send menu control messages:
```json
{"type": "control", "directive": "homepage"}
{"type": "control", "directive": "up"}
{"type": "control", "directive": "enter"}
```

### Keyboard Controls

- **B**: Send single random bullet to Godot
- **C**: Send center screen bullet to Godot  
- **Arrow Keys**: Send directional commands (up/down/left/right)
- **Enter**: Send enter command
- **H**: Homepage command
- **V**: Volume up command
- **D**: Volume down command  
- **P**: Power command
- **Ctrl+C**: Exit server

## Development

The framework is established for message routing. Implement specific message payloads and protocols as needed for your application.

## Dependencies

- `@abandonware/bleno`: Bluetooth LE peripheral functionality
- `ws`: WebSocket server for Godot communication