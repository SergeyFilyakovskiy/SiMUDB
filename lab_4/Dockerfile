FROM python:3.14-slim-bookworm


RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*


COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app


COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev


COPY . .


COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV PYTHONPATH=/app
ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]