import json
import os
import time
import threading
from datetime import datetime
from flask import Flask, render_template, jsonify, request, Response
from config import Config
import cv2
import numpy as np

try:
    from flask_cors import CORS
except ImportError:
    def CORS(app):
        return app

app = Flask(__name__, static_folder='static', template_folder='templates')
app.config.from_object(Config)
CORS(app)

class RoboArmController:
    def __init__(self):
        self.servo_positions = {name: limits['min'] for name, limits in Config.SERVO_LIMITS.items()}
        self.lock = threading.Lock()
        self.command_queue = []
        self.connected = False
        self.last_heartbeat = 0
        self.alerts = self._load_alerts()
        self.waypoints = self._load_waypoints()
        self.guard_mode = False
        self.position_history = []
        self.camera = None
        self._init_camera()
    
    def _init_camera(self):
        try:
            self.camera = cv2.VideoCapture(Config.CAMERA_INDEX)
            self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        except Exception as e:
            print(f"Camera init failed: {e}")
            self.camera = None
    
    def _load_alerts(self):
        try:
            with open(Config.ALERTS_FILE, 'r') as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return []
    
    def _load_waypoints(self):
        try:
            with open(Config.WAYPOINTS_FILE, 'r') as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return []
    
    def _save_alerts(self):
        with open(Config.ALERTS_FILE, 'w') as f:
            json.dump(self.alerts, f, indent=2)
    
    def _save_waypoints(self):
        with open(Config.WAYPOINTS_FILE, 'w') as f:
            json.dump(self.waypoints, f, indent=2)
    
    def set_servo(self, channel, angle):
        with self.lock:
            servo_name = [k for k, v in Config.SERVO_LIMITS.items() if v['channel'] == channel][0]
            limits = Config.SERVO_LIMITS[servo_name]
            angle = max(limits['min'], min(limits['max'], angle))
            self.servo_positions[servo_name] = angle
            self.command_queue.append({'channel': channel, 'angle': angle})
            self.position_history.append({
                'time': datetime.now().isoformat(),
                'servo': servo_name,
                'angle': angle
            })
            if len(self.position_history) > 1000:
                self.position_history = self.position_history[-500:]
            return angle
    
    def get_command(self):
        with self.lock:
            if self.command_queue:
                return self.command_queue.pop(0)
            return None
    
    def update_heartbeat(self):
        self.last_heartbeat = time.time()
        self.connected = True
    
    def add_alert(self, alert_type, details=''):
        alert = {
            'time': datetime.now().isoformat(),
            'type': alert_type,
            'details': details
        }
        self.alerts.append(alert)
        if len(self.alerts) > 100:
            self.alerts = self.alerts[-50:]
        self._save_alerts()
        return alert
    
    def add_waypoint(self, name=None):
        waypoint = {
            'name': name or f"WP{len(self.waypoints)+1}",
            'positions': self.servo_positions.copy(),
            'time': datetime.now().isoformat()
        }
        self.waypoints.append(waypoint)
        self._save_waypoints()
        return waypoint
    
    def get_frame(self):
        if self.camera is None:
            return None
        ret, frame = self.camera.read()
        if not ret:
            return None
        return frame
    
    def generate_frames(self):
        while True:
            frame = self.get_frame()
            if frame is None:
                time.sleep(0.1)
                continue
            _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')

controller = RoboArmController()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/command', methods=['GET'])
def get_command():
    command = controller.get_command()
    if command:
        controller.update_heartbeat()
        return jsonify(command)
    controller.update_heartbeat()
    return jsonify({'idle': True})

@app.route('/set', methods=['POST'])
def set_servo():
    data = request.json
    if not data or 'channel' not in data or 'angle' not in data:
        return jsonify({'error': 'Missing channel or angle'}), 400
    
    channel = int(data['channel'])
    angle = int(data['angle'])
    
    if channel not in range(4):
        return jsonify({'error': 'Invalid channel'}), 400
    
    actual_angle = controller.set_servo(channel, angle)
    return jsonify({'success': True, 'angle': actual_angle})

@app.route('/positions', methods=['GET'])
def get_positions():
    return jsonify(controller.servo_positions)

