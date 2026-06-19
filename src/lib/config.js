const Store = require('electron-store');
const { randomUUID } = require('crypto');

const store = new Store({
  name: 'grafana-menubar',
  defaults: {
    instances: [],
    refreshIntervalSeconds: 60,
  },
});

const INSTANCE_COLORS = [
  '#FF453A',
  '#FF9F0A',
  '#FFD60A',
  '#30D158',
  '#0A84FF',
  '#BF5AF2',
  '#FF375F',
  '#64D2FF',
];

function defaultColorForIndex(index) {
  return INSTANCE_COLORS[index % INSTANCE_COLORS.length];
}

function normalizeInstance(instance, index = 0) {
  return {
    ...instance,
    color: instance.color || defaultColorForIndex(index),
  };
}

function getInstances() {
  return store.get('instances').map((instance, index) => normalizeInstance(instance, index));
}

function getConfig() {
  return {
    instances: getInstances(),
    refreshIntervalSeconds: store.get('refreshIntervalSeconds'),
  };
}

function saveConfig(config) {
  if (config.instances !== undefined) {
    store.set('instances', config.instances);
  }
  if (config.refreshIntervalSeconds !== undefined) {
    store.set('refreshIntervalSeconds', config.refreshIntervalSeconds);
  }
  return getConfig();
}

function addInstance({ name, url, apiToken, enabled = true, color }) {
  const instances = store.get('instances');
  const instance = normalizeInstance({
    id: randomUUID(),
    name: name.trim(),
    url: normalizeUrl(url),
    apiToken: apiToken.trim(),
    enabled,
    color: color || defaultColorForIndex(instances.length),
  }, instances.length);
  instances.push(instance);
  store.set('instances', instances);
  return instance;
}

function updateInstance(id, updates) {
  const instances = store.get('instances');
  const index = instances.findIndex((item) => item.id === id);
  if (index === -1) return null;

  instances[index] = normalizeInstance({
    ...instances[index],
    ...updates,
    id,
    url: updates.url ? normalizeUrl(updates.url) : instances[index].url,
  }, index);
  store.set('instances', instances);
  return instances[index];
}

function removeInstance(id) {
  const instances = store.get('instances').filter((item) => item.id !== id);
  store.set('instances', instances);
}

function getEnabledInstances() {
  return getInstances().filter((item) => item.enabled);
}

function normalizeUrl(url) {
  return url.trim().replace(/\/+$/, '');
}

module.exports = {
  getConfig,
  saveConfig,
  addInstance,
  updateInstance,
  removeInstance,
  getEnabledInstances,
  INSTANCE_COLORS,
  defaultColorForIndex,
};
