import os
import time
import sqlite3
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from google import genai
from google.genai import types
import math

app = Flask(__name__)
CORS(app)

# CONFIGURATION
UPLOAD_FOLDER = 'static/uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024  # 50MB max upload

# INITIALIZE GOOGLE AI CLIENT
GEMINI_API_KEY ="AQ.Ab8RN6L38tUETkvV4SAi0rlRfhjOSsCvSlmuBI8BhNbiU_pqiQ"
ADMIN_KEY = os.environ.get("ADMIN_KEY", "MyFallbackKey2026!")
client = genai.Client(api_key=GEMINI_API_KEY, http_options={'api_version': 'v1alpha'})

# DATABASE SETUP
def init_db():
    conn = sqlite3.connect('vanbond.db')
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
                  verification_status TEXT DEFAULT 'pending',
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
                  rating REAL DEFAULT 0,
                  sessions_completed INTEGER DEFAULT 0,
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
    
    # Invite codes table
    c.execute('''CREATE TABLE IF NOT EXISTS invite_codes 
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  code TEXT UNIQUE,
                  created_by INTEGER,
                  used_by INTEGER,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY(created_by) REFERENCES users(id),
                  FOREIGN KEY(used_by) REFERENCES users(id))''')
    
    # Create some default invite codes for testing
    default_codes = ['VANLIFE2025', 'NOMAD123', 'ROADTRIP', 'WANDERLUST']
    for code in default_codes:
        try:
            c.execute("INSERT INTO invite_codes (code) VALUES (?)", (code,))
        except:
            pass  # Code already exists
    
    conn.commit()
    conn.close()

init_db()

# UTILITY FUNCTIONS

def get_db():
    conn = sqlite3.connect('vanbond.db')
    conn.row_factory = sqlite3.Row
    return conn

def calculate_distance(lat1, lon1, lat2, lon2):
    """Calculate distance in miles between two coordinates"""
    if not all([lat1, lon1, lat2, lon2]):
        return None
    
    R = 3959  # Earth radius in miles
    
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    
    a = (math.sin(dlat / 2) * math.sin(dlat / 2) +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) * math.sin(dlon / 2))
    
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    distance = R * c
    
    return distance

def get_user_profile_data(user_id):
    """Get complete user profile with images and activities"""
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    
    if not user:
        return None
    
    # Get profile images
    images = conn.execute(
        "SELECT image_url FROM profile_images WHERE user_id = ? ORDER BY uploaded_at DESC",
        (user_id,)
    ).fetchall()
    
    # Get activities
    activities = conn.execute(
        "SELECT activity FROM user_activities WHERE user_id = ?",
        (user_id,)
    ).fetchall()
    
    conn.close()
    
    return {
        'user_id': str(user['id']),
        'email': user['email'],
        'name': user['name'],
        'bio': user['bio'],
        'age': user['age'],
        'gender': user['gender'],
        'location': user['location'],
        'latitude': user['latitude'],
        'longitude': user['longitude'],
        'van_type': user['van_type'],
        'travel_route': user['travel_route'],
        'looking_for': user['looking_for'],
        'verification_status': user['verification_status'],
        'credits_remaining': user['credits'],
        'tier': user['tier'],
        'profile_images': [img['image_url'] for img in images],
        'activities': [act['activity'] for act in activities],
    }

# === AUTH ROUTES ===

