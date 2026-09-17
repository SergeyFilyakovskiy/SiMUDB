from __future__ import annotations

from redis.asyncio import Redis

from uuid import UUID

from typing import Dict

class RedisReserveProduct:

    def __init__(self, redis: Redis) -> None:
        self.redis = redis

    @staticmethod
    def _cart_key(user_id: UUID) -> str:
        return f"cart:{user_id}"

    async def reserve_product(
            self, 
            user_id: UUID,
            product_id: UUID,
            ttl: int,
            quantity: int,
        ) -> bool:
        
        key = self._cart_key(user_id)

        await self.redis.hincrby(key, str(product_id), quantity)
        await self.redis.expire(key, ttl)

        return True
    
    async def remove_product_from_reserve(
            self,
            user_id: UUID,
            product_id: UUID,
            quantity: int,
    )-> int:

        key = self._cart_key(user_id)

        new_quantity = await self.redis.hincrby(key, str(product_id), -quantity)

        if new_quantity<= 0:
            await self.redis.hdel(key, str(product_id))
            return 0

        return new_quantity

    async def get_user_reservations(
            self,
            user_id: UUID,
    )-> Dict[str, int]:

        key = self._cart_key(user_id)
        raw_data = await self.redis.hgetall(key)

        return {
            k.decode('utf-8') : int(v) # pyright: ignore[reportAttributeAccessIssue]
            for k, v in raw_data.items()
        }
        
    async def clear_user_reservations(self, user_id: UUID) -> None:

        await self.redis.delete(self._cart_key(user_id))
        