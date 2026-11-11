const http = require('http');
const fs = require('fs');
const path = require('path');
const { DatabaseSync } = require('node:sqlite');

const PORT = process.env.PORT || 8080;
const DB_FILE = path.join(__dirname, 'local_dev.db');
const FRONTEND_DIR = path.join(__dirname, 'frontend', 'src');

// Initialize SQLite database
const db = new DatabaseSync(DB_FILE);

db.exec(`
  CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TEXT NOT NULL
  );
`);

// Seed default tasks if empty
const countStmt = db.prepare('SELECT COUNT(*) as count FROM tasks');
const countRow = countStmt.get();
if (countRow.count === 0) {
  const insertTask = db.prepare(
    'INSERT INTO tasks (content, status, created_at) VALUES (?, ?, ?)'
  );
  insertTask.run('Provision AKS Cluster via Terraform', 'done', new Date().toISOString());
  insertTask.run('Configure GitHub Actions CI/CD Pipeline', 'done', new Date().toISOString());
  insertTask.run('Setup Prometheus & Grafana Monitoring', 'pending', new Date().toISOString());
  insertTask.run('Verify Nginx Reverse Proxy Routing', 'pending', new Date().toISOString());
}

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Origin, Content-Type, Authorization');
}

function sendJson(res, statusCode, data) {
  setCors(res);
  res.writeHead(statusCode, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data));
}

function parseJsonBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      if (!body.trim()) return resolve({});
      try {
        resolve(JSON.parse(body));
      } catch (err) {
        reject(err);
      }
    });
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  setCors(res);

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const parsedUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  let pathname = parsedUrl.pathname;

  // Normalize /api prefix if present
  let apiPath = pathname;
  if (apiPath.startsWith('/api')) {
    apiPath = apiPath.slice(4) || '/';
  }

  // --- API Routes ---

  // GET / or /api/
  if ((pathname === '/' || pathname === '/api/' || pathname === '/api') && req.headers.accept?.includes('application/json')) {
    return sendJson(res, 200, { message: 'Hello World v2' });
  }

  // Tasks API
  if (apiPath === '/tasks') {
    if (req.method === 'GET') {
      const stmt = db.prepare('SELECT id, content, status, created_at FROM tasks ORDER BY id ASC');
      const rows = stmt.all();
      return sendJson(res, 200, {
        success: true,
        message: 'List Data Posts',
        data: rows
      });
    }

    if (req.method === 'POST') {
      try {
        const body = await parseJsonBody(req);
        if (!body.content || !body.status) {
          return sendJson(res, 400, {
            errors: [
              { field: 'Content', message: 'Content is required' },
              { field: 'Status', message: 'Status is required' }
            ]
          });
        }
        const createdAt = new Date().toISOString();
        const stmt = db.prepare('INSERT INTO tasks (content, status, created_at) VALUES (?, ?, ?)');
        const result = stmt.run(body.content, body.status, createdAt);
        const task = {
          id: Number(result.lastInsertRowid),
          content: body.content,
          status: body.status,
          created_at: createdAt
        };
        return sendJson(res, 201, {
          success: true,
          message: 'Task created successfully',
          data: task
        });
      } catch (e) {
        return sendJson(res, 400, { error: 'Invalid JSON payload' });
      }
    }
  }

  // Match /tasks/:id
  const taskMatch = apiPath.match(/^\/tasks\/(\d+)$/);
  if (taskMatch) {
    const taskId = Number(taskMatch[1]);

    if (req.method === 'GET') {
      const stmt = db.prepare('SELECT id, content, status, created_at FROM tasks WHERE id = ?');
      const task = stmt.get(taskId);
      if (!task) {
        return sendJson(res, 400, { error: 'Record not found!' });
      }
      return sendJson(res, 200, {
        success: true,
        message: `Detail Data Post By ID : ${taskId}`,
        data: task
      });
    }

    if (req.method === 'PUT') {
      try {
        const body = await parseJsonBody(req);
        const getStmt = db.prepare('SELECT id, content, status, created_at FROM tasks WHERE id = ?');
        const task = getStmt.get(taskId);
        if (!task) {
          return sendJson(res, 400, { error: 'Record not found' });
        }

        const newContent = body.content !== undefined ? body.content : task.content;
        const newStatus = body.status !== undefined ? body.status : task.status;

        const updateStmt = db.prepare('UPDATE tasks SET content = ?, status = ? WHERE id = ?');
        updateStmt.run(newContent, newStatus, taskId);

        return sendJson(res, 200, {
          success: true,
          message: 'Task Updated Successfully',
          data: {
            id: taskId,
            content: newContent,
            status: newStatus,
            created_at: task.created_at
          }
        });
      } catch (e) {
        return sendJson(res, 400, { error: 'Invalid JSON payload' });
      }
    }

    if (req.method === 'DELETE') {
      const getStmt = db.prepare('SELECT id FROM tasks WHERE id = ?');
      const task = getStmt.get(taskId);
      if (!task) {
        return sendJson(res, 400, { error: 'Record not found' });
      }
      const deleteStmt = db.prepare('DELETE FROM tasks WHERE id = ?');
      deleteStmt.run(taskId);

      return sendJson(res, 200, {
        success: true,
        message: 'Task Deleted Successfully'
      });
    }
  }

  // Users API
  if (apiPath === '/users') {
    if (req.method === 'GET') {
      const stmt = db.prepare('SELECT id, username, created_at FROM users');
      const users = stmt.all();
      return sendJson(res, 200, {
        success: true,
        message: 'List Data Users',
        data: users
      });
    }

    if (req.method === 'POST') {
      try {
        const body = await parseJsonBody(req);
        if (!body.username || !body.password) {
          return sendJson(res, 400, { error: 'Username and password required' });
        }
        const createdAt = new Date().toISOString();
        const stmt = db.prepare('INSERT INTO users (username, password_hash, created_at) VALUES (?, ?, ?)');
        const result = stmt.run(body.username, 'mock_hash_' + body.password, createdAt);
        return sendJson(res, 201, {
          success: true,
          message: 'User created successfully',
          data: {
            id: Number(result.lastInsertRowid),
            username: body.username,
            created_at: createdAt
          }
        });
      } catch (err) {
        return sendJson(res, 400, { error: err.message });
      }
    }
  }

  // Health check / root message
  if (apiPath === '/' && req.method === 'GET') {
    // If browser requesting HTML, serve frontend
    if (req.headers.accept?.includes('text/html')) {
      const htmlFile = path.join(FRONTEND_DIR, 'index.html');
      if (fs.existsSync(htmlFile)) {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        return fs.createReadStream(htmlFile).pipe(res);
      }
    }
    return sendJson(res, 200, { message: 'Hello World v2' });
  }

  // --- Static Files ---
  let safePath = path.normalize(pathname).replace(/^(\.\.[\/\\])+/, '');
  if (safePath === '/' || safePath === '\\') safePath = '/index.html';
  const filePath = path.join(FRONTEND_DIR, safePath);

  if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
    const ext = path.extname(filePath).toLowerCase();
    const mimeTypes = {
      '.html': 'text/html; charset=utf-8',
      '.css': 'text/css',
      '.js': 'application/javascript',
      '.json': 'application/json',
      '.png': 'image/png',
      '.svg': 'image/svg+xml'
    };
    res.writeHead(200, { 'Content-Type': mimeTypes[ext] || 'application/octet-stream' });
    return fs.createReadStream(filePath).pipe(res);
  }

  // Fallback to index.html for single page app routing
  const fallbackHtml = path.join(FRONTEND_DIR, 'index.html');
  if (fs.existsSync(fallbackHtml)) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    return fs.createReadStream(fallbackHtml).pipe(res);
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not Found');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`====================================================`);
  console.log(`CloudOps Platform Local Server running!`);
  console.log(`- Frontend UI:  http://localhost:${PORT}`);
  console.log(`- Tasks API:    http://localhost:${PORT}/api/tasks`);
  console.log(`- Health Check: http://localhost:${PORT}/api/`);
  console.log(`====================================================`);
});
