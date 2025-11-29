# 🏗️ PocketBizz Multi-Tenant Architecture
## Designed for 10,000+ Users

---

## 📊 SYSTEM OVERVIEW

```
┌─────────────────────────────────────────────────────────────┐
│                     FLUTTER CLIENTS                          │
├──────────────┬──────────────┬──────────────┬────────────────┤
│   iOS App    │  Android App │   Web App    │   PWA          │
└──────────────┴──────────────┴──────────────┴────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  SUPABASE (Backend as a Service)             │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Auth      │  │   Database   │  │   Storage    │       │
│  │   (JWT)     │  │ (PostgreSQL) │  │   (Files)    │       │
│  └─────────────┘  └──────────────┘  └──────────────┘       │
│                                                               │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Realtime   │  │   Edge Fns   │  │   Row Level  │       │
│  │  (WebSocket)│  │  (Serverless)│  │   Security   │       │
│  └─────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   EXTERNAL INTEGRATIONS                      │
├──────────────┬──────────────┬──────────────┬────────────────┤
│  ToyyibPay   │   WhatsApp   │   Thermal    │   Analytics    │
│  (Payment)   │   Business   │   Printer    │   (Firebase)   │
└──────────────┴──────────────┴──────────────┴────────────────┘
```

---

## 🔐 MULTI-TENANT DATA ISOLATION

### Tenant Model:
```
1 User = 1 Business Owner
1 Business Owner = 1 Tenant
1 Tenant = Isolated Data Set
```

### Database Schema Pattern:
```sql
-- Every table follows this pattern
CREATE TABLE <table_name> (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users(id),
    -- other columns...
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for performance
CREATE INDEX idx_<table>_owner ON <table>(business_owner_id);

-- Row Level Security for data isolation
ALTER TABLE <table> ENABLE ROW LEVEL SECURITY;

CREATE POLICY "<table>_select_own" ON <table>
    FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY "<table>_insert_own" ON <table>
    FOR INSERT WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY "<table>_update_own" ON <table>
    FOR UPDATE USING (business_owner_id = auth.uid());

CREATE POLICY "<table>_delete_own" ON <table>
    FOR DELETE USING (business_owner_id = auth.uid());
```

---

## 📊 DATABASE DESIGN

### Core Tables:

#### **1. Users & Authentication**
```sql
users (
    id UUID PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    phone TEXT,
    subscription_plan TEXT DEFAULT 'free',
    subscription_expires_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
```

#### **2. Business Profiles**
```sql
business_profiles (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    business_name TEXT NOT NULL,
    business_type TEXT,
    registration_number TEXT,
    tax_number TEXT,
    address JSONB,
    logo_url TEXT,
    settings JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
```

#### **3. Products**
```sql
products (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    sku TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    unit TEXT NOT NULL,
    cost_price NUMERIC(12,2) NOT NULL,
    sale_price NUMERIC(12,2) NOT NULL,
    current_stock NUMERIC(12,3) DEFAULT 0,
    min_stock NUMERIC(12,3) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    barcode TEXT,
    images JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
```

#### **4. Sales**
```sql
sales (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    sale_number TEXT UNIQUE NOT NULL,
    customer_id UUID REFERENCES customers(id),
    channel TEXT NOT NULL, -- walk-in, online, delivery
    total_amount NUMERIC(12,2) NOT NULL,
    discount_amount NUMERIC(12,2),
    tax_amount NUMERIC(12,2),
    final_amount NUMERIC(12,2) NOT NULL,
    payment_method TEXT,
    payment_status TEXT DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)

sale_items (
    id UUID PRIMARY KEY,
    sale_id UUID REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    product_name TEXT NOT NULL,
    quantity NUMERIC(12,3) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL,
    created_at TIMESTAMPTZ
)
```

#### **5. Stock Movements**
```sql
stock_movements (
    id UUID PRIMARY KEY,
    business_owner_id UUID REFERENCES users(id),
    product_id UUID REFERENCES products(id),
    reference_type TEXT, -- sale, purchase, adjustment, production
    reference_id UUID,
    movement_type TEXT NOT NULL, -- in, out
    quantity NUMERIC(12,3) NOT NULL,
    unit_cost NUMERIC(12,2),
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ
)
```

---

## ⚡ PERFORMANCE OPTIMIZATION

### Indexing Strategy:

```sql
-- Composite indexes for common queries
CREATE INDEX idx_sales_owner_date ON sales(business_owner_id, created_at DESC);
CREATE INDEX idx_products_owner_active ON products(business_owner_id, is_active) WHERE is_active = true;
CREATE INDEX idx_stock_movements_product ON stock_movements(product_id, created_at DESC);
CREATE INDEX idx_sale_items_product ON sale_items(product_id);

-- Partial indexes for status queries
CREATE INDEX idx_sales_pending ON sales(business_owner_id) WHERE payment_status = 'pending';

-- GIN indexes for JSONB columns
CREATE INDEX idx_business_settings ON business_profiles USING GIN(settings);
```

