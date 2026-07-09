let isVoiceActive = false;
let recognition = null;
let joystickInterval = null;
let chartCtx = null;

document.addEventListener('DOMContentLoaded', () => {
    initSliders();
    initJoystick();
    initVoiceRecognition();
    initChart();
    updateStatus();
    loadWaypoints();
    loadAlerts();
    setInterval(updateStatus, 1000);
    setInterval(updateChart, 2000);
});

function initSliders() {
    document.querySelectorAll('input[type="range"]').forEach(slider => {
        slider.addEventListener('input', (e) => {
            const channel = e.target.dataset.channel;
            const angle = e.target.value;
            document.getElementById(`${e.target.id}-value`).textContent = angle;
            setServo(channel, angle);
        });
    });
}

async function setServo(channel, angle) {
    try {
        await fetch('/set', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({channel: parseInt(channel), angle: parseInt(angle)})
        });
    } catch (err) {
        console.error('Failed to set servo:', err);
    }
}

async function setPreset(name) {
    try {
        const response = await fetch(`/preset/${name}`, {method: 'POST'});
        const data = await response.json();
        if (data.success) {
            updateSliders(data.positions);
        }
    } catch (err) {
        console.error('Failed to set preset:', err);
    }
}

function updateSliders(positions) {
    for (const [servo, angle] of Object.entries(positions)) {
        const slider = document.getElementById(servo);
        if (slider) {
            slider.value = angle;
            document.getElementById(`${servo}-value`).textContent = angle;
        }
    }
}

async function updateStatus() {
    try {
        const response = await fetch('/status');
        const data = await response.json();
        
        const connStatus = document.getElementById('connection-status');
        connStatus.textContent = data.connected ? 'Connected' : 'Disconnected';
        connStatus.className = `status ${data.connected ? 'connected' : 'disconnected'}`;
        
        const guardStatus = document.getElementById('guard-status');
        guardStatus.textContent = `Guard: ${data.guard_mode ? 'ON' : 'OFF'}`;
        guardStatus.className = `status ${data.guard_mode ? 'guard-on' : 'guard-off'}`;
        
        if (data.connected) {
            updateSliders(data.positions);
        }
    } catch (err) {
        document.getElementById('connection-status').textContent = 'Disconnected';
        document.getElementById('connection-status').className = 'status disconnected';
    }
}

function initJoystick() {
    const canvas = document.getElementById('joystick');
    const ctx = canvas.getContext('2d');
    let isDragging = false;
    let centerX = canvas.width / 2;
    let centerY = canvas.height / 2;
    let currentX = centerX;
    let currentY = centerY;

    function drawJoystick() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.beginPath();
        ctx.arc(centerX, centerY, 80, 0, Math.PI * 2);
        ctx.strokeStyle = '#00d9ff';
        ctx.lineWidth = 2;
        ctx.stroke();
        
        ctx.beginPath();
        ctx.arc(currentX, currentY, 20, 0, Math.PI * 2);
        ctx.fillStyle = '#00d9ff';
        ctx.fill();
    }

    function handleMove(clientX, clientY) {
        const rect = canvas.getBoundingClientRect();
        currentX = clientX - rect.left;
        currentY = clientY - rect.top;
        
        const dx = currentX - centerX;
        const dy = currentY - centerY;
        const distance = Math.sqrt(dx * dx + dy * dy);
        
        if (distance > 80) {
            currentX = centerX + (dx / distance) * 80;
            currentY = centerY + (dy / distance) * 80;
        }
        
        drawJoystick();
    }

    canvas.addEventListener('mousedown', (e) => {
        isDragging = true;
        handleMove(e.clientX, e.clientY);
    });

    canvas.addEventListener('mousemove', (e) => {
        if (isDragging) {
            handleMove(e.clientX, e.clientY);
        }
    });

    canvas.addEventListener('mouseup', () => {
        isDragging = false;
        currentX = centerX;
        currentY = centerY;
        drawJoystick();
    });

    canvas.addEventListener('mouseleave', () => {
        isDragging = false;
        currentX = centerX;
        currentY = centerY;
        drawJoystick();
    });

    canvas.addEventListener('touchstart', (e) => {
        isDragging = true;
        handleMove(e.touches[0].clientX, e.touches[0].clientY);
        e.preventDefault();
    });

    canvas.addEventListener('touchmove', (e) => {
        if (isDragging) {
            handleMove(e.touches[0].clientX, e.touches[0].clientY);
            e.preventDefault();
        }
    });

    canvas.addEventListener('touchend', () => {
        isDragging = false;
        currentX = centerX;
        currentY = centerY;
        drawJoystick();
    });

    drawJoystick();
}

function initVoiceRecognition() {
    if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        recognition = new SpeechRecognition();
        recognition.continuous = false;
        recognition.interimResults = false;
        recognition.lang = 'en-US';

        recognition.onresult = (event) => {
            const command = event.results[0][0].transcript.toLowerCase();
            processVoiceCommand(command);
        };

        recognition.onend = () => {
            if (isVoiceActive) {
                recognition.start();
            }
        };

        recognition.onerror = (event) => {
            console.error('Speech recognition error:', event.error);
            if (event.error !== 'no-speech') {
                stopVoice();
            }
        };
    }
}

function toggleVoice() {
    if (isVoiceActive) {
        stopVoice();
    } else {
        startVoice();
    }
}

function startVoice() {
    if (!recognition) {
        alert('Speech recognition not supported in this browser');
        return;
    }
    isVoiceActive = true;
    document.getElementById('voice-btn').classList.add('active');
    document.getElementById('voice-btn').textContent = 'Listening...';
    recognition.start();
}