@app.route('/preset/<name>', methods=['POST'])
def set_preset(name):
    if name not in Config.PRESET_POSITIONS:
        return jsonify({'error': 'Unknown preset'}), 400
    
    positions = Config.PRESET_POSITIONS[name]
    for servo_name, angle in positions.items():
        channel = Config.SERVO_LIMITS[servo_name]['channel']
        controller.set_servo(channel, angle)
    
    return jsonify({'success': True, 'positions': positions})

@app.route('/presets', methods=['GET'])
def get_presets():
    return jsonify(Config.PRESET_POSITIONS)

@app.route('/status', methods=['GET'])
def get_status():
    connected = (time.time() - controller.last_heartbeat) < 5
    return jsonify({
        'connected': connected,
        'positions': controller.servo_positions,
        'guard_mode': controller.guard_mode
    })

@app.route('/stream')
def video_stream():
    return Response(controller.generate_frames(),
                    mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/snapshot', methods=['POST'])
def snapshot():
    frame = controller.get_frame()
    if frame is None:
        return jsonify({'error': 'Camera not available'}), 500
    
    filename = f"snapshot_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
    cv2.imwrite(filename, frame)
    return jsonify({'success': True, 'filename': filename})

@app.route('/motion', methods=['POST'])
def motion_detected():
    alert = controller.add_alert('motion', 'PIR sensor triggered')
    return jsonify({'success': True, 'alert': alert})

@app.route('/alerts', methods=['GET'])
def get_alerts():
    return jsonify(controller.alerts)

@app.route('/alerts/clear', methods=['POST'])
def clear_alerts():
    controller.alerts = []
    controller._save_alerts()
    return jsonify({'success': True})

@app.route('/guard/<action>', methods=['POST'])
def guard_mode(action):
    controller.guard_mode = action == 'enable'
    return jsonify({'success': True, 'guard_mode': controller.guard_mode})

@app.route('/waypoints', methods=['GET'])
def get_waypoints():
    return jsonify(controller.waypoints)

@app.route('/waypoints/add', methods=['POST'])
def add_waypoint():
    data = request.json or {}
    waypoint = controller.add_waypoint(data.get('name'))
    return jsonify({'success': True, 'waypoint': waypoint})

@app.route('/waypoints/<int:index>/play', methods=['POST'])
def play_waypoint(index):
    if index >= len(controller.waypoints):
        return jsonify({'error': 'Invalid waypoint index'}), 400
    
    waypoint = controller.waypoints[index]
    for servo_name, angle in waypoint['positions'].items():
        channel = Config.SERVO_LIMITS[servo_name]['channel']
        controller.set_servo(channel, angle)
    
    return jsonify({'success': True, 'played': waypoint['name']})

@app.route('/waypoints/<int:index>', methods=['DELETE'])
def delete_waypoint(index):
    if index >= len(controller.waypoints):
        return jsonify({'error': 'Invalid waypoint index'}), 400
    
    controller.waypoints.pop(index)
    controller._save_waypoints()
    return jsonify({'success': True})

@app.route('/history', methods=['GET'])
def get_history():
    return jsonify(controller.position_history[-100:])

@app.route('/api/docs', methods=['GET'])
def api_docs():
    docs = {
        'endpoints': {
            'GET /': 'Web UI',
            'GET /command': 'Arduino polls this for commands',
            'POST /set': 'Set servo: {"channel": 0-3, "angle": 0-180}',
            'GET /positions': 'Get current servo positions',
            'POST /preset/<name>': 'Set preset position (home, grab, reach, rest, wave)',
            'GET /presets': 'List all presets',
            'GET /status': 'Connection status',
            'GET /stream': 'MJPEG camera stream',
            'POST /snapshot': 'Capture photo',
            'POST /motion': 'Trigger motion alert',
            'GET /alerts': 'Get alert history',
            'POST /alerts/clear': 'Clear all alerts',
            'POST /guard/enable': 'Enable guard mode',
            'POST /guard/disable': 'Disable guard mode',
            'GET /waypoints': 'List waypoints',
            'POST /waypoints/add': 'Add waypoint: {"name": "optional"}',
            'POST /waypoints/<index>/play': 'Play waypoint',
            'DELETE /waypoints/<index>': 'Delete waypoint',
            'GET /history': 'Servo position history'
        }
    }
    return jsonify(docs)

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, threaded=True)
