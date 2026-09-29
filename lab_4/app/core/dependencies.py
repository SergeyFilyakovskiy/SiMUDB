# app/core/dependencies.py
from uuid import UUID

from fastapi import Depends, Request

from lab_4.app.v1.infrastructure.cache.reserve import RedisReserveProduct
from lab_4.app.v1.infrastructure.mongo.product_quantity_service import ProductQuantityService
from lab_4.app.v1.infrastructure.services.reserve_service import ReserveService


def get_redis(request: Request):
    """Получить Redis клиент из app.state."""
    return request.app.state.redis


def get_reserve_repo(redis=Depends(get_redis)) -> RedisReserveProduct:
    """Получить репозиторий резервов."""
    return RedisReserveProduct(redis=redis)


def get_quantity_service() -> ProductQuantityService:
    """Получить сервис количества товаров."""
    return ProductQuantityService()


def get_reserve_service(
    reserve_repo: RedisReserveProduct = Depends(get_reserve_repo),
    quantity_service: ProductQuantityService = Depends(get_quantity_service),
) -> ReserveService:
    """Получить сервис резервирования."""
    return ReserveService(
        reserve_repo=reserve_repo,
        quantity_service=quantity_service,
    )