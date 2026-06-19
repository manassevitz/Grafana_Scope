const fs = require('fs');
const path = require('path');

require('./create-icon');

const binPath = path.join(__dirname, '..', 'bin', 'grafana-menubar.js');

try {
  fs.chmodSync(binPath, 0o755);
} catch {
  // Ignore on environments where chmod does not apply
}
