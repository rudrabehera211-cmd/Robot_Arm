import os

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'roboarm-secret-key-change-in-production')
    ESP32_IP = os.environ.get('ESP32_IP', '192.168.4.1')
    ESP32_POLL_INTERVAL = 0.2  # 200ms
    
    SERVO_LIMITS = {
        'base': {'min': 0, 'max': 180, 'channel': 0},
        'shoulder': {'min': 90, 'max': 180, 'channel': 1},
        'elbow': {'min': 0, 'max': 90, 'channel': 2},
        'gripper': {'min': 90, 'max': 130, 'channel': 3}
    }
    
    PRESET_POSITIONS = {
        'home': {'base': 90, 'shoulder': 90, 'elbow': 0, 'gripper': 90},
        'grab': {'base': 90, 'shoulder': 120, 'elbow': 45, 'gripper': 130},
        'reach': {'base': 90, 'shoulder': 150, 'elbow': 60, 'gripper': 90},
        'rest': {'base': 90, 'shoulder': 90, 'elbow': 0, 'gripper': 110},
        'wave': {'base': 45, 'shoulder': 120, 'elbow': 30, 'gripper': 90}
    }
    
    CAMERA_INDEX = 0
    ALERTS_FILE = 'alerts.json'
    WAYPOINTS_FILE = 'waypoints.json'
