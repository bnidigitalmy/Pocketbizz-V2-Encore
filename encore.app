{
	"app":         "pocketbizz-v2",
	"description": "PocketBizz V2 Encore backend for SME management",
	"lang":        "typescript",
	"services": [
		{"id": "products", "path": "./services/products"},
		{"id": "ingredients", "path": "./services/ingredients"},
		{"id": "inventory", "path": "./services/inventory"},
		{"id": "sales", "path": "./services/sales"},
		{"id": "expenses", "path": "./services/expenses"},
		{"id": "recipes", "path": "./services/recipes"},
		{"id": "vendors", "path": "./services/vendors"},
		{"id": "customers", "path": "./services/customers"},
		{"id": "myshop", "path": "./services/myshop"},
		{"id": "analytics", "path": "./services/analytics"},
		{"id": "production", "path": "./services/production"},
		{"id": "purchase", "path": "./services/purchase"},
		{"id": "bookings", "path": "./services/bookings"},
		{"id": "drive", "path": "./services/drive"},
		{"id": "suppliers", "path": "./services/suppliers"},
		{"id": "shopping", "path": "./services/shopping"},
		{"id": "consignment", "path": "./services/consignment"},
		{"id": "claims", "path": "./services/claims"},
		{"id": "payments", "path": "./services/payments"},
		{"id": "shared", "path": "./services/shared"}
	],
	"global_cors": {
		"allow_origins_without_credentials": ["*"]
	},
	"id": "pocketbizz-v2-gaki"
}
