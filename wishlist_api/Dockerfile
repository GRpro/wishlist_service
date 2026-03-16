FROM python:3.10-slim

WORKDIR /app

COPY wishlist_api/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY shared_dal/ /app/shared_dal

COPY wishlist_api/ /app/wishlist_api

CMD ["uvicorn", "wishlist_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
