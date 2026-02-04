let isActive = false;
let selectedIndex = 0;
let menuItems = [];
let isAtHomeland = false; // Track if player is at Homeland

// DOM Elements
const statusIndicator = document.getElementById('statusIndicator');
const menuContainer = document.querySelector('.menu-container');

// Ping variables
let pingedPlayerId = null;
let pingActive = false;
let pingInterval = null;

// Initialize menu
function initMenu() {
    menuItems = Array.from(document.querySelectorAll('.menu-item'));
    updateSelection();
    updateMenuState();
    // Ensure focus on body for keyboard events
    document.body.focus();
}

// Update selection
function updateSelection() {
    menuItems.forEach((item, index) => {
        if (index === selectedIndex) {
            item.classList.add('selected');
        } else {
            item.classList.remove('selected');
        }
    });
}

// Update menu state based on active status
function updateMenuState() {
    const startItem = document.querySelector('[data-action="start"]');
    const stopItem = document.querySelector('[data-action="stop"]');
    const teleportItem = document.querySelector('[data-action="teleportTo"]');
    const teleportBackItem = document.querySelector('[data-action="teleportBack"]');
    const pingPlayerItem = document.querySelector('[data-action="pingPlayer"]');
    
    if (isActive) {
        statusIndicator.classList.add('active');
        startItem.classList.add('disabled');
        stopItem.classList.remove('disabled');
        
        if (isAtHomeland) {
            teleportItem.classList.add('disabled');
        } else {
            teleportItem.classList.remove('disabled');
        }
        
        if (isAtHomeland) {
            teleportBackItem.classList.remove('disabled');
        } else {
            teleportBackItem.classList.add('disabled');
        }
    } else {
        statusIndicator.classList.remove('active');
        startItem.classList.remove('disabled');
        stopItem.classList.add('disabled');
        teleportItem.classList.add('disabled');
        teleportBackItem.classList.add('disabled');
    }
    
    if (pingPlayerItem) pingPlayerItem.classList.remove('disabled');
}

// Navigate up
function navigateUp() {
    selectedIndex = (selectedIndex - 1 + menuItems.length) % menuItems.length;
    updateSelection();
}

// Navigate down
function navigateDown() {
    selectedIndex = (selectedIndex + 1) % menuItems.length;
    updateSelection();
}

// Select current item
function selectItem() {
    const selectedItem = menuItems[selectedIndex];
    if (selectedItem.classList.contains('disabled')) {
        return;
    }
    
    const action = selectedItem.getAttribute('data-action');
    executeAction(action);
}

// Debounce helper
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Optimized fetch wrapper
function safeFetch(endpoint, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).catch(err => console.error(`[HOMELAND] Fetch error (${endpoint}):`, err));
}

// Optimized executeAction
function executeAction(action) {
    switch(action) {
        case 'start':
            if (!isActive) safeFetch('startHomeland');
            break;
        case 'stop':
            if (isActive) {
                safeFetch('stopHomeland');
                isAtHomeland = false;
                updateMenuState();
            }
            break;
        case 'teleportTo':
            if (isActive && !isAtHomeland) {
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
        case 'pingPlayer':
            const playerIdInput = document.getElementById('playerIdInput');
            const playerId = parseInt(playerIdInput.value, 10);
            if (!isNaN(playerId) && playerId >= 0 && playerId <= 1024) {
                startPing(playerId);
            } else {
                playerIdInput.style.borderColor = 'red';
                setTimeout(() => { playerIdInput.style.borderColor = '#ff6b00'; }, 1000);
            }
            break;
        case 'broadcastMessage':
            const broadcastInput = document.getElementById('broadcastInput');
            const message = broadcastInput.value.trim();
            
            if (message.length > 0 && message.length <= 200) {
                safeFetch('broadcastMessage', { message: message });
                broadcastInput.value = '';
                broadcastInput.style.borderColor = '#28a745';
                setTimeout(() => { broadcastInput.style.borderColor = '#ff6b00'; }, 1000);
            } else if (message.length === 0) {
                broadcastInput.style.borderColor = 'red';
                setTimeout(() => { broadcastInput.style.borderColor = '#ff6b00'; }, 1000);
            } else {
                broadcastInput.style.borderColor = 'orange';
                setTimeout(() => { broadcastInput.style.borderColor = '#ff6b00'; }, 1000);
            }
            break;
    }
}

// Close menu
function closeMenu() {
    document.body.style.display = 'none';
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(() => {});
}

// Fetch current status
function fetchStatus() {
    fetch(`https://${GetParentResourceName()}/getStatus`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    })
    .then(resp => resp.json())
    .then(data => {
        isActive = data.active;
        updateMenuState();
    })
    .catch(err => console.error('Error fetching status:', err));
}

// Mouse click handlers
document.addEventListener('click', (e) => {
    const menuItem = e.target.closest('.menu-item');
    if (menuItem && !menuItem.classList.contains('disabled')) {
        const index = menuItems.indexOf(menuItem);
        selectedIndex = index;
        updateSelection();
        
        const action = menuItem.getAttribute('data-action');
        executeAction(action);
    }
});

// Keyboard handlers
document.addEventListener('keydown', (e) => {
    if (document.body.style.display === 'none') return;
    // Ausnahme: Wenn ein Eingabefeld fokussiert ist, keine Menü-Navigation!
    const playerIdInput = document.getElementById('playerIdInput');
    const broadcastInput = document.getElementById('broadcastInput');
    
    if (document.activeElement === playerIdInput || document.activeElement === broadcastInput) return;

    e.preventDefault();
    e.stopPropagation();

    switch(e.key) {
        case 'ArrowUp':
            navigateUp();
            break;
        case 'ArrowDown':
            navigateDown();
            break;
        case 'Enter':
            selectItem();
            break;
        case 'Escape':
            closeMenu();
            break;
    }
});

// Prevent default on keyup as well
document.addEventListener('keyup', (e) => {
    if (document.body.style.display === 'none') return;
    
    if (['ArrowUp', 'ArrowDown', 'Enter', 'Escape'].includes(e.key)) {
        e.preventDefault();
        e.stopPropagation();
    }
});

// Listen for messages from client
window.addEventListener('message', (event) => {
    const data = event.data;
    
    if (data.action === 'open') {
        document.body.style.display = 'block';
        isActive = data.status || false;
        selectedIndex = 0;
        isAtHomeland = data.isAtHomeland || false;
        initMenu();
        fetchStatus();
    } else if (data.type === 'updateStatus') {
        isActive = data.active;
        updateMenuState();
    } else if (data.action === 'refocus') {
        setTimeout(() => {
            document.body.focus();
        }, 50);
    } else if (data.action === 'updateTeleportState') {
        isAtHomeland = data.isAtHomeland || false;
        updateMenuState();
    } else if (data.action === 'stopPing') {
        stopPing();
    }
});

// Maintain focus
window.addEventListener('blur', () => {
    if (document.body.style.display !== 'none') {
        setTimeout(() => {
            document.body.focus();
        }, 10);
    }
});

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', initMenu);

// Wenn Merriweather-Job beendet wird, stoppe das Ping
function handleHomelandStop() {
    stopPing();
}

// ...bestehende Event-Handler für Status-Änderungen...
// Ergänze nach updateStatus und syncStatus:
window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.type === 'updateStatus' && !data.active) {
        handleHomelandStop();
    }
});

// Optimized ping functions
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
        window.postMessage({ action: 'removePingBlip' }, '*');
        safeFetch('stopPingPlayer');
    }
}
