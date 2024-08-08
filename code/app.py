import os
import boto3
import pickle
import uuid
import warnings
import time
import logging

import uvicorn

from fastapi import FastAPI, HTTPException, Request
from mangum import Mangum
from typing import List
from dotenv import load_dotenv

warnings.filterwarnings('ignore')


# Variáveis de ambiente
load_dotenv()
table_name = os.getenv('DYNAMODB_TABLE')
s3_bucket = os.getenv('S3_BUCKET')
log_group_name = os.getenv('CLOUDWATCH_LOG_GROUP')
log_stream_name = os.getenv('CLOUDWATCH_LOG_STREAM')
environment=os.getenv('ENVIRONMENT')


# Configurando o logger para capturar informações sobre as requests
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()


# Recursos AWS
s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(table_name)
logs_client = boto3.client('logs')


# -------------------- Funções Úteis -------------------- #


def send_log_to_cloudwatch(message):
    response = logs_client.describe_log_streams(logGroupName=log_group_name, logStreamNamePrefix=log_stream_name)
    log_stream = response['logStreams'][0]
    sequence_token = log_stream.get('uploadSequenceToken')

    log_event = {
        'logGroupName': log_group_name,
        'logStreamName': log_stream_name,
        'logEvents': [
            {
                'timestamp': int(round(time.time() * 1000)),
                'message': environment + ":: " + message
            }
        ]
    }

    if sequence_token:
        log_event['sequenceToken'] = sequence_token

    logs_client.put_log_events(**log_event)

# ------------------ Middlware ------------------ #

@app.middleware("http")
async def log_request(request: Request, call_next):
    logger.info(f"\tUser: {request.headers.get('x-user-email')}")
    logger.info(f'\tMethod: {request.method}')
    logger.info(f'\tPath: {request.url.path}')
    logger.info(f'\tQuery Parameters: {request.query_params}')
    logger.info(f'\tBody: {await request.body()}')
    logger.info(f'\tHeaders: {request.headers}')
    logger.info(f'\tIP: {request.client.host}')
    logger.info(f'\tOrigem: {request.headers.get("origin")}')

    # Create a custom request object with the body intact
    custom_request = Request(request.scope, request.receive)
    # Pass the custom request with the body intact to the route handler
    response = await call_next(custom_request)
    return response

# -------------------- Rotas -------------------- #

@app.get("/")
def index():
    return "Hello, from AWS Lambda!"

@app.get("/hello")
def hello_world():
    return {"message": "Hello, World!"}


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

    # # Puxar modelo do s3
    # s3 = boto3.client('s3')
    # s3.download_file(s3_bucket, 'model.pkl', '/tmp/model.pkl')

    # Obtém o diretório de trabalho atual
    current_directory = os.getcwd()

    # Imprime o diretório de trabalho atual
    print("Diretório de trabalho atual:", current_directory)

    # Define o caminho do arquivo model.pkl relativo ao diretório de trabalho atual
    model_path = os.path.join(current_directory, 'tmp', 'model.pkl')

    # Carregar modelo
    with open(model_path, 'rb') as file:
        model = pickle.load(file)
    send_log_to_cloudwatch("Modelo carregado.")

    # Calcular a probabilidade de sobrevivência
    try:
        probabilidade_sobrevivencia = model.predict_proba([caracteristicas])[0][1] * 100
        probabilidade_sobrevivencia = round(probabilidade_sobrevivencia, 2)
    except Exception as e:
        send_log_to_cloudwatch(f"Erro ao calcular a probabilidade de sobrevivência: {str(e)}")
        raise HTTPException(status_code=500, detail="Erro ao calcular a probabilidade de sobrevivência.")

    # Salvar no DynamoDB
    table.put_item(
        Item={
            'id': id_passageiro,
            'probabilidade_sobrevivencia': int(probabilidade_sobrevivencia * 100) # necessário multiplicar por 100 para salvar como inteiro
        }
    )
    send_log_to_cloudwatch(f"Dados salvos no DynamoDB para o ID: {id_passageiro}")

    return {
        "id": id_passageiro,
        "probabilidade_sobrevivencia": probabilidade_sobrevivencia
    }

@app.get("/sobreviventes")
def get_sobreviventes():
    '''Rota GET que retorna todos os sobreviventes salvos no banco de dados.'''
    response = table.scan()
    sobreviventes = response['Items']
    for sobrevivente in sobreviventes:
        sobrevivente['probabilidade_sobrevivencia'] = sobrevivente['probabilidade_sobrevivencia'] / 100 # necessário dividir por 100 para retornar como float
    return sobreviventes

@app.get("/sobreviventes/{id_passageiro}")
def get_sobrevivente(id_passageiro: str):
    '''Rota GET que espera receber um ID de passageiro e retorna a probabilidade de sobrevivência do mesmo.'''
    
    response = table.get_item(Key={'id': id_passageiro})
    if 'Item' not in response:
        raise HTTPException(status_code=404, detail="ID de passageiro não encontrado.")
    
    probabilidade_sobrevivencia = response['Item']['probabilidade_sobrevivencia'] / 100 # necessário dividir por 100 para retornar como float
    return {
        "id": id_passageiro,
        "probabilidade_sobrevivencia": probabilidade_sobrevivencia
    }

@app.delete("/sobreviventes/{id_passageiro}")
def delete_sobrevivente(id_passageiro: str):
    '''Rota DELETE que espera receber um ID de passageiro e deleta o registro do banco de dados.'''
    
    # Verifica se o passageiro existe no banco de dados
    response = table.get_item(Key={'id': id_passageiro})
    if 'Item' not in response:
        raise HTTPException(status_code=404, detail="ID de passageiro não encontrado.")

    # Deleta o registro
    response = table.delete_item(Key={'id': id_passageiro})
    
    return {
        "message": "Registro deletado com sucesso."
    }

# -------------------- Configuração do Mangum -------------------- #

handler = Mangum(app, lifespan="off")

# -------------------- Execução do Servidor (Dev) -------------------- #

if __name__ == "__main__":
    uvicorn_app = f"{os.path.basename(__file__).rstrip('.py')}:app"
    uvicorn.run(uvicorn_app, host="0.0.0.0", port=8000, reload=True)