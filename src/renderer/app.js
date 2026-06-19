(function () {
const api = window.grafanaMenubar;

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

const alertsList = document.getElementById('alerts-list');
const alertsSummary = document.getElementById('alerts-summary');
const lastUpdated = document.getElementById('last-updated');

function formatDate(iso) {
  if (!iso) return 'Not updated';
  return new Date(iso).toLocaleString('en-US', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}

function severityClass(severity) {
  const value = (severity || 'unknown').toLowerCase();
  if (['critical', 'high', 'page'].includes(value)) return 'critical';
  if (['warning', 'warn', 'medium'].includes(value)) return 'warning';
  if (['low', 'info'].includes(value)) return 'low';
  return 'unknown';
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function hexToRgba(hex, alpha = 0.14) {
  const normalized = hex.replace('#', '');
  const r = parseInt(normalized.slice(0, 2), 16);
  const g = parseInt(normalized.slice(2, 4), 16);
  const b = parseInt(normalized.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function getCollapseMap() {
  try {
    return JSON.parse(sessionStorage.getItem('group-collapse') || '{}');
  } catch {
    return {};
  }
}

function setCollapseState(instanceId, collapsed) {
  const map = getCollapseMap();
  map[instanceId] = collapsed;
  sessionStorage.setItem('group-collapse', JSON.stringify(map));
}

function isGroupCollapsed(instanceId, hasAlerts, hasError) {
  const map = getCollapseMap();
  if (instanceId in map) return map[instanceId];
  return !(hasAlerts || hasError);
}

function bindGroupToggles() {
  alertsList.querySelectorAll('.group-header').forEach((button) => {
    button.addEventListener('click', () => {
      const group = button.closest('.group');
      const instanceId = group.dataset.instanceId;
      const collapsed = group.classList.toggle('collapsed');
      button.setAttribute('aria-expanded', String(!collapsed));
      setCollapseState(instanceId, collapsed);
    });
  });
}

function renderAlerts(snapshot = {}) {
  const groups = snapshot.groups ?? [];
  const totalCount = snapshot.totalCount ?? 0;
  const updated = snapshot.lastUpdated ?? null;
  const isLoading = Boolean(snapshot.isLoading);

  lastUpdated.textContent = isLoading
    ? 'Updating…'
    : `Last updated: ${formatDate(updated)}`;

  if (!groups.length) {
    alertsSummary.className = 'summary ok';
    alertsSummary.textContent = 'No instances. Open Settings to add Grafana.';
    alertsList.innerHTML = '<div class="empty">Add a Grafana instance</div>';
    return;
  }

  const errors = groups.filter((g) => g.error);
  if (totalCount === 0 && errors.length === 0) {
    alertsSummary.className = 'summary ok';
    alertsSummary.textContent = 'No active alerts across any instance';
  } else if (totalCount > 0) {
    alertsSummary.className = 'summary warn';
    alertsSummary.textContent = `${totalCount} active alert${totalCount === 1 ? '' : 's'}`;
  } else {
    alertsSummary.className = 'summary error';
    alertsSummary.textContent = 'Error fetching instances';
  }

  alertsList.innerHTML = groups
    .map((group) => {
      const color = group.instance.color || INSTANCE_COLORS[0];
      const hasAlerts = group.alerts.length > 0;
      const hasError = Boolean(group.error);
      const collapsed = isGroupCollapsed(group.instance.id, hasAlerts, hasError);
      const groupClass = ['group', hasAlerts ? 'has-alerts' : '', collapsed ? 'collapsed' : '']
        .filter(Boolean)
        .join(' ');

      const errorBlock = group.error
        ? `<div class="group-error">${escapeHtml(group.error)}</div>`
        : '';

      const alertsBlock =
        group.alerts.length === 0 && !group.error
          ? '<div class="empty">No active alerts</div>'
          : group.alerts
              .map(
                (alert) => `
          <div
            class="alert-item severity-${severityClass(alert.severity)}"
            style="border-left-color:${color};background:${hexToRgba(color, 0.1)}"
          >
            <div class="alert-title">
              ${
                severityClass(alert.severity) !== 'unknown'
                  ? `<span class="severity ${severityClass(alert.severity)}">${escapeHtml(alert.severity)}</span>`
                  : ''
              }
              ${escapeHtml(alert.alertName)}
            </div>
          </div>
        `,
              )
              .join('');

      return `
        <section class="${groupClass}" data-instance-id="${group.instance.id}" style="--instance-color:${color}">
          <button
            type="button"
            class="group-header"
            aria-expanded="${!collapsed}"
            style="border-left-color:${color};background:${hexToRgba(color, hasAlerts || hasError ? 0.18 : 0.08)}"
          >
            <span class="group-leading">
              <span class="group-chevron" aria-hidden="true">▾</span>
              <span class="group-color-dot" style="background:${color}"></span>
              <span class="group-name">${escapeHtml(group.instance.name)}</span>
            </span>
            <span class="group-count" style="${hasAlerts ? `background:${color}` : ''}">${group.alerts.length}</span>
          </button>
          <div class="group-body">
            ${errorBlock}
            ${alertsBlock}
          </div>
        </section>
      `;
    })
    .join('');

  bindGroupToggles();
}

document.getElementById('refresh-btn').addEventListener('click', async () => {
  renderAlerts(await api.refreshAlerts());
});

document.getElementById('settings-btn').addEventListener('click', () => {
  if (window.settingsPanel?.openSettings) {
    window.settingsPanel.openSettings();
    return;
  }
  const overlay = document.getElementById('settings-overlay');
  if (overlay) overlay.hidden = false;
});

async function init() {
  try {
    const snapshot = await api.getAlerts();
    renderAlerts(snapshot);
    api.onAlertsUpdated(renderAlerts);
  } catch (error) {
    lastUpdated.textContent = 'Failed to load';
    alertsSummary.className = 'summary error';
    alertsSummary.textContent = 'Could not load alerts';
    alertsList.innerHTML = `<div class="empty">${escapeHtml(error.message || 'Unknown error')}</div>`;
  }
}

init();
})();
