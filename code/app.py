import os
import uvicorn
import boto3

from fastapi import FastAPI, HTTPException
from mangum import Mangum
from typing import List
from dotenv import load_dotenv

# Variáveis de ambiente
table_name = os.getenv('DYNAMODB_TABLE')
load_dotenv()

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
    
    # Validação das características recebidas
    if len(caracteristicas) != 8:
        raise HTTPException(status_code=400, detail="Número de características inválido. Esperado 8 características.")
    
    # Puxar modelo do s3
    s3 = boto3.client('s3')
    s3.download_file('titanic-model', 'model.pkl', '/tmp/model.pkl') 
    
    return { 
        "caracteristicas": caracteristicas
    }

handler = Mangum(app, lifespan="off")

if __name__ == "__main__":
    uvicorn_app = f"{os.path.basename(__file__).removesuffix('.py')}:app"
    uvicorn.run(uvicorn_app, host="0.0.0.0", port=8000, reload=True)