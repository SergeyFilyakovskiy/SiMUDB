
from contextlib import asynccontextmanager, AsyncExitStack

from fastapi import FastAPI

from lab_4.app.v1.infrastructure.cache.redis_client import redis_lifespan
from lab_4.app.v1.infrastructure.mongo.mongo_client import mongo_lifespan

from app.api.v1.routers import v1_router
from app.api.v2.routers import v2_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    async with AsyncExitStack() as stack:
        await stack.enter_async_context(redis_lifespan(app))
        await stack.enter_async_context(mongo_lifespan(app))
        yield


app = FastAPI(
    version="0.2.0",
    title="Warehouse service",
    lifespan=lifespan,
)

app.include_router(v1_router)
app.include_router(v2_router)

@app.get("/")
async def health():
    return {"status": "healthy"}
