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

const settingsOverlay = document.getElementById('settings-overlay');

const views = {
  root: document.getElementById('view-root'),
  instances: document.getElementById('view-instances'),
  interval: document.getElementById('view-interval'),
  form: document.getElementById('view-instance-form'),
};

let viewStack = ['root'];

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function showView(name) {
  for (const [key, element] of Object.entries(views)) {
    if (element) {
      element.classList.toggle('active', key === name);
    }
  }
}

function pushView(name) {
  viewStack.push(name);
  showView(name);
}

function popView() {
  if (viewStack.length <= 1) return;
  viewStack.pop();
  showView(viewStack[viewStack.length - 1]);
}

function resetNavigation() {
  viewStack = ['root'];
  showView('root');
}

function openSettings() {
  if (!settingsOverlay) return;
  resetNavigation();
  settingsOverlay.removeAttribute('hidden');
  loadRootData().catch(() => {});
}

function closeSettings() {
  if (!settingsOverlay) return;
  settingsOverlay.setAttribute('hidden', '');
  resetNavigation();
}

function setupColorPicker(selectedColor = INSTANCE_COLORS[0]) {
  const colorPicker = document.getElementById('instance-color-picker');
  const colorInput = document.getElementById('instance-color');
  if (!colorPicker || !colorInput) return;

  colorPicker.innerHTML = INSTANCE_COLORS.map(
    (color) => `
      <button
        type="button"
        class="color-swatch${color === selectedColor ? ' selected' : ''}"
        data-color="${color}"
        style="background:${color}"
      ></button>
    `,
  ).join('');

  colorPicker.innerHTML += `<input type="color" id="instance-color-custom" class="color-custom" value="${selectedColor}" />`;
  colorInput.value = selectedColor;

  colorPicker.querySelectorAll('.color-swatch').forEach((button) => {
    button.addEventListener('click', () => selectColor(button.dataset.color));
  });

  document.getElementById('instance-color-custom')?.addEventListener('input', (event) => {
    selectColor(event.target.value);
  });
}

function selectColor(color) {
  const colorInput = document.getElementById('instance-color');
  const colorPicker = document.getElementById('instance-color-picker');
  if (!colorInput || !colorPicker) return;

  colorInput.value = color;
  colorPicker.querySelectorAll('.color-swatch').forEach((button) => {
    button.classList.toggle('selected', button.dataset.color === color);
  });
}

function resetForm() {
  const instanceForm = document.getElementById('instance-form');
  const editId = document.getElementById('edit-id');
  const deleteInstanceBtn = document.getElementById('delete-instance-btn');
  const formStatus = document.getElementById('form-status');
  const formToolbarTitle = document.getElementById('form-toolbar-title');

  if (editId) editId.value = '';
  instanceForm?.reset();
  const enabled = document.getElementById('instance-enabled');
  if (enabled) enabled.checked = true;
  if (deleteInstanceBtn) deleteInstanceBtn.hidden = true;
  if (formStatus) {
    formStatus.textContent = '';
    formStatus.className = 'menu-status';
  }
  if (formToolbarTitle) formToolbarTitle.textContent = 'Add instance';
  setupColorPicker(INSTANCE_COLORS[0]);
}

function fillForm(instance) {
  const editId = document.getElementById('edit-id');
  const deleteInstanceBtn = document.getElementById('delete-instance-btn');
  const formToolbarTitle = document.getElementById('form-toolbar-title');

  if (editId) editId.value = instance.id;
  const name = document.getElementById('instance-name');
  const url = document.getElementById('instance-url');
  const token = document.getElementById('instance-token');
  const enabled = document.getElementById('instance-enabled');
  if (name) name.value = instance.name;
  if (url) url.value = instance.url;
  if (token) token.value = instance.apiToken;
  if (enabled) enabled.checked = instance.enabled;
  if (deleteInstanceBtn) deleteInstanceBtn.hidden = false;
  if (formToolbarTitle) formToolbarTitle.textContent = 'Edit instance';
  setupColorPicker(instance.color || INSTANCE_COLORS[0]);
  const formStatus = document.getElementById('form-status');
  if (formStatus) formStatus.textContent = '';
}

async function renderInstancesMenu() {
  const instancesMenuList = document.getElementById('instances-menu-list');
  if (!instancesMenuList || !api) return;

  const config = await api.getConfig();

  if (!config.instances.length) {
    instancesMenuList.innerHTML = '<div class="empty-menu">No instances configured</div>';
    return;
  }

  instancesMenuList.innerHTML = config.instances
    .map(
      (instance) => `
        <button type="button" class="instance-menu-item" data-edit="${instance.id}">
          <span class="instance-menu-dot" style="background:${escapeHtml(instance.color || INSTANCE_COLORS[0])}"></span>
          <span class="instance-menu-info">
            <strong>${escapeHtml(instance.name)}${instance.enabled ? '' : ' (off)'}</strong>
            <span>${escapeHtml(instance.url)}</span>
          </span>
          <span class="menu-chevron">›</span>
        </button>
      `,
    )
    .join('');
}

