FROM public.ecr.aws/lambda/python:3.8
ENV PYTHONUNBUFFERED=1

COPY requirements.txt ./
RUN pip3 install -r requirements.txt

COPY app.py ./

# Cria a pasta tmp e copia o arquivo model.pkl para lá
RUN mkdir -p /var/task/tmp
COPY tmp/model.pkl /var/task/tmp/

CMD [ "app.handler" ]