### Query Optimization:

```sql
-- Use EXPLAIN ANALYZE to check query performance
EXPLAIN ANALYZE
SELECT * FROM sales
WHERE business_owner_id = 'xxx'
AND created_at >= CURRENT_DATE - INTERVAL '30 days';

-- Ensure query uses index
-- Should see "Index Scan" not "Seq Scan"
```

---

## 🔥 SCALABILITY CONSIDERATIONS

### Database Connection Pooling:
```
Supabase handles this automatically:
- Free tier: 60 connections
- Pro tier: 200 connections
- Team tier: 400 connections

For 10k users with good RLS:
- Average concurrent users: ~100-200
- Pro tier should be sufficient
```

### Caching Strategy:
```dart
// Flutter-side caching
class CacheService {
  final _cache = <String, CachedData>{};
  
  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher,
    Duration ttl,
  ) async {
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.data as T;
    }
    
    final data = await fetcher();
    _cache[key] = CachedData(data, DateTime.now().add(ttl));
    return data;
  }
}
```

### Edge Functions for Heavy Operations:
```typescript
// Supabase Edge Function for complex calculations
import { serve } from "https://deno.land/std/http/server.ts"

serve(async (req) => {
  const { businessOwnerId, startDate, endDate } = await req.json()
  
  // Complex aggregation that's heavy on client
  const analytics = await calculateBusinessAnalytics(
    businessOwnerId,
    startDate,
    endDate
  )
  
  return new Response(JSON.stringify(analytics), {
    headers: { "Content-Type": "application/json" },
  })
})
```

---

## 🛡️ SECURITY MEASURES

### 1. Row Level Security (RLS):
✅ Already implemented
- Every query automatically filtered by business_owner_id
- No way for User A to see User B's data

### 2. API Rate Limiting:
```typescript
// Supabase Edge Function with rate limiting
import { RateLimiter } from "./rate-limiter.ts"

const limiter = new RateLimiter({
  windowMs: 60000, // 1 minute
  max: 100, // 100 requests per minute per user
})

serve(async (req) => {
  const userId = await getUserId(req)
  
  if (!limiter.check(userId)) {
    return new Response("Too many requests", { status: 429 })
  }
  
  // Process request...
})
```

### 3. Input Validation:
```dart
// Flutter-side validation
class ValidationService {
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      return 'Invalid email format';
    }
    return null;
  }
  
  static String? validatePrice(String? price) {
    if (price == null || price.isEmpty) {
      return 'Price is required';
    }
    final priceValue = double.tryParse(price);
    if (priceValue == null || priceValue < 0) {
      return 'Invalid price';
    }
    return null;
  }
}
```

---

## 📱 FLUTTER ARCHITECTURE

### Clean Architecture + Riverpod:

```
lib/
├── core/
│   ├── theme/
│   ├── utils/
│   ├── constants/
│   └── supabase/
├── data/
│   ├── models/
│   ├── repositories/
│   └── services/
├── domain/
│   ├── entities/
│   └── use_cases/
├── presentation/
│   ├── screens/
│   ├── widgets/
│   └── providers/
└── main.dart
```

### Repository Pattern:
```dart
abstract class ProductRepository {
  Future<List<Product>> getProducts();
  Future<Product> getProduct(String id);
  Future<Product> createProduct(Product product);
  Future<void> updateProduct(String id, Product product);
  Future<void> deleteProduct(String id);
}

class ProductRepositoryImpl implements ProductRepository {
  final SupabaseClient _supabase;
  
  @override
  Future<List<Product>> getProducts() async {
    final data = await _supabase
        .from('products')
        .select()
        .order('name');
    return data.map((json) => Product.fromJson(json)).toList();
  }
  
  // ... other methods
}
```

---

## 🎯 MONITORING & ANALYTICS

### Key Metrics to Track:

#### **System Health:**
- Database connection pool usage
- Query performance (p50, p95, p99)
- API response times
- Error rates
- Uptime

#### **Business Metrics:**
- Daily Active Users (DAU)
- Monthly Active Users (MAU)
- Retention rate (Day 1, Day 7, Day 30)
- Churn rate
- Conversion rate (free → paid)

#### **Performance Metrics:**
- App load time
- Time to interactive
- Crash-free sessions
- Memory usage
- Battery usage

### Tools:
- **Sentry** - Error tracking
- **Firebase Analytics** - User behavior
- **Supabase Dashboard** - Database metrics
- **Custom Dashboards** - Business metrics

---

**Ready to build multi-tenant platform yang scale! 🚀**


