const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

const LABEL = 'com.grafana.menubar';
const LOG_PATH = path.join(os.homedir(), 'Library', 'Logs', 'grafana-menubar.log');
const PLIST_PATH = path.join(os.homedir(), 'Library', 'LaunchAgents', `${LABEL}.plist`);

function getAppRoot() {
  return path.join(__dirname, '..');
}

function getElectronPath() {
  return require('electron');
}

function launchctlTarget() {
  return `gui/${process.getuid()}`;
}

function buildPlist(appRoot, electronPath) {
  const args = [
    electronPath,
    appRoot,
  ].map((value) => `\n    <string>${value}</string>`).join('');

  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>${args}
  </array>
  <key>WorkingDirectory</key>
  <string>${appRoot}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>ProcessType</key>
  <string>Interactive</string>
  <key>StandardOutPath</key>
  <string>${LOG_PATH}</string>
  <key>StandardErrorPath</key>
  <string>${LOG_PATH}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
</dict>
</plist>
`;
}

function isLoaded() {
  try {
    execSync(`launchctl print ${launchctlTarget()}/${LABEL}`, { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

function loadAgent() {
  try {
    execSync(`launchctl bootstrap ${launchctlTarget()} "${PLIST_PATH}"`, { stdio: 'inherit' });
  } catch {
    execSync(`launchctl load -w "${PLIST_PATH}"`, { stdio: 'inherit' });
  }
}

function unloadAgent() {
  try {
    execSync(`launchctl bootout ${launchctlTarget()}/${LABEL}`, { stdio: 'inherit' });
  } catch {
    try {
      execSync(`launchctl unload -w "${PLIST_PATH}"`, { stdio: 'inherit' });
    } catch {
      // Already unloaded
    }
  }
}

function ensureMacOS() {
  if (process.platform !== 'darwin') {
    console.error('LaunchAgent is only supported on macOS.');
    process.exit(1);
  }
}

function install() {
  ensureMacOS();

  const appRoot = path.resolve(getAppRoot());
  const electronPath = getElectronPath();

  if (!fs.existsSync(electronPath)) {
    console.error('Electron not found. Run npm install first.');
    process.exit(1);
  }

  fs.mkdirSync(path.dirname(PLIST_PATH), { recursive: true });
  fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });

  if (isLoaded()) {
    unloadAgent();
  }

  fs.writeFileSync(PLIST_PATH, buildPlist(appRoot, electronPath), 'utf8');
  loadAgent();

  console.log(`LaunchAgent installed: ${PLIST_PATH}`);
  console.log(`Logs: ${LOG_PATH}`);
  console.log('The app starts at login and is independent of Terminal.');
}

function uninstall() {
  ensureMacOS();

  if (isLoaded()) {
    unloadAgent();
  }

  if (fs.existsSync(PLIST_PATH)) {
    fs.unlinkSync(PLIST_PATH);
  }

  console.log('LaunchAgent removed.');
}

function status() {
  ensureMacOS();

  if (fs.existsSync(PLIST_PATH)) {
    console.log(`Plist: ${PLIST_PATH}`);
  } else {
    console.log('Plist: not installed');
  }

  console.log(`Loaded: ${isLoaded() ? 'yes' : 'no'}`);
  console.log(`Logs: ${LOG_PATH}`);
}

function run(command) {
  switch (command) {
    case 'install':
    case 'install-service':
      install();
      break;
    case 'uninstall':
    case 'uninstall-service':
      uninstall();
      break;
    case 'status':
      status();
      break;
    default:
      console.error(`Unknown command: ${command}`);
      console.error('Usage: install-service | uninstall-service | status');
      process.exit(1);
  }
}

module.exports = { install, uninstall, status, run };

if (require.main === module) {
  run(process.argv[2]);
}
