# app/api/v2/endpoints/products.py
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, HTTPException, status, Depends, Path
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v2.schemas.products import (
    ProductCreate,
    ProductOut,
    StockUpdate,
    ReserveRequest,
    ConfirmOrderRequest,
    AvailabilityResponse,
    OperationResult,
)
from app.core.dependencies import (
    get_pg_session,
    get_pg_inventory_repo,
    get_v2_reservation_repo,
    get_mongo_event_repo,
)
from lab_4.app.v2.postgres.models import Product, Warehouse, WarehouseStock
from lab_4.app.v2.postgres.repositories.inventory import InventoryRepository
from lab_4.app.v2.redis.repositories.reservations import RedisReservationRepository
from lab_4.app.v2.mongo.repositories.events import MongoEventRepository
from lab_4.app.v2.services.saga import OrderConfirmationSaga

router = APIRouter(prefix="/products", tags=["v2 products"])


@router.post(
    "/",
    response_model=ProductOut,
    status_code=status.HTTP_201_CREATED,
    summary="Создать продукт (v2)",
)
async def create_product(
    payload: ProductCreate,
    session: AsyncSession = Depends(get_pg_session),
) -> ProductOut:
    """Создаёт новый продукт в PostgreSQL."""
    product = Product(
        name=payload.name,
        sku=payload.sku,
        category=payload.category,
    )
    session.add(product)
    await session.commit()
    await session.refresh(product)
    
    return ProductOut(
        id=product.id,
        name=product.name,
        sku=product.sku,
        category=product.category,
        created_at=product.created_at,
    )


@router.get(
    "/{product_id}",
    response_model=ProductOut,
    summary="Получить продукт по ID (v2)",
)
async def get_product(
    product_id: Annotated[UUID, Path(description="ID продукта в PostgreSQL")],
    session: AsyncSession = Depends(get_pg_session),
) -> ProductOut:
    """Возвращает продукт по его ID."""
    from sqlalchemy import select
    result = await session.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with id {product_id} not found",
        )
    
    return ProductOut(
        id=product.id,
        name=product.name,
        sku=product.sku,
        category=product.category,
        created_at=product.created_at,
    )


@router.post(
    "/{product_id}/warehouses/{warehouse_id}/stock",
    response_model=OperationResult,
    summary="Установить остаток товара на складе",
)
async def set_stock(
    product_id: Annotated[UUID, Path(description="ID продукта")],
    warehouse_id: Annotated[UUID, Path(description="ID склада")],
    payload: StockUpdate,
    session: AsyncSession = Depends(get_pg_session),
) -> OperationResult:
    """Устанавливает или обновляет остаток товара на конкретном складе."""
    from sqlalchemy import select
    
    # Проверяем существование товара и склада
    product = await session.execute(select(Product).where(Product.id == product_id))
    if not product.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Product not found")
    
    warehouse = await session.execute(select(Warehouse).where(Warehouse.id == warehouse_id))
    if not warehouse.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Warehouse not found")
    
    # Ищем существующую запись остатка
    result = await session.execute(
        select(WarehouseStock).where(
            WarehouseStock.product_id == product_id,
            WarehouseStock.warehouse_id == warehouse_id
        )
    )
    stock = result.scalar_one_or_none()
    
    if stock:
        stock.quantity = payload.quantity
    else:
        stock = WarehouseStock(
            product_id=product_id,
            warehouse_id=warehouse_id,
            quantity=payload.quantity,
        )
        session.add(stock)
    
    await session.commit()
    
    return OperationResult(success=True, message="Stock updated successfully")


@router.post(
    "/reserve",
    response_model=OperationResult,
    summary="Зарезервировать товар (добавить в корзину)",
)
async def reserve_product(
    payload: ReserveRequest,
    redis_repo: RedisReservationRepository = Depends(get_v2_reservation_repo),
    pg_repo: InventoryRepository = Depends(get_pg_inventory_repo),
) -> OperationResult:
    """Резервирует товар для пользователя (имитация добавления в корзину)."""
    # Проверяем, что товар существует
    product = await pg_repo.get_product(payload.product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    
    # Для простоты используем фиктивный user_id (в реальности из JWT)
    fake_user_id = UUID("00000000-0000-0000-0000-000000000001")
    
    await redis_repo.reserve_product(
        user_id=fake_user_id,
        product_id=payload.product_id,
        warehouse_id=payload.warehouse_id,
        quantity=payload.quantity,
    )
    
    return OperationResult(success=True, message="Product reserved successfully")


@router.post(
    "/confirm-order",
    response_model=OperationResult,
    summary="Подтвердить заказ (Saga)",
)
async def confirm_order(
    payload: ConfirmOrderRequest,
    session: AsyncSession = Depends(get_pg_session),
    redis_repo: RedisReservationRepository = Depends(get_v2_reservation_repo),
    mongo_repo: MongoEventRepository = Depends(get_mongo_event_repo),
) -> OperationResult:
    """
    Подтверждает заказ, используя паттерн Saga.
    Списывает товар со склада, записывает событие, снимает резерв.
    """
    saga = OrderConfirmationSaga(
        pg_session=session,
        mongo_db=mongo_repo.db,
        redis_client=redis_repo.redis,
    )
    
    try:
        await saga.execute(
            order_id=payload.order_id,
            user_id=payload.user_id,
            product_id=payload.product_id,
            warehouse_id=payload.warehouse_id,
            quantity=payload.quantity,
        )
        return OperationResult(success=True, message="Order confirmed successfully")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Order confirmation failed: {str(e)}")


@router.get(
    "/{product_id}/warehouses/{warehouse_id}/availability",
    response_model=AvailabilityResponse,
    summary="Проверить доступность товара",
)
async def check_availability(
    product_id: Annotated[UUID, Path(description="ID продукта")],
    warehouse_id: Annotated[UUID, Path(description="ID склада")],
    pg_repo: InventoryRepository = Depends(get_pg_inventory_repo),
    redis_repo: RedisReservationRepository = Depends(get_v2_reservation_repo),
) -> AvailabilityResponse:
    """Возвращает информацию о доступности товара (CQRS для чтения)."""
    stock = await pg_repo.get_stock(product_id, warehouse_id)
    if not stock:
        raise HTTPException(status_code=404, detail="Product not found in this warehouse")
    
    reserved = await redis_repo.get_reserved_quantity(product_id, warehouse_id)
    available = stock.quantity - reserved
    
    return AvailabilityResponse(
        product_id=product_id,
        warehouse_id=warehouse_id,
        total_physical=stock.quantity,
        currently_reserved=reserved,
        available_to_buy=available,
    )