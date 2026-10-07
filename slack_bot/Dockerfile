FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY shopdeck_bot ./shopdeck_bot
ENTRYPOINT ["python", "-m", "shopdeck_bot.app"]
