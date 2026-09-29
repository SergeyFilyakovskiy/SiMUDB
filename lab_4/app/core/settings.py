from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic.types import SecretStr
from pydantic import Field
from pathlib import Path

ENV_FILE = Path(__file__).parent.parent / ".env"

class Config(BaseSettings):

    model_config = SettingsConfigDict(
        env_file= ENV_FILE if ENV_FILE.exists() else None,
        case_sensitive=True,
        extra='ignore'
    )

    postgres_user: str = Field(validation_alias='POSTGRES_USER')
    postgres_password: SecretStr = Field(validation_alias='POSTGRES_PASSWORD')
    postgres_host: str = Field(validation_alias='POSTGRES_HOST')
    postgres_port: int = Field(validation_alias='POSTGRES_PORT')
    postgres_db_name: str = Field(validation_alias='POSTGRES_DB')

    redis_password: SecretStr = Field(validation_alias='REDIS_PASSWORD')
    redis_host: str = Field(validation_alias='REDIS_HOST')
    redis_port: int = Field(validation_alias='REDIS_PORT')
    redis_db: str = Field(validation_alias='REDIS_DB')

    mongo_password: SecretStr = Field(validation_alias='MONGO_PASSWORD')
    mongo_host: str = Field(validation_alias='MONGO_HOST')
    mongo_port: int = Field(validation_alias='MONGO_PORT')
    mongo_user: str = Field(validation_alias='MONGO_USER')
    mongo_db: str = Field(validation_alias='MONGO_DB')

    @property
    def redis_url(self)-> str:
        return(
            f"redis://:{self.redis_password.get_secret_value()}"
            f"@{self.redis_host}:{self.redis_port}/{self.redis_db}"
        )

    @property
    def mongo_url(self)-> str:
        return(
            f"mongodb://{self.mongo_user}:{self.mongo_password.get_secret_value()}"
            f"@{self.mongo_host}:{self.mongo_port}/{self.mongo_db}?authSource=admin"
        )

    @property
    def db_async_url(self) -> str:
        return (
            f"postgresql+asyncpg://{self.postgres_user}:"
            f"{self.postgres_password.get_secret_value()}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db_name}"
        )

    @property
    def db_migrations_url(self) -> str:
        return (
            f"postgresql+psycopg2://{self.postgres_user}:"
            f"{self.postgres_password.get_secret_value()}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db_name}"
        )
    
settings = Config() #type: ignore