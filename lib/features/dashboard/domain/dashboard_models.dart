import '../../../data/api/models/inventory_models.dart';
import '../../../data/api/models/sales_models.dart';

class DashboardMetrics {
  DashboardMetrics({
    required this.todayProfit,
    required this.salesToday,
    required this.quickActions,
    required this.lowStockItems,
    required this.recentSales,
  });

  final double todayProfit;
  final double salesToday;
  final List<QuickAction> quickActions;
  final List<InventorySnapshot> lowStockItems;
  final List<Sale> recentSales;
}

class QuickAction {
  QuickAction({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final String route;
  final ActionIcon icon;
}

class ActionIcon {
  const ActionIcon(this.codePoint, {this.fontFamily = 'MaterialIcons'});

  final int codePoint;
  final String fontFamily;
}

