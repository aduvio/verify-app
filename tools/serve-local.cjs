// Stable origin for IndexedDB retention tests. No cloud service or deployment.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../build/web');
const host = '127.0.0.1';
const port = 8765;
const types = {'.html':'text/html', '.js':'application/javascript', '.json':'application/json',
  '.wasm':'application/wasm', '.css':'text/css', '.png':'image/png', '.ttf':'font/ttf'};
const server = http.createServer((req, res) => {
  let target;
  try { target = path.resolve(root, '.' + decodeURIComponent(new URL(req.url, `http://${host}:${port}`).pathname)); }
  catch { res.writeHead(400); res.end(); return; }
  if (target !== root && !target.startsWith(root + path.sep)) { res.writeHead(403); res.end(); return; }
  if (target === root || fs.existsSync(target) && fs.statSync(target).isDirectory()) target = path.join(target, 'index.html');
  fs.readFile(target, (error, data) => {
    if (error) { res.writeHead(404); res.end('Build first with flutter build web --no-pub.'); return; }
    res.writeHead(200, {'Content-Type': types[path.extname(target)] || 'application/octet-stream', 'Cache-Control':'no-store'});
    res.end(data);
  });
});
server.on('error', error => {
  console.error(`Cannot serve http://${host}:${port}/: ${error.code}. Keep this fixed port; check the existing local server instead of changing origin.`);
  process.exitCode = 1;
});
server.listen(port, host, () => console.log(`Project Verify local preview: http://${host}:${port}/`));
