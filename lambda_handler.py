import pickle
import sklearn
# import uuid

def load_model():
    with open("model.pkl", "rb") as f:
        model = pickle.load(f)
    return model

def lambda_handler(event, context):
    # caractheristics = event["body"]["caractheristics"] #Age, Parch, SibSp, Fare, Pclass, Survived, Sex_male, Embarked_Q, Embarked_S
    return {
        # "passenger_id": str(uuid.uuid4()),
        # "survival_probability": model.predict_proba([caractheristics])[0][1],
        "statusCode": 200,
        "version": sklearn.__version__,
        "event": event
    }