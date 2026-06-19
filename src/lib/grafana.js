function normalizeAlert(alert, instance, index) {
  const labels = alert.labels || {};
  const annotations = alert.annotations || {};
  const state = alert.status?.state || 'active';
  const fingerprint =
    labels.fingerprint || labels.alertname || `${instance.id}-${index}`;

  return {
    id: `${instance.id}-${fingerprint}`,
    instanceId: instance.id,
    instanceName: instance.name,
    alertName: labels.alertname || 'Unnamed',
    summary: annotations.summary || annotations.message || labels.alertname || 'No summary',
    description: annotations.description || '',
    severity: labels.severity || labels.priority || 'unknown',
    state,
    startsAt: alert.startsAt || null,
    labels,
    isFiring: ['active', 'firing'].includes(state.toLowerCase()),
  };
}

async function fetchActiveAlerts(instance) {
  const baseUrl = instance.url.replace(/\/+$/, '');
  const url = new URL(`${baseUrl}/api/alertmanager/grafana/api/v2/alerts`);
  url.searchParams.set('active', 'true');
  url.searchParams.set('silenced', 'false');
  url.searchParams.set('inhibited', 'false');

  const response = await fetch(url, {
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${instance.apiToken}`,
    },
    signal: AbortSignal.timeout(15000),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    throw new Error(`HTTP ${response.status}: ${body || response.statusText}`);
  }

  const data = await response.json();
  if (!Array.isArray(data)) {
    throw new Error('Unexpected response from Grafana');
  }

  return data
    .map((alert, index) => normalizeAlert(alert, instance, index))
    .filter((alert) => alert.isFiring);
}

async function testConnection(instance) {
  const baseUrl = instance.url.replace(/\/+$/, '');
  const response = await fetch(`${baseUrl}/api/health`, {
    headers: {
      Authorization: `Bearer ${instance.apiToken}`,
    },
    signal: AbortSignal.timeout(10000),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    throw new Error(`HTTP ${response.status}: ${body || response.statusText}`);
  }
}

async function fetchAllAlerts(instances) {
  const results = await Promise.all(
    instances.map(async (instance) => {
      try {
        const alerts = await fetchActiveAlerts(instance);
        return { instance, alerts, error: null };
      } catch (error) {
        return {
          instance,
          alerts: [],
          error: error.message || 'Unknown error',
        };
      }
    }),
  );

  results.sort((a, b) => a.instance.name.localeCompare(b.instance.name, 'en'));

  const totalCount = results.reduce((sum, group) => sum + group.alerts.length, 0);

  return {
    groups: results,
    totalCount,
    lastUpdated: new Date().toISOString(),
  };
}

module.exports = {
  fetchActiveAlerts,
  fetchAllAlerts,
  testConnection,
};
