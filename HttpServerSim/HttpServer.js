const http = require('http');
const fs = require('fs');
const url = require('url');

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;

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
        fs.writeFile(fileName, content, 'utf8', (err) => {
          if (err) {
            console.error('Error saving file:', err);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 1, msg: "Failed to save file" }));
          } else {
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
        fs.readFile(fileName, 'utf8', (err, content) => {
          if (err) {
            console.error('Error loading file:', err);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 0, data: "{}", msg: "OK" }));
          } else {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 0, data: content }));
          }
        });
      } catch (error) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON" }));
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

server.listen(80, () => {
  console.log('HTTP server listening on port 80');
});
