FROM python:3.10-slim

WORKDIR /app

COPY reco_api/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY shared_dal/ /app/shared_dal

COPY reco_api/ /app/reco_api

CMD ["uvicorn", "reco_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