async function loadRootData() {
  if (!api) return;
  const version = await api.getVersion();
  const versionEl = document.getElementById('menu-version');
  if (versionEl) versionEl.textContent = `Grafana Menubar v${version}`;
  const config = await api.getConfig();
  const intervalInput = document.getElementById('refresh-interval');
  if (intervalInput) intervalInput.value = config.refreshIntervalSeconds;
}

async function saveInstance(event) {
  event.preventDefault();
  if (!api) return;

  const formStatus = document.getElementById('form-status');
  const editId = document.getElementById('edit-id');
  const colorInput = document.getElementById('instance-color');

  if (formStatus) formStatus.textContent = 'Saving…';

  const payload = {
    name: document.getElementById('instance-name')?.value || '',
    url: document.getElementById('instance-url')?.value || '',
    apiToken: document.getElementById('instance-token')?.value || '',
    enabled: document.getElementById('instance-enabled')?.checked ?? true,
    color: colorInput?.value || INSTANCE_COLORS[0],
  };

  if (editId?.value) {
    await api.updateInstance(editId.value, payload);
  } else {
    await api.addInstance(payload);
  }

  await renderInstancesMenu();
  popView();
  if (formStatus) formStatus.textContent = '';
}

async function handleSettingsClick(event) {
  const navButton = event.target.closest('[data-nav]');
  if (navButton) {
    if (!api) return;
    const target = navButton.dataset.nav;
    if (target === 'instances') {
      pushView('instances');
      try {
        await renderInstancesMenu();
      } catch (error) {
        const list = document.getElementById('instances-menu-list');
        if (list) {
          list.innerHTML = `<div class="empty-menu">${escapeHtml(error.message)}</div>`;
        }
      }
    }
    if (target === 'interval') {
      pushView('interval');
      try {
        const config = await api.getConfig();
        const intervalInput = document.getElementById('refresh-interval');
        if (intervalInput) intervalInput.value = config.refreshIntervalSeconds;
        const intervalStatus = document.getElementById('interval-status');
        if (intervalStatus) intervalStatus.textContent = '';
      } catch (error) {
        const intervalStatus = document.getElementById('interval-status');
        if (intervalStatus) {
          intervalStatus.textContent = error.message;
          intervalStatus.className = 'menu-status error';
        }
      }
    }
    return;
  }

  if (event.target.closest('[data-back]')) {
    popView();
    return;
  }

  if (event.target.closest('#menu-close')) {
    closeSettings();
    return;
  }

  if (event.target.closest('#add-instance-btn')) {
    resetForm();
    pushView('form');
    return;
  }

  if (event.target.closest('#menu-refresh')) {
    if (!api) return;
    await api.refreshAlerts();
    closeSettings();
    return;
  }

  if (event.target.closest('#menu-quit')) {
    if (!api) return;
    api.quitApp();
    return;
  }

  if (event.target.closest('#save-interval-btn')) {
    if (!api) return;
    const refreshIntervalSeconds = Number(document.getElementById('refresh-interval')?.value || 60);
    await api.saveConfig({ refreshIntervalSeconds });
    const intervalStatus = document.getElementById('interval-status');
    if (intervalStatus) {
      intervalStatus.textContent = 'Saved';
      intervalStatus.className = 'menu-status ok';
    }
    return;
  }

  if (event.target.closest('#test-btn')) {
    if (!api) return;
    const formStatus = document.getElementById('form-status');
    if (formStatus) formStatus.textContent = 'Testing…';
    const result = await api.testConnection({
      url: document.getElementById('instance-url')?.value || '',
      apiToken: document.getElementById('instance-token')?.value || '',
    });
    if (formStatus) {
      formStatus.textContent = result.ok ? 'Connection successful' : result.error;
      formStatus.className = `menu-status ${result.ok ? 'ok' : 'error'}`;
    }
    return;
  }

  if (event.target.closest('#delete-instance-btn')) {
    if (!api) return;
    const editId = document.getElementById('edit-id');
    if (!editId?.value) return;
    await api.removeInstance(editId.value);
    resetForm();
    await renderInstancesMenu();
    popView();
    return;
  }

  const editButton = event.target.closest('[data-edit]');
  if (editButton) {
    if (!api) return;
    const config = await api.getConfig();
    const instance = config.instances.find((item) => item.id === editButton.dataset.edit);
    if (instance) {
      fillForm(instance);
      pushView('form');
    }
  }
}

function initSettings() {
  document.getElementById('instance-form')?.addEventListener('submit', saveInstance);
  settingsOverlay?.addEventListener('click', (event) => {
    handleSettingsClick(event).catch((error) => {
      console.error('Settings action failed:', error);
    });
  });

  if (api) {
    api.onConfigUpdated(async () => {
      if (views.instances?.classList.contains('active')) {
        await renderInstancesMenu();
      }
    });
    loadRootData().catch(() => {});
  }
}

window.settingsPanel = { openSettings, closeSettings };
initSettings();
})();
