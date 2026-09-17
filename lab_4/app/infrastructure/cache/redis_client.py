# app/core/redis.py
from redis.asyncio import Redis, ConnectionPool
from app.core.settings import settings

redis_pool: ConnectionPool | None = None

async def init_redis() -> None:
    global redis_pool
    redis_pool = ConnectionPool.from_url(
        settings.redis_url,
        max_connections=20,
        decode_responses=False,
    )

async def close_redis() -> None:
    
    global redis_pool
    if redis_pool:
        await redis_pool.aclose()
        redis_pool = None

async def get_redis() -> Redis:

    if redis_pool is None:
        raise RuntimeError("Redis pool is not initialized. Call init_redis() first.")
    
    return Redis(connection_pool=redis_pool)