@app.route('/auth/register', methods=['POST'])
def register():
    data = request.json
    email = data.get('email')
    password = generate_password_hash(data.get('password'))
    invite_code = data.get('invite_code')
    
    # Verify invite code
    conn = get_db()
    code = conn.execute(
        "SELECT * FROM invite_codes WHERE code = ? AND used_by IS NULL",
        (invite_code,)
    ).fetchone()
    
    if not code:
        return jsonify({'success': False, 'message': 'Invalid or already used invite code'}), 400
    
    try:
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO users (email, password, invite_code) VALUES (?, ?, ?)",
            (email, password, invite_code)
        )
        user_id = cursor.lastrowid
        
        # Mark invite code as used
        conn.execute(
            "UPDATE invite_codes SET used_by = ? WHERE code = ?",
            (user_id, invite_code)
        )
        
        conn.commit()
        
        user_data = get_user_profile_data(user_id)
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'User registered successfully',
            'user': user_data
        })
    except Exception as e:
        conn.close()
        return jsonify({'success': False, 'message': 'User already exists or registration failed'}), 400

@app.route('/auth/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email')
    password_input = data.get('password')
    
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
    conn.close()
    
    if user and check_password_hash(user['password'], password_input):
        user_data = get_user_profile_data(user['id'])
        return jsonify({'success': True, 'user': user_data})
    
    return jsonify({'success': False, 'message': 'Invalid credentials'}), 401

# === USER PROFILE ROUTES ===

@app.route('/user/<user_id>/update', methods=['POST'])
def update_profile(user_id):
    data = request.json
    
    conn = get_db()
    
    # Update basic info
    conn.execute('''UPDATE users 
                    SET name = ?, bio = ?, location = ?, van_type = ?, 
                        travel_route = ?, age = ?, gender = ?, latitude = ?, longitude = ?
                    WHERE id = ?''',
                 (data.get('name'), data.get('bio'), data.get('location'),
                  data.get('van_type'), data.get('travel_route'),
                  data.get('age'), data.get('gender'),
                  data.get('latitude'), data.get('longitude'), user_id))
    
    # Update activities
    conn.execute("DELETE FROM user_activities WHERE user_id = ?", (user_id,))
    for activity in data.get('activities', []):
        conn.execute("INSERT INTO user_activities (user_id, activity) VALUES (?, ?)",
                    (user_id, activity))
    
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'message': 'Profile updated'})

@app.route('/user/<user_id>/upload-image', methods=['POST'])
def upload_image(user_id):
    if 'image' not in request.files:
        return jsonify({'success': False, 'message': 'No image provided'}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({'success': False, 'message': 'No file selected'}), 400
    
    filename = secure_filename(f"{user_id}_{int(time.time())}_{file.filename}")
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(filepath)
    
    image_url = f'/static/uploads/{filename}'
    
    conn = get_db()
    conn.execute("INSERT INTO profile_images (user_id, image_url) VALUES (?, ?)",
                (user_id, image_url))
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'image_url': image_url})

# === DISCOVER & MATCHING ROUTES ===

@app.route('/discover/<user_id>', methods=['GET'])
def get_discover_profiles(user_id):
    mode = request.args.get('mode', 'dating')  # dating or friends
    
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    
    # Get users already swiped on
    swiped = conn.execute(
        "SELECT target_user_id FROM swipes WHERE user_id = ?",
        (user_id,)
    ).fetchall()
    swiped_ids = [s['target_user_id'] for s in swiped]
    
    # Build query based on mode
    if mode == 'dating':
        # Show opposite gender or same gender based on preferences
        query = '''SELECT * FROM users 
                   WHERE id != ? 
                   AND (verification_status = 'verified' OR verification_status = 'pending')
                   AND (looking_for = 'dating' OR looking_for = 'both')
                   ORDER BY RANDOM() LIMIT 20'''
    else:
        # Friends mode - show everyone
        query = '''SELECT * FROM users 
                   WHERE id != ? 
                   AND (verification_status = 'verified' OR verification_status = 'pending')
                   AND (looking_for = 'friends' OR looking_for = 'both')
                   ORDER BY RANDOM() LIMIT 20'''
    
    potential_matches = conn.execute(query, (user_id,)).fetchall()
    
    profiles = []
    for match in potential_matches:
        if match['id'] in swiped_ids:
            continue
        
        # Get images
        images = conn.execute(
            "SELECT image_url FROM profile_images WHERE user_id = ? ORDER BY uploaded_at DESC",
            (match['id'],)
        ).fetchall()
        
        # Get activities
        activities = conn.execute(
            "SELECT activity FROM user_activities WHERE user_id = ?",
            (match['id'],)
        ).fetchall()
        
        # Calculate distance if both users have coordinates
        distance = None
        if user['latitude'] and user['longitude'] and match['latitude'] and match['longitude']:
            distance = calculate_distance(
                user['latitude'], user['longitude'],
                match['latitude'], match['longitude']
            )
        
        profiles.append({
            'user_id': str(match['id']),
            'name': match['name'] or 'Anonymous',
            'age': match['age'],
            'bio': match['bio'],
            'location': match['location'],
            'van_type': match['van_type'],
            'distance': distance,
            'images': [img['image_url'] for img in images],
            'activities': [act['activity'] for act in activities],
        })
    
    conn.close()
    return jsonify({'profiles': profiles})

