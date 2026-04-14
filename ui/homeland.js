let operationState = "INACTIVE";
let selectedIndex = 0;
let menuItems = [];
let isAtHomeland = false;
let isLeader = false;

const statusIndicator = document.getElementById('statusIndicator');
const statusLabel = document.getElementById('statusLabel');
const cinemaAudio = document.getElementById('cinemaAudio');
const menuContainer = document.getElementById('menuContainer');

// Ping variables
let pingedPlayerId = null;
let pingActive = false;
let pingInterval = null;

// Menu visibility helpers
function isMenuVisible() {
    return menuContainer && !menuContainer.classList.contains('hidden');
}

function showMenu() {
    if (menuContainer) menuContainer.classList.remove('hidden');
}

function hideMenu() {
    if (menuContainer) menuContainer.classList.add('hidden');
}

// Initialize menu
function initMenu() {
    menuItems = Array.from(document.querySelectorAll('.menu-item'));
    updateLeaderVisibility();
    updateSelection();
    updateMenuState();
    document.body.focus();
}

// Show/hide leader-only elements
function updateLeaderVisibility() {
    const leaderItems = document.querySelectorAll('.leader-only');
    const leaderDivider = document.getElementById('leaderDivider');

    leaderItems.forEach(item => {
        item.style.display = isLeader ? '' : 'none';
    });

    if (leaderDivider) {
        leaderDivider.style.display = isLeader ? '' : 'none';
    }

    // Rebuild menu items list after visibility changes
    menuItems = Array.from(document.querySelectorAll('.menu-item')).filter(
        item => item.style.display !== 'none'
    );

    if (selectedIndex >= menuItems.length) {
        selectedIndex = 0;
    }
}

// Update selection highlight
function updateSelection() {
    menuItems.forEach((item, index) => {
        item.classList.toggle('selected', index === selectedIndex);
    });
}

// Update menu state based on operation state
function updateMenuState() {
    const alertItem = document.querySelector('[data-action="alertAgents"]');
    const goLiveItem = document.querySelector('[data-action="goLive"]');
    const stopItem = document.querySelector('[data-action="stop"]');
    const teleportItem = document.querySelector('[data-action="teleportTo"]');
    const teleportBackItem = document.querySelector('[data-action="teleportBack"]');

    // Status indicator
    statusIndicator.className = 'status-indicator';
    if (operationState === 'ACTIVE') {
        statusIndicator.classList.add('active');
        statusLabel.textContent = 'AKTIV';
    } else if (operationState === 'ALERTING') {
        statusIndicator.classList.add('alerting');
        statusLabel.textContent = 'SAMMELN';
    } else {
        statusLabel.textContent = 'INAKTIV';
    }

    // Button states per phase
    if (operationState === 'INACTIVE') {
        if (alertItem) alertItem.classList.remove('disabled');
        if (goLiveItem) goLiveItem.classList.add('disabled');
        if (stopItem) stopItem.classList.add('disabled');
        if (teleportItem) teleportItem.classList.add('disabled');
        if (teleportBackItem) teleportBackItem.classList.add('disabled');
    } else if (operationState === 'ALERTING') {
        if (alertItem) alertItem.classList.add('disabled');
        if (goLiveItem) goLiveItem.classList.remove('disabled');
        if (stopItem) stopItem.classList.remove('disabled');
        if (teleportItem) teleportItem.classList.toggle('disabled', isAtHomeland);
        if (teleportBackItem) teleportBackItem.classList.toggle('disabled', !isAtHomeland);
    } else if (operationState === 'ACTIVE') {
        if (alertItem) alertItem.classList.add('disabled');
        if (goLiveItem) goLiveItem.classList.add('disabled');
        if (stopItem) stopItem.classList.remove('disabled');
        if (teleportItem) teleportItem.classList.toggle('disabled', isAtHomeland);
        if (teleportBackItem) teleportBackItem.classList.toggle('disabled', !isAtHomeland);
    }
}

