
from app.infrastructure.cache.reserve import RedisReserveProduct
from app.infrastructure.cache.redis_client import get_redis

async def get_reserve_product()-> RedisReserveProduct:
    redis = await get_redis()
    return RedisReserveProduct(redis=redis)
    