function stopVoice() {
    isVoiceActive = false;
    document.getElementById('voice-btn').classList.remove('active');
    document.getElementById('voice-btn').textContent = 'Push to Talk';
    if (recognition) {
        recognition.stop();
    }
}

function processVoiceCommand(command) {
    document.getElementById('voice-status').textContent = `Heard: "${command}"`;
    
    const presetCommands = ['home', 'grab', 'reach', 'rest', 'wave'];
    for (const preset of presetCommands) {
        if (command.includes(preset)) {
            setPreset(preset);
            return;
        }
    }
    
    const servoMatch = command.match(/(base|shoulder|elbow|gripper)\s+(\d+)/);
    if (servoMatch) {
        const servo = servoMatch[1];
        const angle = parseInt(servoMatch[2]);
        const channel = {'base': 0, 'shoulder': 1, 'elbow': 2, 'gripper': 3}[servo];
        setServo(channel, angle);
    }
}

async function takeSnapshot() {
    try {
        const response = await fetch('/snapshot', {method: 'POST'});
        const data = await response.json();
        if (data.success) {
            alert(`Snapshot saved: ${data.filename}`);
        } else {
            alert('Failed to take snapshot');
        }
    } catch (err) {
        alert('Failed to take snapshot');
    }
}

async function toggleGuard() {
    const btn = document.getElementById('guard-btn');
    const isEnabling = btn.textContent.includes('Enable');
    
    try {
        const response = await fetch(`/guard/${isEnabling ? 'enable' : 'disable'}`, {method: 'POST'});
        const data = await response.json();
        if (data.success) {
            btn.textContent = isEnabling ? 'Disable Guard Mode' : 'Enable Guard Mode';
            btn.classList.toggle('active', isEnabling);
        }
    } catch (err) {
        console.error('Failed to toggle guard mode:', err);
    }
}

async function loadAlerts() {
    try {
        const response = await fetch('/alerts');
        const alerts = await response.json();
        displayAlerts(alerts);
    } catch (err) {
        console.error('Failed to load alerts:', err);
    }
}

function displayAlerts(alerts) {
    const container = document.getElementById('guard-alerts');
    container.innerHTML = '';
    alerts.slice(-10).reverse().forEach(alert => {
        const div = document.createElement('div');
        div.className = 'alert-item';
        div.textContent = `${new Date(alert.time).toLocaleString()} - ${alert.type}: ${alert.details}`;
        container.appendChild(div);
    });
}

async function addWaypoint() {
    const name = prompt('Enter waypoint name (optional):');
    try {
        const response = await fetch('/waypoints/add', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({name: name || undefined})
        });
        const data = await response.json();
        if (data.success) {
            loadWaypoints();
        }
    } catch (err) {
        console.error('Failed to add waypoint:', err);
    }
}

async function loadWaypoints() {
    try {
        const response = await fetch('/waypoints');
        const waypoints = await response.json();
        displayWaypoints(waypoints);
    } catch (err) {
        console.error('Failed to load waypoints:', err);
    }
}

function displayWaypoints(waypoints) {
    const container = document.getElementById('waypoint-list');
    container.innerHTML = '';
    waypoints.forEach((wp, index) => {
        const div = document.createElement('div');
        div.className = 'waypoint-item';
        div.innerHTML = `
            <span>${wp.name}</span>
            <div>
                <button onclick="playWaypoint(${index})">Play</button>
                <button onclick="deleteWaypoint(${index})">Delete</button>
            </div>
        `;
        container.appendChild(div);
    });
}

async function playWaypoint(index) {
    try {
        await fetch(`/waypoints/${index}/play`, {method: 'POST'});
    } catch (err) {
        console.error('Failed to play waypoint:', err);
    }
}

async function deleteWaypoint(index) {
    if (confirm('Delete this waypoint?')) {
        try {
            await fetch(`/waypoints/${index}`, {method: 'DELETE'});
            loadWaypoints();
        } catch (err) {
            console.error('Failed to delete waypoint:', err);
        }
    }
}

function initChart() {
    const canvas = document.getElementById('history-chart');
    chartCtx = canvas.getContext('2d');
    updateChart();
}

async function updateChart() {
    try {
        const response = await fetch('/history');
        const history = await response.json();
        drawChart(history);
    } catch (err) {
        console.error('Failed to load history:', err);
    }
}

function drawChart(history) {
    if (!chartCtx || history.length === 0) return;
    
    const canvas = chartCtx.canvas;
    const width = canvas.width;
    const height = canvas.height;
    
    chartCtx.fillStyle = '#222';
    chartCtx.fillRect(0, 0, width, height);
    
    const colors = ['#00d9ff', '#ff5252', '#00c853', '#ff9800'];
    const servoNames = ['base', 'shoulder', 'elbow', 'gripper'];
    
    const recentHistory = history.slice(-50);
    
    servoNames.forEach((servo, servoIndex) => {
        const servoData = recentHistory.filter(h => h.servo === servo);
        if (servoData.length < 2) return;
        
        chartCtx.beginPath();
        chartCtx.strokeStyle = colors[servoIndex];
        chartCtx.lineWidth = 2;
        
        servoData.forEach((point, i) => {
            const x = (i / (servoData.length - 1)) * width;
            const y = height - (point.angle / 180) * height;
            if (i === 0) {
                chartCtx.moveTo(x, y);
            } else {
                chartCtx.lineTo(x, y);
            }
        });
        
        chartCtx.stroke();
    });
    
    chartCtx.fillStyle = '#fff';
    chartCtx.font = '12px Arial';
    servoNames.forEach((servo, i) => {
        chartCtx.fillStyle = colors[i];
        chartCtx.fillText(servo, 10, 15 + i * 15);
    });
}