@app.route('/swipe', methods=['POST'])
def swipe():
    data = request.json
    user_id = data.get('user_id')
    target_user_id = data.get('target_user_id')
    direction = data.get('direction')  # 'left' or 'right'
    
    conn = get_db()
    
    # Record the swipe
    conn.execute(
        "INSERT INTO swipes (user_id, target_user_id, direction) VALUES (?, ?, ?)",
        (user_id, target_user_id, direction)
    )
    
    is_match = False
    
    # Check if it's a match (both users swiped right)
    if direction == 'right':
        mutual = conn.execute(
            '''SELECT * FROM swipes 
               WHERE user_id = ? AND target_user_id = ? AND direction = 'right' ''',
            (target_user_id, user_id)
        ).fetchone()
        
        if mutual:
            # Create match
            conn.execute(
                "INSERT INTO matches (user_id1, user_id2) VALUES (?, ?)",
                (min(int(user_id), int(target_user_id)), max(int(user_id), int(target_user_id)))
            )
            is_match = True
    
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'match': is_match})

@app.route('/matches/<user_id>', methods=['GET'])
def get_matches(user_id):
    conn = get_db()
    
    # Get all matches
    matches = conn.execute(
        '''SELECT CASE 
               WHEN user_id1 = ? THEN user_id2 
               ELSE user_id1 
           END as match_id
           FROM matches 
           WHERE user_id1 = ? OR user_id2 = ?
           ORDER BY matched_at DESC''',
        (user_id, user_id, user_id)
    ).fetchall()
    
    match_profiles = []
    for match in matches:
        match_id = match['match_id']
        user = conn.execute("SELECT * FROM users WHERE id = ?", (match_id,)).fetchone()
        
        images = conn.execute(
            "SELECT image_url FROM profile_images WHERE user_id = ? ORDER BY uploaded_at DESC LIMIT 1",
            (match_id,)
        ).fetchall()
        
        activities = conn.execute(
            "SELECT activity FROM user_activities WHERE user_id = ?",
            (match_id,)
        ).fetchall()
        
        match_profiles.append({
            'user_id': str(user['id']),
            'name': user['name'] or 'Anonymous',
            'age': user['age'],
            'bio': user['bio'],
            'location': user['location'],
            'van_type': user['van_type'],
            'images': [img['image_url'] for img in images],
            'activities': [act['activity'] for act in activities],
        })
    
    conn.close()
    return jsonify({'matches': match_profiles})

# === MESSAGING ROUTES ===

