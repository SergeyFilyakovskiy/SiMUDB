
from app.infrastructure.cache.reserve import RedisReserveProduct
from fastapi import Request, Depends
from redis.asyncio import Redis

def get_redis(request: Request):
    return request.app.state.redis

async def get_reserve_product(
        redis: Redis = Depends(get_redis),
)-> RedisReserveProduct:
    return RedisReserveProduct(redis=redis)
    