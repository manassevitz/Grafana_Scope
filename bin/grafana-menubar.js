#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');

const serviceCommand = process.argv.find(
  (arg) => arg === 'install-service' || arg === 'uninstall-service' || arg === 'status',
);

if (serviceCommand) {
  require('../devtools/launch-agent').run(serviceCommand);
  return;
}

const electronPath = require('electron');
const appPath = path.join(__dirname, '..');

const child = spawn(electronPath, [appPath], {
  stdio: 'inherit',
  env: process.env,
  detached: false,
});

child.on('close', (code) => {
  process.exit(code ?? 0);
});

child.on('error', (err) => {
  console.error('Could not start Grafana Menubar:', err.message);
  process.exit(1);
});
