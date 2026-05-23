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
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.updateCriteria(c, updatedBy);
      _criteria = await _service.getAllCriteria();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCriteriaFascia(
    CurrencyCriteria c,
    int periodDaysA,
    int? periodDaysBC,
    String updatedBy,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.updateCriteria(
        CurrencyCriteria(
          id: c.id,
          criteriaType: c.criteriaType,
          tobCapabilityId: c.tobCapabilityId,
          periodDays: periodDaysA,
          periodDaysA: periodDaysA,
          periodDaysBC: periodDaysBC,
          minHours: c.minHours,
          description: c.description,
          tobCapabilityName: c.tobCapabilityName,
        ),
        updatedBy,
      );
      _criteria = await _service.getAllCriteria();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