@app.route('/messages/<user_id>/<other_user_id>', methods=['GET'])
def get_messages(user_id, other_user_id):
    conn = get_db()
    
    messages = conn.execute(
        '''SELECT * FROM messages 
           WHERE (sender_id = ? AND receiver_id = ?) 
              OR (sender_id = ? AND receiver_id = ?)
           ORDER BY timestamp ASC''',
        (user_id, other_user_id, other_user_id, user_id)
    ).fetchall()
    
    # Mark messages as read
    conn.execute(
        '''UPDATE messages SET is_read = 1 
           WHERE receiver_id = ? AND sender_id = ?''',
        (user_id, other_user_id)
    )
    conn.commit()
    
    message_list = [{
        'id': str(msg['id']),
        'sender_id': str(msg['sender_id']),
        'receiver_id': str(msg['receiver_id']),
        'message': msg['message'],
        'timestamp': msg['timestamp'],
        'is_read': bool(msg['is_read']),
    } for msg in messages]
    
    conn.close()
    return jsonify({'messages': message_list})

@app.route('/messages/send', methods=['POST'])
def send_message():
    data = request.json
    sender_id = data.get('sender_id')
    receiver_id = data.get('receiver_id')
    message = data.get('message')
    
    conn = get_db()
    conn.execute(
        "INSERT INTO messages (sender_id, receiver_id, message) VALUES (?, ?, ?)",
        (sender_id, receiver_id, message)
    )
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'message': 'Message sent'})

# === BUILDER HUB ROUTES ===

@app.route('/builders', methods=['GET'])
def get_builders():
    conn = get_db()
    
    builders = conn.execute(
        '''SELECT u.*, bp.* 
           FROM builder_profiles bp
           JOIN users u ON bp.user_id = u.id
           ORDER BY bp.rating DESC, bp.sessions_completed DESC'''
    ).fetchall()
    
    builder_list = []
    for builder in builders:
        # Get expertise
        expertise = conn.execute(
            "SELECT expertise FROM builder_expertise WHERE builder_id = ?",
            (builder['id'],)
        ).fetchall()
        
        # Get profile image
        image = conn.execute(
            "SELECT image_url FROM profile_images WHERE user_id = ? ORDER BY uploaded_at DESC LIMIT 1",
            (builder['user_id'],)
        ).fetchone()
        
        builder_list.append({
            'user_id': str(builder['user_id']),
            'name': builder['name'] or 'Builder',
            'title': builder['title'],
            'description': builder['description'],
            'hourly_rate': builder['hourly_rate'],
            'rating': builder['rating'],
            'sessions_completed': builder['sessions_completed'],
            'expertise': [exp['expertise'] for exp in expertise],
            'profile_image': image['image_url'] if image else None,
        })
    
    conn.close()
    return jsonify({'builders': builder_list})

@app.route('/builders/<user_id>/create', methods=['POST'])
def create_builder_profile(user_id):
    data = request.json
    
    conn = get_db()
    cursor = conn.cursor()
    
    # Create builder profile
    cursor.execute(
        '''INSERT INTO builder_profiles (user_id, title, description, hourly_rate) 
           VALUES (?, ?, ?, ?)''',
        (user_id, data.get('title'), data.get('description'), data.get('hourly_rate'))
    )
    builder_id = cursor.lastrowid
    
    # Add expertise
    for exp in data.get('expertise', []):
        conn.execute(
            "INSERT INTO builder_expertise (builder_id, expertise) VALUES (?, ?)",
            (builder_id, exp)
        )
    
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'message': 'Builder profile created'})

@app.route('/builders/book', methods=['POST'])
def book_builder():
    data = request.json
    client_id = data.get('client_id')
    builder_id = data.get('builder_id')
    hours = data.get('hours')
    
    conn = get_db()
    
    # Get builder hourly rate
    builder = conn.execute(
        "SELECT hourly_rate FROM builder_profiles WHERE user_id = ?",
        (builder_id,)
    ).fetchone()
    
    if not builder:
        return jsonify({'success': False, 'message': 'Builder not found'}), 404
    
    amount = builder['hourly_rate'] * hours
    
    # Create session
    conn.execute(
        '''INSERT INTO builder_sessions (builder_id, client_id, hours, amount, status) 
           VALUES (?, ?, ?, ?, 'pending')''',
        (builder_id, client_id, hours, amount)
    )
    
    # Send notification message
    conn.execute(
        "INSERT INTO messages (sender_id, receiver_id, message) VALUES (?, ?, ?)",
        (client_id, builder_id,
         f"New session booking request: {hours} hour(s) at ${amount:.2f}")
    )
    
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'message': 'Session booked', 'amount': amount})

