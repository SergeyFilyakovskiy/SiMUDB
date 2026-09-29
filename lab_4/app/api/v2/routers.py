
from fastapi import APIRouter
from app.api.v2.endpoints import products

v2_router = APIRouter(prefix="/api/v2")
v2_router.include_router(products.router)