// Navigation
function navigateUp() {
    selectedIndex = (selectedIndex - 1 + menuItems.length) % menuItems.length;
    updateSelection();
}

function navigateDown() {
    selectedIndex = (selectedIndex + 1) % menuItems.length;
    updateSelection();
}

function selectItem() {
    const selectedItem = menuItems[selectedIndex];
    if (selectedItem && !selectedItem.classList.contains('disabled')) {
        executeAction(selectedItem.getAttribute('data-action'));
    }
}

// Fetch wrapper
function safeFetch(endpoint, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).catch(err => console.error(`[HOMELAND] Fetch error (${endpoint}):`, err));
}

// Execute actions
function executeAction(action) {
    switch (action) {
        case 'alertAgents':
            if (operationState === 'INACTIVE') safeFetch('alertAgents');
            break;
        case 'goLive':
            if (operationState === 'ALERTING') safeFetch('goLive');
            break;
        case 'stop':
            if (operationState !== 'INACTIVE') {
                safeFetch('stopHomeland');
                isAtHomeland = false;
                updateMenuState();
            }
            break;
        case 'teleportTo':
            if (operationState !== 'INACTIVE' && !isAtHomeland) {
                safeFetch('teleportTo').then(() => {
                    isAtHomeland = true;
                    updateMenuState();
                    setTimeout(() => {
                        document.body.focus();
                        safeFetch('refocus');
                    }, 100);
                });
            }
            break;
        case 'teleportBack':
            if (isAtHomeland) {
                safeFetch('teleportBack').then(() => {
                    isAtHomeland = false;
                    updateMenuState();
                    setTimeout(() => {
                        document.body.focus();
                        safeFetch('refocus');
                    }, 100);
                });
            }
            break;
        case 'setWeather':
            safeFetch('setWeather');
            break;
        case 'restoreWeather':
            safeFetch('restoreWeather');
            break;
        case 'close':
            closeMenu();
            break;
        case 'pingPlayer': {
            const playerIdInput = document.getElementById('playerIdInput');
            const playerId = parseInt(playerIdInput.value, 10);
            if (!isNaN(playerId) && playerId >= 0 && playerId <= 1024) {
                startPing(playerId);
            } else {
                playerIdInput.style.borderColor = '#dc3545';
                setTimeout(() => { playerIdInput.style.borderColor = ''; }, 1000);
            }
            break;
        }
        case 'broadcastMessage': {
            const broadcastInput = document.getElementById('broadcastInput');
            const message = broadcastInput.value.trim();

            if (message.length > 0 && message.length <= 200) {
                safeFetch('broadcastMessage', { message });
                broadcastInput.value = '';
                const cc = document.getElementById('charCount');
                if (cc) cc.textContent = '0';
                broadcastInput.style.borderColor = '#28a745';
                setTimeout(() => { broadcastInput.style.borderColor = ''; }, 1000);
            } else {
                broadcastInput.style.borderColor = '#dc3545';
                setTimeout(() => { broadcastInput.style.borderColor = ''; }, 1000);
            }
            break;
        }
    }
}

// Close menu
function closeMenu() {
    hideMenu();
    safeFetch('close');
}

// Fetch current status
function fetchStatus() {
    safeFetch('getStatus')
        .then(resp => resp && resp.json())
        .then(data => {
            if (data) {
                operationState = data.state || 'INACTIVE';
                isLeader = data.isLeader || false;
                updateLeaderVisibility();
                updateMenuState();
            }
        })
        .catch(() => {});
}

// Mouse click handlers
document.addEventListener('click', (e) => {
    const menuItem = e.target.closest('.menu-item');
    if (menuItem && !menuItem.classList.contains('disabled')) {
        const index = menuItems.indexOf(menuItem);
        if (index >= 0) {
            selectedIndex = index;
            updateSelection();
            executeAction(menuItem.getAttribute('data-action'));
        }
    }
});

