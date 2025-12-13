class SplitwiseExpense {
  final String date;
  final String description;
  final String category;
  final double cost;
  final String currency;
  final String paidBy;
  final Map<String, double> owedBy; // name -> amount

  SplitwiseExpense({
    required this.date,
    required this.description,
    required this.category,
    required this.cost,
    required this.currency,
    required this.paidBy,
    required this.owedBy,
  });

  // Get all unique users involved in this expense
  Set<String> get allUsers {
    final users = <String>{paidBy};
    users.addAll(owedBy.keys);
    return users;
  }

  @override
  String toString() {
    return 'SplitwiseExpense(date: $date, description: $description, cost: $cost, paidBy: $paidBy, owedBy: $owedBy)';
  }
}

class SplitwiseImportData {
  final List<SplitwiseExpense> allExpenses;
  final Set<String> allUsers;
  final Map<String, List<SplitwiseExpense>> expensesByUser;

  SplitwiseImportData({
    required this.allExpenses,
    required this.allUsers,
    required this.expensesByUser,
  });

  // Get expenses involving selected users
  List<SplitwiseExpense> getExpensesForUsers(Set<String> selectedUsers) {
    return allExpenses.where((expense) {
      return expense.allUsers.any((user) => selectedUsers.contains(user));
    }).toList();
  }

  // Get expense count for a user
  int getExpenseCountForUser(String userName) {
    return expensesByUser[userName]?.length ?? 0;
  }
}
