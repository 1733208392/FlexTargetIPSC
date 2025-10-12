const http = require('http');
const fs = require('fs');
const url = require('url');

// Netlink state variables
let netlinkStarted = false;
let netlinkChannel = 0;
let netlinkWorkMode = null;
let netlinkDeviceName = null;
let netlinkBluetoothName = null;
let netlinkWifiIp = "192.168.1.100"; // Mock IP for simulation

const server = http.createServer((req, res) => {
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
    const ssidList = ["cjyw", "cjyw2", "cjyw5G"];
    console.log(`[HttpServer] Starting WiFi scan simulation (15s delay)...`);
    // Simulate 15 second delay for WiFi scanning
    setTimeout(() => {
      console.log(`[HttpServer] WiFi scan completed`);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ code: 0, msg: "", data: { ssid_list: ssidList } }));
    }, 15000);
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

        // Simulate WiFi connection - always succeed for simulation
        console.log(`[HttpServer] Connecting to WiFi: SSID=${ssid}`);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 0, msg: '' }));
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

        // Simulate configuration - always succeed for simulation
        console.log(`[HttpServer] Configuring netlink: channel=${channel}, work_mode=${work_mode}, device_name=${device_name}`);
        
        // Store the configuration
        netlinkChannel = channel;
        netlinkWorkMode = work_mode;
        netlinkDeviceName = device_name;
        netlinkBluetoothName = device_name; // Use device_name as bluetooth_name for simulation
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 0, msg: "Configuration successful" }));
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
    /*
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
    */
    // Simulate started=false scenario
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      code: 0,
      msg: "",
      data: {
        wifi_ip: netlinkWifiIp,
        channel: 0,
        work_mode: null,
        device_name: null,
        bluetooth_name: null,
        started: false
      }
    }));
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

server.listen(80, () => {
  console.log('HTTP server listening on port 80');
});