// Keyboard handlers
document.addEventListener('keydown', (e) => {
    if (!isMenuVisible()) return;

    const activeEl = document.activeElement;
    if (activeEl && (activeEl.tagName === 'INPUT' || activeEl.tagName === 'TEXTAREA')) return;

    e.preventDefault();
    e.stopPropagation();

    switch (e.key) {
        case 'ArrowUp': navigateUp(); break;
        case 'ArrowDown': navigateDown(); break;
        case 'Enter': selectItem(); break;
        case 'Escape': closeMenu(); break;
    }
});

document.addEventListener('keyup', (e) => {
    if (!isMenuVisible()) return;
    if (['ArrowUp', 'ArrowDown', 'Enter', 'Escape'].includes(e.key)) {
        e.preventDefault();
        e.stopPropagation();
    }
});

// Single consolidated message listener
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'open':
            showMenu();
            operationState = data.state || 'INACTIVE';
            isAtHomeland = data.isAtHomeland || false;
            isLeader = data.isLeader || false;
            selectedIndex = 0;
            initMenu();
            fetchStatus();
            break;

        case 'refocus':
            setTimeout(() => document.body.focus(), 50);
            break;

        case 'updateTeleportState':
            isAtHomeland = data.isAtHomeland || false;
            updateMenuState();
            break;

        case 'stopPing':
            stopPing();
            break;

        case 'playCinemaMusic':
            if (cinemaAudio && data.file) {
                cinemaAudio.src = data.file;
                cinemaAudio.volume = data.volume || 0.3;
                cinemaAudio.play().catch(() => {});
                cinemaAudio.onended = function () {
                    safeFetch('cinemaMusicEnded');
                };
            }
            break;

        case 'stopCinemaMusic':
            if (cinemaAudio) {
                cinemaAudio.pause();
                cinemaAudio.currentTime = 0;
                cinemaAudio.onended = null;
                cinemaAudio.src = '';
            }
            break;

        case 'playBroadcastSound': {
            const notifAudio = new Audio(data.file || 'notification_agents.ogg');
            notifAudio.volume = data.volume || 0.3;
            notifAudio.play().catch(() => {});
            break;
        }
    }

    // Handle type-based messages
    if (data.type === 'updateStatus') {
        operationState = data.state || 'INACTIVE';
        updateMenuState();

        if (operationState === 'INACTIVE') {
            stopPing();
        }
    }
});

// Maintain focus
window.addEventListener('blur', () => {
    if (isMenuVisible()) {
        setTimeout(() => document.body.focus(), 10);
    }
});

// Char counter for broadcast input
document.addEventListener('DOMContentLoaded', () => {
    initMenu();

    const broadcastInput = document.getElementById('broadcastInput');
    const charCount = document.getElementById('charCount');
    if (broadcastInput && charCount) {
        broadcastInput.addEventListener('input', () => {
            charCount.textContent = broadcastInput.value.length;
        });
    }
});

// Ping functions
function startPing(playerId) {
    stopPing();

    if (playerId === 0) {
        safeFetch('pingPlayer', { playerId: 0 });
        const playerIdInput = document.getElementById('playerIdInput');
        if (playerIdInput) playerIdInput.value = '';
        return;
    }

    pingActive = true;
    pingedPlayerId = playerId;

    safeFetch('pingPlayer', { playerId });

    pingInterval = setInterval(() => {
        if (pingActive && pingedPlayerId && pingedPlayerId !== 0) {
            safeFetch('pingPlayer', { playerId: pingedPlayerId });
        }
    }, 2000);
}

function stopPing() {
    if (pingInterval) {
        clearInterval(pingInterval);
        pingInterval = null;
    }

    if (pingActive || pingedPlayerId) {
        pingActive = false;
        pingedPlayerId = null;
        safeFetch('stopPingPlayer');
    }
}
