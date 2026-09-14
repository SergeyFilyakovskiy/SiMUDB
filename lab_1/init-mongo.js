
db = db.getSiblingDB('task_db');

print("========================================");
print("=== 1. Создание коллекции и вставка ===");
print("========================================");

// Создаем коллекцию 'items', добавляем категории и массивы тегов
db.items.insertMany([
    { 
        title: "Смартфон X", 
        category: "electronics", 
        tags: ["sale", "new", "promo", "mobile"] 
    },
    { 
        title: "Ноутбук Y", 
        category: "electronics", 
        tags: ["new", "laptop", "work"] 
    },
    { 
        title: "Война и мир", 
        category: "books", 
        tags: ["classic", "fiction", "russian"] 
    },
    { 
        title: "Чистый код", 
        category: "books", 
        tags: ["programming", "bestseller"] 
    }
]);
print("Добавлено 4 документа.");

print("\n========================================");
print("=== 2. Создание индексов ===");
print("========================================");

// Создаем индекс по category
db.items.createIndex({ category: 1 });
print("Создан индекс по полю 'category'.");

// Создаем индекс по tags (так как это массив, MongoDB автоматически создаст Multikey Index)
db.items.createIndex({ tags: 1 });
print("Создан индекс по полю 'tags' (Multikey Index).");

print("\n========================================");
print("=== 3. Поиск по категории и тегу ===");
print("========================================");

const query = { category: "electronics", tags: "sale" };
const results = db.items.find(query).toArray();
print("Запрос: db.items.find({ category: 'electronics', tags: 'sale' })");
print("Найдено документов: " + results.length);
printjson(results);

print("\n========================================");
print("=== 4. Оценка структуры хранения ===");
print("========================================");

// А. Смотрим, какие индексы реально создал MongoDB
print("\n--- Список индексов ---");
printjson(db.items.getIndexes());

// Б. Смотрим план выполнения запроса (executionStats)
print("\n--- План выполнения (Explain) ---");
const explain = db.items.find(query).explain("executionStats");
print("Тип сканирования (stage): " + explain.queryPlanner.winningPlan.stage);
print("Время выполнения (executionTimeMillis): " + explain.executionStats.executionTimeMillis + " мс");
print("Просканировано индексов (totalKeysExamined): " + explain.executionStats.totalKeysExamined);
print("Возвращено документов (nReturned): " + explain.executionStats.nReturned);

// В. Смотрим общую статистику коллекции (размер документов, индексов и т.д.)
print("\n--- Статистика коллекции (Storage Stats) ---");
const stats = db.items.stats();
print("Количество документов: " + stats.count);
print("Размер данных на диске (storageSize): " + stats.storageSize + " байт");
print("Размер индексов (totalIndexSize): " + stats.totalIndexSize + " байт");
print("Средний размер документа (avgObjSize): " + stats.avgObjSize + " байт");

print("\n=== Инициализация завершена успешно! ===");