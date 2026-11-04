FROM python:3.12-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir fastapi uvicorn pydantic

# Copy entire application (excluding items in .dockerignore)
COPY . /app

WORKDIR /app/backend

EXPOSE 8000

ENV TERRAFORM_DRY_RUN=true

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
