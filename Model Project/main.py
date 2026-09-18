# main.py
import os
import joblib
import numpy as np
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
from fastapi.middleware.cors import CORSMiddleware





# -------------------
# Pydantic model: matches keys produced by your Flutter PatientInput.toJson()
# -------------------
class PatientInput(BaseModel):
    Age: Optional[int] = None
    Sex: Optional[int] = None
    BMI: Optional[float] = None
    overweight: Optional[int] = None
    Age_bin_num: Optional[int] = None
    bmi_age_interaction: Optional[float] = None
    Education: Optional[int] = None
    Income: Optional[int] = None
    Age_group: Optional[str] = None
    HighBP: Optional[int] = None
    HighChol: Optional[int] = None
    CholCheck: Optional[int] = None
    Stroke: Optional[int] = None
    HeartDiseaseorAttack: Optional[int] = None
    AnyHealthcare: Optional[int] = None
    NoDocbcCost: Optional[int] = None
    Smoker: Optional[int] = None
    PhysActivity: Optional[int] = None
    Fruits: Optional[int] = None
    Veggies: Optional[int] = None
    HvyAlcoholConsump: Optional[int] = None
    DiffWalk: Optional[int] = None
    GenHlth: Optional[int] = None
    MentHlth: Optional[int] = None
    PhysHlth: Optional[int] = None

app = FastAPI(title="Diabetes Prediction API")

# Allow CORS from all origins for dev. In production lock this down.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


MODEL_PATH = "diabetes_model.pkl"


def build_dummy_model_and_save(path: str):
    """If you don't have a saved model, this creates a tiny working classifier for testing."""
    from sklearn.linear_model import LogisticRegression
    # create extremely small synthetic dataset (ONLY for testing)
    rng = np.random.RandomState(0)
    X = rng.normal(size=(200, 10))
    y = (rng.rand(200) > 0.7).astype(int)
    clf = LogisticRegression(max_iter=500)
    clf.fit(X, y)
    joblib.dump(clf, path)
    return clf


def load_model():
    if os.path.exists(MODEL_PATH):
        try:
            model = joblib.load(MODEL_PATH)
            print("Loaded model from", MODEL_PATH)
            return model
        except Exception as e:
            print("Failed to load model:", e)
    # fallback: create dummy model for testing
    print("No model found or failed to load — creating a small dummy model for dev/testing.")
    return build_dummy_model_and_save(MODEL_PATH)


model = load_model()


def prepare_features(payload: dict):
    """Turn input dict into a numeric vector expected by the model.
       Adjust ordering to match how your ML model was trained.
       Here we pick a reasonable subset — adapt to your real model.
    """
    # choose features in a fixed order (adjust to your ML model)
    fields = [
        "Age", "Sex", "BMI", "overweight", "Age_bin_num", "bmi_age_interaction",
        "Education", "Income", "HighBP", "HighChol", "CholCheck",
        "Stroke", "HeartDiseaseorAttack", "AnyHealthcare", "NoDocbcCost",
        "Smoker", "PhysActivity", "Fruits", "Veggies", "HvyAlcoholConsump",
        "DiffWalk", "GenHlth", "MentHlth", "PhysHlth"
    ]
    vec = []
    for f in fields:
        v = payload.get(f)
        # convert to numeric (None -> 0)
        if v is None:
            vec.append(0.0)
        else:
            try:
                vec.append(float(v))
            except:
                vec.append(0.0)
    return np.array(vec).reshape(1, -1)


@app.get("/")
def root():
    return {"message": "Diabetes Prediction API running"}


@app.post("/predict")
def predict(patient: PatientInput):
    payload = patient.dict()
    try:
        X = prepare_features(payload)
        # Predict
        if hasattr(model, "predict_proba"):
            probs = model.predict_proba(X)[0]
            # choose probability of class 1
            prob1 = float(probs[1]) if len(probs) > 1 else 0.0
        else:
            prob1 = 0.0

        pred = int(model.predict(X)[0])
        result = {
            "prediction": pred,
            "probability": prob1,
            "class": "High" if pred == 1 else "Low",
            "raw": payload
        }
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {e}")
