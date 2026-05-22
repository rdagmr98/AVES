import 'package:flutter/material.dart';

import '../models/activity_models.dart';
import '../services/currency_service.dart';

class CurrencyProvider extends ChangeNotifier {
  final _service = CurrencyService();
  List<CurrencyCriteria> _criteria = [];
  bool _isLoading = false;
  String? _error;

  List<CurrencyCriteria> get criteria => _criteria;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCriteria() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _criteria = await _service.getAllCriteria();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCriteria(CurrencyCriteria c, String updatedBy) async {
    await _service.updateCriteria(c, updatedBy);
    await loadCriteria();
  }
}
