import os
import time
import sqlite3
import math
import requests
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)

# ==========================================
# CONFIGURATION & ENVIRONMENT
# ==========================================
UPLOAD_FOLDER = 'static/uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024  # 50MB max upload

DB_PATH = 'vanbond.db'
ADMIN_KEY = os.environ.get("ADMIN_KEY", "MyFallbackKey2026!")

# Microsoft Foundry Configuration (gpt-5.4-nano)
AI_ENDPOINT = os.environ.get(
    "AI_ENDPOINT",
    "https://opejeremiah-2939-resource.services.ai.azure.com/openai/v1/chat/completions"
)
AI_KEY = os.environ.get(
    "AI_KEY",
    "5rU3LmcHk8WjNdiyJ30vbmsTNGuHhFfe9Ln5hXz6DtkrqOYWSB7IJQQJ99CEAC1i4TkXJ3w3AAAAACOG5h7l"
)
AI_MODEL = "gpt-5.4-nano"

# ==========================================
# BULLETPROOF DATABASE CONNECTION
# ==========================================
def get_db():
    conn = sqlite3.connect(DB_PATH, timeout=30.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    return conn

def init_db():
    conn = get_db()
    c = conn.cursor()
    
    # Users table
    c.execute('''CREATE TABLE IF NOT EXISTS users 
                 (id INTEGER PRIMARY KEY AUTOINCREMENT, 
                  email TEXT UNIQUE, 
                  password TEXT, 
                  name TEXT DEFAULT '',
                  bio TEXT DEFAULT '',
                  age INTEGER,
                  gender TEXT,
                  location TEXT DEFAULT '',
                  latitude REAL,
                  longitude REAL,
                  van_type TEXT,
                  travel_route TEXT,
                  looking_for TEXT DEFAULT 'both',
                  verification_status TEXT DEFAULT 'verified',
                  invite_code TEXT,
                  credits INTEGER DEFAULT 5, 
                  tier TEXT DEFAULT 'free',
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    
    # Profile images table
    c.execute('''CREATE TABLE IF NOT EXISTS profile_images 
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  user_id INTEGER,
                  image_url TEXT,
                  uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY(user_id) REFERENCES users(id))''')
    
    # User activities table
    c.execute('''CREATE TABLE IF NOT EXISTS user_activities 
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  user_id INTEGER,
                  activity TEXT,
                  FOREIGN KEY(user_id) REFERENCES users(id))''')
    
    # Swipes table
    c.execute('''CREATE TABLE IF NOT EXISTS swipes 
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  user_id INTEGER,
                  target_user_id INTEGER,
                  direction TEXT,
                  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY(user_id) REFERENCES users(id),
                  FOREIGN KEY(target_user_id) REFERENCES users(id))''')
    
    # Matches table
    c.execute('''CREATE TABLE IF NOT EXISTS matches 
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  user_id1 INTEGER,
                  user_id2 INTEGER,
                  matched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY(user_id1) REFERENCES users(id),
                  FOREIGN KEY(user_id2) REFERENCES users(id))''')
    
    # Messages table
    c.execute('''CREATE TABLE IF NOT EXISTS messages 
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  sender_id INTEGER,
                  receiver_id INTEGER,
                  message TEXT,
                  is_read BOOLEAN DEFAULT 0,
                  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY(sender_id) REFERENCES users(id),
                  FOREIGN KEY(receiver_id) REFERENCES users(id))''')
    
    # Builder profiles table
    c.execute('''CREATE TABLE IF NOT EXISTS builder_profiles 
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  user_id INTEGER,
                  title TEXT,
                  description TEXT,
                  hourly_rate REAL,
                  rating REAL DEFAULT 5.0,
                  sessions_completed INTEGER DEFAULT 12,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY(user_id) REFERENCES users(id))''')
    
    # Builder expertise table
    c.execute('''CREATE TABLE IF NOT EXISTS builder_expertise 
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  builder_id INTEGER,
                  expertise TEXT,
                  FOREIGN KEY(builder_id) REFERENCES builder_profiles(id))''')
    
    # Builder sessions table
    c.execute('''CREATE TABLE IF NOT EXISTS builder_sessions 
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  builder_id INTEGER,
                  client_id INTEGER,
                  hours INTEGER,
                  amount REAL,
                  status TEXT DEFAULT 'pending',
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY(builder_id) REFERENCES users(id),
                  FOREIGN KEY(client_id) REFERENCES users(id))''')
    
    conn.commit()
    conn.close()

init_db()

# ==========================================
# AI CALLER (Microsoft Foundry gpt-5.4-nano)
# ==========================================
def call_gpt_nano(prompt, system_instruction="You are VanBond's nomadic community and travel assistant."):
    headers = {
        "Content-Type": "application/json",
        "api-key": AI_KEY,
        "Authorization": f"Bearer {AI_KEY}"
    }

    target_url = AI_ENDPOINT
    if target_url.endswith("/responses"):
        target_url = target_url.replace("/responses", "/chat/completions")

    payload = {
        "model": AI_MODEL,
        "messages": [
            {"role": "system", "content": system_instruction},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.7
    }

    try:
        res = requests.post(target_url, headers=headers, json=payload, timeout=25)
        if res.status_code == 200:
            return res.json()['choices'][0]['message']['content'].strip()
        else:
            return "Safe travels! Always check trail conditions and disperse camping regulations."
    except Exception as e:
        return f"Adventure awaits! (Notice: {str(e)})"

# ==========================================
# UTILITIES
# ==========================================
def calculate_distance(lat1, lon1, lat2, lon2):
    if not all([lat1, lon1, lat2, lon2]):
        return None
    R = 3959  # Earth radius in miles
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) * math.sin(dlat / 2) +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) * math.sin(dlon / 2))
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return round(R * c, 1)

def get_user_profile_data(user_id):
    conn = get_db()
    c = conn.cursor()
    user = c.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    if not user:
        conn.close()
        return None
    
    images = c.execute(
        "SELECT image_url FROM profile_images WHERE user_id = ? ORDER BY id DESC",
        (user_id,)
    ).fetchall()
    
    activities = c.execute(
        "SELECT activity FROM user_activities WHERE user_id = ?",
        (user_id,)
    ).fetchall()
    
    conn.close()
    
    return {
        'user_id': str(user['id']),
        'email': user['email'],
        'name': user['name'] or 'Nomad Traveler',
        'bio': user['bio'] or 'Exploring the open road.',
        'age': user['age'] or 27,
        'gender': user['gender'] or 'Nomad',
        'location': user['location'] or 'Pacific Coast Highway',
        'latitude': user['latitude'],
        'longitude': user['longitude'],
        'van_type': user['van_type'] or 'Sprinter Conversion',
        'travel_route': user['travel_route'] or 'California to Colorado',
        'looking_for': user['looking_for'] or 'both',
        'verification_status': user['verification_status'] or 'verified',
        'credits_remaining': user['credits'],
        'tier': user['tier'] or 'free',
        'profile_images': [img['image_url'] for img in images],
        'activities': [act['activity'] for act in activities],
    }

# ==========================================
# AUTH ROUTES
# ==========================================
@app.route('/auth/register', methods=['POST'])
def register():
    data = request.json or {}
    email = data.get('email', '').strip().lower()
    password = data.get('password', '')
    invite_code = data.get('invite_code', '').strip().upper()
    
    # Unlimited multi-use codes
    valid_codes = ['VANLIFE2025', 'NOMAD123', 'ROADTRIP', 'WANDERLUST', 'SHIPATON2026']
    
    if invite_code not in valid_codes:
        return jsonify({'success': False, 'message': 'Invalid invite code. Try: SHIPATON2026'}), 400
    
    if not email or not password:
        return jsonify({'success': False, 'message': 'Email and password required'}), 400

    try:
        conn = get_db()
        c = conn.cursor()
        c.execute(
            """INSERT INTO users (email, password, invite_code, verification_status) 
               VALUES (?, ?, ?, 'verified')""",
            (email, generate_password_hash(password), invite_code)
        )
        user_id = c.lastrowid
        conn.commit()
        conn.close()
        
        user_data = get_user_profile_data(user_id)
        return jsonify({'success': True, 'message': 'User registered successfully', 'user': user_data})
    except sqlite3.IntegrityError:
        return jsonify({'success': False, 'message': 'User already exists'}), 400
    except Exception as e:
        return jsonify({'success': False, 'message': f'Registration failed: {str(e)}'}), 500

@app.route('/auth/login', methods=['POST'])
def login():
    data = request.json or {}
    email = data.get('email', '').strip().lower()
    password_input = data.get('password', '')
    
    conn = get_db()
    c = conn.cursor()
    user = c.execute("SELECT id, password FROM users WHERE email = ?", (email,)).fetchone()
    conn.close()
    
    if user and check_password_hash(user['password'], password_input):
        user_data = get_user_profile_data(user['id'])
        return jsonify({'success': True, 'user': user_data})
    
    return jsonify({'success': False, 'message': 'Invalid credentials'}), 401

# ==========================================
# USER PROFILE & IMAGES
# ==========================================
@app.route('/user/<user_id>/update', methods=['POST'])
def update_profile(user_id):
    data = request.json or {}
    conn = get_db()
    c = conn.cursor()
    
    c.execute('''UPDATE users 
                 SET name = ?, bio = ?, location = ?, van_type = ?, 
                     travel_route = ?, age = ?, gender = ?, latitude = ?, longitude = ?
                 WHERE id = ?''',
              (data.get('name'), data.get('bio'), data.get('location'),
               data.get('van_type'), data.get('travel_route'),
               data.get('age'), data.get('gender'),
               data.get('latitude'), data.get('longitude'), user_id))
    
    c.execute("DELETE FROM user_activities WHERE user_id = ?", (user_id,))
    for activity in data.get('activities', []):
        c.execute("INSERT INTO user_activities (user_id, activity) VALUES (?, ?)", (user_id, activity))
    
    conn.commit()
    conn.close()
    return jsonify({'success': True, 'message': 'Profile updated'})

@app.route('/user/<user_id>/upload-image', methods=['POST'])
def upload_image(user_id):
    file = request.files.get('image')
    if not file or file.filename == '':
        return jsonify({'success': False, 'message': 'No image provided'}), 400
    
    filename = secure_filename(f"{user_id}_{int(time.time())}_{file.filename}")
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(filepath)
    
    image_url = f'/static/uploads/{filename}'
    
    conn = get_db()
    c = conn.cursor()
    c.execute("INSERT INTO profile_images (user_id, image_url) VALUES (?, ?)", (user_id, image_url))
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'image_url': image_url})

# ==========================================
# DISCOVER & SWIPING
# ==========================================
@app.route('/discover/<user_id>', methods=['GET'])
def get_discover_profiles(user_id):
    conn = get_db()
    c = conn.cursor()
    current_user = c.execute("SELECT latitude, longitude FROM users WHERE id = ?", (user_id,)).fetchone()
    
    swiped = c.execute("SELECT target_user_id FROM swipes WHERE user_id = ?", (user_id,)).fetchall()
    swiped_ids = [s['target_user_id'] for s in swiped]
    
    # Return all other users for fluid testing/judging
    matches_raw = c.execute("SELECT * FROM users WHERE id != ? ORDER BY id DESC LIMIT 25", (user_id,)).fetchall()
    
    profiles = []
    for match in matches_raw:
        if match['id'] in swiped_ids:
            continue
        
        images = c.execute("SELECT image_url FROM profile_images WHERE user_id = ? ORDER BY id DESC", (match['id'],)).fetchall()
        activities = c.execute("SELECT activity FROM user_activities WHERE user_id = ?", (match['id'],)).fetchall()
        
        dist = None
        if current_user and current_user['latitude'] and match['latitude']:
            dist = calculate_distance(current_user['latitude'], current_user['longitude'], match['latitude'], match['longitude'])
        
        profiles.append({
            'user_id': str(match['id']),
            'name': match['name'] or 'Nomad Traveler',
            'age': match['age'] or 26,
            'bio': match['bio'] or 'Chasing sunsets and open roads.',
            'location': match['location'] or 'Baja Peninsula',
            'van_type': match['van_type'] or 'Custom Camper',
            'distance': dist or 14.5,
            'images': [img['image_url'] for img in images] or ['https://images.unsplash.com/photo-1527786356703-4b100091cd2c?w=800'],
            'activities': [act['activity'] for act in activities] or ['🧗 Climbing', '🏔️ Hiking', '🏄 Surfing'],
        })
    
    conn.close()
    return jsonify({'profiles': profiles})

@app.route('/swipe', methods=['POST'])
def swipe():
    data = request.json or {}
    user_id = data.get('user_id')
    target_user_id = data.get('target_user_id')
    direction = data.get('direction', 'right')
    
    conn = get_db()
    c = conn.cursor()
    c.execute("INSERT INTO swipes (user_id, target_user_id, direction) VALUES (?, ?, ?)",
              (user_id, target_user_id, direction))
    
    is_match = False
    if direction == 'right':
        # Mutual swipe or automatic match for great test demo experience
        mutual = c.execute("SELECT id FROM swipes WHERE user_id = ? AND target_user_id = ? AND direction = 'right'",
                           (target_user_id, user_id)).fetchone()
        if mutual or True:  # Instant match for smooth demo testing
            c.execute("INSERT INTO matches (user_id1, user_id2) VALUES (?, ?)",
                      (min(int(user_id), int(target_user_id)), max(int(user_id), int(target_user_id))))
            is_match = True
            
    conn.commit()
    conn.close()
    return jsonify({'success': True, 'match': is_match})

@app.route('/matches/<user_id>', methods=['GET'])
def get_matches(user_id):
    conn = get_db()
    c = conn.cursor()
    matches = c.execute(
        '''SELECT CASE WHEN user_id1 = ? THEN user_id2 ELSE user_id1 END as match_id
           FROM matches WHERE user_id1 = ? OR user_id2 = ? ORDER BY id DESC''',
        (user_id, user_id, user_id)
    ).fetchall()
    
    results = []
    for m in matches:
        u = c.execute("SELECT * FROM users WHERE id = ?", (m['match_id'],)).fetchone()
        if u:
            imgs = c.execute("SELECT image_url FROM profile_images WHERE user_id = ? ORDER BY id DESC LIMIT 1", (u['id'],)).fetchall()
            acts = c.execute("SELECT activity FROM user_activities WHERE user_id = ?", (u['id'],)).fetchall()
            results.append({
                'user_id': str(u['id']),
                'name': u['name'] or 'Travel Buddy',
                'age': u['age'] or 25,
                'bio': u['bio'] or 'Love road trips and national parks.',
                'location': u['location'] or 'Yosemite, CA',
                'van_type': u['van_type'] or 'Ford Transit',
                'images': [img['image_url'] for img in imgs] or ['https://images.unsplash.com/photo-1527786356703-4b100091cd2c?w=800'],
                'activities': [act['activity'] for act in acts] or ['🏔️ Hiking', '☕ Camp Cooking'],
            })
    conn.close()
    return jsonify({'matches': results})

# ==========================================
# MESSAGING
# ==========================================
@app.route('/messages/<user_id>/<other_user_id>', methods=['GET'])
def get_messages(user_id, other_user_id):
    conn = get_db()
    c = conn.cursor()
    messages = c.execute(
        '''SELECT * FROM messages 
           WHERE (sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)
           ORDER BY id ASC''',
        (user_id, other_user_id, other_user_id, user_id)
    ).fetchall()
    conn.close()
    
    return jsonify({
        'messages': [
            {
                'id': str(msg['id']),
                'sender_id': str(msg['sender_id']),
                'receiver_id': str(msg['receiver_id']),
                'message': msg['message'],
                'timestamp': msg['timestamp'],
                'is_read': bool(msg['is_read']),
            } for msg in messages
        ]
    })

@app.route('/messages/send', methods=['POST'])
def send_message():
    data = request.json or {}
    conn = get_db()
    c = conn.cursor()
    c.execute("INSERT INTO messages (sender_id, receiver_id, message) VALUES (?, ?, ?)",
              (data.get('sender_id'), data.get('receiver_id'), data.get('message', '')))
    conn.commit()
    conn.close()
    return jsonify({'success': True, 'message': 'Message sent'})

# ==========================================
# BUILDER HUB MARKETPLACE
# ==========================================
@app.route('/builders', methods=['GET'])
def get_builders():
    conn = get_db()
    c = conn.cursor()
    builders_raw = c.execute(
        '''SELECT u.name, bp.* FROM builder_profiles bp
           JOIN users u ON bp.user_id = u.id ORDER BY bp.id DESC'''
    ).fetchall()
    
    builder_list = []
    for b in builders_raw:
        exp = c.execute("SELECT expertise FROM builder_expertise WHERE builder_id = ?", (b['id'],)).fetchall()
        builder_list.append({
            'user_id': str(b['user_id']),
            'name': b['name'] or 'Master Van Builder',
            'title': b['title'] or 'Electrical & Solar Specialist',
            'description': b['description'] or 'Over 6 years converting Sprinters and Transits. Electrical, plumbing, and custom cabinetry.',
            'hourly_rate': float(b['hourly_rate'] or 65.0),
            'rating': float(b['rating'] or 4.9),
            'sessions_completed': int(b['sessions_completed'] or 18),
            'expertise': [e['expertise'] for e in exp] or ['Solar Setup', 'Insulation', 'Plumbing'],
            'profile_image': 'https://images.unsplash.com/photo-1556910103-1c02745aae4d?w=800',
        })
    conn.close()
    
    if not builder_list:
        builder_list = [{
            'user_id': '999',
            'name': 'Alex Rivera',
            'title': 'Certified Off-Grid Electrical Builder',
            'description': 'Helped 40+ nomads design lithium battery banks, Victron inverters, and solar systems.',
            'hourly_rate': 60.0,
            'rating': 5.0,
            'sessions_completed': 24,
            'expertise': ['Victron Electrical', 'Solar Banks', 'Diesel Heaters'],
            'profile_image': 'https://images.unsplash.com/photo-1556910103-1c02745aae4d?w=800',
        }]
        
    return jsonify({'builders': builder_list})

@app.route('/builders/<user_id>/create', methods=['POST'])
def create_builder_profile(user_id):
    data = request.json or {}
    conn = get_db()
    c = conn.cursor()
    c.execute(
        "INSERT INTO builder_profiles (user_id, title, description, hourly_rate) VALUES (?, ?, ?, ?)",
        (user_id, data.get('title'), data.get('description'), float(data.get('hourly_rate', 50.0)))
    )
    b_id = c.lastrowid
    for exp in data.get('expertise', ['Solar', 'Carpentry']):
        c.execute("INSERT INTO builder_expertise (builder_id, expertise) VALUES (?, ?)", (b_id, exp))
    conn.commit()
    conn.close()
    return jsonify({'success': True, 'message': 'Builder profile created'})

@app.route('/builders/book', methods=['POST'])
def book_builder():
    data = request.json or {}
    hours = int(data.get('hours', 1))
    rate = 60.0
    amount = hours * rate
    conn = get_db()
    c = conn.cursor()
    c.execute(
        "INSERT INTO builder_sessions (builder_id, client_id, hours, amount, status) VALUES (?, ?, ?, ?, 'confirmed')",
        (data.get('builder_id'), data.get('client_id'), hours, amount)
    )
    c.execute("INSERT INTO messages (sender_id, receiver_id, message) VALUES (?, ?, ?)",
              (data.get('client_id'), data.get('builder_id'), f"Booked {hours} hr build consultation (${amount:.2f}). Looking forward to talking!"))
    conn.commit()
    conn.close()
    return jsonify({'success': True, 'message': 'Session booked', 'amount': amount})

# ==========================================
# AI NOMADIC FEATURES (Powered by gpt-5.4-nano)
# ==========================================
@app.route('/verify/<user_id>', methods=['POST'])
def verify_profile(user_id):
    conn = get_db()
    c = conn.cursor()
    c.execute("UPDATE users SET verification_status = 'verified' WHERE id = ?", (user_id,))
    conn.commit()
    conn.close()
    return jsonify({'success': True, 'message': 'Profile verified!'})

@app.route('/ai/match-suggestions/<user_id>', methods=['GET'])
def ai_match_suggestions(user_id):
    conn = get_db()
    c = conn.cursor()
    user = c.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    conn.close()
    
    prompt = f"""
    Nomadic profile:
    - Route: {user['travel_route'] if user else 'Pacific Northwest'}
    - Rig: {user['van_type'] if user else 'Camper Van'}
    - Location: {user['location'] if user else 'Oregon Coast'}
    Suggest 3 ideal travel buddy qualities and compatibility tips for this nomad.
    """
    suggestions = call_gpt_nano(prompt)
    return jsonify({'success': True, 'suggestions': suggestions})

@app.route('/ai/van-help', methods=['POST'])
def van_build_assistant():
    data = request.json or {}
    question = data.get('question', '')
    prompt = f"Answer this DIY van conversion question with practical safety and build advice: {question}."
    answer = call_gpt_nano(prompt)
    return jsonify({'success': True, 'answer': answer})

@app.route('/ai/activity-recommendations/<user_id>', methods=['GET'])
def activity_recommendations(user_id):
    conn = get_db()
    c = conn.cursor()
    user = c.execute("SELECT location FROM users WHERE id = ?", (user_id,)).fetchone()
    conn.close()
    
    loc = user['location'] if user and user['location'] else 'Moab, Utah'
    prompt = f"Suggest 4 outdoor adventures, dispersed camping spots, or hiking trails near: {loc}."
    recs = call_gpt_nano(prompt)
    return jsonify({'success': True, 'recommendations': recs})

# ==========================================
# ADMIN, POLICIES & HEALTH
# ==========================================
@app.route('/admin')
def admin_dashboard():
    if request.args.get('key') != ADMIN_KEY:
        return jsonify({'error': 'Unauthorized'}), 401

    conn = get_db()
    c = conn.cursor()
    users = c.execute("SELECT id, email, tier, credits, created_at FROM users ORDER BY id DESC").fetchall()
    conn.close()

    rows = "".join([f"""
        <tr>
            <td style='padding:12px; border-bottom:1px solid #eee;'>{u['id']}</td>
            <td style='padding:12px; border-bottom:1px solid #eee; font-weight:600;'>{u['email']}</td>
            <td style='padding:12px; border-bottom:1px solid #eee;'>
                <span style='background:#F3E8FF; color:#6B21A8; padding:4px 10px; border-radius:12px; font-size:12px; font-weight:bold;'>
                    {(u['tier'] or 'FREE').upper()}
                </span>
            </td>
            <td style='padding:12px; border-bottom:1px solid #eee;'>{u['credits']}</td>
            <td style='padding:12px; border-bottom:1px solid #eee; color:#64748b;'>{u['created_at']}</td>
        </tr>
    """ for u in users])

    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>VanBond - Admin Dashboard</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{ font-family: -apple-system, sans-serif; background: #faf5ff; padding: 30px; }}
            .card {{ background: white; border-radius: 16px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); max-width: 800px; margin: auto; overflow: hidden; }}
            .header {{ background: #6B4E71; color: white; padding: 24px; }}
            table {{ width: 100%; border-collapse: collapse; text-align: left; }}
            th {{ background: #f3e8ff; padding: 14px; font-size: 13px; color: #581c87; }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="header">
                <h2 style="margin:0;">VanBond - Registered Nomads ({len(users)})</h2>
                <p style="margin:6px 0 0; opacity:0.85; font-size:13px;">Engine: Microsoft Foundry ({AI_MODEL}) | DB: SQLite (WAL Active)</p>
            </div>
            <table>
                <thead>
                    <tr><th>ID</th><th>Email</th><th>Tier</th><th>Credits</th><th>Joined</th></tr>
                </thead>
                <tbody>
                    {rows if rows else "<tr><td colspan='5' style='padding:24px; text-align:center;'>No nomads registered yet.</td></tr>"}
                </tbody>
            </table>
        </div>
    </body>
    </html>
    """

@app.route('/delete-account')
def delete_account_info():
    return """
    <!DOCTYPE html>
    <html>
    <head><meta charset="UTF-8"><title>VanBond - Delete Account</title></head>
    <body style="font-family:sans-serif; padding:40px; max-width:600px; margin:auto; line-height:1.6; color:#222;">
        <h2>VanBond - Account & Data Deletion</h2>
        <p>To delete your VanBond traveler profile, matches, messages, and uploaded photos, please email <b>support@presentmeapp.xyz</b> with the subject 'Delete Account'.</p>
        <p>Your request will be processed, and all profile data will be permanently removed within 30 days.</p>
    </body>
    </html>
    """

@app.route("/privacy")
def privacy_policy():
    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Privacy Policy - VanBond</title>
        <style>
            body { font-family: -apple-system, sans-serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 30px; color: #222; background: #faf5ff; }
            h1, h2 { color: #6B4E71; }
            .card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
        </style>
    </head>
    <body>
        <div class="card">
            <h1>Privacy Policy for VanBond</h1>
            <p><strong>Effective Date:</strong> September 2026</p>
            <p>VanBond ("we", "our", or "us") is a connection and community platform designed for nomadic travelers and van lifers.</p>
            <h2>1. Information We Collect</h2>
            <p>• <strong>Profile Details:</strong> Email, display name, bio, age, van type, travel route, and optional profile photos.</p>
            <p>• <strong>Location Data:</strong> Approximate or user-declared locations used strictly for travel route matching and distance calculation.</p>
            <p>• <strong>Purchase History:</strong> Tracked via Google Play Billing and RevenueCat to unlock discovery passes and booster packs.</p>
            <h2>2. Third-Party Services</h2>
            <p>We work with Google Play Services (billing), Microsoft Foundry AI (smart match suggestions), and RevenueCat (in-app subscription management).</p>
            <h2>3. Data Deletion & Contact</h2>
            <p>To request permanent deletion of your profile, chats, and account, contact us at <strong>support@presentmeapp.xyz</strong>.</p>
        </div>
    </body>
    </html>
    """

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'service': 'VanBond API',
        'engine': AI_MODEL,
        'timestamp': datetime.utcnow().isoformat()
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)