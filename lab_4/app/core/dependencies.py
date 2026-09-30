from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession
from redis.asyncio import Redis
from motor.motor_asyncio import AsyncIOMotorDatabase

from fastapi import Depends, Request

from app.v2.postgres.session import async_session as get_pg_session_v2
from app.v1.infrastructure.cache.reserve import RedisReserveProduct
from app.v1.infrastructure.mongo.product_quantity_service import ProductQuantityService
from app.v1.infrastructure.services.reserve_service import ReserveService


from app.v2.postgres.repositories.inventory import InventoryRepository
from app.v2.mongo.repositories.events import MongoEventRepository
from app.v2.redis.repositories.reservations import RedisReservationRepository
from app.v2.services.saga import OrderConfirmationSaga


def get_redis(request: Request):
    """Получить Redis клиент из app.state."""
    return request.app.state.redis


def get_reserve_repo(redis=Depends(get_redis)) -> RedisReserveProduct:
    """Получить репозиторий резервов (v1)."""
    return RedisReserveProduct(redis=redis)


def get_quantity_service() -> ProductQuantityService:
    """Получить сервис количества товаров (v1)."""
    return ProductQuantityService()


def get_reserve_service(
    reserve_repo: RedisReserveProduct = Depends(get_reserve_repo),
    quantity_service: ProductQuantityService = Depends(get_quantity_service),
) -> ReserveService:
    """Получить сервис резервирования (v1)."""
    return ReserveService(
        reserve_repo=reserve_repo,
        quantity_service=quantity_service,
    )


# --- Зависимости для v2 ---

async def get_pg_session() -> AsyncGenerator[AsyncSession, None]:
    """Сессия PostgreSQL для v2."""
    async with get_pg_session_v2() as session:
        try: 
            yield session
        except Exception as e:
            await session.rollback()
            raise e
        finally:
            await session.aclose()


def get_pg_inventory_repo(session: AsyncSession = Depends(get_pg_session)) -> InventoryRepository:
    """Репозиторий остатков для v2."""
    return InventoryRepository(session=session)


def get_v2_mongo_db(request: Request) -> AsyncIOMotorDatabase:
    """База MongoDB для v2."""
    return request.app.state.mongo.db


def get_mongo_event_repo(mongo_db: AsyncIOMotorDatabase = Depends(get_v2_mongo_db)) -> MongoEventRepository:
    """Репозиторий событий для v2."""
    return MongoEventRepository(db=mongo_db)


def get_v2_reservation_repo(redis: Redis = Depends(get_redis)) -> RedisReservationRepository:
    """Репозиторий резервов для v2."""
    return RedisReservationRepository(redis=redis)