# === VERIFICATION ROUTE ===

@app.route('/verify/<user_id>', methods=['POST'])
def verify_profile(user_id):
    if 'image' not in request.files:
        return jsonify({'success': False, 'message': 'No image provided'}), 400
    
    file = request.files['image']
    image_bytes = file.read()
    
    # Use Gemini to analyze the selfie for verification
    try:
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=[
                types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
                "Is this a clear, well-lit selfie of a single person? Respond with just YES or NO."
            ],
            config=types.GenerateContentConfig(
                thinking_config=types.ThinkingConfig(thinking_level="low")
            )
        )
        
        result = response.text.strip().upper()
        
        conn = get_db()
        if "YES" in result:
            conn.execute(
                "UPDATE users SET verification_status = 'verified' WHERE id = ?",
                (user_id,)
            )
            conn.commit()
            conn.close()
            return jsonify({'success': True, 'message': 'Profile verified!'})
        else:
            conn.close()
            return jsonify({
                'success': False,
                'message': 'Verification failed. Please submit a clear selfie.'
            }), 400
            
    except Exception as e:
        return jsonify({'success': False, 'message': f'Verification error: {str(e)}'}), 500

# === AI-POWERED FEATURES ===

@app.route('/ai/match-suggestions/<user_id>', methods=['GET'])
def ai_match_suggestions(user_id):
    """Use Gemini to provide intelligent match suggestions"""
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    
    if not user:
        return jsonify({'success': False, 'message': 'User not found'}), 404
    
    user_info = f"""
    User Profile:
    - Location: {user['location']}
    - Travel Route: {user['travel_route']}
    - Activities: {user.get('activities', 'None specified')}
    - Van Type: {user['van_type']}
    
    Based on this profile, suggest 3 ideal match characteristics for this nomadic user.
    Consider travel compatibility, shared activities, and lifestyle alignment.
    """
    
    try:
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=user_info,
            config=types.GenerateContentConfig(
                thinking_config=types.ThinkingConfig(thinking_level="medium")
            )
        )
        
        conn.close()
        return jsonify({'success': True, 'suggestions': response.text})
    except Exception as e:
        conn.close()
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/ai/van-help', methods=['POST'])
def van_build_assistant():
    """AI assistant for van build questions using Gemini with search"""
    data = request.json
    question = data.get('question')
    
    try:
        # Use Gemini with Google Search for up-to-date van build information
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=f"Answer this van build question with practical advice: {question}",
            config=types.GenerateContentConfig(
                tools=[{"google_search": {}}],
                thinking_config=types.ThinkingConfig(thinking_level="high")
            )
        )
        
        return jsonify({'success': True, 'answer': response.text})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/ai/activity-recommendations/<user_id>', methods=['GET'])
def activity_recommendations(user_id):
    """Recommend activities based on location and profile"""
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    conn.close()
    
    if not user:
        return jsonify({'success': False, 'message': 'User not found'}), 404
    
    prompt = f"""
    A van lifer is currently in {user['location']}.
    They are interested in outdoor activities and adventure.
    Suggest 5 specific activities or locations they should check out nearby.
    Focus on: hiking, climbing, surfing, photography spots, and van-friendly camping.
    """
    
    try:
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                tools=[{"google_search": {}}],
                thinking_config=types.ThinkingConfig(thinking_level="medium")
            )
        )
        
        return jsonify({'success': True, 'recommendations': response.text})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# === HEALTH CHECK ===

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'app': 'VanBond',
        'version': '1.0.0',
        'message': 'For God so loved the world... - John 3:16'
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)