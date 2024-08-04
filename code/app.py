import os
import uvicorn
import boto3
import pickle
import uuid

from fastapi import FastAPI, HTTPException
from mangum import Mangum
from typing import List
from dotenv import load_dotenv

# Variáveis de ambiente
load_dotenv()
table_name = os.getenv('DYNAMODB_TABLE')
s3_bucket = os.getenv('S3_BUCKET')

app = FastAPI()

# Recursos AWS
s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(table_name)

@app.get("/")
def index():
    return "Hello, from AWS Lambda!"

@app.post("/sobreviventes")
def create_sobrevivente(caracteristicas: List[float]):
    '''Rota POST que espera receber uma lista de características de um sobrevivente.
    Passa essas características para o escoramento de um modelo de Machine Learning treinado no dataset do Titanic.
    '''

    # Validação das características recebidas # Age, Parch, SibSp, Fare, Pclass, Sex_male, Embarked_Q, Embarked_S
    if len(caracteristicas) != 8:
        raise HTTPException(status_code=400, detail="Número de características inválido. Esperado 8 características.")
    
    if (caracteristicas[4] not in [1, 2, 3]) or (caracteristicas[5] not in [0, 1]) or (caracteristicas[6] not in [0, 1]) or (caracteristicas[7] not in [0, 1]):
        raise HTTPException(status_code=400, detail="Características inválidas.")
    
    # Criar identificador do passageiro
    id_passageiro = str(uuid.uuid4())

    # Puxar modelo do s3
    s3 = boto3.client('s3')
    s3.download_file('titanic-model', 'model.pkl', '/tmp/model.pkl')

    # Carregar modelo
    with open('/tmp/model.pkl', 'rb') as file:
        model = pickle.load(file)
    
    # Calcular a probabilidade de sobrevivência
    probabilidade_sobrevivencia = model.predict_proba([caracteristicas])[0][1]

    # Salvar no DynamoDB
    table.put_item(
        Item={
            'id': id_passageiro,
            'caracteristicas': caracteristicas,
            'probabilidade_sobrevivencia': probabilidade_sobrevivencia
        }
    )

    return {
        "id": id_passageiro, 
        "caracteristicas": caracteristicas,
        "probabilidade_sobrevivencia": probabilidade_sobrevivencia
    }

handler = Mangum(app, lifespan="off")

if __name__ == "__main__":
    uvicorn_app = f"{os.path.basename(__file__).removesuffix('.py')}:app"
    uvicorn.run(uvicorn_app, host="0.0.0.0", port=8000, reload=True)