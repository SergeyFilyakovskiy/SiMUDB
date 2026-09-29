from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from beanie import init_beanie
from pymongo import AsyncMongoClient

from fastapi import FastAPI

from app.core.settings import settings
from .documents import Product

@asynccontextmanager
async def mongo_lifespan(app: FastAPI)-> AsyncGenerator[None]:

    client = AsyncMongoClient(
        settings.mongo_url,
        tz_aware=True,
        serverSelectionTimeoutMS = 5_000,
    )

    try: 
        await client.admin.command("ping")

        await init_beanie(
            database=client[settings.mongo_db],
            document_models=[Product],
        )

        app.state.mongo_client = client
        yield
    finally:
        await client.close()
