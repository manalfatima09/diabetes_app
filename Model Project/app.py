from flask import Flask
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials
import os


# Import Blueprints
from api.prediction_routes import prediction_bp
from api.doctor_routes import doctor_bp
from api.medication_routes import medication_bp
from api.glucose_routes import glucose_bp
from api.lifestyle_routes import lifestyle_bp
from api.feedback_routes import feedback_bp
from models.database import close_db

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

# Initialize Firebase
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

# Register Blueprints
app.register_blueprint(prediction_bp)
app.register_blueprint(doctor_bp)
app.register_blueprint(medication_bp)
app.register_blueprint(glucose_bp)
app.register_blueprint(lifestyle_bp)
app.register_blueprint(feedback_bp)

# Close database connection
app.teardown_appcontext(close_db)

@app.route("/")
def home():
    return "✅ DiabetesCare+ Flask API is running successfully!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
