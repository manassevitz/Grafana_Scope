const path = require('path');
const { app, ipcMain, nativeImage } = require('electron');
const { menubar } = require('menubar');
const config = require('./lib/config');
const grafana = require('./lib/grafana');

app.dock?.hide();

let mb;
let pollTimer = null;
let latestSnapshot = {
  groups: [],
  totalCount: 0,
  lastUpdated: null,
  isLoading: false,
};

function getIconPath() {
  return path.join(__dirname, '..', 'assets', 'iconTemplate.png');
}

function getPreloadPath() {
  return path.join(__dirname, 'preload.js');
}

function updateTrayTitle(totalCount, isLoading) {
  if (!mb?.tray) return;

  if (process.platform === 'darwin') {
    if (isLoading && totalCount === 0) {
      mb.tray.setTitle(' …');
    } else if (totalCount > 0) {
      mb.tray.setTitle(` ${totalCount}`);
    } else {
      mb.tray.setTitle('');
    }
  }
}

async function refreshAlerts() {
  const instances = config.getEnabledInstances();
  latestSnapshot = {
    ...latestSnapshot,
    isLoading: true,
  };
  updateTrayTitle(latestSnapshot.totalCount, true);
  broadcast('alerts-updated', latestSnapshot);

  try {
    if (instances.length === 0) {
      latestSnapshot = {
        groups: [],
        totalCount: 0,
        lastUpdated: new Date().toISOString(),
        isLoading: false,
      };
      return latestSnapshot;
    }

    const snapshot = await grafana.fetchAllAlerts(instances);
    latestSnapshot = {
      ...snapshot,
      isLoading: false,
    };
    return latestSnapshot;
  } catch (error) {
    latestSnapshot = {
      groups: instances.map((instance) => ({
        instance,
        alerts: [],
        error: error.message || 'Failed to refresh alerts',
      })),
      totalCount: 0,
      lastUpdated: new Date().toISOString(),
      isLoading: false,
    };
    return latestSnapshot;
  } finally {
    updateTrayTitle(latestSnapshot.totalCount, latestSnapshot.isLoading);
    broadcast('alerts-updated', latestSnapshot);
  }
}

function broadcast(channel, payload) {
  const window = mb?.window;
  if (window && !window.isDestroyed()) {
    window.webContents.send(channel, payload);
  }
}

function broadcastConfigUpdated() {
  broadcast('config-updated', config.getConfig());
}

function restartPolling() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }

  const { refreshIntervalSeconds } = config.getConfig();
  const intervalMs = Math.max(refreshIntervalSeconds, 15) * 1000;

  pollTimer = setInterval(() => {
    refreshAlerts().catch(() => {});
  }, intervalMs);
}

function registerIpc() {
  ipcMain.handle('get-alerts', async () => latestSnapshot);

  ipcMain.handle('refresh-alerts', async () => refreshAlerts());

  ipcMain.handle('get-config', async () => config.getConfig());

  ipcMain.handle('get-version', async () => app.getVersion());

  ipcMain.handle('save-config', async (_event, newConfig) => {
    const saved = config.saveConfig(newConfig);
    restartPolling();
    await refreshAlerts();
    broadcastConfigUpdated();
    return saved;
  });

  ipcMain.handle('add-instance', async (_event, instance) => {
    const created = config.addInstance(instance);
    restartPolling();
    await refreshAlerts();
    broadcastConfigUpdated();
    return created;
  });

  ipcMain.handle('update-instance', async (_event, { id, updates }) => {
    const updated = config.updateInstance(id, updates);
    restartPolling();
    await refreshAlerts();
    broadcastConfigUpdated();
    return updated;
  });

  ipcMain.handle('remove-instance', async (_event, id) => {
    config.removeInstance(id);
    restartPolling();
    await refreshAlerts();
    broadcastConfigUpdated();
    return config.getConfig();
  });

  ipcMain.handle('test-connection', async (_event, instance) => {
    try {
      await grafana.testConnection(instance);
      return { ok: true };
    } catch (error) {
      return { ok: false, error: error.message };
    }
  });

  ipcMain.handle('quit-app', async () => {
    app.quit();
  });
}

registerIpc();

mb = menubar({
  index: `file://${path.join(__dirname, 'renderer', 'index.html')}`,
  icon: getIconPath(),
  preloadWindow: true,
  showDockIcon: false,
  browserWindow: {
    width: 380,
    height: 520,
    resizable: false,
    show: false,
    webPreferences: {
      preload: getPreloadPath(),
      contextIsolation: true,
      nodeIntegration: false,
      scrollBounce: true,
    },
  },
});

mb.on('ready', () => {
  restartPolling();
  refreshAlerts().catch(() => {});

  if (mb.tray && process.platform === 'darwin') {
    const image = nativeImage.createFromPath(getIconPath());
    image.setTemplateImage(true);
    mb.tray.setImage(image);
  }
});

mb.on('after-show', () => {
  broadcast('alerts-updated', latestSnapshot);
});

app.on('before-quit', () => {
  if (pollTimer) clearInterval(pollTimer);
});
