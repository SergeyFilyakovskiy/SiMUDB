from datetime import datetime, timezone
from typing import Annotated

from beanie import PydanticObjectId
from fastapi import APIRouter, HTTPException, Query, status

from app.api.v1.schemas.products import (
    ProductCreate,
    ProductListOut,
    ProductOut,
    ProductUpdate,
)
from app.infrastructure.mongo.documents import Product

router = APIRouter(prefix="/products", tags=["products"])


@router.post(
    "/",
    response_model=ProductOut,
    status_code=status.HTTP_201_CREATED,
    summary="Создать продукт",
)
async def create_product(payload: ProductCreate) -> ProductOut:
    """Создаёт новый продукт в базе данных."""
    product = Product(
        **payload.model_dump(),
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    await product.insert()
    
    return ProductOut(
        id=str(product.id),
        name=product.name,
        price=product.price,
        quantity=product.quantity,
        tags=product.tags,
        created_at=product.created_at,
        updated_at=product.updated_at,
    )


@router.get(
    "/",
    response_model=ProductListOut,
    summary="Получить список продуктов",
)
async def list_products(
    skip: Annotated[int, Query(ge=0, description="Количество пропускаемых записей")] = 0,
    limit: Annotated[int, Query(ge=1, le=100, description="Максимальное количество записей")] = 20,
    tag: Annotated[str | None, Query(description="Фильтр по тегу")] = None,
) -> ProductListOut:
    """Возвращает список продуктов с пагинацией и опциональной фильтрацией."""
    query = {}
    if tag:
        query["tags"] = tag
    
    cursor = Product.find(query).sort("-created_at").skip(skip).limit(limit)
    products = await cursor.to_list()
    total = await Product.find(query).count()
    
    items = [
        ProductOut(
            id=str(p.id),
            name=p.name,
            price=p.price,
            quantity=p.quantity,
            tags=p.tags,
            created_at=p.created_at,
            updated_at=p.updated_at,
        )
        for p in products
    ]
    
    return ProductListOut(items=items, total=total, skip=skip, limit=limit)


@router.get(
    "/{product_id}",
    response_model=ProductOut,
    summary="Получить продукт по ID",
)
async def get_product(
    product_id: Annotated[PydanticObjectId, Query(description="ID продукта в MongoDB")]
) -> ProductOut:
    """Возвращает продукт по его ID."""
    product = await Product.get(product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with id {product_id} not found",
        )
    
    return ProductOut(
        id=str(product.id),
        name=product.name,
        price=product.price,
        quantity=product.quantity,
        tags=product.tags,
        created_at=product.created_at,
        updated_at=product.updated_at,
    )


@router.patch(
    "/{product_id}",
    response_model=ProductOut,
    summary="Обновить продукт",
)
async def update_product(
    product_id: Annotated[PydanticObjectId, Query(description="ID продукта в MongoDB")],
    payload: ProductUpdate,
) -> ProductOut:
    """Обновляет существующий продукт (только переданные поля)."""
    product = await Product.get(product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with id {product_id} not found",
        )
    
    update_data = payload.model_dump(exclude_unset=True, exclude_none=True)
    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update",
        )
    
    update_data["updated_at"] = datetime.now(timezone.utc)
    await product.set(update_data)
    await product.save()
    
    updated_product = await Product.get(product_id)

    if updated_product is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    
    return ProductOut(
        id=str(updated_product.id),
        name=updated_product.name,
        price=updated_product.price,
        quantity=updated_product.quantity,
        tags=updated_product.tags,
        created_at=updated_product.created_at,
        updated_at=updated_product.updated_at,
    )


@router.delete(
    "/{product_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Удалить продукт",
)
async def delete_product(
    product_id: Annotated[PydanticObjectId, Query(description="ID продукта в MongoDB")]
) -> None:
    """Удаляет продукт по его ID."""
    product = await Product.get(product_id)
    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with id {product_id} not found",
        )
    
    await product.delete()
    return None