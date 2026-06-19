const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('grafanaMenubar', {
  getAlerts: () => ipcRenderer.invoke('get-alerts'),
  refreshAlerts: () => ipcRenderer.invoke('refresh-alerts'),
  getConfig: () => ipcRenderer.invoke('get-config'),
  getVersion: () => ipcRenderer.invoke('get-version'),
  saveConfig: (config) => ipcRenderer.invoke('save-config', config),
  addInstance: (instance) => ipcRenderer.invoke('add-instance', instance),
  updateInstance: (id, updates) => ipcRenderer.invoke('update-instance', { id, updates }),
  removeInstance: (id) => ipcRenderer.invoke('remove-instance', id),
  testConnection: (instance) => ipcRenderer.invoke('test-connection', instance),
  quitApp: () => ipcRenderer.invoke('quit-app'),
  onAlertsUpdated: (callback) => {
    const listener = (_event, payload) => callback(payload);
    ipcRenderer.on('alerts-updated', listener);
    return () => ipcRenderer.removeListener('alerts-updated', listener);
  },
  onConfigUpdated: (callback) => {
    const listener = (_event, payload) => callback(payload);
    ipcRenderer.on('config-updated', listener);
    return () => ipcRenderer.removeListener('config-updated', listener);
  },
});
