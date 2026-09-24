const fs = require('node:fs');
const path = require('node:path');
const {
  APP_ID,
  serverConfig,
  trustedUrl,
  trustedSender,
  audioPermission,
  incomingPayload,
  clearPayload,
  floatingState,
  floatingCommand,
  contactUrl,
  externalUrl,
  notificationGate,
} = require('./policy.cjs');

function startDesktop(
  electron,
  {
    argv = process.argv,
    env = process.env,
    fileSystem = fs,
    timers = { setTimeout, clearTimeout },
  } = {}
) {
  const {
    app,
    BrowserWindow,
    Menu,
    nativeImage,
    Notification,
    Tray,
    ipcMain,
    shell,
    dialog,
  } = electron;
  if (!app.requestSingleInstanceLock()) {
    app.quit();
    return;
  }
  app.setAppUserModelId(APP_ID);
  let mainWindow;
  let floatingWindow;
  let latestFloatingState;
  let tray;
  let config;
  let quitting = false;
  let finalQuit = false;
  let shutdownTimer;
  let notification;
  let pendingCallId;
  let recoveryTimer;
  let stabilityTimer;
  let recoveryAttempt = 0;
  let unavailable = true;
  let loading = false;
  let lastExternalOpen = -Infinity;
  const permitNotification = notificationGate();
  const recoveryDelays = [1000, 5000, 15000, 30000, 60000];

  const clearNotification = () => {
    notification?.close();
    notification = undefined;
    pendingCallId = undefined;
    if (mainWindow && !mainWindow.isDestroyed()) mainWindow.flashFrame(false);
  };
  const showWindow = () => {
    if (!mainWindow || mainWindow.isDestroyed()) return;
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.show();
    mainWindow.focus();
    mainWindow.flashFrame(false);
  };
  const sendFloatingState = () => {
    if (floatingWindow && !floatingWindow.isDestroyed() && latestFloatingState)
      floatingWindow.webContents.send(
        'softphone:floating-state',
        latestFloatingState
      );
  };
  const showFloatingWindow = state => {
    if (state) latestFloatingState = state;
    if (!floatingWindow || floatingWindow.isDestroyed()) {
      floatingWindow = new BrowserWindow({
        width: 390,
        height: 650,
        minWidth: 350,
        minHeight: 560,
        show: false,
        title: 'JRC Softphone',
        webPreferences: {
          preload: path.join(__dirname, 'preload.cjs'),
          contextIsolation: true,
          nodeIntegration: false,
          sandbox: true,
          webSecurity: true,
          webviewTag: false,
          devTools: !app.isPackaged,
        },
      });
      floatingWindow.webContents.setWindowOpenHandler(() => ({
        action: 'deny',
      }));
      floatingWindow.webContents.on('will-navigate', event =>
        event.preventDefault()
      );
      floatingWindow.once('ready-to-show', () => {
        sendFloatingState();
        floatingWindow.show();
        floatingWindow.focus();
      });
      floatingWindow.on('close', event => {
        if (!quitting) {
          event.preventDefault();
          floatingWindow.hide();
        }
      });
      floatingWindow.on('closed', () => {
        floatingWindow = undefined;
      });
      floatingWindow
        .loadFile(path.join(__dirname, '../floating/index.html'))
        .catch(() => floatingWindow?.hide());
      return;
    }
    sendFloatingState();
    if (floatingWindow.isMinimized()) floatingWindow.restore();
    floatingWindow.show();
    floatingWindow.focus();
  };
  const loginSettings = () => ({
    path: process.execPath,
    args: [`--server-url=${config.origin}`],
  });
  const refreshTray = () => {
    if (!tray) return;
    tray.setToolTip(
      unavailable ? 'JRC Softphone — conexão indisponível' : 'JRC Softphone'
    );
    tray.setContextMenu(
      Menu.buildFromTemplate([
        { label: 'Abrir JRC Softphone', click: showWindow },
        { label: 'Abrir Softphone', click: showFloatingWindow },
        {
          label: 'Tentar carregar novamente',
          enabled: unavailable,
          click: () => {
            recoveryAttempt = 0;
            timers.clearTimeout(recoveryTimer);
            recoveryTimer = undefined;
            // eslint-disable-next-line no-use-before-define
            loadWindow();
          },
        },
        { type: 'separator' },
        {
          label: 'Iniciar com o Windows',
          type: 'checkbox',
          enabled: app.isPackaged,
          checked:
            app.isPackaged &&
            app.getLoginItemSettings(loginSettings()).openAtLogin,
          click: item =>
            app.setLoginItemSettings({
              ...loginSettings(),
              openAtLogin: item.checked,
            }),
        },
        { label: 'Sair do JRC Softphone', click: () => app.quit() },
      ])
    );
  };
  const scheduleRecovery = () => {
    if (quitting) return;
    clearNotification();
    unavailable = true;
    timers.clearTimeout(stabilityTimer);
    refreshTray();
    if (recoveryTimer || recoveryAttempt >= recoveryDelays.length) return;
    recoveryTimer = timers.setTimeout(() => {
      recoveryTimer = undefined;
      // eslint-disable-next-line no-use-before-define
      loadWindow();
    }, recoveryDelays[recoveryAttempt]);
    recoveryAttempt += 1;
  };
  async function loadWindow() {
    if (quitting || loading || !mainWindow || mainWindow.isDestroyed()) return;
    loading = true;
    try {
      await mainWindow.loadURL(config.url);
    } catch {
      // Never log a remote URL, cookies, tokens or raw Electron errors.
      scheduleRecovery();
    } finally {
      loading = false;
    }
  }
  const openExternal = async url => {
    const allowed = externalUrl(url, config.origin);
    if (!allowed || Date.now() - lastExternalOpen < 1000) return false;
    lastExternalOpen = Date.now();
    try {
      await shell.openExternal(allowed);
      return true;
    } catch {
      dialog.showErrorBox(
        'JRC Softphone',
        'Não foi possível abrir o navegador padrão.'
      );
      return false;
    }
  };
  const configureWindow = () => {
    mainWindow = new BrowserWindow({
      width: 1180,
      height: 820,
      minWidth: 900,
      minHeight: 650,
      show: false,
      webPreferences: {
        preload: path.join(__dirname, 'preload.cjs'),
        // No persist: prefix: cookies, tokens and web storage live only for this process.
        partition: 'jrc-softphone',
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: true,
        webSecurity: true,
        webviewTag: false,
        devTools: !app.isPackaged,
        backgroundThrottling: false,
        autoplayPolicy: 'no-user-gesture-required',
      },
    });
    const contents = mainWindow.webContents;
    contents.session.setPermissionCheckHandler(
      (webContents, permission, origin, details) =>
        audioPermission(
          webContents,
          mainWindow,
          config.origin,
          permission,
          details,
          origin
        )
    );
    contents.session.setPermissionRequestHandler(
      (webContents, permission, callback, details) =>
        callback(
          audioPermission(
            webContents,
            mainWindow,
            config.origin,
            permission,
            details
          )
        )
    );
    contents.setWindowOpenHandler(({ url }) => {
      if (trustedUrl(contents.getURL(), config.origin)) openExternal(url);
      return { action: 'deny' };
    });
    contents.on('will-navigate', (event, url) => {
      if (!trustedUrl(event.url || url, config.origin)) event.preventDefault();
    });
    contents.on('will-frame-navigate', event => {
      if (!event.isMainFrame || !trustedUrl(event.url, config.origin))
        event.preventDefault();
    });
    contents.on('will-redirect', (event, url) => {
      if (!trustedUrl(event.url || url, config.origin)) event.preventDefault();
    });
    contents.on('will-attach-webview', event => event.preventDefault());
    contents.on('did-start-navigation', event => {
      if (event.isMainFrame && !event.isSameDocument) clearNotification();
    });
    contents.on(
      'did-fail-load',
      (_event, code, _description, _url, isMainFrame) => {
        if (isMainFrame && code !== -3) scheduleRecovery();
      }
    );
    contents.on('render-process-gone', () => {
      loading = false;
      scheduleRecovery();
    });
    contents.on('did-finish-load', () => {
      if (!trustedUrl(contents.getURL(), config.origin)) return;
      unavailable = false;
      timers.clearTimeout(recoveryTimer);
      recoveryTimer = undefined;
      timers.clearTimeout(stabilityTimer);
      stabilityTimer = timers.setTimeout(() => {
        recoveryAttempt = 0;
      }, 60000);
      refreshTray();
    });
    mainWindow.once('ready-to-show', showWindow);
    const hideWindow = event => {
      if (quitting) return;
      event.preventDefault();
      mainWindow.hide();
    };
    mainWindow.on('close', hideWindow);
    mainWindow.on('minimize', hideWindow);
    mainWindow.on('focus', () => mainWindow.flashFrame(false));
    // An actually destroyed window has no SIP renderer left to preserve.
    mainWindow.on('closed', () => {
      if (!quitting) app.quit();
    });
  };
  app.on('second-instance', showWindow);
  // This event has no Event argument. Normal close is intercepted by hideWindow.
  app.on('window-all-closed', () => {});
  const finishQuit = () => {
    if (finalQuit) return;
    finalQuit = true;
    timers.clearTimeout(shutdownTimer);
    app.exit(0);
  };
  app.on('before-quit', event => {
    if (!finalQuit) event?.preventDefault();
    quitting = true;
    timers.clearTimeout(recoveryTimer);
    timers.clearTimeout(stabilityTimer);
    clearNotification();
    tray?.destroy();
    if (floatingWindow && !floatingWindow.isDestroyed())
      floatingWindow.destroy();
    if (finalQuit) return;
    mainWindow?.webContents.send('softphone:floating-command', {
      action: 'shutdown',
    });
    shutdownTimer = timers.setTimeout(finishQuit, 3000);
  });
  app
    .whenReady()
    .then(() => {
      const configPath = path.join(
        app.getPath('userData'),
        'softphone-server.json'
      );
      let savedOrigin;
      try {
        savedOrigin = JSON.parse(
          fileSystem.readFileSync(configPath, 'utf8')
        ).origin;
      } catch (error) {
        if (error.code !== 'ENOENT')
          throw new Error('Configuração local do servidor inválida.');
      }
      config = serverConfig({
        argv,
        env,
        isPackaged: app.isPackaged,
        savedOrigin,
      });
      // Only the origin is persisted, without userinfo, query, SIP password or session tokens.
      fileSystem.mkdirSync(path.dirname(configPath), { recursive: true });
      fileSystem.writeFileSync(
        configPath,
        JSON.stringify({ origin: config.origin }),
        'utf8'
      );
      const icon = nativeImage.createFromPath(
        path.join(__dirname, '../assets/tray.png')
      );
      if (icon.isEmpty())
        throw new Error('O ícone da bandeja não pôde ser carregado.');
      tray = new Tray(icon);
      tray.on('click', showWindow);
      configureWindow();
      refreshTray();
      ipcMain.on('softphone:incoming-call', (event, payload) => {
        if (
          !trustedSender(event, mainWindow, config.origin) ||
          !incomingPayload(payload) ||
          !permitNotification(payload.callId)
        )
          return;
        clearNotification();
        pendingCallId = payload.callId;
        mainWindow.flashFrame(true);
        try {
          if (!Notification.isSupported()) {
            showFloatingWindow({
              registered: false,
              status: 'Chamada recebida',
              extension: '',
              destination: '',
              remote: payload.remote,
              duration: '00:00',
              incoming: true,
              sessionActive: true,
              established: false,
              muted: false,
              held: false,
              holdPending: false,
              transferring: false,
              errorMessage: '',
            });
            return;
          }
          notification = new Notification({
            title: 'JRC Softphone',
            body: `Chamada recebida de ${payload.remote}`,
          });
          notification.on('click', showFloatingWindow);
          notification.on('failed', showFloatingWindow);
          notification.show();
          showFloatingWindow({
            registered: false,
            status: 'Chamada recebida',
            extension: '',
            destination: '',
            remote: payload.remote,
            duration: '00:00',
            incoming: true,
            sessionActive: true,
            established: false,
            muted: false,
            held: false,
            holdPending: false,
            transferring: false,
            errorMessage: '',
          });
        } catch {
          showFloatingWindow();
        }
      });
      ipcMain.on('softphone:clear-call', (event, payload) => {
        if (
          trustedSender(event, mainWindow, config.origin) &&
          clearPayload(payload) &&
          payload.callId === pendingCallId
        )
          clearNotification();
      });
      ipcMain.handle('softphone:open-contact', (event, payload) => {
        if (!trustedSender(event, mainWindow, config.origin)) return false;
        const url = contactUrl(payload, config.origin);
        return url ? openExternal(url) : false;
      });
      ipcMain.on('softphone:floating-state', (event, payload) => {
        if (
          !trustedSender(event, mainWindow, config.origin) ||
          !floatingState(payload)
        )
          return;
        latestFloatingState = payload;
        sendFloatingState();
        if (payload.incoming) showFloatingWindow();
      });
      ipcMain.on('softphone:floating-command', (event, payload) => {
        if (
          !floatingWindow ||
          floatingWindow.isDestroyed() ||
          event.sender !== floatingWindow.webContents ||
          !floatingCommand(payload)
        )
          return;
        if (payload.action === 'showMain') showWindow();
        else
          mainWindow?.webContents.send('softphone:floating-command', payload);
      });
      ipcMain.on('softphone:floating-shutdown-complete', event => {
        if (trustedSender(event, mainWindow, config.origin)) finishQuit();
      });
      loadWindow();
    })
    .catch(() => {
      dialog.showErrorBox(
        'JRC Softphone',
        'Não foi possível iniciar. Verifique a URL HTTPS configurada e os arquivos do aplicativo.'
      );
      app.quit();
    });
}
module.exports = { startDesktop };
// Keep native Electron loading at the executable entrypoint so policy/lifecycle tests run in Node.
// eslint-disable-next-line global-require
if (require.main === module) startDesktop(require('electron'));
