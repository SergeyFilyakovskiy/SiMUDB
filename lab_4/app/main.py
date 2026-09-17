from contextlib import asynccontextmanager, AsyncExitStack

from fastapi import FastAPI

from app.infrastructure.cache.redis_client import redis_lifespan
from app.infrastructure.mongo.mongo_client import mongo_lifespan

from app.api.v1.routers import v1_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    async with AsyncExitStack() as stack:
        await stack.enter_async_context(redis_lifespan(app))
        await stack.enter_async_context(mongo_lifespan(app))
        yield


app = FastAPI(
    version="0.1.0",
    title="Warehouse service",
    lifespan= lifespan,
)

app.include_router(v1_router)

@app.get("/")
async def health():
    return {"status": "healthy"}
