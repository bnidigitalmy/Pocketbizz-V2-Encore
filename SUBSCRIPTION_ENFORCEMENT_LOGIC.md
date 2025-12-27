# 🔒 Subscription Enforcement Logic

## 📊 Enforcement Behavior Summary

### ✅ **Allowed (NO Enforcement Block)**

1. **Active Users** (status: `active`, `trial`, `grace`)
   - ✅ Boleh INSERT/UPDATE semua tables (products, sales, stock, etc.)
   - ✅ Boleh create/edit/delete data
   - ✅ Full access to all features

2. **New Users** (no subscription yet)
   - ✅ Boleh create trial subscription (subscriptions table excluded)
   - ❌ TIDAK boleh INSERT/UPDATE other tables (products, sales, etc.)
   - ⚠️ **BUT**: After trial created → automatically become active → boleh access everything

3. **Subscription Operations** (for ALL users)
   - ✅ Boleh INSERT/UPDATE `subscriptions` table (excluded from enforcement)
   - ✅ Payment webhooks boleh update subscription status
   - ✅ Admin boleh create/manage subscriptions

### ❌ **Blocked (Enforcement Active)**

1. **Expired Users** (status: `expired`, no active subscription)
   - ❌ TIDAK boleh INSERT products, sales, stock, expenses, etc.
   - ❌ TIDAK boleh UPDATE existing data
   - ✅ BOLEH SELECT (read-only mode)
   - ✅ BOLEH DELETE own data
   - ✅ BOLEH create/renew subscription (to regain access)

---

## 🔍 How Enforcement Works

### Function: `check_subscription_active(user_uuid)`

```sql
-- Returns TRUE if user has active subscription
SELECT * FROM subscriptions
WHERE user_id = user_uuid
  AND status IN ('active', 'trial', 'grace')
  AND expires_at > NOW()
```

**Results:**
- ✅ Active/Trial/Grace users → Returns TRUE → Access allowed
- ❌ Expired users → Returns FALSE → Access blocked
- ❌ New users (no subscription) → Returns FALSE → Access blocked (until trial created)

### Function: `enforce_subscription_on_insert()`

```sql
-- Special case: subscriptions table
IF TG_TABLE_NAME = 'subscriptions' THEN
  RETURN NEW; -- ✅ ALWAYS ALLOW (no check)
END IF;

-- For all other tables
IF NOT check_subscription_active(auth.uid()) THEN
  RAISE EXCEPTION 'Subscription required...'; -- ❌ BLOCK
END IF;
```

---

## 📋 User Journey Examples

### Scenario 1: New User Registration

```
1. User register → No subscription yet
2. App calls initializeTrial() → INSERT subscriptions table
   ✅ ALLOWED (subscriptions table excluded)
3. Trial subscription created → status = 'trial'
4. User tries to add product → INSERT products table
   ✅ ALLOWED (now has active subscription)
```

### Scenario 2: Expired User

```
1. User subscription expired → status = 'expired'
2. User tries to add product → INSERT products table
   ❌ BLOCKED (enforcement active)
3. User tries to view products → SELECT products table
   ✅ ALLOWED (read-only mode)
4. User renews subscription → INSERT subscriptions table
   ✅ ALLOWED (subscriptions table excluded)
5. Subscription activated → status = 'active'
6. User tries to add product → INSERT products table
   ✅ ALLOWED (now has active subscription)
```

### Scenario 3: Active User

```
1. User has active subscription → status = 'active'
2. User tries to add product → INSERT products table
   ✅ ALLOWED (check_subscription_active returns TRUE)
3. User tries to update product → UPDATE products table
   ✅ ALLOWED (check_subscription_active returns TRUE)
```

---

## 🎯 Key Points

### ✅ What's Protected:
- **Products** - INSERT/UPDATE blocked for expired users
- **Sales** - INSERT blocked for expired users
- **Stock Items** - INSERT/UPDATE blocked for expired users
- **Expenses** - INSERT blocked for expired users
- **Bookings** - INSERT blocked for expired users
- **Deliveries** - INSERT blocked for expired users
- **Claims** - INSERT blocked for expired users
- **Production** - INSERT blocked for expired users

### ✅ What's NOT Protected (Always Allowed):
- **Subscriptions table** - INSERT/UPDATE always allowed (to create/renew)
- **SELECT operations** - Read-only mode for expired users
- **DELETE operations** - Users can delete own data

---

## 🔐 Security Levels

| User Status | INSERT/UPDATE Products/etc | INSERT/UPDATE Subscriptions | SELECT (Read) |
|-------------|---------------------------|----------------------------|---------------|
| **New User** (no subscription) | ❌ Blocked | ✅ Allowed | ✅ Allowed |
| **Trial User** | ✅ Allowed | ✅ Allowed | ✅ Allowed |
| **Active User** | ✅ Allowed | ✅ Allowed | ✅ Allowed |
| **Grace User** | ✅ Allowed | ✅ Allowed | ✅ Allowed |
| **Expired User** | ❌ Blocked | ✅ Allowed | ✅ Allowed |

---

## 🚨 Important Notes

1. **New Users CANNOT create products** until trial is created
   - But trial creation happens automatically during registration
   - So effectively, new users get immediate access after registration

2. **Expired Users CAN renew** subscription
   - Subscriptions table is excluded from enforcement
   - They can pay and reactivate without needing admin help

3. **Read-Only Mode** for expired users
   - Can view all data (SELECT allowed)
   - Cannot modify/create data (INSERT/UPDATE blocked)
   - Can delete own data (DELETE allowed - no enforcement)

4. **Subscription Creation** is special case
   - Must be allowed for all users (new, expired, active)
   - Otherwise, nobody can create subscriptions!
   - Creates circular dependency if blocked


